configure_file(vylo_config.h.in ${CMAKE_CURRENT_BINARY_DIR}/vylo_config.h @ONLY)

add_library(vylo-system STATIC systemapi.cpp systemapi.h)
target_include_directories(vylo-system PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR})
target_link_libraries(vylo-system PUBLIC Qt6::Core Qt6::Gui Qt6::Qml)
