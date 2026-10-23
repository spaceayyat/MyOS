import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// My OS Settings: appearance and widgets. Every change is saved immediately and
// the running desktop updates live (the shell watches the same config file).
ApplicationWindow {
    id: win
    title: "My OS Settings"
    width: 640
    height: 640
    minimumWidth: 420
    minimumHeight: 360
    visible: true
    color: th.panel

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: win.width - 40
            x: 20
            spacing: 16

            Item { Layout.preferredHeight: 4 }
            Text { text: "Settings"; font.pixelSize: 26; font.weight: Font.DemiBold; color: th.text }

            // ---- Appearance ------------------------------------------------------
            Card {
                theme: th; title: "Appearance"
                Layout.fillWidth: true; Layout.preferredHeight: 190
                Column {
                    anchors.fill: parent
                    spacing: 16
                    Row {
                        spacing: 14
                        Switch {
                            id: darkSwitch
                            checked: Sys.theme === "dark"
                            onToggled: Sys.theme = checked ? "dark" : "light"
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Dark theme"; font.pixelSize: 15; color: th.text }
                    }
                    Text { text: "Accent colour"; font.pixelSize: 12; color: th.textMuted }
                    Row {
                        spacing: 12
                        Repeater {
                            model: ["blue", "teal", "violet", "rose", "amber"]
                            delegate: Rectangle {
                                width: 36; height: 36; radius: 18
                                color: (th.accents[modelData])[th.dark ? "d" : "l"]
                                border.width: Sys.prefs.accent === modelData ? 3 : 0
                                border.color: th.text
                                Behavior on border.width { NumberAnimation { duration: th.fast } }
                                MouseArea { anchors.fill: parent; onClicked: Sys.setPref("accent", modelData) }
                            }
                        }
                    }
                }
            }

            // ---- Wallpaper ---------------------------------------------------------
            Card {
                theme: th; title: "Wallpaper"
                Layout.fillWidth: true; Layout.preferredHeight: 150
                Row {
                    anchors.fill: parent
                    spacing: 12
                    Repeater {
                        model: ["midnight", "aurora", "graphite", "dusk"]
                        delegate: Item {
                            width: (parent.width - 36) / 4; height: parent.height
                            Rectangle {
                                anchors.fill: parent; anchors.bottomMargin: 22; radius: th.radiusSmall
                                gradient: Gradient {
                                    GradientStop { position: 0; color: th.wallTop(modelData) }
                                    GradientStop { position: 1; color: th.wallBottom(modelData) }
                                }
                                border.width: Sys.prefs.wallpaper === modelData ? 3 : 1
                                border.color: Sys.prefs.wallpaper === modelData ? th.accent : th.border
                            }
                            Text {
                                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                font.pixelSize: 12; color: th.textMuted
                            }
                            MouseArea { anchors.fill: parent; onClicked: Sys.setPref("wallpaper", modelData) }
                        }
                    }
                }
            }

            // ---- Widgets --------------------------------------------------------------
            Card {
                theme: th; title: "Top widgets"
                Layout.fillWidth: true; Layout.preferredHeight: 232
                Column {
                    anchors.fill: parent
                    spacing: 2
                    Repeater {
                        model: [
                            { key: "showClock", label: "Clock and date" },
                            { key: "showCalendar", label: "Calendar" },
                            { key: "showWeather", label: "Weather" },
                            { key: "showMonitor", label: "System monitor (CPU, memory)" }
                        ]
                        delegate: Row {
                            spacing: 14
                            Switch {
                                checked: Sys.prefs[modelData.key] === true
                                onToggled: Sys.setPref(modelData.key, checked)
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; font.pixelSize: 14; color: th.text }
                        }
                    }
                }
            }

            // ---- Panel (read-only for now) -------------------------------------------------
            Card {
                theme: th; title: "Panel"
                Layout.fillWidth: true; Layout.preferredHeight: 96
                Text {
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "The panel sits at the bottom of the screen. Moving it or changing its size is not available yet."
                    font.pixelSize: 13; color: th.textMuted
                }
            }
            Item { Layout.preferredHeight: 12 }
        }
    }
}
