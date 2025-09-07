# Answer Application - Comprehensive Documentation

## Table of Contents
1. [System Architecture](#system-architecture)
2. [macOS App Distribution](#macos-app-distribution)
3. [User Guide](#user-guide)
4. [Developer Documentation](#developer-documentation)

---

## System Architecture

### Overview
Answer is a hybrid desktop application combining a multi-tab web browser with an AI-powered research assistant, built on Qt 6 framework with C++ backend and QML frontend.

### Technology Stack
- **Core Framework**: Qt 6.5+ (QtCore, QtGui, QtNetwork)
- **User Interface**: Qt Quick/QML for hardware-accelerated UI
- **Browser Engine**: Qt WebEngine (Chromium-based)
- **Build System**: CMake 3.16+
- **Language**: C++17 with QML

### Architecture Components

#### Core Components
1. **Browser Core**: Multi-tab browsing with session persistence
2. **Insights Engine**: Content analysis and theme extraction
3. **AI Interface**: Streaming chat with Statista integration

#### Component Details

##### ChatBridge (`src/chatbridge.cpp`)
- Manages conversation history and streaming responses
- Handles NDJSON/SSE protocol parsing
- Orchestrates tool calls to Statista MCP
- Key signals: `messagesChanged()`, `partialUpdated()`, `streamingFinished()`

##### Analyzer (`src/analyzer.cpp`)
- Content analysis service
- Theme extraction (naive and LLM-based)
- Statista MCP API integration
- Key methods: `analyzeTextLLM()`, `searchTheme()`, `executeMCPTool()`

##### Session (`src/session.cpp`)
- Application state management
- Tab persistence between sessions
- User preferences storage

### Data Flow

#### Chat with Tool Use
1. User input in ChatView.qml
2. QML calls `chat.sendMessage()`
3. ChatBridge sends request to Claude API
4. Streaming response processing
5. Tool call detection and execution
6. Analyzer executes MCP requests
7. Tool results returned to Claude
8. UI updates via signals

---

## macOS App Distribution

### Prerequisites
- Apple Developer Program membership
- Xcode Command Line Tools
- Developer ID Application certificate
- Qt 6.5+ installation

### Step 1: Build Release Version

```bash
cd /Users/colin.clark/Dev/answer
rm -rf build && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

### Step 2: Deploy Qt Dependencies

```bash
# Find macdeployqt (adjust path for your Qt installation)
# Homebrew: /opt/homebrew/opt/qt@6/bin/macdeployqt
# MacPorts: /opt/local/libexec/qt6/bin/macdeployqt

/path/to/macdeployqt answer.app -qmldir=../qml -always-overwrite
```

### Step 3: Code Signing

```bash
# Set your identity
IDENTITY="Developer ID Application: Your Name (TEAMID)"

# Sign frameworks
find answer.app/Contents/Frameworks -name "*.framework" -exec \
  codesign --force --verify --verbose --sign "$IDENTITY" \
  --options runtime --timestamp {} \;

# Sign plugins
find answer.app/Contents/PlugIns -name "*.dylib" -exec \
  codesign --force --verify --verbose --sign "$IDENTITY" \
  --options runtime --timestamp {} \;

# Sign main executable
codesign --force --verify --verbose --sign "$IDENTITY" \
  --options runtime --timestamp \
  answer.app/Contents/MacOS/answer

# Sign the app bundle
codesign --force --verify --verbose --sign "$IDENTITY" \
  --options runtime --timestamp \
  --entitlements ../distribution/entitlements.plist \
  answer.app
```

### Step 4: Create DMG

```bash
# Create DMG with hdiutil
mkdir dmg_contents
cp -R answer.app dmg_contents/
ln -s /Applications dmg_contents/Applications

hdiutil create -volname "Answer" -srcfolder dmg_contents \
  -ov -format UDZO answer.dmg

# Clean up
rm -rf dmg_contents
```

### Step 5: Notarization

```bash
# Store credentials
xcrun notarytool store-credentials "AC_PASSWORD" \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

# Submit for notarization
xcrun notarytool submit answer.dmg \
  --keychain-profile "AC_PASSWORD" \
  --wait

# Staple the ticket
xcrun stapler staple answer.dmg
```

### Required Entitlements

Create `distribution/entitlements.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <key>com.apple.security.network.server</key>
    <true/>
</dict>
</plist>
```

---

## User Guide

### Installation

1. Download `answer.dmg`
2. Double-click to mount the disk image
3. Drag Answer.app to Applications folder
4. Launch from Applications or Launchpad

### Initial Configuration

#### Setting API Keys

On first launch, configure your API keys via environment variables or the `.env` file:

```bash
# Create .env file in app directory
STATISTA_MCP_ENDPOINT=https://api.statista.ai/v1/mcp
STATISTA_MCP_API_KEY=your_statista_key
ANTHROPIC_API_KEY=your_claude_key
```

### Features

#### Multi-Tab Browsing
- Click `+` to add new tabs
- Click `×` on tabs to close them
- Tabs persist between sessions

#### Insights Panel
- Automatically extracts themes from web pages
- Click themes to search for related statistics
- Resizable split-view layout

#### AI Chat Assistant
- Ask questions about page content
- Automatic Statista database search
- Streaming responses with citations
- Follow-up suggestions

#### Right-Click Context Menu
- Select text on any webpage
- Right-click and choose "Ask Statista!"
- Selected text sent to chat for analysis

### Keyboard Shortcuts
- `Cmd+T`: New tab
- `Cmd+W`: Close current tab
- `Cmd+L`: Focus URL bar
- `Cmd+R`: Reload page

### Troubleshooting

| Issue | Solution |
|-------|----------|
| "Unidentified developer" error | Ensure using notarized version |
| API features not working | Check API keys in .env file |
| Slow performance | Close unnecessary tabs |
| Chat not responding | Verify internet connection |

---

## Developer Documentation

### Development Setup

#### Prerequisites
- Qt 6.5+ with WebEngine
- CMake 3.16+
- C++17 compiler
- macOS 11+ / Linux / Windows 10+

#### Build Instructions

```bash
# Clone repository
git clone https://github.com/yourusername/answer.git
cd answer

# Setup environment
cp .env.example .env
# Edit .env with your API keys

# Build
mkdir build && cd build
cmake ..
cmake --build .

# Run
./answer
```

### Project Structure

```
answer/
├── build/                  # Build artifacts
├── distribution/           # Distribution files
│   └── entitlements.plist # macOS entitlements
├── qml/                    # QML UI files
│   ├── Main.qml           # Main window
│   ├── TabWebView.qml     # Browser tab
│   ├── InsightsPanel.qml  # Insights sidebar
│   └── ChatView.qml       # Chat interface
├── src/                    # C++ source
│   ├── main.cpp           # Entry point
│   ├── chatbridge.h/cpp   # Chat management
│   ├── analyzer.h/cpp     # Content analysis
│   └── session.h/cpp      # Session state
├── CMakeLists.txt         # Build configuration
├── CLAUDE.md              # AI assistant guide
└── README.md              # Quick start guide
```

### API Integration

#### Adding New Tools

1. Add method to Analyzer:
```cpp
// analyzer.h
Q_INVOKABLE void newTool(const QString& param);
```

2. Handle in ChatBridge:
```cpp
// chatbridge.cpp
void ChatBridge::executeToolCall(...) {
    if (toolName == "new_tool") {
        m_analyzer->newTool(params);
    }
}
```

3. Emit result signal:
```cpp
// analyzer.cpp
void Analyzer::newTool(const QString& param) {
    // Process...
    emit toolResult(requestId, result);
}
```

### Testing

```bash
# Run tests
cd build
ctest

# Debug build
cmake .. -DCMAKE_BUILD_TYPE=Debug
cmake --build .
```

### Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing`)
3. Commit changes (`git commit -m 'Add feature'`)
4. Push to branch (`git push origin feature/amazing`)
5. Open Pull Request

### License

[Specify your license here]

---

## Appendix

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `STATISTA_MCP_ENDPOINT` | Statista API endpoint | Yes |
| `STATISTA_MCP_API_KEY` | Statista API key | Yes |
| `ANTHROPIC_API_KEY` | Claude API key | Yes |

### Dependencies

- Qt 6.5+
  - Core, Gui, Network, Quick, WebEngineQuick
- CMake 3.16+
- C++17 standard library

### Support

For issues and questions:
- GitHub Issues: [repository-url]/issues
- Email: support@example.com