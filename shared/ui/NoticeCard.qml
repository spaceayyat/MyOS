import QtQuick

// One notification, used by the popups and the quick panel.
Rectangle {
    id: card
    required property var theme
    required property var notice
    signal dismissed()
    signal clicked()

    height: text.height + 22
    radius: theme.radiusSmall + 4
    color: theme.cardAlt
    border.width: 1
    border.color: notice.critical ? "#ff6f7d" : theme.border

    MouseArea { anchors.fill: parent; onClicked: card.clicked() }
    Rectangle { x: 10; y: 12; width: 3; height: parent.height - 24; radius: 2; color: card.theme.accent }
    Column {
        id: text
        x: 22; y: 11
        width: parent.width - 58
        spacing: 3
        Text {
            width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
            text: (card.notice.app !== "" ? card.notice.app + "  ·  " : "") + card.notice.time
            font.family: card.theme.fontUi; font.pixelSize: 10; color: card.theme.textMuted
        }
        Text {
            width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
            textFormat: Text.PlainText
            text: card.notice.summary
            font.family: card.theme.fontUi; font.pixelSize: card.theme.textBody; font.weight: Font.DemiBold
            color: card.theme.text
        }
        Text {
            visible: text !== ""
            width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
            textFormat: Text.PlainText
            text: card.notice.body
            font.family: card.theme.fontUi; font.pixelSize: 12; color: card.theme.textMuted
        }
    }
    Rectangle {
        anchors.right: parent.right; anchors.rightMargin: 8; y: 8
        width: 22; height: 22; radius: 11
        color: closeArea.containsMouse ? card.theme.hover : "transparent"
        Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 15; color: card.theme.textMuted }
        MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: card.dismissed() }
    }
}
