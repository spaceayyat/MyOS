import QtQuick

// A pane of glass: used by widgets, popups and settings sections.
Rectangle {
    id: card
    required property var theme
    property string title: ""
    default property alias content: body.data

    radius: theme.radius
    color: theme.card
    border.width: 1
    border.color: theme.border

    // A thin highlight along the top edge, as light would catch glass.
    Rectangle {
        x: card.radius
        y: 1
        width: card.width - card.radius * 2
        height: 1
        color: card.theme.edge
    }
    Text {
        id: heading
        visible: card.title !== ""
        x: 16
        y: 13
        text: card.title
        font.family: card.theme.fontHead
        font.pixelSize: card.theme.textBody
        font.weight: Font.DemiBold
        color: card.theme.text
    }
    Item {
        id: body
        anchors.fill: parent
        anchors.margins: 16
        anchors.topMargin: heading.visible ? 40 : 16
    }
}
