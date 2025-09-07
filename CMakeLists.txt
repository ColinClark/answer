cmake_minimum_required(VERSION 3.16)
project(MicroBrowser VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable better defaults
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Set build type if not specified
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# Compiler optimizations and warnings
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    add_compile_options(-Wall -Wextra -Wpedantic)
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        add_compile_options(-O3 -DNDEBUG)
    elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
        add_compile_options(-O0 -g -DDEBUG)
        # Enable WebEngine debugging
        add_compile_definitions(QTWEBENGINE_REMOTE_DEBUGGING)
    endif()
elseif(MSVC)
    add_compile_options(/W4)
    if(CMAKE_BUILD_TYPE STREQUAL "Release")
        add_compile_options(/O2 /DNDEBUG)
    elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
        add_compile_options(/Od /DEBUG)
    endif()
endif()

# macOS specific settings
if(APPLE)
    set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0" CACHE STRING "Minimum macOS version")
endif()

find_package(Qt6 6.5 REQUIRED COMPONENTS Quick WebEngineQuick Network)

qt_add_executable(MicroBrowserApp
    src/main.cpp
    src/session.h
    src/session.cpp
    src/analyzer.h
    src/analyzer.cpp
    src/chatbridge.h
    src/chatbridge.cpp
)

qt_add_qml_module(MicroBrowserApp
    URI MicroBrowser
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/TabWebView.qml
        qml/InsightsPanel.qml
        qml/ChatView.qml
)

target_link_libraries(MicroBrowserApp
    PRIVATE
        Qt6::Quick
        Qt6::WebEngineQuick
        Qt6::Network
)

# Create a nicer output name
set_target_properties(MicroBrowserApp PROPERTIES OUTPUT_NAME answer)