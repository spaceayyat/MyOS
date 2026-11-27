set(VYLO_SETTINGS_SHARED ${CMAKE_SOURCE_DIR}/shared/theme/Theme.qml)
foreach(f ${VYLO_SETTINGS_SHARED})
    get_filename_component(_name ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS ${_name})
endforeach()

set(VYLO_SETTINGS_BRAND ${CMAKE_SOURCE_DIR}/assets/brand/vylo-logo.svg
                        ${CMAKE_SOURCE_DIR}/assets/brand/vylo-logo-dark.svg)
foreach(f ${VYLO_SETTINGS_BRAND})
    get_filename_component(_name ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS brand/${_name})
endforeach()

qt_add_executable(vylo-settings main.cpp)

qt_add_resources(vylo-settings settings_qml
    PREFIX "/vylo/settings"
    FILES
        main.qml
        ${VYLO_SETTINGS_SHARED}
        ${VYLO_SETTINGS_BRAND}
)

target_link_libraries(vylo-settings PRIVATE
    vylo-system
    Qt6::Quick
    Qt6::QuickControls2
)

install(TARGETS vylo-settings RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES vylo-settings.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES ${CMAKE_SOURCE_DIR}/assets/brand/vylo-app-icon.svg
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
        RENAME vylo.svg)
