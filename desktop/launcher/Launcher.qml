import QtQuick
import QtQuick.Controls
import QtQuick.Window

// Left-side launcher. A transparent layer-shell surface (left edge, above the
// panel) whose card slides in and out. It only starts programs listed in
// installed .desktop files, through Sys.launch (never a shell).
Window {
    id: win
    objectName: "launcher"
    title: "My OS Launcher"
    width: 392
    height: 720
    color: "transparent"
    visible: Shell.launcherOpen || card.x > -card.width

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent }

    property int view: 0   // 0 Home, 1 Applications, 2 Appearance
    readonly property var filtered: {
        var q = search.text.toLowerCase().trim()
        return Sys.applications.filter(function (a) { return a.name.toLowerCase().indexOf(q) !== -1 })
    }

    function run(commandLine) { Sys.launch(commandLine); Shell.closeAll() }

    Connections {
        target: Shell
        function onLauncherOpenChanged() {
            if (Shell.launcherOpen) {
                search.text = ""
                win.view = 0
                Sys.refreshApplications()
                search.forceActiveFocus()
            }
        }
    }

    Rectangle {
        id: card
        width: 368
        height: parent.height - 16
        y: 8
        x: Shell.launcherOpen ? 8 : -width - 12
        radius: th.radius + 4
        color: th.surface
        border.width: 1
        border.color: th.border
        Behavior on x { NumberAnimation { duration: th.slide; easing.type: Easing.OutCubic } }
        focus: true
        Keys.onEscapePressed: Shell.closeAll()

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Row {
                spacing: 10
                Rectangle { width: 10; height: 10; radius: 5; color: th.accent; anchors.verticalCenter: parent.verticalCenter }
                Text { text: Sys.osName; font.pixelSize: 20; font.weight: Font.DemiBold; color: th.text }
            }

            TextField {
                id: search
                width: parent.width
                height: 40
                placeholderText: "Search applications"
                color: th.text
                placeholderTextColor: th.textMuted
                selectByMouse: true
                leftPadding: 14
                background: Rectangle {
                    radius: th.radiusSmall + 2
                    color: th.cardAlt
                    border.width: 1
                    border.color: search.activeFocus ? th.accent : th.border
                    Behavior on border.color { ColorAnimation { duration: th.fast } }
                }
                onTextChanged: { if (text !== "") { win.view = 1; list.currentIndex = 0 } }
                Keys.onEscapePressed: Shell.closeAll()
                Keys.onDownPressed: { win.view = 1; list.incrementCurrentIndex() }
                Keys.onUpPressed: list.decrementCurrentIndex()
                onAccepted: {
                    if (list.currentIndex >= 0 && list.currentIndex < win.filtered.length)
                        win.run(win.filtered[list.currentIndex].exec)
                }
            }

            // Navigation: Home, Applications, Appearance, Settings.
            Row {
                spacing: 6
                Repeater {
                    model: ["Home", "Applications", "Appearance", "Settings"]
                    delegate: Rectangle {
                        height: 32; width: navText.implicitWidth + 20; radius: 9
                        property bool current: index < 3 && win.view === index
                        color: current ? th.accentSoft : (navMouse.containsMouse ? th.hover : "transparent")
                        Behavior on color { ColorAnimation { duration: th.fast } }
                        Text {
                            id: navText
                            anchors.centerIn: parent
                            text: modelData
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: parent.current ? th.accent : th.textMuted
                        }
                        MouseArea {
                            id: navMouse; anchors.fill: parent; hoverEnabled: true
                            onClicked: { if (index === 3) win.run("myos-settings"); else win.view = index }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: parent.height - y - footer.height - 14

                // ---- Home -------------------------------------------------------
                Column {
                    visible: win.view === 0
                    width: parent.width
                    spacing: 10
                    Text { text: "Pinned"; font.pixelSize: 11; font.bold: true; color: th.textMuted }
                    Repeater {
                        model: Sys.pinnedApps
                        delegate: Rectangle {
                            width: parent.width; height: 44; radius: th.radiusSmall + 2
                            color: pinMouse.containsMouse ? th.hover : th.cardAlt
                            Text { anchors.verticalCenter: parent.verticalCenter; x: 14; text: modelData.name; font.pixelSize: 14; color: th.text }
                            MouseArea { id: pinMouse; anchors.fill: parent; hoverEnabled: true; onClicked: win.run(modelData.exec) }
                        }
                    }
                    Text {
                        visible: Sys.pinnedApps.length === 0
                        text: "Pinned apps appear here when they are installed."
                        font.pixelSize: 12; color: th.textMuted
                    }
                }

                // ---- Applications ---------------------------------------------------
                ListView {
                    id: list
                    visible: win.view === 1
                    anchors.fill: parent
                    clip: true
                    model: win.filtered
                    currentIndex: 0
                    keyNavigationEnabled: false
                    delegate: Rectangle {
                        width: list.width; height: 40; radius: th.radiusSmall
                        color: (ListView.isCurrentItem || rowMouse.containsMouse) ? th.hover : "transparent"
                        Text { anchors.verticalCenter: parent.verticalCenter; x: 12; text: modelData.name; font.pixelSize: 14; color: th.text }
                        MouseArea {
                            id: rowMouse; anchors.fill: parent; hoverEnabled: true
                            onClicked: win.run(modelData.exec)
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0
                        text: "No applications found"
                        color: th.textMuted
                    }
                }

                // ---- Appearance (quick) -------------------------------------------------
                Column {
                    visible: win.view === 2
                    width: parent.width
                    spacing: 14
                    Row {
                        spacing: 12
                        Switch {
                            checked: Sys.theme === "dark"
                            onToggled: Sys.theme = checked ? "dark" : "light"
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Dark theme"; color: th.text; font.pixelSize: 14 }
                    }
                    Row {
                        spacing: 10
                        Repeater {
                            model: ["blue", "teal", "violet", "rose", "amber"]
                            delegate: Rectangle {
                                width: 30; height: 30; radius: 15
                                color: (th.accents[modelData])[th.dark ? "d" : "l"]
                                border.width: Sys.prefs.accent === modelData ? 3 : 0
                                border.color: th.text
                                MouseArea { anchors.fill: parent; onClicked: Sys.setPref("accent", modelData) }
                            }
                        }
                    }
                    Text { text: "Wallpaper, widgets and more are in Settings."; font.pixelSize: 12; color: th.textMuted }
                }
            }

            Row {
                id: footer
                spacing: 8
                Rectangle {
                    width: 120; height: 36; radius: 10
                    color: setMouse.containsMouse ? th.hover : "transparent"
                    border.width: 1; border.color: th.border
                    Text { anchors.centerIn: parent; text: "Settings"; color: th.text; font.pixelSize: 13 }
                    MouseArea { id: setMouse; anchors.fill: parent; hoverEnabled: true; onClicked: win.run("myos-settings") }
                }
                Rectangle {
                    width: 120; height: 36; radius: 10
                    opacity: Sys.terminalAvailable ? 1.0 : 0.4
                    color: termMouse.containsMouse && Sys.terminalAvailable ? th.hover : "transparent"
                    border.width: 1; border.color: th.border
                    Text { anchors.centerIn: parent; text: Sys.terminalAvailable ? "Terminal" : "No terminal"; color: th.text; font.pixelSize: 13 }
                    MouseArea {
                        id: termMouse; anchors.fill: parent; hoverEnabled: true
                        enabled: Sys.terminalAvailable
                        onClicked: { Sys.openTerminal(); Shell.closeAll() }
                    }
                }
            }
        }
    }
}
