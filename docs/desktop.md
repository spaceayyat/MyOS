# My OS desktop (Phase 1A)

Status legend: **Implemented** = written and statically checked, **Simulated** = shows an honest placeholder, **Needs integration** = interface exists, backend does not.
Nothing here has been compiled or run: the authoring sandbox had no Qt. Treat the first build as the real test.

## Layout (all surfaces are wlr-layer-shell windows of one process, `myos-shell`)

| Surface | Layer / anchors | File |
| --- | --- | --- |
| Wallpaper | background, all edges, ignores other zones | `desktop/shell/Wallpaper.qml` |
| Top widgets | bottom layer (windows cover them), top edge | `desktop/shell/Widgets.qml` + `desktop/widgets/*` |
| Bottom panel | top layer, bottom edge, reserves 44 px | `desktop/shell/Panel.qml` |
| Left launcher | top layer, left edge, exclusive keyboard while open | `desktop/launcher/Launcher.qml` |
| Right drawer | top layer, right edge, keyboard on demand | `desktop/shell/Drawer.qml` |
| Edge handle | 4 px strip on the right edge; hover opens the drawer | `desktop/shell/EdgeHandle.qml` |

Application windows are managed by `labwc`; nothing in QML pretends to be a window manager. The centre of the screen is the wallpaper plus real windows.

## Feature status

| Feature | Status |
| --- | --- |
| Dark default, light theme, 5 accents, wallpaper presets, one shared `Theme.qml` | Implemented |
| Widget visibility (clock, calendar, weather, monitor) | Implemented |
| Preferences saved to `~/.config/myos/myos.conf`, live-synced between shell and settings | Implemented |
| Clock/date from system time | Implemented |
| CPU and memory from `/proc/stat`, `/proc/meminfo` (parsers unit-tested with g++) | Implemented |
| Calendar: local week view, no events, no account | Implemented (local only) |
| Weather | **Simulated empty state** ("Not configured"); no data is ever invented |
| Launcher search over installed `.desktop` files; keyboard Up/Down/Enter/Esc | Implemented |
| Pinned apps (foot, My OS Settings) resolved from installed `.desktop` files | Implemented |
| Wallpapers are generated gradients defined in `Theme.qml`, not image files | Implemented (no image assets yet) |
| Running-app indicators in the panel | **Needs integration** (window-management protocol) |
| Drawer: workspace overview, window list, workspace switching | **Needs integration**; the drawer shows a "not connected" state. `Sys.windowManagementAvailable` is the switch |
| Drawer shortcuts (launcher, terminal, settings) | Implemented |
| Widget reordering/resizing, panel position/size | Not implemented (documented in Settings) |

## Safety rules kept

`SystemApi` never runs shell strings; programs start from an argument list parsed from `.desktop` `Exec`. Preference keys and values are validated against an allow-list (`SystemApi::normalizePref`). Settings and shell only read/write the user's own config file.

## Runtime dependencies

No new packages compared with the existing KIWI package list. QtQuick.Layouts and QtQuick.Controls (Basic style) are part of `qt6-qtdeclarative`, which is already listed. Build time needs `qt6-qtbase-devel`, `qt6-qtdeclarative-devel`, `layer-shell-qt-devel`, `cmake`, `gcc-c++` (installed by `scripts/build-desktop.sh`). Install paths follow `GNUInstallDirs` (`/usr/bin`, `/usr/share/applications`).

## Known risks (unverified)

- `layer-shell-qt` API names were written from memory of its headers.
- A full-width bottom-layer widget surface receives clicks over its transparent areas; the 4 px edge handle intercepts clicks on the right screen edge.
- Exclusive keyboard focus on the launcher means keys go to it until it is closed (Esc, panel button, or clicking the desktop).
- Opening the launcher while another app has focus depends on labwc honouring exclusive layer focus.
