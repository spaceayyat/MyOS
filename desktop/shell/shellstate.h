#pragma once

#include <QObject>

// State shared between the shell's windows. The launcher (left) and the
// workspace drawer (right) are never open at the same time.
class ShellState : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool launcherOpen READ launcherOpen WRITE setLauncherOpen NOTIFY launcherOpenChanged)
    Q_PROPERTY(bool drawerOpen READ drawerOpen WRITE setDrawerOpen NOTIFY drawerOpenChanged)

public:
    using QObject::QObject;

    bool launcherOpen() const { return m_launcher; }
    bool drawerOpen() const { return m_drawer; }

    void setLauncherOpen(bool open)
    {
        if (open == m_launcher)
            return;
        m_launcher = open;
        emit launcherOpenChanged();
        if (open)
            setDrawerOpen(false);
    }
    void setDrawerOpen(bool open)
    {
        if (open == m_drawer)
            return;
        m_drawer = open;
        emit drawerOpenChanged();
        if (open)
            setLauncherOpen(false);
    }
    Q_INVOKABLE void closeAll()
    {
        setLauncherOpen(false);
        setDrawerOpen(false);
    }

signals:
    void launcherOpenChanged();
    void drawerOpenChanged();

private:
    bool m_launcher = false;
    bool m_drawer = false;
};
