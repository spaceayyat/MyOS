// myos-shell: wallpaper, top widgets, bottom panel, left launcher, right drawer.
//
// Six QML windows are loaded and then turned into wlr-layer-shell surfaces
// (via layer-shell-qt) so the compositor (labwc) keeps ordinary application
// windows out of the panel area.

#include <LayerShellQt/Shell>
#include <LayerShellQt/Window>

#include <QGuiApplication>
#include <QMargins>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTextStream>
#include <QUrl>

#include "shellstate.h"
#include "systemapi.h"

namespace {

constexpr int kPanelHeight = 44;

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

} // namespace

int main(int argc, char *argv[])
{
    // Must be called before the QGuiApplication is created.
    LayerShellQt::Shell::useLayerShell();

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("myos-shell"));
    QGuiApplication::setDesktopFileName(QStringLiteral("myos-shell"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    MyOS::SystemApi system;
    ShellState state;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Sys"), &system);
    engine.rootContext()->setContextProperty(QStringLiteral("Shell"), &state);

    const QStringList files = {QStringLiteral("qrc:/myos/shell/Wallpaper.qml"),
                               QStringLiteral("qrc:/myos/shell/Widgets.qml"),
                               QStringLiteral("qrc:/myos/shell/Panel.qml"),
                               QStringLiteral("qrc:/myos/shell/EdgeHandle.qml"),
                               QStringLiteral("qrc:/myos/shell/Drawer.qml"),
                               QStringLiteral("qrc:/myos/shell/Launcher.qml")};
    for (const QString &file : files)
        engine.load(QUrl(file));

    if (engine.rootObjects().size() != files.size()) {
        QTextStream(stderr) << "myos-shell: failed to load all QML files\n";
        return 1;
    }

    using A = LayerWindow::Anchor;
    const LayerWindow::Anchors all = LayerWindow::Anchors(A::AnchorTop) | A::AnchorBottom
                                     | A::AnchorLeft | A::AnchorRight;
    const LayerWindow::Anchors top = LayerWindow::Anchors(A::AnchorTop) | A::AnchorLeft | A::AnchorRight;
    const LayerWindow::Anchors bottom = LayerWindow::Anchors(A::AnchorBottom) | A::AnchorLeft | A::AnchorRight;
    const LayerWindow::Anchors left = LayerWindow::Anchors(A::AnchorTop) | A::AnchorBottom | A::AnchorLeft;
    const LayerWindow::Anchors right = LayerWindow::Anchors(A::AnchorTop) | A::AnchorBottom | A::AnchorRight;
    using KI = LayerWindow::KeyboardInteractivity;

    for (QObject *object : engine.rootObjects()) {
        auto *window = qobject_cast<QQuickWindow *>(object);
        if (!window)
            continue;
        const QString name = window->objectName();

        // Always-visible surfaces are shown here; the launcher and drawer show
        // themselves from QML when their state changes.
        if (name == QLatin1String("wallpaper")) {
            configureLayer(window, LayerWindow::LayerBackground, all, -1,
                           QStringLiteral("myos-wallpaper"), KI::KeyboardInteractivityNone);
            window->show();
        } else if (name == QLatin1String("widgets")) {
            // Bottom layer: application windows cover the widgets.
            configureLayer(window, LayerWindow::LayerBottom, top, 0,
                           QStringLiteral("myos-widgets"), KI::KeyboardInteractivityNone);
            window->show();
        } else if (name == QLatin1String("panel")) {
            window->setHeight(kPanelHeight);
            configureLayer(window, LayerWindow::LayerTop, bottom, kPanelHeight,
                           QStringLiteral("myos-panel"), KI::KeyboardInteractivityNone);
            window->show();
        } else if (name == QLatin1String("edge")) {
            configureLayer(window, LayerWindow::LayerTop, right, 0,
                           QStringLiteral("myos-edge"), KI::KeyboardInteractivityNone);
            window->show();
        } else if (name == QLatin1String("launcher")) {
            // Exclusive keyboard focus while open so search and arrow keys work.
            configureLayer(window, LayerWindow::LayerTop, left, 0,
                           QStringLiteral("myos-launcher"), KI::KeyboardInteractivityExclusive);
        } else if (name == QLatin1String("drawer")) {
            configureLayer(window, LayerWindow::LayerTop, right, 0,
                           QStringLiteral("myos-drawer"), KI::KeyboardInteractivityOnDemand);
        }
    }

    return app.exec();
}
