#include "systemapi.h"
#include "myos_config.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QSet>
#include <QSettings>
#include <QStandardPaths>
#include <QTextStream>
#include <algorithm>

namespace MyOS {

namespace {
const QString kLight = QStringLiteral("light");
const QString kDark = QStringLiteral("dark");

QString normalizeTheme(const QString &value)
{
    return value == kLight ? kLight : kDark; // dark is the default
}
} // namespace

SystemApi::SystemApi(QObject *parent)
    : QObject(parent)
{
    m_theme = readThemeFromDisk();
    m_terminal = findTerminal();
    m_prefs = readPrefsFromDisk();
    connect(&m_statsTimer, &QTimer::timeout, this, &SystemApi::updateStats);
    m_statsTimer.start(2000);
    updateStats();

    // Watch the config directory (not the file): QSettings replaces the file
    // atomically, which would drop a file-level watch. This is what keeps the
    // shell and the settings app in sync when the theme is changed.
    const QString dir = QFileInfo(configFilePath()).absolutePath();
    QDir().mkpath(dir);
    m_watcher.addPath(dir);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this,
            [this](const QString &) { onConfigDirChanged(); });

    refreshApplications();
}

QString SystemApi::osName() const
{
    return QStringLiteral(MYOS_DISPLAY_NAME);
}

QString SystemApi::theme() const
{
    return m_theme;
}

void SystemApi::setTheme(const QString &theme)
{
    const QString normalized = normalizeTheme(theme);
    if (normalized == m_theme)
        return;
    m_theme = normalized;

    QSettings settings(configFilePath(), QSettings::IniFormat);
    settings.setValue(QStringLiteral("appearance/theme"), m_theme);
    settings.sync();

    emit themeChanged();
}

QVariantList SystemApi::applications() const
{
    return m_applications;
}

bool SystemApi::terminalAvailable() const
{
    return !m_terminal.isEmpty();
}

bool SystemApi::launch(const QString &commandLine)
{
    QStringList args = commandToArgs(commandLine);
    if (args.isEmpty())
        return false;
    const QString program = args.takeFirst();
    return startDetachedClean(program, args);
}

bool SystemApi::openTerminal()
{
    if (m_terminal.isEmpty())
        return false;
    return startDetachedClean(m_terminal, {});
}

void SystemApi::refreshApplications()
{
    QVariantList result;
    QSet<QString> seenIds;

    const QStringList dirs =
        QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);
    for (const QString &dirPath : dirs) {
        const QDir dir(dirPath);
        const QFileInfoList files =
            dir.entryInfoList({QStringLiteral("*.desktop")}, QDir::Files, QDir::Name);
        for (const QFileInfo &fi : files) {
            if (seenIds.contains(fi.fileName()))
                continue; // earlier directories (user) win
            QString name;
            QString exec;
            if (!parseDesktopFile(fi.absoluteFilePath(), &name, &exec))
                continue;
            seenIds.insert(fi.fileName());
            QVariantMap entry;
            entry.insert(QStringLiteral("name"), name);
            entry.insert(QStringLiteral("exec"), exec);
            result.append(entry);
        }
    }

    std::sort(result.begin(), result.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value(QStringLiteral("name")).toString().compare(
                   b.toMap().value(QStringLiteral("name")).toString(),
                   Qt::CaseInsensitive) < 0;
    });

    m_applications = result;
    resolvePinned();
    emit applicationsChanged();
}

QStringList SystemApi::commandToArgs(const QString &exec)
{
    static const QRegularExpression fieldCode(QStringLiteral("%[a-zA-Z]"));
    QStringList out;
    const QStringList parts = QProcess::splitCommand(exec);
    for (QString part : parts) {
        part.replace(QStringLiteral("%%"), QStringLiteral("\x01"));
        part.remove(fieldCode);
        part.replace(QLatin1Char('\x01'), QLatin1Char('%'));
        if (!part.isEmpty())
            out.append(part);
    }
    return out;
}

bool SystemApi::parseDesktopFile(const QString &path, QString *name, QString *exec)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return false;

    QTextStream in(&file);
    bool inEntry = false;
    bool hidden = false;
    QString type;
    QString parsedName;
    QString parsedExec;

    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#')))
            continue;
        if (line.startsWith(QLatin1Char('['))) {
            inEntry = (line == QLatin1String("[Desktop Entry]"));
            continue;
        }
        if (!inEntry)
            continue;
        const int eq = line.indexOf(QLatin1Char('='));
        if (eq <= 0)
            continue;
        const QString key = line.left(eq).trimmed();
        const QString value = line.mid(eq + 1).trimmed();
        if (key == QLatin1String("Name"))
            parsedName = value;
        else if (key == QLatin1String("Exec"))
            parsedExec = value;
        else if (key == QLatin1String("Type"))
            type = value;
        else if (key == QLatin1String("NoDisplay") || key == QLatin1String("Hidden")) {
            if (value.compare(QLatin1String("true"), Qt::CaseInsensitive) == 0)
                hidden = true;
        }
    }

    if (hidden || type != QLatin1String("Application") || parsedName.isEmpty()
        || parsedExec.isEmpty())
        return false;
    // The desktop must not list itself.
    if (parsedExec.startsWith(QLatin1String("myos-shell")))
        return false;

    *name = parsedName;
    *exec = parsedExec;
    return true;
}

QString SystemApi::findTerminal()
{
    // Wayland-native terminals first, then common alternatives.
    static const QStringList candidates = {
        QStringLiteral("foot"),          QStringLiteral("alacritty"),
        QStringLiteral("kitty"),         QStringLiteral("ptyxis"),
        QStringLiteral("gnome-terminal"), QStringLiteral("konsole"),
        QStringLiteral("xfce4-terminal"), QStringLiteral("lxterminal"),
        QStringLiteral("xterm"),
    };
    for (const QString &name : candidates) {
        const QString path = QStandardPaths::findExecutable(name);
        if (!path.isEmpty())
            return path;
    }
    return {};
}

QString SystemApi::configFilePath()
{
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
           + QStringLiteral("/myos/myos.conf");
}

QString SystemApi::readThemeFromDisk()
{
    // A fresh QSettings object each time avoids stale cached values.
    QSettings settings(configFilePath(), QSettings::IniFormat);
    return normalizeTheme(
        settings.value(QStringLiteral("appearance/theme"), kDark).toString());
}

bool SystemApi::startDetachedClean(const QString &program, const QStringList &args)
{
    // layer-shell-qt makes the *shell* process use the layer-shell surface
    // role through this variable. Child applications must get normal windows,
    // so it is removed from their environment.
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.remove(QStringLiteral("QT_WAYLAND_SHELL_INTEGRATION"));

    QProcess process;
    process.setProgram(program);
    process.setArguments(args);
    process.setProcessEnvironment(env);
    return process.startDetached();
}

void SystemApi::onConfigDirChanged()
{
    const QVariantMap prefsOnDisk = readPrefsFromDisk();
    if (prefsOnDisk != m_prefs) {
        m_prefs = prefsOnDisk;
        emit prefsChanged();
    }
    const QString onDisk = readThemeFromDisk();
    if (onDisk != m_theme) {
        m_theme = onDisk;
        emit themeChanged();
    }
}


QStringList SystemApi::accentNames()
{
    return {QStringLiteral("blue"), QStringLiteral("teal"), QStringLiteral("violet"),
            QStringLiteral("rose"), QStringLiteral("amber")};
}

QStringList SystemApi::wallpaperNames()
{
    return {QStringLiteral("midnight"), QStringLiteral("aurora"),
            QStringLiteral("graphite"), QStringLiteral("dusk")};
}

QVariantMap SystemApi::defaultPrefs()
{
    return {{QStringLiteral("accent"), QStringLiteral("blue")},
            {QStringLiteral("wallpaper"), QStringLiteral("midnight")},
            {QStringLiteral("showClock"), true},
            {QStringLiteral("showCalendar"), true},
            {QStringLiteral("showWeather"), true},
            {QStringLiteral("showMonitor"), true}};
}

QVariant SystemApi::normalizePref(const QString &key, const QVariant &value)
{
    if (key == QLatin1String("accent")) {
        const QString v = value.toString();
        return accentNames().contains(v) ? QVariant(v) : QVariant();
    }
    if (key == QLatin1String("wallpaper")) {
        const QString v = value.toString();
        return wallpaperNames().contains(v) ? QVariant(v) : QVariant();
    }
    if (key.startsWith(QLatin1String("show")) && defaultPrefs().contains(key)) {
        if (value.typeId() == QMetaType::Bool)
            return value;
        const QString v = value.toString().toLower();
        if (v == QLatin1String("true")) return true;
        if (v == QLatin1String("false")) return false;
    }
    return {};
}

QVariantMap SystemApi::readPrefsFromDisk()
{
    QSettings settings(configFilePath(), QSettings::IniFormat);
    QVariantMap out = defaultPrefs();
    for (auto it = out.begin(); it != out.end(); ++it) {
        const QVariant raw = settings.value(QStringLiteral("prefs/") + it.key());
        if (!raw.isValid())
            continue;
        const QVariant ok = normalizePref(it.key(), raw);
        if (ok.isValid())
            it.value() = ok;
    }
    return out;
}

void SystemApi::setPref(const QString &key, const QVariant &value)
{
    const QVariant ok = normalizePref(key, value);
    if (!ok.isValid() || m_prefs.value(key) == ok)
        return;
    m_prefs.insert(key, ok);
    QSettings settings(configFilePath(), QSettings::IniFormat);
    settings.setValue(QStringLiteral("prefs/") + key, ok);
    settings.sync();
    emit prefsChanged();
}

namespace {
std::string slurp(const char *path)
{
    QFile f(QString::fromLatin1(path));
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return f.readAll().toStdString(); // /proc files report size 0, so readAll
}
} // namespace

void SystemApi::updateStats()
{
    myos::CpuTimes cpu;
    myos::MemInfo mem;
    const bool cpuOk = myos::parseCpuTimes(slurp("/proc/stat"), &cpu);
    const bool memOk = myos::parseMemInfo(slurp("/proc/meminfo"), &mem);
    m_statsOk = cpuOk && memOk;
    if (cpuOk) {
        if (m_havePrevCpu)
            m_cpu = myos::cpuPercent(m_prevCpu, cpu);
        m_prevCpu = cpu;
        m_havePrevCpu = true;
    }
    if (memOk) {
        m_memPct = myos::memUsedPercent(mem);
        m_memTotalGb = double(mem.totalKb) / 1048576.0;
        m_memUsedGb = double(mem.totalKb - mem.availableKb) / 1048576.0;
    }
    emit statsChanged();
}

void SystemApi::resolvePinned()
{
    // Pinned apps are matched against installed .desktop metadata; anything
    // not installed is simply not shown.
    static const QStringList wanted = {QStringLiteral("foot"), QStringLiteral("myos-settings")};
    QVariantList pinned;
    for (const QString &program : wanted) {
        for (const QVariant &v : std::as_const(m_applications)) {
            const QVariantMap app = v.toMap();
            const QStringList args = commandToArgs(app.value(QStringLiteral("exec")).toString());
            if (!args.isEmpty() && QFileInfo(args.first()).fileName() == program) {
                pinned.append(app);
                break;
            }
        }
    }
    m_pinned = pinned;
}

} // namespace MyOS
