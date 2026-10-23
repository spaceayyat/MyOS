import QtQuick

// No weather service exists yet, so this shows an honest empty state.
// It must never display invented conditions.
Card {
    id: root
    title: "Weather"

    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Text { text: "Not configured"; font.pixelSize: 18; font.bold: true; color: root.theme.text }
        Text {
            width: root.width - 28
            wrapMode: Text.WordWrap
            text: "No weather service is set up. Live conditions will appear here once one is connected."
            font.pixelSize: 11
            color: root.theme.textMuted
        }
    }
}
