import QtQuick

// CPU, memory, disk and temperature as measured by the system. A value the
// machine cannot report shows as a dash.
Card {
    id: root
    title: "System"

    component Dial: Column {
        id: dial
        property string label
        property real value: -1       // 0..100, negative: unavailable
        property string reading: value < 0 ? "–" : Math.round(value) + "%"
        spacing: 6
        Item {
            width: 54; height: 54
            Canvas {
                id: ring
                anchors.fill: parent
                property real shown: dial.value
                property color accent: root.theme.accent
                onShownChanged: requestPaint()
                onAccentChanged: requestPaint()
                onPaint: {
                    var c = getContext("2d")
                    c.reset()
                    c.lineWidth = 4
                    c.lineCap = "round"
                    c.strokeStyle = root.theme.track
                    c.beginPath(); c.arc(27, 27, 24, 0, Math.PI * 2); c.stroke()
                    if (shown > 0) {
                        c.strokeStyle = accent
                        c.beginPath()
                        c.arc(27, 27, 24, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(shown, 100) / 100)
                        c.stroke()
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: dial.reading
                font.family: root.theme.fontMono; font.pixelSize: 11; color: root.theme.text
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: dial.label
            font.family: root.theme.fontUi; font.pixelSize: root.theme.textSmall; color: root.theme.textMuted
        }
    }

    Row {
        visible: Sys.statsAvailable
        anchors.centerIn: parent
        spacing: (parent.width - 4 * 54) / 3
        Dial { label: "CPU"; value: Sys.cpuPercent }
        Dial { label: "Memory"; value: Sys.memUsedPercent }
        Dial { label: "Disk"; value: Sys.diskUsedPercent }
        Dial {
            label: "Temp"
            value: Sys.temperature
            reading: Sys.temperature < 0 ? "–" : Math.round(Sys.temperature) + "°"
        }
    }
    Text {
        visible: !Sys.statsAvailable
        anchors.centerIn: parent
        text: "System data unavailable"
        font.family: root.theme.fontUi; font.pixelSize: 12; color: root.theme.textMuted
    }
}
