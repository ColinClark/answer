# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run Commands

```bash
# Clean previous build
./clean.sh

# Build the application (loads .env automatically)
./build.sh

# The app is built as Mercury.app with proper branding
# Executable: build/Mercury.app/Contents/MacOS/Mercury
```

## API Key Configuration

The app uses embedded API keys from `src/config_keys.h` (gitignored):
1. Copy `src/config_keys.h.example` to `src/config_keys.h`
2. Add your API keys to the file
3. Build the app - keys will be embedded

Environment variables in `.env` override embedded keys if present:
- `STATISTA_MCP_ENDPOINT` - Statista API endpoint
- `STATISTA_MCP_API_KEY` - Statista API key  
- `ANTHROPIC_API_KEY` - Claude API key

## macOS Distribution

**Important**: The app requires Qt6 installed via Homebrew to run.

### Creating DMG for Distribution
```bash
# Sign the app (ad-hoc for local testing)
codesign --force --deep --sign - build/Mercury.app

# Create DMG
./create_dmg_simple.sh
# Output: build/Mercury-Simple.dmg
```

### Known Issues with macOS Packaging
- Qt 6.9's macdeployqt has bugs preventing proper framework bundling
- The app binary must link to system Qt libraries at `/opt/homebrew/opt/qt/lib/`
- Info.plist must have `CFBundleExecutable` set to "Mercury" not "answer"

## Project Architecture

This is a Qt6/QML-based streaming chat application with web browser integration. Key architectural components:

- **Qt/QML Stack**: Uses Qt6 with Quick, WebEngineQuick, and Network modules for UI and networking
- **Streaming Chat**: Implements NDJSON streaming (`statista.llm.chat.stream`) supporting:
  - Delta tokens for incremental text updates
  - Citation events with title/url for source references
  - Follow-up query suggestions from the assistant
- **Multi-tab Browser**: Embedded WebEngine views allow opening citations in new tabs
- **Follow-up Queue**: Manages suggested queries that can be run individually or sequentially

## Core Components

- **ChatBridge** (`src/chatbridge.cpp`): Handles streaming chat communication with the MCP endpoint, parsing NDJSON responses
- **Session** (`src/session.cpp`): Manages application session state
- **Analyzer** (`src/analyzer.cpp`): Analyzes content and interfaces with the MCP API
- **QML Views**: 
  - `Main.qml`: Application entry point and window management
  - `ChatView.qml`: Chat interface with streaming support
  - `TabWebView.qml`: Browser tab implementation
  - `InsightsPanel.qml`: Panel for displaying insights and analysis

## Stream Format

The application expects NDJSON format from the chat endpoint:
```json
{"type":"delta","text":"partial token ..."}
{"type":"citation","title":"Title","url":"https://..."}
{"type":"followups","items":[{"query":"..."}]}
```

Modify `ChatBridge::postStream()` if switching to SSE or different schema.
- remember to always clean before build
- remember to look at todo list after compaction
- remember not to run the code - i will run the code myself for testing
- remember to read claude.md if you need to remember how to build the app