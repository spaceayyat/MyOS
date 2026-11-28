import QtQuick
import QtQuick.Controls
import QtQuick.Window

// The conversation panel above PIP.
Window {
    id: win
    title: "PIP chat"
    width: 340
    height: 430
    color: "transparent"
    visible: Pip.open

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }
    onVisibleChanged: if (visible) line.forceActiveFocus()

    Rectangle {
        anchors.fill: parent
        radius: th.radius
        color: th.popup
        border.width: 1; border.color: th.border

        Text {
            x: 16; y: 12
            text: "PIP"
            font.family: th.fontHead; font.pixelSize: 16; font.weight: Font.DemiBold; color: th.text
        }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 10; y: 9
            width: 26; height: 26; radius: 13
            color: closeArea.containsMouse ? th.hover : "transparent"
            Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 17; color: th.textMuted }
            MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: Pip.open = false }
        }

        ListView {
            id: talk
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.bottom: footer.top
            anchors.margins: 12; anchors.topMargin: 44
            clip: true
            spacing: 8
            model: Pip.messages
            onCountChanged: Qt.callLater(positionViewAtEnd)
            onHeightChanged: Qt.callLater(positionViewAtEnd)
            delegate: Item {
                id: row
                required property var modelData
                width: ListView.view.width
                height: bubble.height
                Rectangle {
                    id: bubble
                    anchors.right: row.modelData.mine ? parent.right : undefined
                    width: Math.min(words.implicitWidth + 24, parent.width * 0.88)
                    height: words.height + 16
                    radius: 13
                    color: row.modelData.mine ? th.accent : th.cardAlt
                    Text {
                        id: words
                        x: 12; y: 8
                        width: parent.width - 24
                        text: row.modelData.text
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        font.family: th.fontUi; font.pixelSize: th.textBody
                        color: row.modelData.mine ? th.accentText : th.text
                    }
                }
            }
        }

        Column {
            id: footer
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 12
            spacing: 8

            Row {
                visible: !Pip.asking && !Pip.downloading
                spacing: 6
                Repeater {
                    model: ["Help", "Status", "Screenshot", "Notes"]
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        width: chipText.implicitWidth + 20; height: 26; radius: 13
                        color: chipArea.containsMouse ? th.hover : th.cardAlt
                        border.width: 1; border.color: th.border
                        Text { id: chipText; anchors.centerIn: parent; text: chip.modelData; font.family: th.fontUi; font.pixelSize: 11; color: th.text }
                        MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; onClicked: Pip.say(chip.modelData.toLowerCase()) }
                    }
                }
            }
            Row {
                visible: Pip.asking
                spacing: 8
                Repeater {
                    model: [{ label: "Yes", value: true }, { label: "No", value: false }]
                    delegate: Rectangle {
                        id: choice
                        required property var modelData
                        width: 74; height: 30; radius: 15
                        color: modelData.value ? th.accent : th.cardAlt
                        border.width: 1; border.color: th.border
                        Text {
                            anchors.centerIn: parent; text: choice.modelData.label
                            font.family: th.fontUi; font.pixelSize: th.textBody
                            color: choice.modelData.value ? th.accentText : th.text
                        }
                        MouseArea { anchors.fill: parent; onClicked: Pip.answer(choice.modelData.value) }
                    }
                }
            }
            Row {
                visible: Pip.downloading
                spacing: 10
                Rectangle {
                    width: footer.width - 70; height: 6; radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: th.track
                    Rectangle { width: parent.width * Math.max(0, Pip.percent) / 100; height: 6; radius: 3; color: th.accent }
                }
                Text {
                    text: "Stop"
                    font.family: th.fontUi; font.pixelSize: 12; color: th.textMuted
                    MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: Pip.cancelDownload() }
                }
            }
            TextField {
                id: line
                width: parent.width; height: 38
                leftPadding: 14
                placeholderText: "Ask PIP…"
                placeholderTextColor: th.textMuted
                color: th.text
                font.family: th.fontUi; font.pixelSize: th.textBody
                background: Rectangle { radius: 19; color: th.cardAlt; border.width: 1; border.color: line.activeFocus ? th.accent : th.border }
                onAccepted: { Pip.say(text); text = "" }
                Keys.onEscapePressed: Pip.open = false
            }
        }
    }
}
