import QtQuick
import QtQuick.Window

// Orbit Dock: pinned applications and open windows, floating above the bottom
// edge. Click: open, switch to, or minimise. Middle click: another window.
// Right click: pin, new window, close.
Window {
    id: win
    objectName: "dock"
    title: "VYLO Orbit Dock"
    width: Math.max(body.width + 24, menu.width + 8)
    height: 92
    visible: false
    color: "transparent"

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }

    // Pinned applications first, then anything else that has a window open.
    readonly property var entries: {
        var list = Sys.pinnedApps.map(function (a) { return { app: a, pinned: true, windows: [] } })
        Windows.list.forEach(function (w) {
            var wanted = w.appId.toLowerCase()
            var same = function (a) { return a.id.toLowerCase() === wanted }
            var entry = list.find(function (e) { return same(e.app) })
            if (!entry) {
                var app = Sys.applications.find(same)
                        || { id: w.appId, name: w.appId || "Window", icon: w.appId, exec: "" }
                entry = { app: app, pinned: false, windows: [] }
                list.push(entry)
            }
            entry.windows.push(w)
        })
        return list
    }

    property string menuFor: "" // application id whose menu is open
    readonly property var menuEntry: entries.find(function (e) { return e.app.id === win.menuFor }) || null
    Timer { id: menuTimeout; interval: 5000; onTriggered: win.menuFor = "" }

    function activateEntry(e) {
        win.menuFor = ""
        Shell.closeAll()
        if (e.windows.length === 0) {
            Sys.launch(e.app.exec)
            return
        }
        // One window in front: put it away. Several: step to the next one.
        var front = e.windows.findIndex(function (w) { return w.active })
        if (front >= 0 && e.windows.length === 1)
            Windows.minimize(e.windows[0].id)
        else
            Windows.activate(e.windows[(front + 1) % e.windows.length].id)
    }

    component DockButton: Item {
        id: btn
        property string tip
        default property alias content: holder.data
        signal clicked()
        signal middle()
        signal secondary()
        width: th.dockIcon + 8
        height: th.dockIcon + 8
        Item {
            id: holder
            width: th.dockIcon
            height: th.dockIcon
            anchors.horizontalCenter: parent.horizontalCenter
            y: area.containsMouse && !th.reducedMotion ? -3 : 3
            scale: area.pressed ? 0.92 : (area.containsMouse && !th.reducedMotion ? 1.12 : 1)
            Behavior on y { NumberAnimation { duration: th.fast; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: th.fast; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: function (mouse) {
                if (mouse.button === Qt.RightButton) btn.secondary()
                else if (mouse.button === Qt.MiddleButton) btn.middle()
                else btn.clicked()
            }
            onContainsMouseChanged: label.text = containsMouse ? btn.tip : ""
        }
    }

    Text {
        id: label
        visible: win.menuEntry === null
        anchors.horizontalCenter: parent.horizontalCenter
        y: 2
        font.family: th.fontUi; font.pixelSize: th.textSmall; font.weight: Font.DemiBold
        color: th.cosmicWhite
        style: Text.Outline; styleColor: "#cc100B25"
    }

    Rectangle {
        id: menu
        visible: win.menuEntry !== null
        anchors.horizontalCenter: parent.horizontalCenter
        width: actions.width + 12
        height: 22
        radius: 11
        color: th.popup
        border.width: 1; border.color: th.border
        Row {
            id: actions
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: {
                    var e = win.menuEntry
                    if (!e) return []
                    var items = []
                    if (e.app.exec !== "") {
                        items.push({ key: "pin", label: e.pinned ? "Unpin" : "Pin" })
                        items.push({ key: "new", label: "New window" })
                    }
                    if (e.windows.length > 0)
                        items.push({ key: "close", label: e.windows.length > 1 ? "Close all" : "Close" })
                    return items
                }
                delegate: Rectangle {
                    id: action
                    required property var modelData
                    width: caption.width + 16; height: 18; radius: 9
                    color: actionArea.containsMouse ? th.accent : "transparent"
                    Text {
                        id: caption; anchors.centerIn: parent; text: action.modelData.label
                        font.family: th.fontUi; font.pixelSize: th.textSmall
                        color: actionArea.containsMouse ? th.accentText : th.text
                    }
                    MouseArea {
                        id: actionArea; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            var e = win.menuEntry
                            var key = action.modelData.key
                            win.menuFor = ""
                            if (key === "pin") Sys.togglePin(e.app.id)
                            else if (key === "new") Sys.launch(e.app.exec)
                            else e.windows.forEach(function (w) { Windows.close(w.id) })
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        width: row.width + 20
        height: th.dockIcon + 18
        radius: th.radius + 4
        color: th.surface
        border.width: 1; border.color: th.border

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6
            DockButton {
                tip: "Constellation  (Super + Space)"
                onClicked: { win.menuFor = ""; Shell.launcherOpen = !Shell.launcherOpen }
                // The launcher button wears the accent colour.
                Rectangle {
                    anchors.fill: parent
                    radius: th.dockIcon * 0.23
                    color: th.accent
                    Behavior on color { ColorAnimation { duration: th.slide } }
                    Logo { colour: th.accentText; height: th.dockIcon * 0.62; anchors.centerIn: parent }
                }
            }
            Rectangle { width: 1; height: 30; color: th.border; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: win.entries
                delegate: DockButton {
                    id: item
                    required property var modelData
                    tip: modelData.app.name
                    onClicked: win.activateEntry(modelData)
                    onMiddle: Sys.launch(modelData.app.exec)
                    onSecondary: {
                        win.menuFor = win.menuFor === modelData.app.id ? "" : modelData.app.id
                        menuTimeout.restart()
                    }
                    AppIcon { theme: th; app: item.modelData.app; size: th.dockIcon }
                    // One dot when running; a longer bar for the window in front.
                    Rectangle {
                        visible: item.modelData.windows.length > 0
                        readonly property bool front: item.modelData.windows.some(function (w) { return w.active })
                        width: front ? 16 : 5; height: 4; radius: 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: th.dockIcon + 2
                        color: front ? th.accent : th.textMuted
                    }
                }
            }
        }
    }
}
