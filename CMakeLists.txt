cmake_minimum_required(VERSION 3.21)
project(MyOS VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

include(GNUInstallDirs)

# Name shown on the wallpaper and the panel menu button.
set(MYOS_DISPLAY_NAME "My OS" CACHE STRING "OS name shown in the desktop")

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)
find_package(LayerShellQt REQUIRED)

add_subdirectory(shared/system-api)
add_subdirectory(desktop/shell)
add_subdirectory(desktop/settings)
