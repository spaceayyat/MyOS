import QtQuick
import QtQuick.Window

// PIP himself: a small round moon creature with a star on an antenna.
Window {
    id: win
    title: "PIP"
    width: 84
    height: 92
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

    Item {
        id: body
        width: 70
        height: 80
        x: 7
        y: 10
        opacity: win.mood === "sleepy" ? 0.75 : 1

        SequentialAnimation {
            id: hop
            NumberAnimation { target: body; property: "y"; to: 2; duration: 170; easing.type: Easing.OutQuad }
            NumberAnimation { target: body; property: "y"; to: 10; duration: 260; easing.type: Easing.OutBounce }
        }

        Rectangle { x: 39; y: 3; width: 3; height: 20; rotation: 18; radius: 2; color: th.starlight }
        Text { x: 37; y: -9; text: "✦"; font.pixelSize: 18; color: th.cyan }

        Rectangle {
            x: 4; y: 17; width: 62; height: 58; radius: 29
            color: th.accent
            border.width: 2; border.color: th.starlight
            // a soft highlight and two craters
            Rectangle { x: 10; y: 7; width: 20; height: 10; radius: 5; color: "#40ffffff"; rotation: -24 }
            Rectangle { x: 44; y: 40; width: 8; height: 8; radius: 4; color: "#26000000" }
            Rectangle { x: 13; y: 42; width: 5; height: 5; radius: 3; color: "#26000000" }

            Repeater {
                model: [17, 37]
                delegate: Rectangle {
                    required property int modelData
                    readonly property bool shut: win.blink || (win.mood === "sleepy" && !Pip.open)
                    x: modelData; y: shut ? 28 : 22
                    width: 9; height: shut ? 2 : 13; radius: 4.5
                    color: "#ffffff"
                    Rectangle { visible: !parent.shut; x: 3; y: 5; width: 4; height: 5; radius: 2; color: th.voidBlack }
                }
            }
            Rectangle { x: 26; y: 40; width: 11; height: 4; radius: 2; color: "#ffffff" }
        }
        Text { visible: win.mood === "sleepy" && !Pip.open; x: 56; y: 8; text: "z"; font.pixelSize: 13; font.italic: true; color: th.cosmicWhite }
    }

    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Pip.open = !Pip.open }
}
