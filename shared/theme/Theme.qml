import QtQuick

// The VYLO design system: colour, type, spacing, shape, glass and motion.
// Instantiate once per window and pass it to components:
//     Theme { id: th; dark: Sys.theme === "dark"; accentName: Sys.prefs.accent
//             reducedMotion: Sys.prefs.reducedMotion === true }
QtObject {
    property bool dark: true
    property string accentName: "indigo"
    property bool reducedMotion: false

    // ---- brand colours ------------------------------------------------------
    readonly property color voidBlack:   "#100B25"
    readonly property color indigo:      "#4A47FF"   // the logo
    readonly property color lilac:       "#C278FF"   // the logo, second colour
    readonly property color cyan:        "#37D9FF"
    readonly property color starlight:   "#C5AEFF"
    readonly property color cosmicWhite: "#F4F2FF"

    // ---- accents (dark value, light value) ----------------------------------
    readonly property var accents: ({
        indigo:    { d: "#4A47FF", l: "#3a36e0" },
        lilac:     { d: "#C278FF", l: "#8e3ed6" },
        cyan:      { d: "#37D9FF", l: "#0889ad" },
        rose:      { d: "#ff6fa8", l: "#c9246a" },
        amber:     { d: "#ffb84d", l: "#a96500" }
    })
    readonly property color accent: (accents[accentName] || accents.indigo)[dark ? "d" : "l"]
    readonly property color accentSoft: Qt.alpha(accent, dark ? 0.24 : 0.14)
    // Dark text on the pale accents, white on the deep ones.
    readonly property color accentText: (accent.r * 0.3 + accent.g * 0.59 + accent.b * 0.11) > 0.6 ? voidBlack : "#ffffff"

    // ---- glass surfaces -------------------------------------------------------
    // Translucency without blur: blur needs compositor support labwc lacks.
    // Popups are solid, so whatever is behind them does not show through.
    readonly property color popup:       dark ? "#161033" : "#fbf9ff"
    readonly property color panel:     dark ? "#d90f0a22" : "#e6f4f2ff"
    readonly property color surface:   dark ? "#ee130d2c" : "#f4ffffff"
    readonly property color card:      dark ? "#c2160f33" : "#dcffffff"
    readonly property color cardAlt:   dark ? "#801f1647" : "#99ebe4ff"
    readonly property color border:    dark ? "#40a284ff" : "#406a45d9"
    readonly property color edge:      dark ? "#26ffffff" : "#80ffffff"   // top highlight
    readonly property color hover:     dark ? "#33a284ff" : "#264A47FF"
    readonly property color text:      dark ? cosmicWhite : "#1b1238"
    readonly property color textMuted: dark ? "#a99fd0" : "#5b5080"
    readonly property color track:     dark ? "#33c5aeff" : "#264A47FF"
    readonly property color iconTile:  dark ? "#00000000" : "#cc2a1d55"   // behind line icons in light mode

    // ---- type -------------------------------------------------------------------
    readonly property string fontUi: "Inter"
    // Space Grotesk is not packaged by Fedora; it is used when installed.
    readonly property string fontHead: Qt.fontFamilies().indexOf("Space Grotesk") >= 0 ? "Space Grotesk" : "Inter"
    readonly property string fontMono: "JetBrains Mono"
    readonly property int textSmall: 11
    readonly property int textBody: 13
    readonly property int textTitle: 18

    // ---- space and shape ------------------------------------------------------------
    readonly property int space: 8
    readonly property int gap: 12
    readonly property int radius: 18
    readonly property int radiusSmall: 10
    readonly property int barHeight: 40
    readonly property int dockIcon: 44
    readonly property int iconSmall: 17

    // ---- motion (milliseconds; zero when reduced) ------------------------------------
    readonly property int fast: reducedMotion ? 0 : 130
    readonly property int slide: reducedMotion ? 0 : 230
}
