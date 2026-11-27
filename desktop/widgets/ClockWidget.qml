import QtQuick

// Real system time, refreshed every second.
Card {
    id: root
    property date now: new Date()

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    Column {
        anchors.centerIn: parent
        spacing: 2
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
                text: Qt.formatTime(root.now, "HH")
                font.family: root.theme.fontHead; font.pixelSize: 62; font.weight: Font.Medium
                color: root.theme.text
            }
            Text {
                text: ":" + Qt.formatTime(root.now, "mm")
                font.family: root.theme.fontHead; font.pixelSize: 62; font.weight: Font.Medium
                color: root.theme.dark ? "#9b6bff" : root.theme.accent
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(root.now, "dddd, d MMMM yyyy")
            font.family: root.theme.fontUi; font.pixelSize: root.theme.textBody
            color: root.theme.textMuted
        }
    }
}
