import QtQuick

// The single source of truth for My OS colours, shapes and wallpapers.
// Instantiate once per window and pass it to components:
//     Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent }
QtObject {
    property bool dark: true
    property string accentName: "blue"

    // ---- shape and rhythm -------------------------------------------------
    readonly property int radius: 14
    readonly property int radiusSmall: 8
    readonly property int gap: 12
    readonly property int fast: 140      // ms, hover/press feedback
    readonly property int slide: 220     // ms, drawers

    // ---- accents (dark value, light value) ----------------------------------
    readonly property var accents: ({
        blue:   { d: "#6c93ff", l: "#2f5bff" },
        teal:   { d: "#3fd0c4", l: "#0a8f86" },
        violet: { d: "#a98bff", l: "#6a43e0" },
        rose:   { d: "#ff7fa3", l: "#d02a5f" },
        amber:  { d: "#ffb84d", l: "#b86e00" }
    })
    readonly property color accent: (accents[accentName] || accents.blue)[dark ? "d" : "l"]
    readonly property color accentSoft: Qt.alpha(accent, dark ? 0.20 : 0.14)
    readonly property color onAccent: dark ? "#07102b" : "#ffffff"

    // ---- surfaces (deep navy / charcoal in dark mode) -------------------------
    readonly property color panel:     dark ? "#0e1224" : "#f4f6fd"
    readonly property color surface:   dark ? "#141a30" : "#ffffff"
    readonly property color card:      dark ? "#171e38" : "#ffffff"
    readonly property color cardAlt:   dark ? "#1d2543" : "#eef2ff"
    readonly property color border:    dark ? "#2a3358" : "#d3dcf5"
    readonly property color hover:     dark ? "#222b4d" : "#e4eaff"
    readonly property color text:      dark ? "#edf0ff" : "#0f1a3a"
    readonly property color textMuted: dark ? "#98a2cc" : "#5a6a96"
    readonly property color track:     dark ? "#262f55" : "#dbe3fa"

    // Names kept from the first version of the shell.
    readonly property color panelText:     text
    readonly property color surfaceText:   text
    readonly property color surfaceMuted:  textMuted
    readonly property color wallpaperText: dark ? "#e8ecff" : "#0d1b3d"
    readonly property color wallpaperMuted: dark ? "#8f9ac4" : "#35508f"

    // ---- wallpapers: generated gradients bundled with the app --------------------
    readonly property var wallpapers: ({
        midnight: { dt: "#18224d", db: "#070a16", lt: "#8fb0ff", lb: "#e3ecff" },
        aurora:   { dt: "#0f3a45", db: "#080d1c", lt: "#8fe0d6", lb: "#e2f6f3" },
        graphite: { dt: "#2a2d38", db: "#0d0e13", lt: "#c9ccd8", lb: "#f1f2f6" },
        dusk:     { dt: "#3b2358", db: "#0c0a1c", lt: "#c9a8ff", lb: "#f1e8ff" }
    })
    function wallTop(name)    { var w = wallpapers[name] || wallpapers.midnight; return dark ? w.dt : w.lt }
    function wallBottom(name) { var w = wallpapers[name] || wallpapers.midnight; return dark ? w.db : w.lb }
    readonly property color wallpaperTop:    wallTop("midnight")
    readonly property color wallpaperBottom: wallBottom("midnight")
}
