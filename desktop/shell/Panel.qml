import QtQuick
import QtQuick.Window

// Slim bottom panel: launcher toggle, pinned apps (from installed .desktop
// files), clock and the workspace-drawer toggle. Running-app indicators need a
// window-management interface that is not integrated yet (see docs).
Window {
    id: win
    objectName: "panel"
    title: "My OS Panel"
    width: 1280
    height: 44
    visible: false
    color: th.panel

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent }

    component PanelButton: Rectangle {
        id: btn
        property alias label: lbl.text
        property bool active: false
        signal clicked()
        height: 32; width: lbl.implicitWidth + 24; radius: 9
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: active ? th.accent : (m.containsMouse ? th.hover : "transparent")
        Behavior on color { ColorAnimation { duration: th.fast } }
        Text {
            id: lbl
            anchors.centerIn: parent
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: btn.active ? th.onAccent : th.text
        }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
    }

    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: th.border }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        PanelButton { label: Sys.osName; active: Shell.launcherOpen; onClicked: Shell.launcherOpen = !Shell.launcherOpen }
        Rectangle { width: 1; height: 20; color: th.border; anchors.verticalCenter: parent.verticalCenter }
        Repeater {
            model: Sys.pinnedApps
            delegate: PanelButton { label: modelData.name; onClicked: Sys.launch(modelData.exec) }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Text {
            id: clock
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 13
            color: th.textMuted
            Timer {
                interval: 1000; repeat: true; running: true; triggeredOnStart: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd d MMM  HH:mm")
            }
        }
        PanelButton { label: "Workspaces"; active: Shell.drawerOpen; onClicked: Shell.drawerOpen = !Shell.drawerOpen }
    }
}
