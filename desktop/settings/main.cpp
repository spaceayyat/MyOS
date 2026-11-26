// vylo-settings: a small, normal (xdg-shell) window with the theme switch.

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QTextStream>
#include <QUrl>

#include "systemapi.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("vylo-settings"));
    QGuiApplication::setDesktopFileName(QStringLiteral("vylo-settings"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    VYLO::SystemApi system;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("Sys"), &system);
    engine.load(QUrl(QStringLiteral("qrc:/vylo/settings/main.qml")));

    if (engine.rootObjects().isEmpty()) {
        QTextStream(stderr) << "vylo-settings: failed to load QML\n";
        return 1;
    }
    return app.exec();
}
