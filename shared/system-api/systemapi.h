#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>
#include <QVariantMap>
#include "procparse.h"
#include <QString>
#include <QStringList>
#include <QVariantList>

namespace MyOS {

// Small, typed bridge between the QML desktop and the system.
//
// Deliberate limits (see docs/security.md):
//  * It never runs shell command strings. Programs are started directly with
//    an argument list.
//  * It only reads .desktop files from the standard application directories.
//  * The only thing it writes is the user's own config file.
class SystemApi : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString osName READ osName CONSTANT)
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY themeChanged)
    Q_PROPERTY(QVariantList applications READ applications NOTIFY applicationsChanged)
    Q_PROPERTY(bool terminalAvailable READ terminalAvailable CONSTANT)
    // User preferences: accent, wallpaper, showClock/showCalendar/showWeather/showMonitor.
    Q_PROPERTY(QVariantMap prefs READ prefs NOTIFY prefsChanged)
    Q_PROPERTY(QVariantList pinnedApps READ pinnedApps NOTIFY applicationsChanged)
    // Real system data read from /proc. statsAvailable is false if unreadable.
    Q_PROPERTY(bool statsAvailable READ statsAvailable NOTIFY statsChanged)
    Q_PROPERTY(double cpuPercent READ cpuPercent NOTIFY statsChanged)
    Q_PROPERTY(double memUsedPercent READ memUsedPercent NOTIFY statsChanged)
    Q_PROPERTY(double memUsedGb READ memUsedGb NOTIFY statsChanged)
    Q_PROPERTY(double memTotalGb READ memTotalGb NOTIFY statsChanged)
    // Capability flags. Both are false until a real integration exists.
    Q_PROPERTY(bool windowManagementAvailable READ windowManagementAvailable CONSTANT)
    Q_PROPERTY(QString weatherState READ weatherState CONSTANT) // "unconfigured"

public:
    explicit SystemApi(QObject *parent = nullptr);

    QString osName() const;
    QString theme() const;
    void setTheme(const QString &theme);
    QVariantList applications() const;
    bool terminalAvailable() const;
    QVariantMap prefs() const { return m_prefs; }
    QVariantList pinnedApps() const { return m_pinned; }
    bool statsAvailable() const { return m_statsOk; }
    double cpuPercent() const { return m_cpu; }
    double memUsedPercent() const { return m_memPct; }
    double memUsedGb() const { return m_memUsedGb; }
    double memTotalGb() const { return m_memTotalGb; }
    bool windowManagementAvailable() const { return false; }
    QString weatherState() const { return QStringLiteral("unconfigured"); }

    // Validates and saves one preference. Unknown keys / bad values are ignored.
    Q_INVOKABLE void setPref(const QString &key, const QVariant &value);
    // Exposed for tests: returns an invalid QVariant if key or value is not allowed.
    static QVariant normalizePref(const QString &key, const QVariant &value);
    static QVariantMap defaultPrefs();
    static QStringList accentNames();
    static QStringList wallpaperNames();

    // Start a program from a command line (a .desktop Exec value or a plain
    // program name). Returns false if it could not be started.
    Q_INVOKABLE bool launch(const QString &commandLine);
    // Start the first installed terminal emulator. False if none is installed.
    Q_INVOKABLE bool openTerminal();
    Q_INVOKABLE void refreshApplications();

    // Exposed for tests.
    static QStringList commandToArgs(const QString &exec);
    static bool parseDesktopFile(const QString &path, QString *name, QString *exec);
    static QString findTerminal();

signals:
    void themeChanged();
    void applicationsChanged();
    void prefsChanged();
    void statsChanged();

private:
    static QString configFilePath();
    static QString readThemeFromDisk();
    static bool startDetachedClean(const QString &program, const QStringList &args);
    void onConfigDirChanged();
    static QVariantMap readPrefsFromDisk();
    void updateStats();
    void resolvePinned();

    QString m_theme;
    QVariantList m_applications;
    QString m_terminal;
    QFileSystemWatcher m_watcher;
    QVariantMap m_prefs;
    QVariantList m_pinned;
    QTimer m_statsTimer;
    myos::CpuTimes m_prevCpu;
    bool m_havePrevCpu = false;
    bool m_statsOk = false;
    double m_cpu = 0, m_memPct = 0, m_memUsedGb = 0, m_memTotalGb = 0;
};

} // namespace MyOS
