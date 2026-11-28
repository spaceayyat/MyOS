import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// VYLO OS Settings: look and widgets. Every change is saved at once and the
// running desktop follows (the shell watches the same config file).
ApplicationWindow {
    id: win
    title: "VYLO OS Settings"
    width: 760
    height: 560
    minimumWidth: 620
    minimumHeight: 420
    visible: true
    color: th.dark ? th.voidBlack : th.cosmicWhite

    // "vylo-settings --pip" opens the PIP page.
    property int page: Qt.application.arguments.indexOf("--pip") >= 0 ? 3 : 0
    readonly property var pages: ["Appearance", "Wallpaper", "Widgets", "PIP", "About"]
    property bool pipHere: Sys.pipInstalled()
    onActiveChanged: if (active) pipHere = Sys.pipInstalled()

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }

    component Heading: Text {
        font.family: th.fontUi; font.pixelSize: th.textSmall; font.weight: Font.DemiBold
        color: th.textMuted
    }
    component Option: RowLayout {
        id: option
        property string label
        property string hint
        property bool checked
        signal toggled(bool value)
        Layout.fillWidth: true
        spacing: 12
        Column {
            Layout.fillWidth: true
            Text { text: option.label; font.family: th.fontUi; font.pixelSize: 14; color: th.text }
            Text { visible: text !== ""; text: option.hint; font.family: th.fontUi; font.pixelSize: th.textSmall; color: th.textMuted }
        }
        Toggle {
            theme: th
            checked: option.checked
            onToggled: function (value) { option.toggled(value) }
        }
    }

    Rectangle {
        id: side
        width: 180; height: parent.height
        color: th.card
        Row {
            x: 18; y: 18; spacing: 12
            Logo { colour: th.accent; height: 26 }
            Logo { word: true; colour: th.text; height: 22; anchors.verticalCenter: parent.verticalCenter }
        }
        Column {
            x: 10; y: 70; width: parent.width - 20; spacing: 3
            Repeater {
                model: win.pages
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    width: parent.width; height: 36; radius: th.radiusSmall
                    color: win.page === index ? th.accent : (area.containsMouse ? th.hover : "transparent")
                    Text {
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData
                        font.family: th.fontUi; font.pixelSize: th.textBody
                        color: win.page === parent.index ? th.accentText : th.text
                    }
                    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: win.page = parent.index }
                }
            }
        }
    }

    StackLayout {
        anchors.left: side.right; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.margins: 26
        currentIndex: win.page

        // ---- Appearance ---------------------------------------------------
        ColumnLayout {
            spacing: 16
            Text { text: "Appearance"; font.family: th.fontHead; font.pixelSize: 24; font.weight: Font.DemiBold; color: th.text }
            Option {
                label: "Dark theme"
                checked: Sys.theme === "dark"
                onToggled: function (value) { Sys.theme = value ? "dark" : "light" }
            }
            Option {
                label: "Reduce motion"
                hint: "Turns off fades and hover movement"
                checked: Sys.prefs.reducedMotion === true
                onToggled: function (value) { Sys.setPref("reducedMotion", value) }
            }
            Heading { text: "Accent colour" }
            Row {
                spacing: 12
                Repeater {
                    model: ["indigo", "lilac", "cyan", "rose", "amber"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 34; height: 34; radius: 17
                        color: th.accents[modelData][th.dark ? "d" : "l"]
                        border.width: Sys.prefs.accent === modelData ? 3 : 0
                        border.color: th.text
                        MouseArea { anchors.fill: parent; onClicked: Sys.setPref("accent", parent.modelData) }
                    }
                }
            }
            Heading { text: "Greeting in the top bar" }
            TextField {
                Layout.preferredWidth: 300
                text: Sys.prefs.greeting
                maximumLength: 40
                placeholderText: "Leave empty to hide"
                placeholderTextColor: th.textMuted
                color: th.text
                font.family: th.fontUi
                background: Rectangle { radius: th.radiusSmall; color: th.cardAlt; border.width: 1; border.color: parent.activeFocus ? th.accent : th.border }
                onEditingFinished: Sys.setPref("greeting", text)
            }
            Item { Layout.fillHeight: true }
        }

        // ---- Wallpaper ----------------------------------------------------
        ColumnLayout {
            spacing: 16
            Text { text: "Wallpaper"; font.family: th.fontHead; font.pixelSize: 24; font.weight: Font.DemiBold; color: th.text }
            GridLayout {
                columns: 2
                columnSpacing: 14; rowSpacing: 10
                Repeater {
                    model: [
                        { key: "cosmos", label: "Cosmos (follows the accent)" },
                        { key: "orbit-hills", label: "Orbit hills (follows the accent)" },
                        { key: "observatory-isles", label: "Observatory isles" },
                        { key: "nebula-drift", label: "Nebula drift" },
                        { key: "deep-void", label: "Deep void" }
                    ]
                    delegate: Column {
                        id: choice
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            width: 230; height: 108; radius: th.radiusSmall
                            color: "transparent"
                            border.width: Sys.prefs.wallpaper === choice.modelData.key ? 3 : 1
                            border.color: Sys.prefs.wallpaper === choice.modelData.key ? th.accent : th.border
                            Image {
                                anchors.fill: parent; anchors.margins: 4
                                source: Sys.wallpaperUrl(choice.modelData.key, Sys.prefs.accent)
                                sourceSize.width: 460
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                            MouseArea { anchors.fill: parent; onClicked: Sys.setPref("wallpaper", choice.modelData.key) }
                        }
                        Text { text: choice.modelData.label; font.family: th.fontUi; font.pixelSize: 12; color: th.textMuted }
                    }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // ---- Widgets ------------------------------------------------------
        ColumnLayout {
            spacing: 16
            Text { text: "Widgets"; font.family: th.fontHead; font.pixelSize: 24; font.weight: Font.DemiBold; color: th.text }
            Repeater {
                model: [
                    { key: "showClock", label: "Clock and date" },
                    { key: "showMonitor", label: "System (CPU, memory, disk, temperature)" },
                    { key: "showCalendar", label: "Calendar" },
                    { key: "showWeather", label: "Weather (no provider set up yet)" }
                ]
                delegate: Option {
                    required property var modelData
                    label: modelData.label
                    checked: Sys.prefs[modelData.key] === true
                    onToggled: function (value) { Sys.setPref(modelData.key, value) }
                }
            }
            Item { Layout.fillHeight: true }
        }

        // ---- PIP ----------------------------------------------------------
        ColumnLayout {
            spacing: 16
            Text { text: "PIP"; font.family: th.fontHead; font.pixelSize: 24; font.weight: Font.DemiBold; color: th.text }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: "An optional little helper. He opens apps and links, downloads files after asking, sets reminders and changes settings. He never runs terminal commands."
                font.family: th.fontUi; font.pixelSize: th.textBody; color: th.textMuted
            }
            ColumnLayout {
                visible: !win.pipHere
                Layout.fillWidth: true
                spacing: 8
                Heading { text: "Not installed" }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    text: "Download the vylo-pip package (see the install guide), then run this in a terminal from your Downloads folder:"
                    font.family: th.fontUi; font.pixelSize: th.textBody; color: th.text
                }
                TextEdit {
                    readOnly: true; selectByMouse: true
                    text: "sudo dnf install ./vylo-pip-*.rpm"
                    font.family: th.fontMono; font.pixelSize: th.textBody; color: th.text
                }
            }
            ColumnLayout {
                visible: win.pipHere
                Layout.fillWidth: true
                spacing: 16
                Option {
                    label: "Use PIP"
                    hint: "Starts him now and each time you sign in"
                    checked: Sys.prefs.pipEnabled === true
                    onToggled: function (value) {
                        Sys.setPref("pipEnabled", value)
                        if (value) Sys.launch("vylo-pip")
                    }
                }
                Heading { text: "Mood" }
                Row {
                    spacing: 8
                    Repeater {
                        model: ["cheerful", "quiet", "sleepy", "explorer"]
                        delegate: Rectangle {
                            id: mood
                            required property string modelData
                            readonly property bool current: Sys.prefs.pipMode === modelData
                            width: 96; height: 32; radius: 16
                            color: current ? th.accent : th.cardAlt
                            border.width: 1; border.color: th.border
                            Text {
                                anchors.centerIn: parent
                                text: mood.modelData.charAt(0).toUpperCase() + mood.modelData.slice(1)
                                font.family: th.fontUi; font.pixelSize: 12
                                color: mood.current ? th.accentText : th.text
                            }
                            MouseArea { anchors.fill: parent; onClicked: Sys.setPref("pipMode", mood.modelData) }
                        }
                    }
                }
                Text {
                    text: "To remove him completely:  sudo dnf remove vylo-pip"
                    font.family: th.fontUi; font.pixelSize: th.textSmall; color: th.textMuted
                }
            }
            Item { Layout.fillHeight: true }
        }

        // ---- About --------------------------------------------------------
        ColumnLayout {
            spacing: 12
            Text { text: Sys.osName; font.family: th.fontHead; font.pixelSize: 24; font.weight: Font.DemiBold; color: th.text }
            Text { text: "Make Space Yours."; font.family: th.fontUi; font.pixelSize: 15; color: th.accent }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: "A Fedora-based desktop, still early. Network and Bluetooth controls, movable widgets and themes you can share are not built yet."
                font.family: th.fontUi; font.pixelSize: th.textBody; color: th.textMuted
            }
            Item { Layout.fillHeight: true }
        }
    }
}
