#!/bin/bash

# Quick run script for the Mercury application

# Load environment variables from .env
if [ -f .env ]; then
    echo "Loading environment variables from .env..."
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Warning: .env file not found"
fi

# Check if built
if [ ! -f build/Mercury.app/Contents/MacOS/Mercury ]; then
    echo "Application not built. Building now..."
    ./build.sh
fi

# Run the application with environment variables
echo "Starting Mercury application..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # On macOS, use open with --env to pass environment variables
    # First, check if we have the required API keys
    if [ -z "$STATISTA_MCP_API_KEY" ]; then
        echo "Warning: STATISTA_MCP_API_KEY not set"
    fi
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        echo "Warning: ANTHROPIC_API_KEY not set"
    fi

    # Launch with environment variables
    STATISTA_MCP_ENDPOINT="$STATISTA_MCP_ENDPOINT" \
    STATISTA_MCP_API_KEY="$STATISTA_MCP_API_KEY" \
    ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
    open build/Mercury.app
else
    build/Mercury.app/Contents/MacOS/Mercury
fi