# PIP is optional: built only with -DVYLO_BUILD_PIP=ON and shipped as its own
# package. The ISO does not contain it.
set(VYLO_PIP_SHARED ${CMAKE_SOURCE_DIR}/shared/theme/Theme.qml)
foreach(f ${VYLO_PIP_SHARED})
    get_filename_component(_name ${f} NAME)
    set_source_files_properties(${f} PROPERTIES QT_RESOURCE_ALIAS ${_name})
endforeach()

add_library(vylo-pip-core STATIC pipbrain.cpp pipbrain.h pipmath.cpp downloader.cpp downloader.h)
target_include_directories(vylo-pip-core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(vylo-pip-core PUBLIC Qt6::Core Qt6::Network)

qt_add_executable(vylo-pip main.cpp controller.cpp controller.h)

qt_add_resources(vylo-pip pip_qml
    PREFIX "/vylo/pip"
    FILES
        Buddy.qml
        Chat.qml
        PipFace.qml
        ${VYLO_PIP_SHARED}
)

target_link_libraries(vylo-pip PRIVATE
    vylo-pip-core
    vylo-system
    Qt6::Quick
    Qt6::QuickControls2
    LayerShellQt::Interface
)

install(TARGETS vylo-pip RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES vylo-pip.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES vylo-pip.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)

if(VYLO_BUILD_TESTS)
    find_package(Qt6 REQUIRED COMPONENTS Test)
    qt_add_executable(pip-test ${CMAKE_SOURCE_DIR}/tests/pip/test_pip.cpp)
    target_link_libraries(pip-test PRIVATE vylo-pip-core Qt6::Test)
    add_test(NAME pip COMMAND pip-test)
endif()
