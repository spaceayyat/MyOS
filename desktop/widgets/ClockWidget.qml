import QtQuick

// Real system time, refreshed every second.
Card {
    id: root
    title: "Time"
    property date now: new Date()

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            text: Qt.formatTime(root.now, "HH:mm")
            font.pixelSize: 44
            font.weight: Font.Light
            color: root.theme.text
        }
        Text {
            text: Qt.formatDate(root.now, "dddd, d MMMM")
            font.pixelSize: 13
            color: root.theme.textMuted
        }
    }
}
