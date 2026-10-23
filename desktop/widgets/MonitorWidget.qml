import QtQuick

// CPU and memory from /proc (via Sys). Shows an empty state if unreadable.
Card {
    id: root
    title: "System"

    component Meter: Item {
        property string label
        property real value: 0
        property string detail
        width: parent.width; height: 34
        Text { text: label; font.pixelSize: 12; color: root.theme.textMuted }
        Text { anchors.right: parent.right; text: detail; font.pixelSize: 12; font.bold: true; color: root.theme.text }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 6; radius: 3; color: root.theme.track
            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, value)) / 100
                height: parent.height; radius: 3; color: root.theme.accent
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }

    Column {
        visible: Sys.statsAvailable
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: 10
        Meter { label: "CPU"; value: Sys.cpuPercent; detail: Math.round(Sys.cpuPercent) + "%" }
        Meter {
            label: "Memory"; value: Sys.memUsedPercent
            detail: Sys.memUsedGb.toFixed(1) + " / " + Sys.memTotalGb.toFixed(1) + " GB"
        }
    }
    Text {
        visible: !Sys.statsAvailable
        anchors.centerIn: parent
        text: "System data unavailable"
        font.pixelSize: 12; color: root.theme.textMuted
    }
}
