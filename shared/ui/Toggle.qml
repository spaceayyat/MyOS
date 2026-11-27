import QtQuick

// An on/off switch in the VYLO style.
Item {
    id: root
    required property var theme
    property bool checked: false
    signal toggled(bool value)
    implicitWidth: 44
    implicitHeight: 26
    activeFocusOnTab: true
    function flip() { root.checked = !root.checked; root.toggled(root.checked) }
    Keys.onSpacePressed: flip()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.theme.accent : root.theme.track
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? root.theme.cyan : root.theme.border
        Behavior on color { ColorAnimation { duration: root.theme.fast } }
        Rectangle {
            width: 18; height: 18; radius: 9
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 4 : 4
            color: "#ffffff"
            Behavior on x { NumberAnimation { duration: root.theme.fast; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: root.flip() }
}
