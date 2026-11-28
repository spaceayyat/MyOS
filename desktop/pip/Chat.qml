import QtQuick
import QtQuick.Controls
import QtQuick.Window

// The conversation panel above PIP.
Window {
    id: win
    title: "PIP chat"
    width: 360
    height: 470
    color: "transparent"
    visible: Pip.open

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }
    onVisibleChanged: if (visible) line.forceActiveFocus()
    readonly property var moodLines: ({ cheerful: "Ready when you are", quiet: "Listening quietly",
                                        sleepy: "A bit sleepy", explorer: "Let's look around" })

    component Chip: Rectangle {
        id: chip
        property string label
        property bool primary: false
        signal clicked()
        width: chipText.implicitWidth + 24; height: 28; radius: 14
        color: primary ? th.accent : (chipArea.containsMouse ? th.accentSoft : "transparent")
        border.width: 1; border.color: primary || chipArea.containsMouse ? th.accent : th.border
        Text {
            id: chipText; anchors.centerIn: parent; text: chip.label
            font.family: th.fontUi; font.pixelSize: 12
            color: chip.primary ? th.accentText : th.text
        }
        MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 24
        color: th.dark ? "#0b0719" : "#fbf9ff"
        border.width: 1; border.color: Qt.alpha(th.accent, 0.55)

        // A wash of the accent colour behind the header.
        Rectangle {
            x: 1; y: 1; width: parent.width - 2; height: 110; radius: 23
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(th.accent, th.dark ? 0.34 : 0.18) }
                GradientStop { position: 1; color: "transparent" }
            }
        }

        PipFace { x: 8; y: 6; width: 60; height: 60; accent: th.accent; moon: false }
        Column {
            x: 74; y: 18
            spacing: 1
            Text { text: "PIP"; font.family: th.fontHead; font.pixelSize: 18; font.weight: Font.DemiBold; font.letterSpacing: 2; color: th.text }
            Text { text: win.moodLines[Sys.prefs.pipMode] || ""; font.family: th.fontUi; font.pixelSize: 11; color: th.textMuted }
        }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 14; y: 20
            width: 28; height: 28; radius: 14
            color: closeArea.containsMouse ? th.hover : "transparent"
            Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 18; color: th.textMuted }
            MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: Pip.open = false }
        }
        Rectangle { x: 18; y: 70; width: parent.width - 36; height: 1; color: th.border }

        ListView {
            id: talk
            anchors.left: parent.left; anchors.right: parent.right
            anchors.top: parent.top; anchors.bottom: footer.top
            anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.topMargin: 80; anchors.bottomMargin: 10
            clip: true
            spacing: 10
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
                    width: Math.min(words.implicitWidth + 28, parent.width * 0.9)
                    height: words.height + 18
                    radius: 15
                    color: row.modelData.mine ? th.accent : th.cardAlt
                    border.width: row.modelData.mine ? 0 : 1; border.color: th.border
                    Text {
                        id: words
                        x: 14; y: 9
                        width: parent.width - 28
                        text: row.modelData.text
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        lineHeight: 1.12
                        font.family: th.fontUi; font.pixelSize: th.textBody
                        color: row.modelData.mine ? th.accentText : th.text
                    }
                }
            }
        }

        Column {
            id: footer
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 14
            spacing: 10

            Row {
                visible: !Pip.asking && !Pip.downloading
                spacing: 6
                Repeater {
                    model: ["Help", "Status", "Screenshot", "Notes"]
                    delegate: Chip {
                        required property string modelData
                        label: modelData
                        onClicked: Pip.say(modelData.toLowerCase())
                    }
                }
            }
            Row {
                visible: Pip.asking
                spacing: 8
                Chip { label: "Yes, do it"; primary: true; onClicked: Pip.answer(true) }
                Chip { label: "No"; onClicked: Pip.answer(false) }
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
                Chip { label: "Stop"; onClicked: Pip.cancelDownload() }
            }
            Item {
                width: parent.width; height: 44
                TextField {
                    id: line
                    anchors.fill: parent
                    leftPadding: 18; rightPadding: 50
                    placeholderText: "Ask PIP…"
                    placeholderTextColor: th.textMuted
                    color: th.text
                    font.family: th.fontUi; font.pixelSize: th.textBody
                    background: Rectangle { radius: 22; color: th.cardAlt; border.width: line.activeFocus ? 2 : 1; border.color: line.activeFocus ? th.accent : th.border }
                    onAccepted: { Pip.say(text); text = "" }
                    Keys.onEscapePressed: Pip.open = false
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                    width: 32; height: 32; radius: 16
                    color: th.accent
                    opacity: line.text === "" ? 0.5 : 1
                    Text { anchors.centerIn: parent; text: "→"; font.pixelSize: 16; color: th.accentText }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Pip.say(line.text); line.text = "" } }
                }
            }
        }
    }
}
