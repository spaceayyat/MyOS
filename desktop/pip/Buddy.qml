import QtQuick
import QtQuick.Window

// PIP himself, in the corner of the screen. Click him to talk.
Window {
    id: win
    title: "PIP"
    width: 96
    height: 106
    visible: false
    color: "transparent"

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }
    readonly property string mood: Sys.prefs.pipMode
    readonly property bool still: th.reducedMotion || mood === "quiet" || mood === "sleepy"
    property bool blink: false

    // Short movements now and then; nothing runs continuously.
    Timer { interval: 4200; repeat: true; running: !win.still; onTriggered: { win.blink = true; open.start() } }
    Timer { id: open; interval: 140; onTriggered: win.blink = false }
    Timer { interval: 11000; repeat: true; running: win.mood === "cheerful" && !win.still; onTriggered: hop.start() }
    Connections { target: Pip; function onSpoke() { if (!win.still) hop.start() } }

    PipFace {
        id: body
        y: 8
        accent: th.accent
        dozing: win.mood === "sleepy" && !Pip.open
        shut: win.blink || dozing
        opacity: win.mood === "sleepy" ? 0.8 : 1
        scale: pointer.containsMouse && !win.still ? 1.05 : 1

        SequentialAnimation {
            id: hop
            NumberAnimation { target: body; property: "y"; to: 0; duration: 170; easing.type: Easing.OutQuad }
            NumberAnimation { target: body; property: "y"; to: 8; duration: 260; easing.type: Easing.OutBounce }
        }
    }

    MouseArea { id: pointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Pip.open = !Pip.open }
}
