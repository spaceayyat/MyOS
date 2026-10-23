# QML files that live outside this directory get a flat alias so every shell
# QML file sits in one resource directory and can use the others by name.
set(MYOS_SHARED_QML
    ${CMAKE_SOURCE_DIR}/shared/theme/Theme.qml
    ${CMAKE_SOURCE_DIR}/shared/ui/Card.qml
    ${CMAKE_SOURCE_DIR}/desktop/launcher/Launcher.qml
    ${CMAKE_SOURCE_DIR}/desktop/widgets/ClockWidget.qml
    ${CMAKE_SOURCE_DIR}/desktop/widgets/CalendarWidget.qml
    ${CMAKE_SOURCE_DIR}/desktop/widgets/WeatherWidget.qml
    ${CMAKE_SOURCE_DIR}/desktop/widgets/MonitorWidget.qml)
foreach(f ${MYOS_SHARED_QML})
    get_filename_component(_name ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS ${_name})
endforeach()

qt_add_executable(myos-shell main.cpp shellstate.h)

qt_add_resources(myos-shell shell_qml
    PREFIX "/myos/shell"
    FILES
        Wallpaper.qml
        Widgets.qml
        Panel.qml
        EdgeHandle.qml
        Drawer.qml
        ${MYOS_SHARED_QML}
)

target_link_libraries(myos-shell PRIVATE
    myos-system
    Qt6::Quick
    Qt6::QuickControls2
    LayerShellQt::Interface
)

install(TARGETS myos-shell RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
