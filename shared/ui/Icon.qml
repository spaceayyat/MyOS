import QtQuick

// One of the VYLO line icons in desktop/shell/icons.
Image {
    property string name
    property int size: 17
    width: size
    height: size
    sourceSize.width: size * 2
    sourceSize.height: size * 2
    source: name === "" ? "" : "qrc:/vylo/shell/icons/" + name + ".svg"
}
