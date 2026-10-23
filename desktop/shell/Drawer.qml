import QtQuick
import QtQuick.Window

// Right-side workspace drawer. It slides over the desktop and is dismissed with
// the close button, Escape, the panel toggle, or by clicking the desktop.
//
// Capability note: listing and switching real windows/workspaces needs a
// window-management interface that is not integrated yet
// (Sys.windowManagementAvailable is false). The drawer says so instead of
// showing invented windows. Shortcuts below do work.
Window {
    id: win
    objectName: "drawer"
    title: "My OS Workspaces"
    width: 372
    height: 720
    color: "transparent"
    visible: Shell.drawerOpen || card.x < win.width

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent }

    function run(c) { Sys.launch(c); Shell.closeAll() }

    Rectangle {
        id: card
        width: 348
        height: parent.height - 16
        y: 8
        x: Shell.drawerOpen ? win.width - width - 8 : win.width + 12
        radius: th.radius + 4
        color: th.surface
        border.width: 1
        border.color: th.border
        Behavior on x { NumberAnimation { duration: th.slide; easing.type: Easing.OutCubic } }
        focus: true
        Keys.onEscapePressed: Shell.closeAll()

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Item {
                width: parent.width; height: 28
                Text { text: "Workspaces"; font.pixelSize: 20; font.weight: Font.DemiBold; color: th.text }
                Rectangle {
                    anchors.right: parent.right; width: 28; height: 28; radius: 8
                    color: closeMouse.containsMouse ? th.hover : "transparent"
                    Text { anchors.centerIn: parent; text: "✕"; color: th.textMuted; font.pixelSize: 13 }
                    MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: Shell.closeAll() }
                }
            }

            // Overview: honest empty state until a window-management backend exists.
            Rectangle {
                width: parent.width; height: 150; radius: th.radius
                color: th.cardAlt; border.width: 1; border.color: th.border
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    spacing: 6
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Sys.windowManagementAvailable ? "Workspace overview" : "Overview not connected"
                        font.pixelSize: 15; font.bold: true; color: th.text
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: "Open windows and workspace switching need a window-management interface from the session. It is not connected yet."
                        font.pixelSize: 11; color: th.textMuted
                    }
                }
            }

            Text { text: "Shortcuts"; font.pixelSize: 11; font.bold: true; color: th.textMuted }

            Repeater {
                model: [
                    { label: "Open launcher", action: "launcher" },
                    { label: "Terminal", action: "terminal" },
                    { label: "Settings", action: "settings" }
                ]
                delegate: Rectangle {
                    width: card.width - 32; height: 44; radius: th.radiusSmall + 2
                    opacity: (modelData.action === "terminal" && !Sys.terminalAvailable) ? 0.4 : 1
                    color: scMouse.containsMouse ? th.hover : th.cardAlt
                    Behavior on color { ColorAnimation { duration: th.fast } }
                    Text { anchors.verticalCenter: parent.verticalCenter; x: 14; text: modelData.label; font.pixelSize: 14; color: th.text }
                    MouseArea {
                        id: scMouse; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            if (modelData.action === "launcher") Shell.launcherOpen = true
                            else if (modelData.action === "terminal") { if (Sys.terminalAvailable) { Sys.openTerminal(); Shell.closeAll() } }
                            else win.run("myos-settings")
                        }
                    }
                }
            }
        }
    }
}
