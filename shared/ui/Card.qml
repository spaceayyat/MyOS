import QtQuick

// Reusable rounded card used by every widget and by settings sections.
Rectangle {
    id: card
    required property var theme
    property string title: ""
    default property alias content: body.data

    radius: theme.radius
    color: theme.card
    border.width: 1
    border.color: theme.border

    Text {
        id: heading
        visible: card.title !== ""
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 14
        text: card.title.toUpperCase()
        font.pixelSize: 10
        font.letterSpacing: 1.4
        font.bold: true
        color: card.theme.textMuted
    }
    Item {
        id: body
        anchors.fill: parent
        anchors.margins: 14
        anchors.topMargin: heading.visible ? 34 : 14
    }
}
