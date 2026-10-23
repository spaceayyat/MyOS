import QtQuick
import QtQuick.Layouts
import QtQuick.Window

// Top widget area: a bottom-layer surface, so application windows cover it.
// Widget visibility comes from the user's preferences.
Window {
    id: win
    objectName: "widgets"
    title: "My OS Widgets"
    width: 1280
    height: 178
    visible: false
    color: "transparent"

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        anchors.topMargin: 18
        spacing: th.gap

        // Keeps widgets centred when there is spare width.
        Item { Layout.fillWidth: true; Layout.preferredWidth: 0 }
        ClockWidget {
            theme: th; visible: Sys.prefs.showClock
            Layout.preferredWidth: 250; Layout.maximumWidth: 280; Layout.fillWidth: true; Layout.fillHeight: true
        }
        CalendarWidget {
            theme: th; visible: Sys.prefs.showCalendar
            Layout.preferredWidth: 340; Layout.maximumWidth: 380; Layout.fillWidth: true; Layout.fillHeight: true
        }
        WeatherWidget {
            theme: th; visible: Sys.prefs.showWeather
            Layout.preferredWidth: 240; Layout.maximumWidth: 280; Layout.fillWidth: true; Layout.fillHeight: true
        }
        MonitorWidget {
            theme: th; visible: Sys.prefs.showMonitor
            Layout.preferredWidth: 250; Layout.maximumWidth: 280; Layout.fillWidth: true; Layout.fillHeight: true
        }
        Item { Layout.fillWidth: true; Layout.preferredWidth: 0 }
    }
}
