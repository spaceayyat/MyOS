#pragma once

#include <QDBusAbstractAdaptor>
#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

// The desktop's notification service (org.freedesktop.Notifications): shows
// what applications send and keeps a short history until the session ends.
class Notifications : public QObject
{
    Q_OBJECT
    // Newest first. Each entry: id, app, summary, body, critical, time.
    Q_PROPERTY(QVariantList history READ history NOTIFY changed)
    Q_PROPERTY(QVariantList popups READ popups NOTIFY changed)
    Q_PROPERTY(bool quiet READ quiet WRITE setQuiet NOTIFY quietChanged)

public:
    explicit Notifications(QObject *parent = nullptr);

    // Claims the service name. False if another service already has it.
    bool start();

    QVariantList history() const { return m_history; }
    QVariantList popups() const;
    bool quiet() const { return m_quiet; }
    void setQuiet(bool quiet);

    uint post(const QString &app, uint replaces, const QString &summary,
              const QString &body, const QVariantMap &hints, int timeout);

    Q_INVOKABLE void hidePopup(uint id);   // stays in the history
    Q_INVOKABLE void dismiss(uint id);
    Q_INVOKABLE void clearAll();
    void closeFromApp(uint id);

signals:
    void changed();
    void quietChanged();
    void closed(uint id, uint reason);

private:
    bool remove(uint id);

    QVariantList m_history;
    QList<uint> m_popups;
    uint m_lastId = 0;
    bool m_quiet = false;
};

// The D-Bus face of the class above, as the specification names it.
class NotificationsAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")

public:
    explicit NotificationsAdaptor(Notifications *service);

public slots:
    QStringList GetCapabilities();
    uint Notify(const QString &app_name, uint replaces_id, const QString &app_icon,
                const QString &summary, const QString &body, const QStringList &actions,
                const QVariantMap &hints, int expire_timeout);
    void CloseNotification(uint id);
    QString GetServerInformation(QString &vendor, QString &version, QString &spec_version);

signals:
    void NotificationClosed(uint id, uint reason);
    void ActionInvoked(uint id, const QString &action_key);

private:
    Notifications *m_service;
};
