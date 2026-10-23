import QtQuick

// Local week view using the system clock. Not connected to any account.
Card {
    id: root
    title: "Calendar"
    property int weekOffset: 0

    readonly property var days: {
        var t = new Date()
        var monday = new Date(t.getFullYear(), t.getMonth(), t.getDate() - ((t.getDay() + 6) % 7) + weekOffset * 7)
        var out = []
        for (var i = 0; i < 7; ++i)
            out.push(new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i))
        return out
    }
    function isToday(d) {
        var t = new Date()
        return d.getFullYear() === t.getFullYear() && d.getMonth() === t.getMonth() && d.getDate() === t.getDate()
    }

    Row {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        spacing: 4
        Repeater {
            model: [{ t: "‹", d: -1 }, { t: "Today", d: 0 }, { t: "›", d: 1 }]
            delegate: Rectangle {
                width: modelData.d === 0 ? 46 : 24; height: 22; radius: 6
                color: m.containsMouse ? root.theme.hover : "transparent"
                Text { anchors.centerIn: parent; text: modelData.t; font.pixelSize: 12; color: root.theme.textMuted }
                MouseArea {
                    id: m; anchors.fill: parent; hoverEnabled: true
                    onClicked: root.weekOffset = modelData.d === 0 ? 0 : root.weekOffset + modelData.d
                }
            }
        }
    }

    Column {
        anchors.fill: parent
        spacing: 8
        Text {
            text: Qt.formatDate(root.days[3], "MMMM yyyy")
            font.pixelSize: 15; font.bold: true; color: root.theme.text
        }
        Row {
            spacing: 4
            Repeater {
                model: root.days
                delegate: Rectangle {
                    width: (parent.parent.width - 24) / 7; height: 46; radius: 10
                    color: root.isToday(modelData) ? root.theme.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: root.theme.fast } }
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDate(modelData, "ddd").slice(0, 2)
                            font.pixelSize: 10
                            color: root.isToday(modelData) ? root.theme.onAccent : root.theme.textMuted
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.getDate()
                            font.pixelSize: 16; font.bold: true
                            color: root.isToday(modelData) ? root.theme.onAccent : root.theme.text
                        }
                    }
                }
            }
        }
        Text { text: "No events. Local calendar, not synced."; font.pixelSize: 11; color: root.theme.textMuted }
    }
}
