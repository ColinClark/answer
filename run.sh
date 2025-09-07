#!/bin/bash

# Quick run script for the answer application

# Load environment
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check if built
if [ ! -f build/answer ]; then
    echo "Application not built. Building now..."
    ./build.sh
fi

# Run the application
echo "Starting answer application..."
cd build && ./answer