# Files that live outside this directory get a flat alias, so every shell QML
# file sits in one resource directory and can use the others by name.
set(VYLO_SHARED_QML
    ${CMAKE_SOURCE_DIR}/shared/theme/Theme.qml
    ${CMAKE_SOURCE_DIR}/shared/ui/Card.qml
    ${CMAKE_SOURCE_DIR}/shared/ui/Icon.qml
    ${CMAKE_SOURCE_DIR}/shared/ui/AppIcon.qml
    ${CMAKE_SOURCE_DIR}/shared/ui/Logo.qml
    ${CMAKE_SOURCE_DIR}/shared/ui/Toggle.qml
    ${CMAKE_SOURCE_DIR}/shared/ui/NoticeCard.qml
    ${CMAKE_SOURCE_DIR}/desktop/launcher/Launcher.qml
    ${CMAKE_SOURCE_DIR}/desktop/widgets/ClockWidget.qml
    ${CMAKE_SOURCE_DIR}/desktop/widgets/CalendarWidget.qml
    ${CMAKE_SOURCE_DIR}/desktop/widgets/MonthView.qml
    ${CMAKE_SOURCE_DIR}/desktop/widgets/WeatherWidget.qml
    ${CMAKE_SOURCE_DIR}/desktop/widgets/MonitorWidget.qml)
foreach(f ${VYLO_SHARED_QML})
    get_filename_component(_name ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS ${_name})
endforeach()

file(GLOB VYLO_ICONS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} icons/*.svg)

# Client code for the compositor protocol that lists open windows.
find_package(PkgConfig REQUIRED)
pkg_check_modules(WAYLAND_CLIENT REQUIRED IMPORTED_TARGET wayland-client)
find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)
find_file(TOPLEVEL_XML wlr-foreign-toplevel-management-unstable-v1.xml
          PATHS /usr/share/wlr-protocols/unstable REQUIRED)
set(TOPLEVEL ${CMAKE_CURRENT_BINARY_DIR}/wlr-foreign-toplevel-management-unstable-v1)
add_custom_command(
    OUTPUT ${TOPLEVEL}-client-protocol.h ${TOPLEVEL}-protocol.c
    COMMAND ${WAYLAND_SCANNER} client-header ${TOPLEVEL_XML} ${TOPLEVEL}-client-protocol.h
    COMMAND ${WAYLAND_SCANNER} private-code ${TOPLEVEL_XML} ${TOPLEVEL}-protocol.c
    DEPENDS ${TOPLEVEL_XML}
    VERBATIM)

qt_add_executable(vylo-shell main.cpp shellstate.h appicons.h
    windows.cpp windows.h notifications.cpp notifications.h
    ${TOPLEVEL}-protocol.c ${TOPLEVEL}-client-protocol.h)
target_include_directories(vylo-shell PRIVATE ${CMAKE_CURRENT_BINARY_DIR})

qt_add_resources(vylo-shell shell_qml
    PREFIX "/vylo/shell"
    FILES
        Wallpaper.qml
        Widgets.qml
        Panel.qml
        Dock.qml
        Flyout.qml
        Toasts.qml
        Welcome.qml
        ${VYLO_SHARED_QML}
        ${VYLO_ICONS}
)

target_link_libraries(vylo-shell PRIVATE
    vylo-system
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::DBus
    Qt6::Network
    LayerShellQt::Interface
    PkgConfig::WAYLAND_CLIENT
)

install(TARGETS vylo-shell RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
