#include "systemapi.h"
#include "vylo_config.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QSet>
#include <QSettings>
#include <QStorageInfo>
#include <QUrl>
#include <QStandardPaths>
#include <QTextStream>
#include <algorithm>

namespace VYLO {

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
    refreshVolume();

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
    return QStringLiteral(VYLO_DISPLAY_NAME);
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
            QString icon;
            QStringList categories;
            if (!parseDesktopFile(fi.absoluteFilePath(), &name, &exec, &icon, &categories))
                continue;
            seenIds.insert(fi.fileName());
            // foot's server and client entries are plumbing, not applications.
            if (fi.completeBaseName() == QLatin1String("footclient")
                || fi.completeBaseName() == QLatin1String("foot-server"))
                continue;
            QVariantMap entry;
            entry.insert(QStringLiteral("name"), name);
            entry.insert(QStringLiteral("exec"), exec);
            entry.insert(QStringLiteral("id"), fi.completeBaseName());
            entry.insert(QStringLiteral("icon"), icon);
            entry.insert(QStringLiteral("categories"), categories);
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

bool SystemApi::parseDesktopFile(const QString &path, QString *name, QString *exec,
                                 QString *icon, QStringList *categories)
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
    QString parsedIcon;
    QString parsedCategories;

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
        else if (key == QLatin1String("Icon"))
            parsedIcon = value;
        else if (key == QLatin1String("Categories"))
            parsedCategories = value;
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
    if (parsedExec.startsWith(QLatin1String("vylo-shell")))
        return false;

    *name = parsedName;
    *exec = parsedExec;
    if (icon)
        *icon = parsedIcon;
    if (categories)
        *categories = parsedCategories.split(QLatin1Char(';'), Qt::SkipEmptyParts);
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
           + QStringLiteral("/vylo/vylo.conf");
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
        resolvePinned();
        emit applicationsChanged();
    }
    const QString onDisk = readThemeFromDisk();
    if (onDisk != m_theme) {
        m_theme = onDisk;
        emit themeChanged();
    }
}


QStringList SystemApi::accentNames()
{
    return {QStringLiteral("indigo"), QStringLiteral("lilac"), QStringLiteral("cyan"),
            QStringLiteral("rose"), QStringLiteral("amber")};
}

QStringList SystemApi::wallpaperNames()
{
    return {QStringLiteral("cosmos"), QStringLiteral("orbit-hills"), QStringLiteral("observatory-isles"),
            QStringLiteral("nebula-drift"), QStringLiteral("deep-void")};
}

QStringList SystemApi::defaultPins()
{
    // Desktop file names without ".desktop". Missing applications are skipped.
    return {QStringLiteral("vylo-install"), QStringLiteral("org.gnome.Nautilus"), QStringLiteral("helium"),
            QStringLiteral("foot"), QStringLiteral("org.gnome.TextEditor"),
            QStringLiteral("org.gnome.Software"), QStringLiteral("vylo-settings")};
}

QVariantMap SystemApi::defaultPrefs()
{
    return {{QStringLiteral("accent"), QStringLiteral("indigo")},
            {QStringLiteral("wallpaper"), QStringLiteral("cosmos")},
            {QStringLiteral("greeting"), QStringLiteral("Make Space Yours.")},
            {QStringLiteral("pins"), defaultPins().join(QLatin1Char(';'))},
            {QStringLiteral("reducedMotion"), false},
            {QStringLiteral("pipEnabled"), false},
            {QStringLiteral("welcomeDone"), false},
            {QStringLiteral("pipMode"), QStringLiteral("cheerful")},
            {QStringLiteral("showClock"), true},
            {QStringLiteral("showCalendar"), true},
            {QStringLiteral("showWeather"), false},
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
    if (key == QLatin1String("greeting")) {
        const QString v = value.toString().simplified();
        return v.size() <= 40 ? QVariant(v) : QVariant();
    }
    if (key == QLatin1String("pins")) {
        static const QRegularExpression valid(QStringLiteral("^[A-Za-z0-9._;-]{0,600}$"));
        // QSettings may hand back a list if the value held separators.
        const QString v = value.toStringList().join(QLatin1Char(';'));
        return valid.match(v).hasMatch() ? QVariant(v) : QVariant();
    }
    if (key == QLatin1String("pipMode")) {
        static const QStringList modes{QStringLiteral("cheerful"), QStringLiteral("quiet"),
                                       QStringLiteral("sleepy"), QStringLiteral("explorer")};
        return modes.contains(value.toString()) ? QVariant(value.toString()) : QVariant();
    }
    if (key == QLatin1String("reducedMotion") || key == QLatin1String("pipEnabled")
        || key == QLatin1String("welcomeDone")
        || (key.startsWith(QLatin1String("show")) && defaultPrefs().contains(key))) {
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
    if (key == QLatin1String("pins")) {
        resolvePinned();
        emit applicationsChanged();
    }
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
    vylo::CpuTimes cpu;
    vylo::MemInfo mem;
    const bool cpuOk = vylo::parseCpuTimes(slurp("/proc/stat"), &cpu);
    const bool memOk = vylo::parseMemInfo(slurp("/proc/meminfo"), &mem);
    m_statsOk = cpuOk && memOk;
    if (cpuOk) {
        if (m_havePrevCpu)
            m_cpu = vylo::cpuPercent(m_prevCpu, cpu);
        m_prevCpu = cpu;
        m_havePrevCpu = true;
    }
    if (memOk) {
        m_memPct = vylo::memUsedPercent(mem);
        m_memTotalGb = double(mem.totalKb) / 1048576.0;
        m_memUsedGb = double(mem.totalKb - mem.availableKb) / 1048576.0;
    }
    updateStatus();
    emit statsChanged();
}

void SystemApi::resolvePinned()
{
    // Pins are matched against installed applications, in the user's order.
    const QStringList wanted = m_prefs.value(QStringLiteral("pins")).toString()
                                   .split(QLatin1Char(';'), Qt::SkipEmptyParts);
    QVariantList pinned;
    for (const QString &id : wanted) {
        for (const QVariant &v : std::as_const(m_applications)) {
            if (v.toMap().value(QStringLiteral("id")).toString() == id) {
                pinned.append(v);
                break;
            }
        }
    }
    m_pinned = pinned;
}

bool SystemApi::isPinned(const QString &id) const
{
    return m_prefs.value(QStringLiteral("pins")).toString()
        .split(QLatin1Char(';'), Qt::SkipEmptyParts).contains(id);
}

void SystemApi::togglePin(const QString &id)
{
    QStringList pins = m_prefs.value(QStringLiteral("pins")).toString()
                           .split(QLatin1Char(';'), Qt::SkipEmptyParts);
    if (!pins.removeOne(id))
        pins.append(id);
    setPref(QStringLiteral("pins"), pins.join(QLatin1Char(';')));
}

QString SystemApi::wallpaperUrl(const QString &name, const QString &accent) const
{
    QString file = wallpaperNames().contains(name) ? name : wallpaperNames().first();
    // "cosmos" and "orbit-hills" have one picture per accent colour.
    if (file == QLatin1String("cosmos") || file == QLatin1String("orbit-hills"))
        file += QLatin1Char('-') + (accentNames().contains(accent) ? accent : accentNames().first());
    // VYLO_DATA_DIR lets the preview run from a source tree.
    const QString base = qEnvironmentVariable("VYLO_DATA_DIR", QStringLiteral("/usr/share"));
    return QUrl::fromLocalFile(base + QStringLiteral("/wallpapers/vylo/") + file
                               + QStringLiteral(".jpg")).toString();
}

bool SystemApi::pipInstalled() const
{
    return !QStandardPaths::findExecutable(QStringLiteral("vylo-pip")).isEmpty();
}

bool SystemApi::pipEnabledOnDisk()
{
    return readPrefsFromDisk().value(QStringLiteral("pipEnabled")).toBool();
}

bool SystemApi::live() const
{
    if (qEnvironmentVariableIsSet("VYLO_LIVE"))
        return true;
    QFile cmdline(QStringLiteral("/proc/cmdline"));
    return cmdline.open(QIODevice::ReadOnly) && cmdline.readAll().contains("rd.live.image");
}

QString SystemApi::userName() const
{
    return qEnvironmentVariable("USER");
}

namespace {
QString readLine(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return QString::fromLatin1(f.readAll()).trimmed();
}
} // namespace

void SystemApi::updateStatus()
{
    QString network = QStringLiteral("offline");
    const QDir net(QStringLiteral("/sys/class/net"));
    const QStringList links = net.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &name : links) {
        const QString dir = net.filePath(name);
        // Only hardware interfaces (they have a "device" link).
        if (!QFileInfo::exists(dir + QStringLiteral("/device"))
            || readLine(dir + QStringLiteral("/operstate")) != QLatin1String("up"))
            continue;
        if (QFileInfo::exists(dir + QStringLiteral("/wireless"))) {
            network = QStringLiteral("wifi");
        } else {
            network = QStringLiteral("wired");
            break;
        }
    }
    m_network = network;

    m_battery = -1;
    m_charging = false;
    const QDir power(QStringLiteral("/sys/class/power_supply"));
    const QStringList supplies = power.entryList({QStringLiteral("BAT*")}, QDir::Dirs);
    if (!supplies.isEmpty()) {
        bool ok = false;
        const int level = readLine(power.filePath(supplies.first()) + QStringLiteral("/capacity")).toInt(&ok);
        if (ok)
            m_battery = qBound(0, level, 100);
        m_charging = readLine(power.filePath(supplies.first()) + QStringLiteral("/status"))
                     == QLatin1String("Charging");
    }

    // The live system's root is an overlay, so report the home directory's disk.
    const QStorageInfo disk(QDir::homePath());
    m_disk = (disk.isValid() && disk.bytesTotal() > 0)
                 ? 100.0 * double(disk.bytesTotal() - disk.bytesAvailable()) / double(disk.bytesTotal())
                 : -1;

    m_temp = -1;
    const QDir thermal(QStringLiteral("/sys/class/thermal"));
    const QStringList zones = thermal.entryList({QStringLiteral("thermal_zone*")}, QDir::Dirs);
    for (const QString &zone : zones) {
        bool ok = false;
        const double milli = readLine(thermal.filePath(zone) + QStringLiteral("/temp")).toDouble(&ok);
        if (ok && milli > 0)
            m_temp = qMax(m_temp, milli / 1000.0);
    }
}

void SystemApi::refreshVolume()
{
    runWpctl({QStringLiteral("get-volume"), QStringLiteral("@DEFAULT_AUDIO_SINK@")});
}

void SystemApi::setVolume(int percent)
{
    const QString value = QString::number(qBound(0, percent, 100) / 100.0, 'f', 2);
    runWpctl({QStringLiteral("set-volume"), QStringLiteral("@DEFAULT_AUDIO_SINK@"), value});
}

void SystemApi::toggleMute()
{
    runWpctl({QStringLiteral("set-mute"), QStringLiteral("@DEFAULT_AUDIO_SINK@"), QStringLiteral("toggle")});
}

// Runs wpctl without blocking the desktop. A change is followed by a read, so
// the bar shows what the audio service really did.
void SystemApi::runWpctl(const QStringList &args)
{
    auto *process = new QProcess(this);
    const bool reading = args.first() == QLatin1String("get-volume");
    connect(process, &QProcess::errorOccurred, process, &QObject::deleteLater);
    connect(process, &QProcess::finished, this, [this, process, reading](int code) {
        process->deleteLater();
        if (!reading) {
            refreshVolume();
            return;
        }
        // Output: "Volume: 0.40" or "Volume: 0.40 [MUTED]"
        const QString out = QString::fromUtf8(process->readAllStandardOutput());
        static const QRegularExpression pattern(QStringLiteral("Volume:\\s*([0-9.]+)"));
        const auto match = pattern.match(out);
        m_volume = (code == 0 && match.hasMatch()) ? qRound(match.captured(1).toDouble() * 100) : -1;
        m_muted = out.contains(QLatin1String("[MUTED]"));
        emit volumeChanged();
    });
    process->start(QStringLiteral("wpctl"), args);
}

QStringList SystemApi::powerCommand(const QString &action)
{
    if (action == QLatin1String("poweroff") || action == QLatin1String("reboot")
        || action == QLatin1String("suspend"))
        return {QStringLiteral("systemctl"), action};
    if (action == QLatin1String("logout"))
        return {QStringLiteral("labwc"), QStringLiteral("--exit")};
    return {};
}

bool SystemApi::power(const QString &action)
{
    QStringList command = powerCommand(action);
    if (command.isEmpty())
        return false;
    const QString program = command.takeFirst();
    return startDetachedClean(program, command);
}

} // namespace VYLO
