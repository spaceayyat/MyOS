cmake_minimum_required(VERSION 3.21)
project(VYLO VERSION 0.4.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

include(GNUInstallDirs)

# Name shown in the top bar and in Settings.
set(VYLO_DISPLAY_NAME "VYLO OS" CACHE STRING "OS name shown in the desktop")

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 DBus Network)
find_package(LayerShellQt REQUIRED)

option(VYLO_BUILD_DESKTOP "Build the shell and Settings" ON)
option(VYLO_BUILD_PIP "Build the optional PIP helper" OFF)
option(VYLO_BUILD_TESTS "Build the C++ tests" OFF)
enable_testing()

add_subdirectory(shared/system-api)
if(VYLO_BUILD_DESKTOP)
    add_subdirectory(desktop/shell)
    add_subdirectory(desktop/settings)
endif()
if(VYLO_BUILD_PIP)
    add_subdirectory(desktop/pip)
endif()
