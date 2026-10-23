import QtQuick
import QtQuick.Window

// Full-screen workspace background (layer-shell "background" surface).
Window {
    id: win
    objectName: "wallpaper"
    title: "My OS Wallpaper"
    width: 1280
    height: 720
    visible: false
    color: th.wallBottom(Sys.prefs.wallpaper)

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: th.wallTop(Sys.prefs.wallpaper) }
            GradientStop { position: 1.0; color: th.wallBottom(Sys.prefs.wallpaper) }
        }
        Behavior on opacity { NumberAnimation { duration: th.slide } }

        // Soft accent glow so the empty workspace still looks intentional.
        Rectangle {
            width: Math.min(parent.width, parent.height) * 0.9
            height: width
            radius: width / 2
            anchors.centerIn: parent
            color: th.accentSoft
            opacity: 0.55
        }

        MouseArea { anchors.fill: parent; onClicked: Shell.closeAll() }

        Column {
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Sys.osName
                color: th.wallpaperText
                opacity: 0.92
                font.pixelSize: Math.max(44, win.height / 9)
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Open the launcher to get started"
                color: th.wallpaperMuted
                font.pixelSize: Math.max(14, win.height / 48)
            }
        }
    }
}
