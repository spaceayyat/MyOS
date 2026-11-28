#pragma once

#include <QString>
#include <QUrl>

// What PIP understands. Plain text matching: no AI, no network, no shell.
namespace Pip {

struct Intent {
    QString action;     // see parse() in pipbrain.cpp; "unknown" if not understood
    QString text;       // what the action is about
    int number = 0;     // volume percent, or reminder delay in seconds
};

Intent parse(const QString &input);

// "example.com/page" or "https://example.com" -> an https/http address.
// Invalid if it does not look like a web address.
QUrl webAddress(const QString &text);

// Downloads are only accepted over HTTPS, without a user name or password.
bool safeDownload(const QUrl &url);

// A file name taken from the address that cannot leave the download folder or
// create a hidden file.
QString safeFileName(const QUrl &url);

// folder/name, or folder/name (1).ext and so on if it already exists.
QString freePath(const QString &folder, const QString &name);

// "2*(3+4)" -> "14". Empty if it is not a sum, or has no finite answer.
QString calculate(const QString &expression);

} // namespace Pip
