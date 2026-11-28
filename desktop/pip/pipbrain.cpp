#include "pipbrain.h"

#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>

namespace Pip {

namespace {
QRegularExpression rx(const char *pattern)
{
    return QRegularExpression(QStringLiteral("^(?:%1)$").arg(QString::fromUtf8(pattern)),
                              QRegularExpression::CaseInsensitiveOption);
}

Intent make(const char *action, const QString &text = {}, int number = 0)
{
    return Intent{QString::fromLatin1(action), text, number};
}
} // namespace

Intent parse(const QString &input)
{
    QString s = input.simplified().left(500);
    while (s.endsWith(QLatin1Char('.')) || s.endsWith(QLatin1Char('!')) || s.endsWith(QLatin1Char('?')))
        s.chop(1);
    // Politeness is welcome and ignored.
    s.remove(QRegularExpression(QStringLiteral("^(?:hey |ok )?pip,? "), QRegularExpression::CaseInsensitiveOption));
    s.remove(QRegularExpression(QStringLiteral("^(?:please |can you |could you )+"), QRegularExpression::CaseInsensitiveOption));
    s.remove(QRegularExpression(QStringLiteral(" please$"), QRegularExpression::CaseInsensitiveOption));
    if (s.isEmpty())
        return make("empty");

    QRegularExpressionMatch m;
    auto is = [&](const char *pattern) { m = rx(pattern).match(s); return m.hasMatch(); };

    if (is("help|what can you do|commands"))             return make("help");
    if (is("hi|hello|hey|good (?:morning|evening|night)")) return make("hello");
    if (is("thanks|thank you"))                           return make("thanks");
    if (is("(?:what(?:'s| is) the )?time|what time is it")) return make("time");
    if (is("(?:what(?:'s| is) the )?date|what day is it|today")) return make("date");
    if (is("status|system(?: status)?|battery|how(?:'s| is) my (?:computer|pc)")) return make("status");
    if (is("bye|close|quit|go away|close pip|goodbye"))  return make("quit");

    if (is("(?:calc(?:ulate)?|what(?:'s| is)) ([-0-9(][-+*/%x×÷(). 0-9]*)")
        || is("([-0-9(][-0-9(). ]*[+*/%x×÷-][-+*/%x×÷(). 0-9]*)"))
        return make("calc", m.captured(1));
    if (is("(?:take a )?screen ?shot"))                   return make("screenshot");
    if (is("(?:open )?(?:my )?(downloads|documents|pictures|music|videos)(?: folder)?"))
        return make("folder", m.captured(1).toLower());
    if (is("(?:show |my |list )?notes"))                  return make("notes");
    if (is("(?:clear|delete)(?: all)?(?: my)? notes"))    return make("clearnotes");
    if (is("(?:take a )?note(?: that| down)?:? (.+)"))    return make("note", m.captured(1));
    if (is("(?:show |my |list )?(?:reminders|timers)"))   return make("reminders");
    if (is("(?:cancel|clear|stop)(?: all)?(?: my| the)? (?:reminders?|timers?)")) return make("cancelreminders");
    if (is("(?:flip|toss) a coin|coin flip"))             return make("coin");
    if (is("roll(?: a)? (?:dice|die)"))                   return make("dice");

    if (is("download (.+)"))                              return make("download", m.captured(1));
    if (is("(?:search(?: for)?|google|look up) (.+)"))    return make("search", m.captured(1));
    if (is("install (.+)"))                               return make("install", m.captured(1));
    if (is("(?:open|launch|start|run|go to|visit) (.+)")) return make("open", m.captured(1));

    if (is("(?:set )?volume(?: to)? (\\d{1,3}) ?%?"))     return make("volume", {}, qMin(100, m.captured(1).toInt()));
    if (is("mute|unmute"))                                return make("mute", s.toLower());

    if (is("(dark|light)(?: mode| theme)?"))              return make("theme", m.captured(1).toLower());
    if (is("(?:set )?(?:accent|colou?r)(?: to)? (\\w+)")) return make("accent", m.captured(1).toLower());
    if (is("(?:next|change|new)(?: the)? wallpaper"))     return make("wallpaper");
    if (is("(?:be )?(cheerful|quiet|sleepy|explorer)(?: mode)?")) return make("mode", m.captured(1).toLower());

    if (is("(?:remind me|timer|set a timer)(?: in| for)? (\\d{1,4}) ?(s|secs?|seconds?|m|mins?|minutes?|h|hours?)(?: (?:to |that )?(.+))?")) {
        const QChar unit = m.captured(2).at(0).toLower();
        const int factor = unit == QLatin1Char('h') ? 3600 : unit == QLatin1Char('m') ? 60 : 1;
        const qint64 seconds = qint64(m.captured(1).toInt()) * factor;
        if (seconds > 0 && seconds <= 24 * 3600)
            return make("remind", m.captured(3), int(seconds));
        return make("unknown", s);
    }

    if (is("shut ?down|power off|turn off"))              return make("power", QStringLiteral("poweroff"));
    if (is("restart|reboot"))                             return make("power", QStringLiteral("reboot"));
    if (is("sleep|suspend"))                              return make("power", QStringLiteral("suspend"));
    if (is("log ?out|sign out"))                          return make("power", QStringLiteral("logout"));

    return make("unknown", s);
}

QUrl webAddress(const QString &text)
{
    const QString t = text.trimmed();
    static const QRegularExpression looksLikeHost(
        QStringLiteral("^(?:https?://\\S+|(?:[a-z0-9-]+\\.)+[a-z]{2,}(?::\\d+)?(?:[/?#]\\S*)?)$"),
        QRegularExpression::CaseInsensitiveOption);
    if (!looksLikeHost.match(t).hasMatch())
        return {};
    const QUrl url(t.contains(QLatin1String("://")) ? t : QStringLiteral("https://") + t, QUrl::StrictMode);
    const bool web = url.scheme() == QLatin1String("https") || url.scheme() == QLatin1String("http");
    return (url.isValid() && web && !url.host().isEmpty() && url.userInfo().isEmpty()) ? url : QUrl();
}

bool safeDownload(const QUrl &url)
{
    return url.isValid() && url.scheme() == QLatin1String("https") && !url.host().isEmpty()
           && url.userInfo().isEmpty();
}

QString safeFileName(const QUrl &url)
{
    QString name = url.path(QUrl::FullyDecoded).section(QLatin1Char('/'), -1);
    name.remove(QRegularExpression(QStringLiteral("[\\x00-\\x1f\\x7f/\\\\:*?\"<>|\\x{200e}\\x{200f}\\x{202a}-\\x{202e}\\x{2066}-\\x{2069}]")));
    name = name.trimmed();
    while (name.startsWith(QLatin1Char('.')))
        name.remove(0, 1);
    if (name.size() > 120)
        name = name.right(120);
    return name.isEmpty() ? QStringLiteral("download") : name;
}

QString freePath(const QString &folder, const QString &name)
{
    const QDir dir(folder);
    const QFileInfo info(name);
    QString candidate = dir.filePath(name);
    for (int i = 1; QFileInfo::exists(candidate); ++i) {
        const QString suffix = info.suffix().isEmpty() ? QString() : QLatin1Char('.') + info.suffix();
        candidate = dir.filePath(QStringLiteral("%1 (%2)%3").arg(info.completeBaseName()).arg(i).arg(suffix));
    }
    return candidate;
}

} // namespace Pip
