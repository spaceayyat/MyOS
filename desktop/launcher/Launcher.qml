import QtQuick
import QtQuick.Controls
import QtQuick.Window

// Constellation, standard mode: search, categories, an application grid and
// power actions. It only starts programs listed in installed .desktop files,
// through Sys.launch (never a shell). The connected-node mode is not built yet.
Window {
    id: win
    objectName: "launcher"
    title: "VYLO OS Constellation"
    width: 720
    height: 520
    color: "transparent"
    visible: Shell.launcherOpen

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }

    // name shown, desktop-file categories that belong to it
    readonly property var groups: [
        { name: "All apps", match: [] },
        { name: "Pinned", match: [] },
        { name: "Internet", match: ["Network"] },
        { name: "Multimedia", match: ["AudioVideo", "Audio", "Video"] },
        { name: "Graphics", match: ["Graphics"] },
        { name: "Development", match: ["Development"] },
        { name: "Games", match: ["Game"] },
        { name: "Utilities", match: ["Utility"] },
        { name: "Settings", match: ["Settings", "System"] }
    ]
    property int group: 0
    property string armed: ""   // power action waiting for a second click

    readonly property var shown: {
        var q = search.text.toLowerCase().trim()
        var base = (q === "" && win.group === 1) ? Sys.pinnedApps : Sys.applications
        return base.filter(function (a) {
            if (q !== "")
                return a.name.toLowerCase().indexOf(q) !== -1
            var wanted = win.groups[win.group].match
            return wanted.length === 0 || wanted.some(function (c) { return a.categories.indexOf(c) !== -1 })
        })
    }

    function run(app) { Sys.launch(app.exec); Shell.closeAll() }

    Connections {
        target: Shell
        function onLauncherOpenChanged() {
            if (Shell.launcherOpen) {
                search.text = ""
                win.group = 0
                win.armed = ""
                grid.currentIndex = 0
                Sys.refreshApplications()
                search.forceActiveFocus()
            }
        }
    }
    Timer { id: disarm; interval: 3000; onTriggered: win.armed = "" }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: th.radius + 4
        color: th.surface
        border.width: 1; border.color: th.border
        opacity: Shell.launcherOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: th.slide } }

        Text {
            id: hello
            x: 22; y: 18
            text: Sys.userName !== "" ? "Welcome back, " + Sys.userName : "Welcome back"
            font.family: th.fontHead; font.pixelSize: th.textTitle; font.weight: Font.DemiBold
            color: th.text
        }

        TextField {
            id: search
            anchors.right: parent.right; anchors.rightMargin: 18
            y: 12
            width: 300; height: 36
            leftPadding: 14
            placeholderText: "Search applications"
            placeholderTextColor: th.textMuted
            color: th.text
            font.family: th.fontUi; font.pixelSize: th.textBody
            selectByMouse: true
            background: Rectangle {
                radius: 18; color: th.cardAlt
                border.width: 1; border.color: search.activeFocus ? th.accent : th.border
            }
            onTextChanged: grid.currentIndex = 0
            Keys.onEscapePressed: Shell.closeAll()
            Keys.onDownPressed: grid.moveCurrentIndexDown()
            Keys.onUpPressed: grid.moveCurrentIndexUp()
            Keys.onTabPressed: grid.moveCurrentIndexRight()
            Keys.onBacktabPressed: grid.moveCurrentIndexLeft()
            onAccepted: if (grid.currentIndex >= 0 && grid.currentIndex < win.shown.length) win.run(win.shown[grid.currentIndex])
        }

        Column {
            id: categories
            x: 12; y: 64
            width: 150
            spacing: 2
            Repeater {
                model: win.groups
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: categories.width; height: 34; radius: th.radiusSmall
                    readonly property bool current: win.group === index && search.text === ""
                    color: current ? th.accent : (categoryArea.containsMouse ? th.hover : "transparent")
                    Behavior on color { ColorAnimation { duration: th.fast } }
                    Text {
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        font.family: th.fontUi; font.pixelSize: th.textBody
                        color: parent.current ? th.onAccent : th.text
                    }
                    MouseArea {
                        id: categoryArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: { search.text = ""; win.group = index; grid.currentIndex = 0 }
                    }
                }
            }
        }

        GridView {
            id: grid
            anchors.left: categories.right; anchors.leftMargin: 14
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.top: categories.top
            anchors.bottom: footer.top; anchors.bottomMargin: 8
            cellWidth: Math.floor(width / 5)
            cellHeight: 94
            clip: true
            model: win.shown
            keyNavigationEnabled: false
            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                width: grid.cellWidth; height: grid.cellHeight
                Rectangle {
                    anchors.fill: parent; anchors.margins: 3
                    radius: th.radiusSmall + 2
                    color: (cellArea.containsMouse || cell.GridView.isCurrentItem) ? th.hover : "transparent"
                }
                AppIcon { theme: th; app: cell.modelData; size: 44; anchors.horizontalCenter: parent.horizontalCenter; y: 12 }
                Text {
                    y: 64; x: 6; width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: cell.modelData.name
                    font.family: th.fontUi; font.pixelSize: th.textSmall; color: th.text
                }
                Rectangle {
                    visible: Sys.isPinned(cell.modelData.id)
                    anchors.right: parent.right; anchors.rightMargin: 12; y: 10
                    width: 6; height: 6; radius: 3; color: th.cyan
                }
                MouseArea {
                    id: cellArea; anchors.fill: parent; hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: function (mouse) {
                        if (mouse.button === Qt.RightButton) Sys.togglePin(cell.modelData.id)
                        else win.run(cell.modelData)
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: grid.count === 0
                text: search.text !== "" ? "Nothing matches “" + search.text + "”" : "Nothing here yet"
                font.family: th.fontUi; font.pixelSize: th.textBody; color: th.textMuted
            }
        }

        Item {
            id: footer
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: 14
            height: 34
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: win.armed === "" ? "Right-click an app to pin it to the dock" : "Click again to confirm"
                font.family: th.fontUi; font.pixelSize: th.textSmall
                color: win.armed === "" ? th.textMuted : th.cyan
            }
            Row {
                anchors.right: parent.right
                spacing: 6
                Repeater {
                    model: ["suspend", "logout", "reboot", "poweroff"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 34; height: 34; radius: th.radiusSmall
                        color: win.armed === modelData ? th.accent
                             : powerArea.containsMouse ? th.hover : th.iconTile
                        border.width: 1; border.color: th.border
                        Icon { anchors.centerIn: parent; name: parent.modelData; size: 17 }
                        MouseArea {
                            id: powerArea; anchors.fill: parent; hoverEnabled: true
                            // Two clicks, so a stray one cannot shut the machine down.
                            onClicked: {
                                if (win.armed === parent.modelData) { Shell.closeAll(); Sys.power(parent.modelData) }
                                else { win.armed = parent.modelData; disarm.restart() }
                            }
                        }
                    }
                }
            }
        }
    }
}
