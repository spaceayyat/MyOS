import QtQuick
import QtQuick.Window

// Thin strip on the right screen edge: hovering it opens the workspace drawer.
Window {
    objectName: "edge"
    title: "My OS Edge"
    width: 4
    height: 720
    visible: false
    color: "#01000000"
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: Shell.drawerOpen = true
    }
}
