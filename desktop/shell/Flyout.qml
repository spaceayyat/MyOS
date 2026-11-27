import QtQuick
import QtQuick.Controls
import QtQuick.Window

// Opened from the right of the bar: volume and a month calendar.
Window {
    id: win
    objectName: "flyout"
    title: "VYLO OS Quick Panel"
    width: 320
    height: 396
    color: "transparent"
    visible: Shell.flyoutOpen

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }

    Connections {
        target: Shell
        function onFlyoutOpenChanged() { if (Shell.flyoutOpen) { Sys.refreshVolume(); month.offset = 0 } }
    }

    Card {
        theme: th
        anchors.fill: parent
        color: th.popup
        Column {
            anchors.fill: parent
            spacing: 16
            Row {
                width: parent.width
                spacing: 10
                Rectangle {
                    width: 32; height: 32; radius: th.radiusSmall
                    color: muteArea.containsMouse ? th.hover : th.iconTile
                    Icon { anchors.centerIn: parent; name: Sys.volume < 0 || Sys.muted ? "muted" : "volume" }
                    MouseArea { id: muteArea; anchors.fill: parent; hoverEnabled: true; onClicked: Sys.toggleMute() }
                }
                Slider {
                    id: level
                    visible: Sys.volume >= 0
                    width: parent.width - 90; height: 32
                    from: 0; to: 100; stepSize: 1
                    value: Sys.volume
                    onMoved: Sys.setVolume(value)
                }
                Text {
                    visible: Sys.volume >= 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(level.value) + "%"
                    font.family: th.fontMono; font.pixelSize: th.textSmall; color: th.text
                }
                Text {
                    visible: Sys.volume < 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "No audio device found"
                    font.family: th.fontUi; font.pixelSize: th.textBody; color: th.textMuted
                }
            }
            Rectangle { width: parent.width; height: 1; color: th.border }
            MonthView { id: month; theme: th; width: parent.width }
        }
    }
}
