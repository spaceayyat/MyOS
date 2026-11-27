import QtQuick
import QtQuick.Window

// Notification popups in the top right corner. Text is always shown as plain
// text, whatever the sender put in it.
Window {
    id: win
    objectName: "toasts"
    title: "VYLO OS Notifications"
    width: 340
    height: Math.max(1, column.height)
    color: "transparent"
    visible: Notices.popups.length > 0

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }

    Column {
        id: column
        width: parent.width
        spacing: 8
        Repeater {
            model: Notices.popups
            delegate: NoticeCard {
                required property var modelData
                theme: th
                notice: modelData
                width: column.width
                color: th.popup
                onDismissed: Notices.dismiss(modelData.id)
                onClicked: Notices.hidePopup(modelData.id)
            }
        }
    }
}
