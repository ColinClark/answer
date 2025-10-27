#!/bin/bash

# MicroBrowser Debug Build Script
# Builds the application with debug symbols and development features

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Building MicroBrowser (Debug)...${NC}"

# Load environment variables from .env file
if [ -f .env ]; then
    echo -e "${GREEN}Loading .env file...${NC}"
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${YELLOW}Warning: .env file not found${NC}"
fi

# Check for required environment variables
if [ -z "$STATISTA_MCP_ENDPOINT" ]; then
    echo -e "${YELLOW}Warning: STATISTA_MCP_ENDPOINT not set, using default${NC}"
    export STATISTA_MCP_ENDPOINT="https://api.statista.ai/v1/mcp"
fi

if [ -z "$STATISTA_MCP_API_KEY" ]; then
    echo -e "${RED}Error: STATISTA_MCP_API_KEY not set${NC}"
    echo "Please create a .env file with your API key"
    exit 1
fi

# Detect number of cores for parallel build
if [[ "$OSTYPE" == "darwin"* ]]; then
    CORES=$(sysctl -n hw.ncpu)
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    CORES=$(nproc)
else
    CORES=4
fi

echo -e "Using ${CORES} cores for build"

# Create build directory
mkdir -p build-debug
cd build-debug

# Configure with CMake for Debug
echo -e "${BLUE}Configuring for Debug...${NC}"

# Use system clang and set ARM64 architecture for macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    CC=/usr/bin/clang CXX=/usr/bin/clang++ cmake -DCMAKE_BUILD_TYPE=Debug \
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
          -DCMAKE_OSX_ARCHITECTURES=arm64 \
          ..
else
    cmake -DCMAKE_BUILD_TYPE=Debug \
          -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
          ..
fi

# Build
echo -e "${BLUE}Building...${NC}"
cmake --build . --config Debug -j${CORES}

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Debug build successful!${NC}"

    # On macOS, show app bundle info
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [ -d "Mercury.app" ]; then
            echo -e "Executable: ${PWD}/Mercury.app/Contents/MacOS/Mercury"
        fi
    else
        echo -e "Executable: ${PWD}/Mercury"
    fi

    echo -e "${BLUE}Debug features enabled:${NC}"
    echo "  - Debug symbols"
    echo "  - WebEngine DevTools on port 9222"
    echo "  - Assertions enabled"
    echo "  - Compile commands exported"
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Done!${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}To run: open build-debug/Mercury.app${NC}"
else
    echo -e "${YELLOW}To run: cd build-debug && ./Mercury${NC}"
fi