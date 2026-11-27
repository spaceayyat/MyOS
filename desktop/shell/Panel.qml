import QtQuick
import QtQuick.Window

// The VYLO Bar: identity on the left, search in the middle, status on the right.
Window {
    id: win
    objectName: "panel"
    title: "VYLO OS Bar"
    width: 1280
    height: 40
    visible: false
    color: th.panel

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }
    property date now: new Date()
    Timer { interval: 1000; repeat: true; running: true; onTriggered: win.now = new Date() }

    component BarButton: Rectangle {
        id: btn
        default property alias content: inner.data
        property bool active: false
        signal clicked()
        height: 30
        width: inner.width + 18
        radius: 9
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: active ? th.accentSoft : (area.containsMouse ? th.hover : "transparent")
        Behavior on color { ColorAnimation { duration: th.fast } }
        Row { id: inner; anchors.centerIn: parent; spacing: 10 }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
    }
    component StatusIcon: Rectangle {
        property alias name: icon.name
        width: 22; height: 22; radius: 6; color: th.iconTile
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Icon { id: icon; anchors.centerIn: parent; size: th.iconSmall }
    }

    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: th.border }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        BarButton {
            active: Shell.launcherOpen
            onClicked: Shell.launcherOpen = !Shell.launcherOpen
            Logo {
                colour: th.accent
                height: 21
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Sys.osName
                font.family: th.fontHead; font.pixelSize: 14; font.weight: Font.DemiBold
                color: th.text
            }
        }
        Rectangle { visible: greeting.visible; width: 1; height: 18; color: th.border; anchors.verticalCenter: parent.verticalCenter }
        Text {
            id: greeting
            visible: Sys.prefs.greeting !== "" && win.width >= 1100
            anchors.verticalCenter: parent.verticalCenter
            text: Sys.prefs.greeting
            font.family: th.fontUi; font.pixelSize: th.textBody; font.italic: true
            color: th.textMuted
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(380, win.width * 0.3)
        height: 28
        radius: 14
        color: searchArea.containsMouse ? th.hover : th.cardAlt
        border.width: 1; border.color: th.border
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 12; spacing: 9
            Rectangle {
                width: 18; height: 18; radius: 5; color: th.iconTile
                Icon { anchors.centerIn: parent; name: "search"; size: 14 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Search applications"
                font.family: th.fontUi; font.pixelSize: 12; color: th.textMuted
            }
        }
        MouseArea { id: searchArea; anchors.fill: parent; hoverEnabled: true; onClicked: Shell.launcherOpen = true }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        BarButton {
            active: Shell.flyoutOpen
            onClicked: Shell.flyoutOpen = !Shell.flyoutOpen
            StatusIcon { name: Sys.networkState }
            StatusIcon { name: Sys.volume < 0 || Sys.muted ? "muted" : "volume" }
            StatusIcon { visible: Sys.batteryPercent >= 0; name: "battery" }
            Text {
                visible: Sys.batteryPercent >= 0
                anchors.verticalCenter: parent.verticalCenter
                text: Sys.batteryPercent + "%" + (Sys.batteryCharging ? " +" : "")
                font.family: th.fontUi; font.pixelSize: 12; color: th.text
            }
            Rectangle { width: 1; height: 18; color: th.border; anchors.verticalCenter: parent.verticalCenter }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(win.now, "ddd d MMM   HH:mm")
                font.family: th.fontUi; font.pixelSize: th.textBody; font.weight: Font.DemiBold
                color: th.text
            }
        }
    }
}
