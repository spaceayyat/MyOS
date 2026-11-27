#pragma once

#include <QDir>
#include <QIcon>
#include <QPixmap>
#include <QQuickImageProvider>

// image://appicon/<name> — the icon an application's .desktop file names.
class AppIconProvider : public QQuickImageProvider
{
public:
    AppIconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requested) override
    {
        const int side = requested.width() > 0 ? requested.width() : 96;
        const QIcon icon = QDir::isAbsolutePath(id) ? QIcon(id) : QIcon::fromTheme(id);
        QPixmap pixmap = icon.pixmap(side, side);
        if (pixmap.isNull()) { // QML then draws the application's initial
            pixmap = QPixmap(1, 1);
            pixmap.fill(Qt::transparent);
        }
        if (size)
            *size = pixmap.size();
        return pixmap;
    }
};
