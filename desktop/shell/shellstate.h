#pragma once

#include <QObject>

// State shared between the shell's windows. The launcher and the quick panel
// are never open at the same time.
class ShellState : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool launcherOpen READ launcherOpen WRITE setLauncherOpen NOTIFY launcherOpenChanged)
    Q_PROPERTY(bool flyoutOpen READ flyoutOpen WRITE setFlyoutOpen NOTIFY flyoutOpenChanged)

public:
    using QObject::QObject;

    bool launcherOpen() const { return m_launcher; }
    bool flyoutOpen() const { return m_flyout; }

    void setLauncherOpen(bool open)
    {
        if (open == m_launcher)
            return;
        m_launcher = open;
        emit launcherOpenChanged();
        if (open)
            setFlyoutOpen(false);
    }
    void setFlyoutOpen(bool open)
    {
        if (open == m_flyout)
            return;
        m_flyout = open;
        emit flyoutOpenChanged();
        if (open)
            setLauncherOpen(false);
    }
    Q_INVOKABLE void closeAll()
    {
        setLauncherOpen(false);
        setFlyoutOpen(false);
    }

signals:
    void launcherOpenChanged();
    void flyoutOpenChanged();

private:
    bool m_launcher = false;
    bool m_flyout = false;
};
