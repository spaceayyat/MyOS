import QtQuick
import QtQuick.Controls

// VYLO login screen. SDDM provides sddm, userModel, sessionModel and config.
// It uses only plain QtQuick, so it also draws without a GPU.
Rectangle {
    id: root
    width: 1280
    height: 800
    color: "#05030c"

    property string message: ""
    property int session: sessionModel.lastIndex
    readonly property color accent: config.accent ? config.accent : "#4A47FF"
    readonly property color glowText: "#d9d6ff"
    readonly property real unit: Math.max(0.8, Math.min(1.4, height / 900))

    function login() {
        // An empty password is never sent.
        if (password.text === "" || user.text === "")
            return
        root.message = ""
        sddm.login(user.text, password.text, root.session)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.text = ""
            root.message = "That password did not work. Try again."
            shake.start()
            password.forceActiveFocus()
        }
    }

    // Prefer the VYLO session, and pre-fill the name of the first account.
    Repeater {
        model: sessionModel
        delegate: Item {
            Component.onCompleted: if (model.name === "VYLO") root.session = index
        }
    }
    Repeater {
        model: userModel
        delegate: Item {
            Component.onCompleted: if (user.text === "" && index === 0) user.text = model.name
        }
    }

    Image {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
    }
    // Darken the left side, where the writing is.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#f005030c" }
            GradientStop { position: 0.38; color: "#b005030c" }
            GradientStop { position: 0.7; color: "#1005030c" }
            GradientStop { position: 1.0; color: "#3005030c" }
        }
    }

    Item {
        id: column
        x: Math.max(40, root.width * 0.08)
        width: 360
        height: parent.height

        Image {
            y: 48 * root.unit
            source: "logo.png"
            width: 132; height: width * sourceSize.height / Math.max(1, sourceSize.width)
            smooth: true; mipmap: true
        }

        Column {
            id: stack
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 14

            Text {
                id: time
                property date now: new Date()
                text: Qt.formatTime(now, "HH:mm")
                font.family: "Inter"; font.pixelSize: 108 * root.unit; font.weight: Font.Thin
                font.letterSpacing: -3
                color: "#ffffff"
                Timer { interval: 1000; running: true; repeat: true; onTriggered: time.now = new Date() }
            }
            Text {
                text: Qt.formatDate(time.now, "dddd, d MMMM")
                font.family: "Inter"; font.pixelSize: 18; color: root.glowText
            }
            Rectangle { width: 54; height: 3; radius: 2; color: root.accent }
            Item { width: 1; height: 14 }

            Row {
                spacing: 14
                Rectangle {
                    width: 56; height: 56; radius: 28
                    color: "#99100a26"
                    border.width: 2; border.color: root.accent
                    Text {
                        anchors.centerIn: parent
                        text: user.text === "" ? "?" : user.text.charAt(0).toUpperCase()
                        font.family: "Inter"; font.pixelSize: 22; font.weight: Font.DemiBold; color: "#ffffff"
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    TextField {
                        id: user
                        width: 270; height: 28
                        padding: 0
                        color: "#ffffff"
                        placeholderText: "User name"
                        placeholderTextColor: "#8f88b8"
                        font.family: "Inter"; font.pixelSize: 20; font.weight: Font.DemiBold
                        background: Rectangle {
                            color: "transparent"
                            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: user.activeFocus ? root.accent : "transparent" }
                        }
                        KeyNavigation.tab: password
                        onAccepted: password.forceActiveFocus()
                    }
                    Text { text: "Welcome back"; font.family: "Inter"; font.pixelSize: 12; color: "#a99fd0" }
                }
            }

            Item {
                id: entry
                width: parent.width; height: 52
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: entry; property: "x"; to: 12; duration: 50 }
                    NumberAnimation { target: entry; property: "x"; to: -10; duration: 70 }
                    NumberAnimation { target: entry; property: "x"; to: 6; duration: 60 }
                    NumberAnimation { target: entry; property: "x"; to: 0; duration: 50 }
                }
                TextField {
                    id: password
                    anchors.fill: parent
                    leftPadding: 22; rightPadding: 62
                    focus: true
                    echoMode: TextInput.Password
                    color: "#ffffff"
                    placeholderText: "Password"
                    placeholderTextColor: "#a99fd0"
                    font.family: "Inter"; font.pixelSize: 15
                    background: Rectangle {
                        radius: 26; color: "#b30d0920"
                        border.width: password.activeFocus ? 2 : 1
                        border.color: password.activeFocus ? root.accent : "#4da9a0ff"
                    }
                    KeyNavigation.tab: user
                    onAccepted: root.login()
                }
                Rectangle {
                    anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40; radius: 20
                    color: signIn.containsMouse ? Qt.lighter(root.accent, 1.2) : root.accent
                    Text { anchors.centerIn: parent; text: "→"; font.pixelSize: 20; color: "#ffffff" }
                    MouseArea { id: signIn; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.login() }
                }
            }
            Text {
                width: parent.width
                height: 18
                text: root.message !== "" ? root.message : (keyboard.capsLock ? "Caps Lock is on" : "")
                font.family: "Inter"; font.pixelSize: 12; color: "#ffd27a"
            }
        }

        Row {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 40
            spacing: 10
            Repeater {
                model: [
                    { label: "Restart", can: sddm.canReboot, run: function () { sddm.reboot() } },
                    { label: "Shut down", can: sddm.canPowerOff, run: function () { sddm.powerOff() } }
                ]
                delegate: Rectangle {
                    required property var modelData
                    visible: modelData.can
                    width: caption.width + 34; height: 36; radius: 18
                    color: area.containsMouse ? "#40ffffff" : "#14ffffff"
                    border.width: 1; border.color: "#33ffffff"
                    Text { id: caption; anchors.centerIn: parent; text: parent.modelData.label; font.family: "Inter"; font.pixelSize: 12; color: "#ffffff" }
                    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: parent.modelData.run() }
                }
            }
        }
    }

    Text {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 40
        text: "Make Space Yours."
        font.family: "Inter"; font.pixelSize: 13; font.italic: true; color: "#b3ffffff"
    }

    Component.onCompleted: password.forceActiveFocus()
}
