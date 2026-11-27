# Files that live outside this directory get a flat alias, so every shell QML
# file sits in one resource directory and can use the others by name.
set(VYLO_SHARED_QML
    ${CMAKE_SOURCE_DIR}/shared/theme/Theme.qml
    ${CMAKE_SOURCE_DIR}/shared/ui/Card.qml
    ${CMAKE_SOURCE_DIR}/shared/ui/Icon.qml
    ${CMAKE_SOURCE_DIR}/shared/ui/AppIcon.qml
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

set(VYLO_BRAND ${CMAKE_SOURCE_DIR}/assets/brand/vylo-mark.svg
               ${CMAKE_SOURCE_DIR}/assets/brand/vylo-app-icon.svg)
foreach(f ${VYLO_BRAND})
    get_filename_component(_name ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS brand/${_name})
endforeach()

file(GLOB VYLO_ICONS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} icons/*.svg)

qt_add_executable(vylo-shell main.cpp shellstate.h appicons.h)

qt_add_resources(vylo-shell shell_qml
    PREFIX "/vylo/shell"
    FILES
        Wallpaper.qml
        Widgets.qml
        Panel.qml
        Dock.qml
        Flyout.qml
        ${VYLO_SHARED_QML}
        ${VYLO_BRAND}
        ${VYLO_ICONS}
)

target_link_libraries(vylo-shell PRIVATE
    vylo-system
    Qt6::Quick
    Qt6::QuickControls2
    LayerShellQt::Interface
)

install(TARGETS vylo-shell RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
