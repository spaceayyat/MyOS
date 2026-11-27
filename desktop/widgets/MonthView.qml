import QtQuick

// A month grid from the system clock. Not connected to any account.
Column {
    id: root
    required property var theme
    property int offset: 0
    spacing: 8

    readonly property date today: new Date()
    readonly property date first: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property int lead: (first.getDay() + 6) % 7 // Monday first

    Item {
        width: root.width; height: 24
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDate(root.first, "MMMM yyyy")
            font.family: root.theme.fontHead; font.pixelSize: 14; font.weight: Font.DemiBold; color: root.theme.text
        }
        Row {
            anchors.right: parent.right
            spacing: 4
            Repeater {
                model: [{ t: "‹", d: -1 }, { t: "•", d: 0 }, { t: "›", d: 1 }]
                delegate: Rectangle {
                    required property var modelData
                    width: 24; height: 24; radius: 7
                    color: area.containsMouse ? root.theme.hover : "transparent"
                    Text { anchors.centerIn: parent; text: parent.modelData.t; font.pixelSize: 15; color: root.theme.textMuted }
                    MouseArea {
                        id: area; anchors.fill: parent; hoverEnabled: true
                        onClicked: root.offset = parent.modelData.d === 0 ? 0 : root.offset + parent.modelData.d
                    }
                }
            }
        }
    }
    Grid {
        columns: 7
        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            delegate: Text {
                required property string modelData
                width: root.width / 7; horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.family: root.theme.fontUi; font.pixelSize: 10; color: root.theme.textMuted
            }
        }
        Repeater {
            model: 42
            delegate: Item {
                required property int index
                readonly property date day: new Date(root.first.getFullYear(), root.first.getMonth(), index - root.lead + 1)
                readonly property bool isToday: day.toDateString() === root.today.toDateString()
                width: root.width / 7; height: 30
                Rectangle {
                    anchors.centerIn: parent; width: 26; height: 26; radius: 13
                    color: parent.isToday ? root.theme.accent : "transparent"
                }
                Text {
                    anchors.centerIn: parent
                    text: parent.day.getDate()
                    font.family: root.theme.fontUi; font.pixelSize: 12
                    color: parent.isToday ? root.theme.onAccent : root.theme.text
                    opacity: parent.day.getMonth() === root.first.getMonth() ? 1 : 0.35
                }
            }
        }
    }
}
