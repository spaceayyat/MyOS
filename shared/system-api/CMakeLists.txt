configure_file(myos_config.h.in ${CMAKE_CURRENT_BINARY_DIR}/myos_config.h @ONLY)

add_library(myos-system STATIC systemapi.cpp systemapi.h)
target_include_directories(myos-system PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR})
target_link_libraries(myos-system PUBLIC Qt6::Core Qt6::Gui Qt6::Qml)
