#!/bin/bash

# MicroBrowser Build Script
# Builds the application for release

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Building MicroBrowser...${NC}"

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
    echo -e "${YELLOW}Warning: STATISTA_MCP_API_KEY not set${NC}"
    echo "Please create a .env file with your API key"
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
mkdir -p build
cd build

# Configure with CMake
echo -e "${GREEN}Configuring...${NC}"

# Use system clang and set ARM64 architecture for macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    CC=/usr/bin/clang CXX=/usr/bin/clang++ cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 ..
else
    cmake -DCMAKE_BUILD_TYPE=Release ..
fi

# Build
echo -e "${GREEN}Building...${NC}"
cmake --build . --config Release -j${CORES}

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Build successful!${NC}"

    # On macOS, show app bundle info
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [ -d "Mercury.app" ]; then
            echo -e "${GREEN}App bundle created: ${PWD}/Mercury.app${NC}"
            echo -e "Executable: ${PWD}/Mercury.app/Contents/MacOS/Mercury"
        fi
    else
        echo -e "Executable: ${PWD}/Mercury"
    fi
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Done!${NC}"