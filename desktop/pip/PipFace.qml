import QtQuick

// PIP: a pocket planet with a ring of light and two bright eyes, in the accent
// colour. Painted once; only the eyes and the little moon ever move.
Item {
    id: face
    property color accent: "#4A47FF"
    property bool shut: false
    property bool moon: true
    property bool dozing: false
    width: 96
    height: 96

    Canvas {
        id: planet
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const c = getContext("2d")
            const w = width, s = w / 96
            const a = face.accent
            const tint = function (alpha) { return Qt.rgba(a.r, a.g, a.b, alpha) }
            const pale = function (alpha) {
                return Qt.rgba(a.r * 0.35 + 0.65, a.g * 0.35 + 0.65, a.b * 0.35 + 0.65, alpha)
            }
            c.reset()
            c.scale(s, s)

            // glow around him
            let g = c.createRadialGradient(48, 50, 22, 48, 50, 47)
            g.addColorStop(0, tint(0.75)); g.addColorStop(0.45, tint(0.22)); g.addColorStop(1, tint(0))
            c.fillStyle = g
            c.beginPath(); c.arc(48, 50, 47, 0, Math.PI * 2); c.fill()

            // half of the ring, in local ring coordinates
            const ring = function (from, to, width, colour) {
                c.save()
                c.translate(48, 58); c.rotate(-0.22); c.scale(1, 0.27)
                c.beginPath(); c.arc(0, 0, 43, from, to)
                c.restore()
                c.lineWidth = width; c.strokeStyle = colour; c.lineCap = "round"; c.stroke()
            }
            ring(Math.PI, Math.PI * 2, 3, tint(0.8))

            // the dark body, lit along its upper edge
            g = c.createRadialGradient(48, 66, 4, 48, 50, 29)
            g.addColorStop(0, "#07040f"); g.addColorStop(0.72, "#140c2b"); g.addColorStop(1, tint(1))
            c.fillStyle = g
            c.beginPath(); c.arc(48, 50, 28, 0, Math.PI * 2); c.fill()
            c.lineWidth = 2; c.strokeStyle = pale(0.95)
            c.beginPath(); c.arc(48, 50, 27.4, Math.PI * 1.08, Math.PI * 1.92); c.stroke()

            // front of the ring, bright
            ring(0, Math.PI, 7, tint(0.35))
            ring(0, Math.PI, 2.6, pale(1))
        }
    }
    onAccentChanged: planet.requestPaint()

    Repeater {
        model: [37, 53]
        delegate: Item {
            id: eye
            required property int modelData
            readonly property real s: face.width / 96
            x: modelData * s; y: 38 * s; width: 7 * s; height: 14 * s
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 4 * eye.s; height: face.shut ? 6 * eye.s : parent.height + 4 * eye.s
                radius: width / 2; color: face.accent; opacity: 0.45
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width; height: face.shut ? 2.5 * eye.s : parent.height
                radius: width / 2; color: "#ffffff"
            }
        }
    }

    // a small moon keeping him company
    Rectangle {
        visible: face.moon
        x: face.width * 0.76; y: face.height * 0.12
        width: face.width * 0.11; height: width; radius: width / 2
        color: "#ffffff"
        border.width: 2; border.color: face.accent
    }
    Text {
        visible: face.dozing
        x: face.width * 0.08; y: face.height * 0.04
        text: "z z"; font.pixelSize: face.width * 0.13; font.italic: true; color: "#ffffff"
    }
}
