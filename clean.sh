#!/bin/bash

# Clean build artifacts

echo "Cleaning build artifacts..."

# Remove build directory
if [ -d "build" ]; then
    rm -rf build
    echo "Removed build directory"
fi

# Remove CMake cache files if they exist in root
if [ -f "CMakeCache.txt" ]; then
    rm -f CMakeCache.txt
    echo "Removed CMakeCache.txt"
fi

if [ -d "CMakeFiles" ]; then
    rm -rf CMakeFiles
    echo "Removed CMakeFiles"
fi

# Remove any generated files
rm -f cmake_install.cmake
rm -f Makefile
rm -f *.cmake

# Remove Qt generated files
rm -rf .rcc
rm -rf .moc
rm -rf .obj
rm -rf .qmake.stash

# Remove any debug symbols
rm -rf *.dSYM

echo "Clean complete!"