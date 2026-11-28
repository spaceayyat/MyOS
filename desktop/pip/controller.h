#pragma once

#include <QHash>
#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <functional>

#include "downloader.h"
#include "pipbrain.h"

class QTimer;
namespace VYLO { class SystemApi; }

// PIP's conversation: turns what the user typed into an action. Anything that
// downloads a file or ends the session waits for a "yes" button first.
class Controller : public QObject
{
    Q_OBJECT
    // Oldest first. Each entry: mine (bool), text.
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    Q_PROPERTY(bool open READ isOpen WRITE setOpen NOTIFY openChanged)
    Q_PROPERTY(bool asking READ asking NOTIFY askingChanged)
    Q_PROPERTY(bool downloading READ downloading NOTIFY downloadChanged)
    Q_PROPERTY(int percent READ percent NOTIFY downloadChanged)

public:
    explicit Controller(VYLO::SystemApi *system, QObject *parent = nullptr);

    QVariantList messages() const { return m_messages; }
    bool isOpen() const { return m_open; }
    void setOpen(bool open);
    bool asking() const { return bool(m_pending); }
    bool downloading() const { return m_downloader.busy(); }
    int percent() const { return m_percent; }

    Q_INVOKABLE void say(const QString &text);
    Q_INVOKABLE void answer(bool yes);
    Q_INVOKABLE void cancelDownload();

signals:
    void messagesChanged();
    void openChanged();
    void askingChanged();
    void downloadChanged();
    void spoke(); // PIP said something: the face can react

private:
    void add(const QString &text, bool mine);
    void reply(const QString &text);
    void ask(const QString &question, std::function<void()> action);
    void run(const Pip::Intent &intent);
    void openThing(const QString &name);
    void takeScreenshot();
    void openLink(const QUrl &url);
    QVariantMap findApp(const QString &name) const;

    VYLO::SystemApi *m_system;
    Downloader m_downloader;
    std::function<void()> m_pending;
    QHash<QTimer *, QString> m_reminders;
    QVariantList m_messages;
    bool m_open = false;
    int m_percent = -1;
};
