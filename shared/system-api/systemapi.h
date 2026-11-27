#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>
#include <QVariantMap>
#include "procparse.h"
#include <QString>
#include <QStringList>
#include <QVariantList>

namespace VYLO {

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
    // Status shown in the bar. Anything the machine does not report is flagged
    // unavailable rather than guessed.
    Q_PROPERTY(QString networkState READ networkState NOTIFY statsChanged) // wired, wifi, offline
    Q_PROPERTY(int batteryPercent READ batteryPercent NOTIFY statsChanged) // -1: no battery
    Q_PROPERTY(bool batteryCharging READ batteryCharging NOTIFY statsChanged)
    Q_PROPERTY(double diskUsedPercent READ diskUsedPercent NOTIFY statsChanged) // -1: unknown
    Q_PROPERTY(double temperature READ temperature NOTIFY statsChanged) // Celsius, -1: no sensor
    Q_PROPERTY(int volume READ volume NOTIFY volumeChanged) // percent, -1: no audio service
    Q_PROPERTY(bool muted READ muted NOTIFY volumeChanged)
    Q_PROPERTY(QString userName READ userName CONSTANT)
    // "unconfigured" until a weather provider exists.
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
    QString weatherState() const { return QStringLiteral("unconfigured"); }

    QString networkState() const { return m_network; }
    int batteryPercent() const { return m_battery; }
    bool batteryCharging() const { return m_charging; }
    double diskUsedPercent() const { return m_disk; }
    double temperature() const { return m_temp; }
    int volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    QString userName() const;

    Q_INVOKABLE void setVolume(int percent);
    Q_INVOKABLE void toggleMute();
    Q_INVOKABLE void refreshVolume();
    // action: poweroff, reboot, suspend or logout. Anything else is refused.
    Q_INVOKABLE bool power(const QString &action);
    Q_INVOKABLE bool isPinned(const QString &id) const;
    Q_INVOKABLE void togglePin(const QString &id);
    Q_INVOKABLE QString wallpaperUrl(const QString &name, const QString &accent) const;

    // Validates and saves one preference. Unknown keys / bad values are ignored.
    Q_INVOKABLE void setPref(const QString &key, const QVariant &value);
    // Exposed for tests: returns an invalid QVariant if key or value is not allowed.
    static QVariant normalizePref(const QString &key, const QVariant &value);
    static QVariantMap defaultPrefs();
    static QStringList accentNames();
    static QStringList wallpaperNames();
    static QStringList defaultPins();
    static QStringList powerCommand(const QString &action);

    // Start a program from a command line (a .desktop Exec value or a plain
    // program name). Returns false if it could not be started.
    Q_INVOKABLE bool launch(const QString &commandLine);
    // Start the first installed terminal emulator. False if none is installed.
    Q_INVOKABLE bool openTerminal();
    Q_INVOKABLE void refreshApplications();

    // Exposed for tests.
    static QStringList commandToArgs(const QString &exec);
    static bool parseDesktopFile(const QString &path, QString *name, QString *exec,
                                 QString *icon = nullptr, QStringList *categories = nullptr);
    static QString findTerminal();

signals:
    void themeChanged();
    void applicationsChanged();
    void prefsChanged();
    void statsChanged();
    void volumeChanged();

private:
    static QString configFilePath();
    static QString readThemeFromDisk();
    static bool startDetachedClean(const QString &program, const QStringList &args);
    void onConfigDirChanged();
    static QVariantMap readPrefsFromDisk();
    void updateStats();
    void resolvePinned();
    void updateStatus();
    void runWpctl(const QStringList &args);

    QString m_theme;
    QVariantList m_applications;
    QString m_terminal;
    QFileSystemWatcher m_watcher;
    QVariantMap m_prefs;
    QVariantList m_pinned;
    QTimer m_statsTimer;
    vylo::CpuTimes m_prevCpu;
    bool m_havePrevCpu = false;
    QString m_network = QStringLiteral("offline");
    int m_battery = -1;
    bool m_charging = false;
    double m_disk = -1, m_temp = -1;
    int m_volume = -1;
    bool m_muted = false;
    bool m_statsOk = false;
    double m_cpu = 0, m_memPct = 0, m_memUsedGb = 0, m_memTotalGb = 0;
};

} // namespace VYLO
