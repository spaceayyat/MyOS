import QtQuick
import QtQuick.Controls
import QtQuick.Window

// Opened from the right of the bar: volume, connection and battery,
// notifications and a month calendar.
Window {
    id: win
    objectName: "flyout"
    title: "VYLO OS Quick Panel"
    width: 340
    height: 600
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
            id: top
            width: parent.width
            spacing: 12
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
            Text {
                text: ({ wired: "Wired network", wifi: "Wi-Fi connected", offline: "Not connected" })[Sys.networkState]
                      + (Sys.batteryPercent >= 0 ? "   ·   Battery " + Sys.batteryPercent + "%" : "")
                font.family: th.fontUi; font.pixelSize: 12; color: th.textMuted
            }
            Rectangle { width: parent.width; height: 1; color: th.border }
            Item {
                width: parent.width; height: 24
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    font.family: th.fontHead; font.pixelSize: 14; font.weight: Font.DemiBold; color: th.text
                }
                Row {
                    anchors.right: parent.right; spacing: 10
                    Text {
                        visible: Notices.history.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Clear"
                        font.family: th.fontUi; font.pixelSize: 12; color: th.textMuted
                        MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: Notices.clearAll() }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Do not disturb"
                        font.family: th.fontUi; font.pixelSize: 12; color: th.textMuted
                    }
                    Toggle { theme: th; checked: Notices.quiet; onToggled: function (value) { Notices.quiet = value } }
                }
            }
        }

        ListView {
            anchors.top: top.bottom; anchors.topMargin: 10
            anchors.bottom: month.top; anchors.bottomMargin: 12
            width: parent.width
            clip: true
            spacing: 8
            model: Notices.history
            delegate: NoticeCard {
                required property var modelData
                theme: th
                notice: modelData
                width: ListView.view.width
                onDismissed: Notices.dismiss(modelData.id)
            }
            Text {
                anchors.centerIn: parent
                visible: Notices.history.length === 0
                text: "All quiet"
                font.family: th.fontUi; font.pixelSize: th.textBody; color: th.textMuted
            }
        }

        MonthView { id: month; theme: th; width: parent.width; anchors.bottom: parent.bottom }
    }
}
