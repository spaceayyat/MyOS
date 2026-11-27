import QtQuick
import QtQuick.Window

// The widget column on the right: a bottom-layer surface, so application
// windows cover it. Which widgets show comes from the user's preferences.
// Moving and resizing widgets is not built yet.
Window {
    id: win
    objectName: "widgets"
    title: "VYLO OS Widgets"
    width: 332
    height: 620
    visible: false
    color: "transparent"

    Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent; reducedMotion: Sys.prefs.reducedMotion === true }

    Column {
        x: 4; y: 14
        width: 312
        spacing: th.gap
        ClockWidget { theme: th; width: parent.width; height: 132; visible: Sys.prefs.showClock }
        MonitorWidget { theme: th; width: parent.width; height: 138; visible: Sys.prefs.showMonitor }
        CalendarWidget { theme: th; width: parent.width; height: 270; visible: Sys.prefs.showCalendar }
        WeatherWidget { theme: th; width: parent.width; height: 120; visible: Sys.prefs.showWeather }
    }
}
