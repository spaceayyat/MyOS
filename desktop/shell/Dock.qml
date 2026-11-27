import QtQuick
import QtQuick.Window

// Orbit Dock: pinned applications, floating above the bottom edge. Showing and
// switching open windows is not built yet.
Window {
    id: win
    objectName: "dock"
    title: "VYLO Orbit Dock"
    width: body.width + 24
    height: 92
    visible: false
    color: "transparent"

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }

    component DockButton: Item {
        id: btn
        property string tip
        default property alias content: holder.data
        signal clicked()
        signal secondary()
        width: th.dockIcon + 8
        height: th.dockIcon + 8
        Item {
            id: holder
            width: th.dockIcon
            height: th.dockIcon
            anchors.horizontalCenter: parent.horizontalCenter
            y: area.containsMouse ? -3 : 4
            scale: area.pressed ? 0.92 : (area.containsMouse ? 1.12 : 1)
            Behavior on y { NumberAnimation { duration: th.fast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: th.fast; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (mouse) { if (mouse.button === Qt.RightButton) btn.secondary(); else btn.clicked() }
            onContainsMouseChanged: label.text = containsMouse ? btn.tip : ""
        }
    }

    Text {
        id: label
        anchors.horizontalCenter: parent.horizontalCenter
        y: 2
        font.family: th.fontUi; font.pixelSize: th.textSmall; font.weight: Font.DemiBold
        color: th.cosmicWhite
        style: Text.Outline; styleColor: "#cc100B25"
    }

    Rectangle {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        width: row.width + 20
        height: th.dockIcon + 18
        radius: th.radius + 4
        color: th.surface
        border.width: 1; border.color: th.border
        // The orbit: a soft line of accent light under the dock.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: parent.width * 0.6; height: 2; radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: th.accent }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            DockButton {
                tip: "Constellation"
                onClicked: Shell.launcherOpen = !Shell.launcherOpen
                // The launcher button wears the accent colour.
                Rectangle {
                    anchors.fill: parent
                    radius: th.dockIcon * 0.23
                    color: th.accent
                    Behavior on color { ColorAnimation { duration: th.slide } }
                    Logo { colour: th.accentText; height: th.dockIcon * 0.62; anchors.centerIn: parent }
                }
            }
            Rectangle { width: 1; height: 30; color: th.border; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: Sys.pinnedApps
                delegate: DockButton {
                    id: pin
                    required property var modelData
                    tip: modelData.name
                    onClicked: { Sys.launch(modelData.exec); Shell.closeAll() }
                    onSecondary: Sys.togglePin(modelData.id)
                    AppIcon { theme: th; app: pin.modelData; size: th.dockIcon }
                }
            }
        }
    }
}
