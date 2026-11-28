// A small calculator: + - * / % and brackets. No scripting engine is involved.
#include "pipbrain.h"

#include <cmath>

namespace Pip {
namespace {

struct Reader {
    const QString s;
    int at = 0;
    int depth = 0;
    bool ok = true;

    bool take(QChar c)
    {
        while (at < s.size() && s.at(at).isSpace())
            ++at;
        if (at >= s.size() || s.at(at) != c)
            return false;
        ++at;
        return true;
    }
    double sum()
    {
        double v = product();
        for (;;) {
            if (take(u'+')) v += product();
            else if (take(u'-')) v -= product();
            else return v;
        }
    }
    double product()
    {
        double v = value();
        for (;;) {
            if (take(u'*') || take(u'x') || take(u'×')) v *= value();
            else if (take(u'/') || take(u'÷')) v /= value();
            else if (take(u'%')) v = std::fmod(v, value());
            else return v;
        }
    }
    double value()
    {
        if (++depth > 40) {
            ok = false;
            at = s.size();
            return 0;
        }
        double v = 0;
        if (take(u'-')) {
            v = -value();
        } else if (take(u'(')) {
            v = sum();
            ok = take(u')') && ok;
        } else {
            const int start = at;
            while (at < s.size() && (s.at(at).isDigit() || s.at(at) == u'.'))
                ++at;
            bool number = false;
            v = s.mid(start, at - start).toDouble(&number);
            ok = ok && number;
        }
        --depth;
        return v;
    }
};

} // namespace

QString calculate(const QString &expression)
{
    Reader r{expression.trimmed()};
    const double v = r.sum();
    if (!r.ok || r.at != r.s.size() || !std::isfinite(v))
        return {};
    return QString::number(v, 'g', 12);
}

} // namespace Pip
