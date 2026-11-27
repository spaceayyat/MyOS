import QtQuick

// An application's own icon from the icon theme, or its initial if it has none.
Item {
    id: root
    required property var theme
    required property var app
    property int size: 44
    width: size
    height: size

    Image {
        id: picture
        anchors.fill: parent
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        source: root.app.icon ? "image://appicon/" + root.app.icon : ""
    }
    Rectangle {
        anchors.fill: parent
        visible: picture.status !== Image.Ready || picture.implicitWidth <= 1
        radius: root.size * 0.28
        color: root.theme.accentSoft
        Text {
            anchors.centerIn: parent
            text: root.app.name.charAt(0).toUpperCase()
            font.family: root.theme.fontHead
            font.pixelSize: root.size * 0.45
            color: root.theme.text
        }
    }
}
