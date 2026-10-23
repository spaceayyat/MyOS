set(MYOS_SETTINGS_SHARED ${CMAKE_SOURCE_DIR}/shared/theme/Theme.qml ${CMAKE_SOURCE_DIR}/shared/ui/Card.qml)
foreach(f ${MYOS_SETTINGS_SHARED})
    get_filename_component(_name ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS ${_name})
endforeach()

qt_add_executable(myos-settings main.cpp)

qt_add_resources(myos-settings settings_qml
    PREFIX "/myos/settings"
    FILES
        main.qml
        ${MYOS_SETTINGS_SHARED}
)

target_link_libraries(myos-settings PRIVATE
    myos-system
    Qt6::Quick
    Qt6::QuickControls2
)

install(TARGETS myos-settings RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES myos-settings.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
