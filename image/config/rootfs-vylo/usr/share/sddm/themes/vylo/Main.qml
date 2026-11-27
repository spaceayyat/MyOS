import QtQuick
import QtQuick.Controls

// VYLO login screen. SDDM provides sddm, userModel, sessionModel and config.
Rectangle {
    id: root
    width: 1280
    height: 800
    color: "#100B25"

    property string message: ""
    property int session: sessionModel.lastIndex

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
    Rectangle { anchors.fill: parent; color: "#80100B25" }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.12
        spacing: 4
        Text {
            id: time
            anchors.horizontalCenter: parent.horizontalCenter
            property date now: new Date()
            text: Qt.formatTime(now, "HH:mm")
            font.family: "Inter"; font.pixelSize: 76; font.weight: Font.Light; color: "#F4F2FF"
            Timer { interval: 1000; running: true; repeat: true; onTriggered: time.now = new Date() }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(time.now, "dddd, d MMMM")
            font.family: "Inter"; font.pixelSize: 17; color: "#C5AEFF"
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.40
        width: 360
        height: form.height + 52
        radius: 22
        color: "#e0130d2c"
        border.width: 1; border.color: "#59a284ff"

        Column {
            id: form
            x: 30; y: 26
            width: parent.width - 60
            spacing: 12

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "logo.png"
                width: 150; height: width * sourceSize.height / Math.max(1, sourceSize.width)
                smooth: true; mipmap: true
            }

            component Field: TextField {
                width: form.width; height: 40
                leftPadding: 14
                color: "#F4F2FF"
                placeholderTextColor: "#a99fd0"
                font.family: "Inter"; font.pixelSize: 14
                background: Rectangle {
                    radius: 12; color: "#661f1647"
                    border.width: 1; border.color: parent.activeFocus ? "#713BFA" : "#40a284ff"
                }
                onAccepted: root.login()
            }
            Field { id: user; placeholderText: "User name"; KeyNavigation.tab: password }
            Field {
                id: password
                placeholderText: "Password"
                echoMode: TextInput.Password
                focus: true
                KeyNavigation.tab: user
            }
            Rectangle {
                width: parent.width; height: 40; radius: 12
                color: signIn.containsMouse ? "#8657ff" : "#713BFA"
                Text { anchors.centerIn: parent; text: "Sign in"; font.family: "Inter"; font.pixelSize: 14; font.weight: Font.DemiBold; color: "white" }
                MouseArea { id: signIn; anchors.fill: parent; hoverEnabled: true; onClicked: root.login() }
            }
            Text {
                width: parent.width
                visible: root.message !== "" || keyboard.capsLock
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.message !== "" ? root.message : "Caps Lock is on"
                font.family: "Inter"; font.pixelSize: 12; color: "#37D9FF"
            }
        }
    }

    Row {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 24
        spacing: 10
        Repeater {
            model: [
                { label: "Restart", can: sddm.canReboot, run: function () { sddm.reboot() } },
                { label: "Shut down", can: sddm.canPowerOff, run: function () { sddm.powerOff() } }
            ]
            delegate: Rectangle {
                required property var modelData
                visible: modelData.can
                width: caption.width + 28; height: 34; radius: 17
                color: area.containsMouse ? "#33a284ff" : "#99130d2c"
                Text { id: caption; anchors.centerIn: parent; text: parent.modelData.label; font.family: "Inter"; font.pixelSize: 12; color: "#F4F2FF" }
                MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: parent.modelData.run() }
            }
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
