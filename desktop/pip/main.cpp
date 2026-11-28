// vylo-pip: the optional PIP helper. One small face in the corner and a chat
// panel. When it is not running there is no PIP process at all.
#include <QGuiApplication>
#include <QIcon>
#include <QLockFile>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTextStream>
#include <QTimer>
#include <cstring>

#include <LayerShellQt/Window>

#include "controller.h"
#include "systemapi.h"

namespace {
void place(QQuickWindow *window, const QMargins &margins, const QString &scope,
           LayerShellQt::Window::KeyboardInteractivity keys)
{
    using LayerWindow = LayerShellQt::Window;
    auto *layer = LayerWindow::get(window);
    layer->setLayer(LayerWindow::LayerTop);
    layer->setAnchors(LayerWindow::Anchors(LayerWindow::AnchorBottom) | LayerWindow::AnchorRight);
    layer->setMargins(margins);
    layer->setExclusiveZone(0);
    layer->setScope(scope);
    layer->setKeyboardInteractivity(keys);
}
} // namespace

int main(int argc, char *argv[])
{
    // At sign-in: leave at once unless the user has switched PIP on.
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "--autostart") == 0 && !VYLO::SystemApi::pipEnabledOnDisk())
            return 0;
    }
    // Software drawing keeps memory use low; PIP has little to draw.
    if (qEnvironmentVariableIsEmpty("QT_QUICK_BACKEND"))
        qputenv("QT_QUICK_BACKEND", "software");

    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("vylo-pip"));
    QGuiApplication::setDesktopFileName(QStringLiteral("vylo-pip"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    QIcon::setFallbackThemeName(QStringLiteral("Adwaita"));

    QLockFile lock(qEnvironmentVariable("XDG_RUNTIME_DIR", QStringLiteral("/tmp"))
                   + QStringLiteral("/vylo-pip-")
                   + qEnvironmentVariable("WAYLAND_DISPLAY", QStringLiteral("0")) + QStringLiteral(".lock"));
    if (!lock.tryLock(100)) {
        QTextStream(stderr) << "vylo-pip: already running\n";
        return 0;
    }

    VYLO::SystemApi system;
    Controller pip(&system);

    // Switching PIP off in Settings closes a running one.
    bool enabled = system.prefs().value(QStringLiteral("pipEnabled")).toBool();
    QObject::connect(&system, &VYLO::SystemApi::prefsChanged, &app, [&system, &enabled] {
        const bool now = system.prefs().value(QStringLiteral("pipEnabled")).toBool();
        if (enabled && !now)
            QCoreApplication::quit();
        enabled = now;
    });

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Sys"), &system);
    engine.rootContext()->setContextProperty(QStringLiteral("Pip"), &pip);
    engine.load(QUrl(QStringLiteral("qrc:/vylo/pip/Buddy.qml")));
    engine.load(QUrl(QStringLiteral("qrc:/vylo/pip/Chat.qml")));
    if (engine.rootObjects().size() != 2) {
        QTextStream(stderr) << "vylo-pip: failed to load its windows\n";
        return 1;
    }

    auto *buddy = qobject_cast<QQuickWindow *>(engine.rootObjects().at(0));
    auto *chat = qobject_cast<QQuickWindow *>(engine.rootObjects().at(1));
    place(buddy, QMargins(0, 0, 18, 14), QStringLiteral("vylo-pip"),
          LayerShellQt::Window::KeyboardInteractivityNone);
    place(chat, QMargins(0, 0, 18, 112), QStringLiteral("vylo-pip-chat"),
          LayerShellQt::Window::KeyboardInteractivityOnDemand);
    buddy->show();

    // For screenshots in CI: type one line into the open panel.
    const QString demo = qEnvironmentVariable("VYLO_PIP_DEMO");
    if (!demo.isEmpty()) {
        pip.setOpen(true);
        QTimer::singleShot(1500, &pip, [&pip, demo] { pip.say(demo); });
    }
    return app.exec();
}
