#include "notifications.h"

#include <QDBusConnection>
#include <QDateTime>
#include <QPointer>
#include <QTimer>

namespace {
constexpr int kHistory = 30;
constexpr int kPopups = 3;
// Reasons from the specification.
constexpr uint kDismissed = 2;
constexpr uint kClosedByApp = 3;
}

Notifications::Notifications(QObject *parent)
    : QObject(parent)
{
}

bool Notifications::start()
{
    new NotificationsAdaptor(this);
    QDBusConnection bus = QDBusConnection::sessionBus();
    return bus.registerObject(QStringLiteral("/org/freedesktop/Notifications"), this)
        && bus.registerService(QStringLiteral("org.freedesktop.Notifications"));
}

QVariantList Notifications::popups() const
{
    QVariantList result;
    for (const QVariant &v : m_history) {
        if (m_popups.contains(v.toMap().value(QStringLiteral("id")).toUInt()))
            result.append(v);
        if (result.size() == kPopups)
            break;
    }
    return result;
}

void Notifications::setQuiet(bool quiet)
{
    if (quiet == m_quiet)
        return;
    m_quiet = quiet;
    if (quiet)
        m_popups.clear();
    emit quietChanged();
    emit changed();
}

uint Notifications::post(const QString &app, uint replaces, const QString &summary,
                         const QString &body, const QVariantMap &hints, int timeout)
{
    const uint id = replaces ? replaces : ++m_lastId;
    remove(id);
    const bool critical = hints.value(QStringLiteral("urgency")).toInt() == 2;
    // Lengths are capped: the text comes from other programs.
    m_history.prepend(QVariantMap{
        {QStringLiteral("id"), id},
        {QStringLiteral("app"), app.left(60)},
        {QStringLiteral("summary"), summary.left(160)},
        {QStringLiteral("body"), body.left(600)},
        {QStringLiteral("critical"), critical},
        {QStringLiteral("time"), QDateTime::currentDateTime().toString(QStringLiteral("HH:mm"))}});
    while (m_history.size() > kHistory)
        m_history.removeLast();

    if (!m_quiet || critical) {
        m_popups.append(id);
        // Critical notices and timeout 0 stay until the user closes them.
        if (!critical && timeout != 0) {
            const int wait = timeout < 0 ? 6000 : qBound(2000, timeout, 20000);
            QTimer::singleShot(wait, this, [this, id] { hidePopup(id); });
        }
    }
    emit changed();
    return id;
}

void Notifications::hidePopup(uint id)
{
    if (m_popups.removeAll(id))
        emit changed();
}

bool Notifications::remove(uint id)
{
    m_popups.removeAll(id);
    for (int i = 0; i < m_history.size(); ++i) {
        if (m_history.at(i).toMap().value(QStringLiteral("id")).toUInt() == id) {
            m_history.removeAt(i);
            return true;
        }
    }
    return false;
}

void Notifications::dismiss(uint id)
{
    if (remove(id)) {
        emit closed(id, kDismissed);
        emit changed();
    }
}

void Notifications::closeFromApp(uint id)
{
    if (remove(id)) {
        emit closed(id, kClosedByApp);
        emit changed();
    }
}

void Notifications::clearAll()
{
    const QVariantList old = m_history;
    m_history.clear();
    m_popups.clear();
    for (const QVariant &v : old)
        emit closed(v.toMap().value(QStringLiteral("id")).toUInt(), kDismissed);
    emit changed();
}

NotificationsAdaptor::NotificationsAdaptor(Notifications *service)
    : QDBusAbstractAdaptor(service)
    , m_service(service)
{
    connect(service, &Notifications::closed, this, &NotificationsAdaptor::NotificationClosed);
}

QStringList NotificationsAdaptor::GetCapabilities()
{
    return {QStringLiteral("body"), QStringLiteral("persistence")};
}

uint NotificationsAdaptor::Notify(const QString &app_name, uint replaces_id, const QString &,
                                  const QString &summary, const QString &body, const QStringList &,
                                  const QVariantMap &hints, int expire_timeout)
{
    return m_service->post(app_name, replaces_id, summary, body, hints, expire_timeout);
}

void NotificationsAdaptor::CloseNotification(uint id)
{
    m_service->closeFromApp(id);
}

QString NotificationsAdaptor::GetServerInformation(QString &vendor, QString &version, QString &spec_version)
{
    vendor = QStringLiteral("VYLO");
    version = QStringLiteral("0.4");
    spec_version = QStringLiteral("1.2");
    return QStringLiteral("vylo-shell");
}
