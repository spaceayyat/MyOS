// vylo-shell: the wallpaper, bar, widgets, dock, launcher and quick panel.
//
// Each is a QML window turned into a wlr-layer-shell surface (via
// layer-shell-qt), so the compositor (labwc) keeps application windows clear of
// the bar and the dock.

#include <LayerShellQt/Window>

#include <QGuiApplication>
#include <QIcon>
#include <QLocalServer>
#include <QLocalSocket>
#include <QMargins>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTextStream>
#include <QUrl>

#include "appicons.h"
#include "notifications.h"
#include "shellstate.h"
#include "systemapi.h"
#include "windows.h"

namespace {

constexpr int kBarHeight = 40;
constexpr int kDockZone = 74; // visible dock; its hover label floats above

using LayerWindow = LayerShellQt::Window;

void configureLayer(QWindow *window,
                    LayerWindow::Layer layer,
                    LayerWindow::Anchors anchors,
                    int exclusiveZone,
                    const QString &scope,
                    LayerWindow::KeyboardInteractivity keyboard,
                    const QMargins &margins = QMargins())
{
    LayerWindow *ls = LayerWindow::get(window);
    ls->setLayer(layer);
    ls->setAnchors(anchors);
    ls->setExclusiveZone(exclusiveZone);
    ls->setScope(scope);
    ls->setKeyboardInteractivity(keyboard);
    ls->setMargins(margins);
}

// One name per Wayland session, in the user's runtime directory.
QString controlSocket()
{
    return qEnvironmentVariable("XDG_RUNTIME_DIR") + QStringLiteral("/vylo-shell-")
           + qEnvironmentVariable("WAYLAND_DISPLAY", QStringLiteral("0"));
}

// "vylo-shell --launcher" asks the running shell to open or close the launcher.
int sendToRunningShell(const QByteArray &command)
{
    QLocalSocket socket;
    socket.connectToServer(controlSocket());
    if (!socket.waitForConnected(1000)) {
        QTextStream(stderr) << "vylo-shell: no running shell to talk to\n";
        return 1;
    }
    socket.write(command);
    socket.waitForBytesWritten(1000);
    return 0;
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("vylo-shell"));
    QGuiApplication::setDesktopFileName(QStringLiteral("vylo-shell"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    if (app.arguments().contains(QStringLiteral("--launcher")))
        return sendToRunningShell("launcher");

    // Application icons: Papirus ships in the VYLO image.
    if (QIcon::themeName().isEmpty() || QIcon::themeName() == QLatin1String("hicolor"))
        QIcon::setThemeName(QStringLiteral("Papirus-Dark"));
    QIcon::setFallbackThemeName(QStringLiteral("Adwaita"));

    VYLO::SystemApi system;
    ShellState state;

    Windows windows;
    Notifications notifications;
    if (!notifications.start())
        QTextStream(stderr) << "vylo-shell: another notification service is running\n";

    QLocalServer control;
    control.setSocketOptions(QLocalServer::UserAccessOption);
    QLocalServer::removeServer(controlSocket());
    if (!control.listen(controlSocket()))
        QTextStream(stderr) << "vylo-shell: the launcher shortcut is unavailable\n";
    QObject::connect(&control, &QLocalServer::newConnection, &state, [&control, &state] {
        QLocalSocket *client = control.nextPendingConnection();
        QObject::connect(client, &QLocalSocket::readyRead, &state, [client, &state] {
            if (client->readAll() == "launcher")
                state.setLauncherOpen(!state.launcherOpen());
        });
        QObject::connect(client, &QLocalSocket::disconnected, client, &QObject::deleteLater);
    });

    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("appicon"), new AppIconProvider);
    engine.rootContext()->setContextProperty(QStringLiteral("Sys"), &system);
    engine.rootContext()->setContextProperty(QStringLiteral("Shell"), &state);
    engine.rootContext()->setContextProperty(QStringLiteral("Windows"), &windows);
    engine.rootContext()->setContextProperty(QStringLiteral("Notices"), &notifications);

    // Load order is stacking order within a layer.
    const QStringList files = {QStringLiteral("Wallpaper"), QStringLiteral("Widgets"),
                               QStringLiteral("Panel"), QStringLiteral("Dock"),
                               QStringLiteral("Launcher"), QStringLiteral("Flyout"),
                               QStringLiteral("Toasts"),
                               QStringLiteral("Welcome")};
    for (const QString &file : files)
        engine.load(QUrl(QStringLiteral("qrc:/vylo/shell/%1.qml").arg(file)));

    if (engine.rootObjects().size() != files.size()) {
        QTextStream(stderr) << "vylo-shell: failed to load all QML files\n";
        return 1;
    }

    using A = LayerWindow::Anchor;
    using L = LayerWindow::Anchors;
    using KI = LayerWindow::KeyboardInteractivity;

    for (QObject *object : engine.rootObjects()) {
        auto *window = qobject_cast<QQuickWindow *>(object);
        if (!window)
            continue;
        const QString name = window->objectName();

        // Always-visible surfaces are shown here; the launcher and quick panel
        // show themselves from QML when their state changes.
        if (name == QLatin1String("wallpaper")) {
            configureLayer(window, LayerWindow::LayerBackground,
                           L(A::AnchorTop) | A::AnchorBottom | A::AnchorLeft | A::AnchorRight, -1,
                           QStringLiteral("vylo-wallpaper"), KI::KeyboardInteractivityNone);
            window->show();
        } else if (name == QLatin1String("widgets")) {
            // Bottom layer: application windows cover the widgets.
            configureLayer(window, LayerWindow::LayerBottom,
                           L(A::AnchorTop) | A::AnchorRight, 0,
                           QStringLiteral("vylo-widgets"), KI::KeyboardInteractivityNone,
                           QMargins(0, 0, 4, 0));
            window->show();
        } else if (name == QLatin1String("panel")) {
            window->setHeight(kBarHeight);
            configureLayer(window, LayerWindow::LayerTop,
                           L(A::AnchorTop) | A::AnchorLeft | A::AnchorRight, kBarHeight,
                           QStringLiteral("vylo-bar"), KI::KeyboardInteractivityNone);
            window->show();
        } else if (name == QLatin1String("dock")) {
            // Anchored to one edge only, so the compositor centres it.
            configureLayer(window, LayerWindow::LayerTop, L(A::AnchorBottom), kDockZone,
                           QStringLiteral("vylo-dock"), KI::KeyboardInteractivityNone);
            window->show();
        } else if (name == QLatin1String("launcher")) {
            // Exclusive keyboard focus while open so search and arrow keys work.
            configureLayer(window, LayerWindow::LayerTop, L(A::AnchorTop) | A::AnchorLeft, 0,
                           QStringLiteral("vylo-launcher"), KI::KeyboardInteractivityExclusive,
                           QMargins(10, 8, 0, 0));
        } else if (name == QLatin1String("welcome")) {
            // No anchors: centred on the screen. It takes the keyboard so
            // Enter works straight away, and closes before anything else opens.
            configureLayer(window, LayerWindow::LayerTop, L(), -1,
                           QStringLiteral("vylo-welcome"), KI::KeyboardInteractivityExclusive);
        } else if (name == QLatin1String("toasts")) {
            configureLayer(window, LayerWindow::LayerOverlay, L(A::AnchorTop) | A::AnchorRight, 0,
                           QStringLiteral("vylo-toasts"), KI::KeyboardInteractivityNone,
                           QMargins(0, 8, 10, 0));
        } else if (name == QLatin1String("flyout")) {
            configureLayer(window, LayerWindow::LayerTop, L(A::AnchorTop) | A::AnchorRight, 0,
                           QStringLiteral("vylo-flyout"), KI::KeyboardInteractivityOnDemand,
                           QMargins(0, 8, 10, 0));
        }
    }

    // Opens a surface at start, for the screenshots taken in CI.
    const QString preview = qEnvironmentVariable("VYLO_PREVIEW");
    if (preview == QLatin1String("launcher"))
        state.setLauncherOpen(true);
    else if (preview == QLatin1String("flyout"))
        state.setFlyoutOpen(true);

    // The welcome window: always on the live image, once on an installed one.
    const bool firstStart = system.live() || !system.prefs().value(QStringLiteral("welcomeDone")).toBool();
    if (preview == QLatin1String("welcome") || (preview.isEmpty() && firstStart))
        state.setWelcomeOpen(true);

    return app.exec();
}
