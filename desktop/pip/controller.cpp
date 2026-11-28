#include "controller.h"

#include <QCoreApplication>
#include <QDate>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRandomGenerator>
#include <QProcess>
#include <QStandardPaths>
#include <QTime>
#include <QTimer>
#include <QUrlQuery>

#include "systemapi.h"

namespace {
bool start(const QString &program, const QStringList &args)
{
    return !QStandardPaths::findExecutable(program).isEmpty()
           && QProcess::startDetached(program, args);
}

QString notesFile()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
           + QStringLiteral("/vylo/pip-notes.txt");
}

QString duration(int seconds)
{
    if (seconds % 3600 == 0) return QStringLiteral("%1 h").arg(seconds / 3600);
    if (seconds % 60 == 0)   return QStringLiteral("%1 min").arg(seconds / 60);
    return QStringLiteral("%1 s").arg(seconds);
}
} // namespace

Controller::Controller(VYLO::SystemApi *system, QObject *parent)
    : QObject(parent)
    , m_system(system)
{
    connect(&m_downloader, &Downloader::progress, this, [this](int percent) {
        if (percent != m_percent) {
            m_percent = percent;
            emit downloadChanged();
        }
    });
    connect(&m_downloader, &Downloader::finished, this, [this](bool ok, const QString &message) {
        m_percent = -1;
        emit downloadChanged();
        reply(ok ? QStringLiteral("Saved to %1. I haven't opened it.").arg(message)
                 : QStringLiteral("That download didn't work. %1").arg(message));
        setOpen(true);
    });
    add(QStringLiteral("Hi, I'm PIP. Try \"open files\", or type \"help\"."), false);
}

void Controller::setOpen(bool open)
{
    if (open == m_open)
        return;
    m_open = open;
    if (open)
        m_system->refreshApplications();
    emit openChanged();
}

void Controller::add(const QString &text, bool mine)
{
    m_messages.append(QVariantMap{{QStringLiteral("mine"), mine}, {QStringLiteral("text"), text}});
    while (m_messages.size() > 40) // memory stays small
        m_messages.removeFirst();
    emit messagesChanged();
}

void Controller::reply(const QString &text)
{
    add(text, false);
    emit spoke();
}

void Controller::ask(const QString &question, std::function<void()> action)
{
    m_pending = std::move(action);
    emit askingChanged();
    reply(question);
}

void Controller::answer(bool yes)
{
    if (!m_pending)
        return;
    const auto action = std::move(m_pending);
    m_pending = nullptr;
    emit askingChanged();
    add(yes ? QStringLiteral("Yes") : QStringLiteral("No"), true);
    if (yes)
        action();
    else
        reply(QStringLiteral("Okay, leaving it."));
}

void Controller::cancelDownload()
{
    m_downloader.cancel();
}

void Controller::say(const QString &text)
{
    const QString line = text.simplified();
    if (line.isEmpty())
        return;
    // A new request drops an unanswered question: nothing runs by accident.
    if (m_pending) {
        m_pending = nullptr;
        emit askingChanged();
    }
    add(line.left(500), true);
    run(Pip::parse(line));
}

QVariantMap Controller::findApp(const QString &name) const
{
    QString wanted = name.toLower();
    const QHash<QString, QString> nicknames{
        {QStringLiteral("browser"), QStringLiteral("helium")},
        {QStringLiteral("terminal"), QStringLiteral("foot")},
        {QStringLiteral("settings"), QStringLiteral("vylo os settings")},
        {QStringLiteral("store"), QStringLiteral("software")},
        {QStringLiteral("file manager"), QStringLiteral("files")}};
    wanted = nicknames.value(wanted, wanted);

    // Exact name first, then a name that starts or contains the words.
    for (int pass = 0; pass < 3; ++pass) {
        if (pass == 2 && wanted.size() < 3)
            break;
        for (const QVariant &v : m_system->applications()) {
            const QVariantMap app = v.toMap();
            const QString title = app.value(QStringLiteral("name")).toString().toLower();
            const QString id = app.value(QStringLiteral("id")).toString().toLower();
            if ((pass == 0 && (title == wanted || id == wanted))
                || (pass == 1 && title.startsWith(wanted))
                || (pass == 2 && title.contains(wanted)))
                return app;
        }
    }
    return {};
}

void Controller::openLink(const QUrl &url)
{
    reply(start(QStringLiteral("xdg-open"), {url.toString(QUrl::FullyEncoded)})
              ? QStringLiteral("Opening %1.").arg(url.host())
              : QStringLiteral("I couldn't open a browser."));
}

void Controller::openThing(const QString &name)
{
    const QVariantMap app = findApp(name);
    if (!app.isEmpty()) {
        const QString title = app.value(QStringLiteral("name")).toString();
        reply(m_system->launch(app.value(QStringLiteral("exec")).toString())
                  ? QStringLiteral("Opening %1.").arg(title)
                  : QStringLiteral("%1 would not start.").arg(title));
        return;
    }
    const QUrl url = Pip::webAddress(name);
    if (url.isValid()) {
        openLink(url);
        return;
    }
    ask(QStringLiteral("I can't find an app called \"%1\". Look for it in Software?").arg(name),
        [this, name] { run(Pip::Intent{QStringLiteral("install"), name, 0}); });
}

void Controller::takeScreenshot()
{
    if (QStandardPaths::findExecutable(QStringLiteral("grim")).isEmpty()) {
        reply(QStringLiteral("The screenshot tool (grim) isn't installed."));
        return;
    }
    const QString folder = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    QDir().mkpath(folder);
    const QString path = Pip::freePath(folder, QStringLiteral("Screenshot %1.png")
        .arg(QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH-mm-ss"))));
    setOpen(false); // stay out of the picture
    QTimer::singleShot(500, this, [this, path] {
        auto *grim = new QProcess(this);
        connect(grim, &QProcess::finished, this, [this, grim, path](int code, QProcess::ExitStatus status) {
            grim->deleteLater();
            reply(code == 0 && status == QProcess::NormalExit
                      ? QStringLiteral("Screenshot saved to %1.").arg(path)
                      : QStringLiteral("The screenshot failed."));
            setOpen(true);
        });
        grim->start(QStringLiteral("grim"), {path});
    });
}

void Controller::run(const Pip::Intent &in)
{
    const QString &a = in.action;
    if (a == QLatin1String("help")) {
        reply(QStringLiteral("I can:\n"
                             "• open files  /  open github.com\n"
                             "• search moon phases\n"
                             "• download https://…\n"
                             "• install gimp\n"
                             "• remind me in 10 minutes to stretch, reminders\n"
                             "• note buy tea, notes\n"
                             "• 12 * (3 + 4), screenshot, open downloads\n"
                             "• volume 40, mute, dark mode, accent lilac\n"
                             "• status, time, restart, shut down\n"
                             "• quiet / sleepy / explorer / cheerful, bye"));
    } else if (a == QLatin1String("hello")) {
        reply(QStringLiteral("Hello! What shall we do?"));
    } else if (a == QLatin1String("thanks")) {
        reply(QStringLiteral("Any time."));
    } else if (a == QLatin1String("time")) {
        reply(QStringLiteral("It's %1.").arg(QTime::currentTime().toString(QStringLiteral("HH:mm"))));
    } else if (a == QLatin1String("date")) {
        reply(QStringLiteral("Today is %1.").arg(QDate::currentDate().toString(QStringLiteral("dddd, d MMMM yyyy"))));
    } else if (a == QLatin1String("status")) {
        QStringList parts;
        if (m_system->statsAvailable())
            parts << QStringLiteral("Processor %1%").arg(qRound(m_system->cpuPercent()))
                  << QStringLiteral("memory %1%").arg(qRound(m_system->memUsedPercent()));
        if (m_system->diskUsedPercent() >= 0)
            parts << QStringLiteral("disk %1% full").arg(qRound(m_system->diskUsedPercent()));
        if (m_system->batteryPercent() >= 0)
            parts << QStringLiteral("battery %1%").arg(m_system->batteryPercent());
        reply(parts.isEmpty() ? QStringLiteral("This machine isn't telling me.") : parts.join(QStringLiteral(", ")) + QLatin1Char('.'));
    } else if (a == QLatin1String("open")) {
        openThing(in.text);
    } else if (a == QLatin1String("search")) {
        QUrl url(QStringLiteral("https://duckduckgo.com/"));
        QUrlQuery query;
        query.addQueryItem(QStringLiteral("q"), QString::fromLatin1(QUrl::toPercentEncoding(in.text)));
        url.setQuery(query);
        openLink(url);
    } else if (a == QLatin1String("download")) {
        const QUrl url = Pip::webAddress(in.text);
        if (!Pip::safeDownload(url)) {
            reply(QStringLiteral("Give me a full https:// address of a file."));
        } else if (m_downloader.busy()) {
            reply(QStringLiteral("One download at a time, please."));
        } else {
            const QString folder = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
            ask(QStringLiteral("Download \"%1\" from %2 into %3?")
                    .arg(Pip::safeFileName(url), url.host(), folder),
                [this, url, folder] {
                    if (m_downloader.start(url, folder)) {
                        emit downloadChanged();
                        reply(QStringLiteral("On it."));
                    } else {
                        reply(QStringLiteral("I couldn't start that download."));
                    }
                });
        }
    } else if (a == QLatin1String("install")) {
        // Software shows the source and asks for permission itself.
        reply(start(QStringLiteral("gnome-software"), {QStringLiteral("--search=") + in.text})
                  ? QStringLiteral("I've searched Software for \"%1\". You choose what to install.").arg(in.text)
                  : QStringLiteral("The Software app isn't installed."));
    } else if (a == QLatin1String("volume") || a == QLatin1String("mute")) {
        if (m_system->volume() < 0) {
            reply(QStringLiteral("I can't find a sound device."));
        } else if (a == QLatin1String("volume")) {
            m_system->setVolume(in.number);
            reply(QStringLiteral("Volume %1%.").arg(in.number));
        } else {
            const bool mute = in.text == QLatin1String("mute");
            if (mute != m_system->muted())
                m_system->toggleMute();
            reply(mute ? QStringLiteral("Muted.") : QStringLiteral("Sound is back."));
        }
    } else if (a == QLatin1String("theme")) {
        m_system->setTheme(in.text);
        reply(QStringLiteral("Switched to the %1 theme.").arg(in.text));
    } else if (a == QLatin1String("accent")) {
        if (VYLO::SystemApi::accentNames().contains(in.text)) {
            m_system->setPref(QStringLiteral("accent"), in.text);
            reply(QStringLiteral("%1 it is.").arg(in.text.at(0).toUpper() + in.text.mid(1)));
        } else {
            reply(QStringLiteral("My colours are: %1.").arg(VYLO::SystemApi::accentNames().join(QStringLiteral(", "))));
        }
    } else if (a == QLatin1String("wallpaper")) {
        const QStringList all = VYLO::SystemApi::wallpaperNames();
        const int now = all.indexOf(m_system->prefs().value(QStringLiteral("wallpaper")).toString());
        m_system->setPref(QStringLiteral("wallpaper"), all.at((now + 1) % all.size()));
        reply(QStringLiteral("New view."));
    } else if (a == QLatin1String("mode")) {
        m_system->setPref(QStringLiteral("pipMode"), in.text);
        reply(QStringLiteral("I'm in %1 mode now.").arg(in.text));
    } else if (a == QLatin1String("remind")) {
        const QString about = in.text.isEmpty() ? QStringLiteral("Time's up.") : in.text;
        if (m_reminders.size() >= 20) {
            reply(QStringLiteral("That's a lot of reminders. Cancel some first."));
            return;
        }
        auto *timer = new QTimer(this);
        timer->setSingleShot(true);
        m_reminders.insert(timer, about);
        connect(timer, &QTimer::timeout, this, [this, timer] {
            const QString text = m_reminders.take(timer);
            timer->deleteLater();
            start(QStringLiteral("notify-send"), {QStringLiteral("-a"), QStringLiteral("PIP"),
                                                  QStringLiteral("--"), QStringLiteral("Reminder"), text});
            reply(QStringLiteral("Reminder: %1").arg(text));
            setOpen(true);
        });
        timer->start(in.number * 1000);
        reply(QStringLiteral("I'll remind you in %1. Keep me running until then.").arg(duration(in.number)));
    } else if (a == QLatin1String("reminders")) {
        QStringList lines;
        for (auto it = m_reminders.constBegin(); it != m_reminders.constEnd(); ++it)
            lines << QStringLiteral("• %1, in %2").arg(it.value(), duration((it.key()->remainingTime() + 999) / 1000));
        reply(lines.isEmpty() ? QStringLiteral("No reminders waiting.") : lines.join(u'\n'));
    } else if (a == QLatin1String("cancelreminders")) {
        qDeleteAll(m_reminders.keys());
        m_reminders.clear();
        reply(QStringLiteral("All reminders cancelled."));
    } else if (a == QLatin1String("calc")) {
        const QString result = Pip::calculate(in.text);
        reply(result.isEmpty() ? QStringLiteral("I can't work that one out.")
                               : QStringLiteral("%1 = %2").arg(in.text.trimmed(), result));
    } else if (a == QLatin1String("note")) {
        QDir().mkpath(QFileInfo(notesFile()).path());
        QFile file(notesFile());
        const bool saved = file.size() < 64 * 1024
                           && file.open(QIODevice::Append)
                           && file.write(in.text.toUtf8() + '\n') > 0;
        if (saved)
            file.setPermissions(QFile::ReadOwner | QFile::WriteOwner);
        reply(saved ? QStringLiteral("Noted.") : QStringLiteral("I couldn't save that note."));
    } else if (a == QLatin1String("notes")) {
        QFile file(notesFile());
        QStringList lines;
        if (file.open(QIODevice::ReadOnly))
            lines = QString::fromUtf8(file.readAll()).split(u'\n', Qt::SkipEmptyParts);
        reply(lines.isEmpty() ? QStringLiteral("No notes yet. Try \"note buy tea\".")
                              : QStringLiteral("• ") + lines.mid(qMax(0, lines.size() - 12)).join(QStringLiteral("\n• ")));
    } else if (a == QLatin1String("clearnotes")) {
        ask(QStringLiteral("Delete all your notes?"), [this] {
            const bool gone = !QFile::exists(notesFile()) || QFile::remove(notesFile());
            reply(gone ? QStringLiteral("Notes cleared.") : QStringLiteral("I couldn't delete them."));
        });
    } else if (a == QLatin1String("folder")) {
        using P = QStandardPaths;
        const QHash<QString, P::StandardLocation> places{
            {QStringLiteral("downloads"), P::DownloadLocation}, {QStringLiteral("documents"), P::DocumentsLocation},
            {QStringLiteral("pictures"), P::PicturesLocation}, {QStringLiteral("music"), P::MusicLocation},
            {QStringLiteral("videos"), P::MoviesLocation}};
        const QString path = P::writableLocation(places.value(in.text));
        reply(QDir().mkpath(path) && start(QStringLiteral("xdg-open"), {path})
                  ? QStringLiteral("Opening your %1.").arg(in.text)
                  : QStringLiteral("I couldn't open that folder."));
    } else if (a == QLatin1String("screenshot")) {
        takeScreenshot();
    } else if (a == QLatin1String("coin")) {
        reply(QRandomGenerator::global()->bounded(2) ? QStringLiteral("Heads.") : QStringLiteral("Tails."));
    } else if (a == QLatin1String("dice")) {
        reply(QStringLiteral("You rolled a %1.").arg(QRandomGenerator::global()->bounded(1, 7)));
    } else if (a == QLatin1String("power")) {
        const QString what = in.text;
        const QHash<QString, QString> names{{QStringLiteral("poweroff"), QStringLiteral("Shut down")},
                                            {QStringLiteral("reboot"), QStringLiteral("Restart")},
                                            {QStringLiteral("suspend"), QStringLiteral("Put the computer to sleep")},
                                            {QStringLiteral("logout"), QStringLiteral("Log out")}};
        ask(names.value(what) + QStringLiteral(" now?"), [this, what] {
            if (!m_system->power(what))
                reply(QStringLiteral("That didn't work."));
        });
    } else if (a == QLatin1String("quit")) {
        reply(QStringLiteral("Bye for now."));
        QTimer::singleShot(900, qApp, &QCoreApplication::quit);
    } else {
        ask(QStringLiteral("I don't know that one yet. Search the web for it?"),
            [this, text = in.text] { run(Pip::Intent{QStringLiteral("search"), text, 0}); });
    }

    if (m_system->prefs().value(QStringLiteral("pipMode")) == QLatin1String("explorer")
        && (a == QLatin1String("hello") || a == QLatin1String("thanks")))
        reply(QStringLiteral("Tip: press Super + Space to find any app."));
}
