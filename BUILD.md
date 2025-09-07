# Build Instructions

## Prerequisites

- Qt 6.5+ with WebEngine and Quick modules
- CMake 3.16+
- C++17 compatible compiler
- API key for Statista MCP endpoint

## Quick Start

1. **Set up environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your API key
   ```

2. **Build and run:**
   ```bash
   make build
   make run
   ```

## Build Commands

### Using Make (Recommended)

```bash
make build       # Build release version
make debug       # Build debug version with symbols
make clean       # Remove all build artifacts
make run         # Build and run release
make run-debug   # Build and run debug
make env-setup   # Create .env template
make help        # Show all available commands
```

### Using Scripts Directly

```bash
./build.sh       # Build release version
./build-debug.sh # Build debug version
./clean.sh       # Clean build artifacts
```

### Manual CMake Build

```bash
# Load environment
source .env

# Create build directory
mkdir build && cd build

# Configure
cmake -DCMAKE_BUILD_TYPE=Release ..

# Build
cmake --build . -j$(nproc)

# Run
./MicroBrowser
```

## Platform-Specific Notes

### macOS
- Install Qt6: `brew install qt@6`
- May need to add Qt to PATH: `export PATH="/opt/homebrew/opt/qt@6/bin:$PATH"`

### Linux (Ubuntu/Debian)
- Install dependencies: `make deps-linux`
- Or manually: `sudo apt-get install qt6-base-dev qt6-webengine-dev qt6-declarative-dev`

### Windows
- Use `build.bat` for building
- Ensure Qt6 is in your PATH
- Visual Studio 2019 or later recommended

## Debug Build Features

Debug builds include:
- Debug symbols for GDB/LLDB
- WebEngine DevTools on port 9222
- Assertions enabled
- Compile commands export for IDE integration

## Environment Variables

Required (set in .env):
- `STATISTA_MCP_ENDPOINT`: API endpoint URL
- `STATISTA_MCP_API_KEY`: Your API key

## Troubleshooting

1. **Qt not found:** Ensure Qt6 is installed and in PATH
2. **API key errors:** Check .env file exists and contains valid key
3. **Build failures:** Run `make clean` then rebuild
4. **WebEngine issues:** Ensure qt6-webengine-dev is installed