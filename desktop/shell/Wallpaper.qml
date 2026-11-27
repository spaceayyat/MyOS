import QtQuick
import QtQuick.Window

// Full-screen background (layer-shell "background" surface). Still pictures
// only: it costs nothing once drawn.
Window {
    id: win
    objectName: "wallpaper"
    title: "VYLO OS Wallpaper"
    width: 1280
    height: 720
    visible: false
    color: th.voidBlack

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }

    Image {
        anchors.fill: parent
        source: Sys.wallpaperUrl(Sys.prefs.wallpaper)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: win.width
        sourceSize.height: win.height
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: th.slide * 2 } }
    }
    MouseArea { anchors.fill: parent; onClicked: Shell.closeAll() }
}
