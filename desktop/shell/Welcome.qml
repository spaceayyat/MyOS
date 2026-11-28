import QtQuick
import QtQuick.Window

// Shown when VYLO starts: on the live image it offers to install; after an
// installation it asks, once, how the desktop should look.
Window {
    id: win
    objectName: "welcome"
    title: "Welcome to VYLO"
    width: 520
    height: 400
    color: "transparent"
    visible: Shell.welcomeOpen

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }
    property string problem: ""
    readonly property bool pipHere: Sys.pipInstalled()

    function install() {
        if (Sys.launch("liveinst"))
            Shell.welcomeOpen = false
        else
            win.problem = "The installer could not be started."
    }
    function finish() {
        if (!Sys.live)
            Sys.setPref("welcomeDone", true)
        Shell.welcomeOpen = false
    }

    component Button: Rectangle {
        id: button
        property string label
        property bool primary: false
        signal clicked()
        height: 44; radius: 22
        color: primary ? th.accent : (area.containsMouse ? th.hover : th.cardAlt)
        border.width: activeFocus ? 2 : 1
        border.color: activeFocus ? th.cyan : th.border
        activeFocusOnTab: true
        Keys.onReturnPressed: clicked()
        Keys.onEnterPressed: clicked()
        Keys.onSpacePressed: clicked()
        Text {
            anchors.centerIn: parent; text: button.label
            font.family: th.fontUi; font.pixelSize: 14; font.weight: Font.DemiBold
            color: button.primary ? th.accentText : th.text
        }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: button.clicked() }
    }

    Rectangle {
        anchors.fill: parent
        radius: th.radius
        color: th.popup
        border.width: 1; border.color: th.border
        focus: true
        Keys.onEscapePressed: win.finish()

        Column {
            x: 40; y: 32
            width: parent.width - 80
            spacing: 14
            Row {
                spacing: 14
                Logo { colour: th.accent; height: 40 }
                Logo { word: true; colour: th.text; height: 32; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                text: Sys.live ? "Welcome. Make Space Yours." : "Make it yours."
                font.family: th.fontHead; font.pixelSize: 24; font.weight: Font.DemiBold; color: th.text
            }
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: Sys.live
                      ? "You are running VYLO from the installation media. Install it, or look around first. The installer asks you to confirm before it changes any disk."
                      : "Pick a look. You can change it later in Settings."
                font.family: th.fontUi; font.pixelSize: th.textBody; color: th.textMuted
            }

            // First start of an installed system.
            Column {
                visible: !Sys.live
                width: parent.width
                spacing: 14
                Row {
                    spacing: 8
                    Button { width: 100; height: 36; label: "Dark"; primary: Sys.theme === "dark"; onClicked: Sys.theme = "dark" }
                    Button { width: 100; height: 36; label: "Light"; primary: Sys.theme === "light"; onClicked: Sys.theme = "light" }
                }
                Row {
                    spacing: 12
                    Repeater {
                        model: [{ name: "indigo", colour: "#4A47FF" }, { name: "lilac", colour: "#C278FF" },
                                { name: "cyan", colour: "#37D9FF" }, { name: "rose", colour: "#FF6FA5" },
                                { name: "amber", colour: "#FFB347" }]
                        delegate: Rectangle {
                            id: dot
                            required property var modelData
                            width: 30; height: 30; radius: 15
                            color: modelData.colour
                            border.width: Sys.prefs.accent === modelData.name ? 3 : 0
                            border.color: th.text
                            MouseArea { anchors.fill: parent; onClicked: Sys.setPref("accent", dot.modelData.name) }
                        }
                    }
                }
                Row {
                    visible: win.pipHere
                    spacing: 12
                    Toggle {
                        theme: th
                        checked: Sys.prefs.pipEnabled === true
                        onToggled: function (value) {
                            Sys.setPref("pipEnabled", value)
                            if (value) Sys.launch("vylo-pip")
                        }
                    }
                    Text { text: "Turn on PIP, the little helper"; anchors.verticalCenter: parent.verticalCenter; font.family: th.fontUi; font.pixelSize: th.textBody; color: th.text }
                }
            }
            Text {
                visible: win.problem !== ""
                text: win.problem
                font.family: th.fontUi; font.pixelSize: th.textBody; color: th.cyan
            }
        }

        // The VM test clicks the first button: keep x 40, y 318, 220 x 44.
        Button {
            id: main
            x: 40; y: 318; width: 220
            primary: true
            focus: true
            label: Sys.live ? "Install VYLO" : "Start using VYLO"
            onClicked: Sys.live ? win.install() : win.finish()
        }
        Button {
            visible: Sys.live
            x: 272; y: 318; width: 208
            label: "Try it first"
            onClicked: win.finish()
        }
    }
    onVisibleChanged: if (visible) main.forceActiveFocus()
}
