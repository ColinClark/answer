# Mercury - Statista Research Assistant

A Qt6/QML-based desktop application that combines web browsing with AI-powered statistical research capabilities through integration with the Statista API and Claude.

## Features

### 🌐 Multi-Tab Web Browser
- Full-featured web browser with multiple tab support
- WebEngine-based rendering for modern web compatibility
- Download manager with progress tracking
- Session persistence across application restarts
- DevTools integration for debugging

### 🤖 AI-Powered Research Assistant
- **Streaming Chat Interface**: Real-time responses with smooth text streaming (no flashing)
- **Statista Integration**: Direct access to statistical data and research
- **Smart Themes**: Automatic extraction and analysis of page content themes
- **Citations**: Automatic source tracking with clickable references
- **Follow-up Suggestions**: Intelligent query suggestions based on context

### 📊 Insights Panel
- **Theme Extraction**: Automatically identifies key topics from web pages
- **LLM vs Fast Mode**: Toggle between AI-powered and quick theme extraction
- **Interactive Chat**: Context-aware conversations about current page content
- **Visual Design**: Modern, gradient-based UI with smooth animations

## Quick Start for End Users

**If you received Mercury-Simple.dmg**, see [INSTALLATION.md](INSTALLATION.md) for complete setup instructions.

## Prerequisites for Development

- Qt6 (6.5 or later) with the following modules:
  - QtCore
  - QtQuick
  - QtWebEngine
  - QtNetwork
  - Qt.labs.platform
- CMake 3.16 or later
- C++17 compatible compiler
- API Keys:
  - Statista MCP API key
  - Claude API key (optional, for direct Claude integration)

## Installation

### macOS

1. Install Qt6 via Homebrew:
```bash
brew install qt@6
```

2. Clone the repository:
```bash
git clone <repository-url>
cd answer
```

3. Configure API keys (choose one method):

#### Method A: Environment Variables (Development)
```bash
cp .env.example .env
# Edit .env and add your API keys:
# STATISTA_MCP_ENDPOINT=https://api.statista.ai/v1/mcp
# STATISTA_MCP_API_KEY=your_key_here
# ANTHROPIC_API_KEY=your_claude_key_here
```

#### Method B: Embedded Keys (Distribution)
```bash
# Copy the example configuration
cp src/config_keys.h.example src/config_keys.h

# Edit src/config_keys.h and add your keys:
# #define TEMP_STATISTA_API_KEY "your_actual_key"
# #define TEMP_ANTHROPIC_API_KEY "your_actual_key"
```

**Note**: `src/config_keys.h` is gitignored and will embed keys directly in the binary. This is useful for demo/distribution but should not be used for production. See `src/config_keys.h.example` for the template.

### Building

```bash
# Clean build (recommended for first build or after major changes)
./clean.sh

# Build the application (automatically loads .env for API keys)
./build.sh

# The app is built as Mercury.app in the build directory
```

### Running

```bash
# Run directly from build directory
open build/Mercury.app

# Or via command line
./build/Mercury.app/Contents/MacOS/Mercury
```

### Creating Distribution DMG

```bash
# 1. Ensure API keys are embedded (see Installation section)
# 2. Sign the app
codesign --force --deep --sign - build/Mercury.app

# 3. Create DMG
./create_dmg_simple.sh
# Output: build/Mercury-Simple.dmg (2.3MB)
```

**Note**: The DMG requires Qt6 to be installed via Homebrew on the target machine.

## Usage

1. **Browse the Web**: Use the browser tabs to navigate to any website
2. **Open Insights Panel**: Click the "Insights" button in the toolbar
3. **Extract Themes**: The panel automatically analyzes visible page content
4. **Ask Questions**: Use the chat interface to ask about statistics and data
5. **Explore Citations**: Click on citation buttons to open sources in new tabs
6. **Follow Suggestions**: Use the suggested follow-up questions for deeper research

## Architecture

### Core Components

- **ChatBridge** (`src/chatbridge.cpp`): Manages streaming chat communication
  - Handles NDJSON streaming format
  - Processes delta tokens, citations, and follow-up suggestions
  - Maintains conversation history and context
  - Implements smooth streaming without UI flashing

- **Analyzer** (`src/analyzer.cpp`): Interfaces with Statista MCP API
  - Extracts themes from web content
  - Manages MCP session initialization
  - Handles both LLM and fast analysis modes

- **Session** (`src/session.cpp`): Manages application state persistence
  - Saves and restores browser tabs
  - Maintains active tab index
  - Stores user preferences

### QML Views

- **Main.qml**: Application window and top-level navigation
- **ChatView.qml**: Modern chat interface with streaming support
- **InsightsPanel.qml**: Side panel for themes and chat interaction
- **TabWebView.qml**: Web browser tab implementation

## Streaming Protocol

The application uses NDJSON (Newline Delimited JSON) for streaming responses:

```json
{"type":"delta","text":"partial token..."}
{"type":"citation","title":"Source Title","url":"https://..."}
{"type":"followups","items":[{"query":"Suggested question?"}]}
```

For SSE endpoints, modify `ChatBridge::postStream()` to parse lines starting with `data:`.

## Development

### Project Structure

```
answer/
├── src/               # C++ source files
│   ├── main.cpp      # Application entry point
│   ├── chatbridge.cpp/h  # Chat streaming logic
│   ├── analyzer.cpp/h    # Content analysis
│   └── session.cpp/h      # Session management
├── qml/              # QML interface files
│   ├── Main.qml      # Main window
│   ├── ChatView.qml  # Chat interface
│   ├── InsightsPanel.qml  # Insights panel
│   └── TabWebView.qml     # Browser tabs
├── CMakeLists.txt    # Build configuration
├── CLAUDE.md         # AI assistant instructions
└── build.sh/clean.sh # Build scripts
```

### Key Features Implementation

#### Streaming Without Flashing
- Uses `partialUpdated` signal for incremental updates
- Maintains `streamingContent` property separate from final messages
- Only updates the active streaming message, not entire message list

#### Theme Display
- Flow layout for responsive horizontal arrangement
- Automatic wrapping to new lines
- Clickable themes trigger relevant searches
- Proper spacing and sizing to prevent overlapping

#### Multi-Tab Browser
- Dynamic tab creation and management
- Session persistence across restarts
- Integration with insights panel for current tab analysis

## Configuration

### Environment Variables

Create a `.env` file with:
```bash
export STATISTA_MCP_ENDPOINT="https://api.statista.ai/v1/mcp"
export STATISTA_MCP_API_KEY="your_key_here"
export ANTHROPIC_API_KEY="your_claude_key_here"  # Optional
```

### Build Options

The `build.sh` script automatically:
- Loads environment variables from `.env`
- Sets up parallel compilation based on CPU cores
- Configures Qt paths
- Handles debug/release builds

## macOS Distribution

To package Mercury for distribution to other Mac users:

```bash
# Run the packaging script
./distribution/package_macos.sh

# Select option 3 for full build, sign, and notarize
# This creates Mercury-1.0.0.dmg ready for distribution
```

The packaged app includes embedded API keys (if configured) and requires no additional setup for end users.

See [DOCUMENTATION.md](DOCUMENTATION.md) for detailed distribution instructions including code signing and notarization.

## Troubleshooting

### Build Issues

If you encounter build errors:
1. Run `./clean.sh` to remove all build artifacts
2. Ensure Qt6 is properly installed and in PATH
3. Check that all required Qt modules are installed
4. Verify CMake version is 3.16 or later

### Runtime Issues

- **Themes overlapping**: Fixed in latest version with proper Flow layout
- **Empty assistant responses**: Ensure API keys are correctly set
- **Streaming flashing**: Uses partial update mechanism to prevent redraws
- **WebEngine errors**: Check Qt WebEngine is properly installed

### API Configuration

Common issues:
- **401 Unauthorized**: Check API key is valid
- **Network errors**: Verify endpoint URL is correct
- **Empty responses**: Ensure proper API permissions

## Contributing

When contributing to this project:
1. Follow existing code patterns and conventions
2. Test changes thoroughly with `./clean.sh && ./build.sh`
3. Update CLAUDE.md if adding new architectural components
4. Ensure streaming functionality remains smooth
5. Maintain backward compatibility

## License

[License information to be added]

## Acknowledgments

- Built with Qt6 framework
- Powered by Statista API for statistical data
- Enhanced with Claude AI for intelligent assistance
- UI/UX inspired by modern chat applications

