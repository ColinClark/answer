# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run Commands

```bash
# Clean previous build (always recommended before rebuilding)
./clean.sh

# Build the application (loads .env automatically)
./build.sh

# Debug build with symbols and WebEngine DevTools on port 9222
./build-debug.sh

# Run the application
open build/Mercury.app
# Or: ./build/Mercury.app/Contents/MacOS/Mercury

# The app is built as Mercury.app with proper branding
# Executable: build/Mercury.app/Contents/MacOS/Mercury
```

## API Key Configuration

The app uses embedded API keys from `src/config_keys.h` (gitignored):
1. Copy `src/config_keys.h.example` to `src/config_keys.h`
2. Add your API keys to the file
3. Build the app - keys will be embedded

Environment variables in `.env` override embedded keys if present:
- `STATISTA_MCP_ENDPOINT` - Statista API endpoint (default: https://api.statista.ai/v1/mcp)
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
- **Streaming Chat**: Implements NDJSON streaming supporting:
  - Delta tokens for incremental text updates
  - Citation events with title/url for source references
  - Follow-up query suggestions from the assistant
- **Multi-tab Browser**: Embedded WebEngine views allow opening citations in new tabs
- **MCP Integration**: Uses JSON-RPC 2.0 protocol for Statista MCP API communication
- **Dual API Architecture**: ChatBridge handles Claude API, Analyzer handles Statista MCP
- **Follow-up Queue**: Manages suggested queries that can be run individually or sequentially

## Core Components

### Backend (C++)

- **ChatBridge** (`src/chatbridge.cpp`):
  - Manages streaming chat communication with Claude API
  - Parses NDJSON responses (delta, citation, followups events)
  - Forwards tool use requests to Analyzer
  - Maintains conversation history in `m_messages` QVariantList
  - Uses `partialUpdated()` signal for smooth streaming without UI flashing
  - Key methods: `sendMessage()`, `sendThemeQuery()`, `runFollowupQueue()`

- **Analyzer** (`src/analyzer.cpp`):
  - Interfaces with Statista MCP API via JSON-RPC 2.0
  - Initializes MCP session with protocol version 2024-11-05
  - Extracts themes (naive parsing or LLM-based)
  - Executes MCP tools: `extract-themes`, `search-statistics`
  - Returns tool results to ChatBridge for Claude's tool use workflow
  - Key methods: `analyzeTextFast()`, `analyzeTextLLM()`, `searchTheme()`, `executeMCPTool()`

- **Session** (`src/session.cpp`):
  - Manages application session persistence via QSettings
  - Saves/loads browser tab URLs and active index
  - Storage location: `~/Library/Preferences/MicroCo.MicroBrowser.plist` (macOS)

- **Config** (`src/config.h`):
  - Provides API key configuration with fallback mechanism
  - Checks config_keys.h first, then environment variables
  - Returns compiled defaults if neither available

### QML Views

- **Main.qml**:
  - Application entry point and window management
  - Manages multi-tab browser with TabBar
  - Routes signals between InsightsPanel, ChatView, and backend components
  - Loads session on startup (tabs + active index)

- **ChatView.qml**:
  - Chat interface with streaming support
  - Displays messages with alternating bubbles (user right, assistant left)
  - Shows numbered citation buttons: `[1] Title`
  - Lists follow-up suggestions with "Run next" queue button
  - Properties: `messages[]`, `streamingContent`, `isStreaming`, `followups[]`

- **TabWebView.qml**:
  - Browser tab implementation with WebEngineView
  - Context menu with "Ask Statista!" option for selected text
  - Extracts visible page text via JavaScript: `document.body.innerText`
  - Auto-detects new windows and opens in new tabs

- **InsightsPanel.qml**:
  - Panel for displaying themes and chat interface
  - Flow layout of clickable theme chips
  - Theme click triggers dual action: search via Analyzer + chat query via ChatBridge
  - Embedded ChatView for context-aware queries

## Stream Format

The application expects NDJSON format from the Claude API streaming endpoint:
```json
{"type":"delta","text":"partial token ..."}
{"type":"citation","title":"Title","url":"https://..."}
{"type":"followups","items":[{"query":"..."}]}
```

Modify `ChatBridge::postStream()` if switching to SSE or different schema.

## Key Data Flows

### Theme Click Flow
```
User clicks theme in InsightsPanel
    ├── themeClicked(theme) → analyzer.searchTheme(theme)
    │   └── MCP: search-statistics → itemsChanged signal
    └── askChat(text) → chatBridge.sendMessage("Search for statistics about: " + theme, context)
        └── Claude API with MCP tools
            ├── Tool calls → Analyzer.executeMCPTool() → Statista MCP
            ├── Stream deltas → ChatView.updateLastAssistant()
            ├── Citations → ChatView.addCitations()
            └── Follow-ups → ChatView.setFollowups()
```

### Tool Use Workflow
When Claude calls a tool (e.g., `statista_search`):
1. ChatBridge intercepts tool call in streaming response
2. Forwards to `Analyzer.executeMCPTool(toolName, params, requestId)`
3. Analyzer makes JSON-RPC call to Statista MCP
4. Emits `toolResult(requestId, result)` signal
5. ChatBridge submits tool result back to Claude API
6. Claude continues response with tool result context

### Citation Extraction
Citations are numbered sequentially as discovered:
- Each unique URL gets a sequential number (1, 2, 3...)
- Duplicate URLs reuse the same number
- Numbers persist throughout conversation
- Extracted from tool results and citation events

## Important Implementation Details

- **Streaming Without Flashing**: Uses `partialUpdated()` signal for incremental updates, not full `messagesChanged()`. Only updates the active streaming message.
- **Tool Call Tracking**: ChatBridge maintains `QHash<QString, bool> m_pendingToolCalls` to track pending tool executions
- **Conversation History**: Maintained in `m_messages` with role ("user"/"assistant") and content
- **Session Persistence**: Tab URLs and active index saved via QSettings on tab changes
- **Theme Extraction**: Naive mode filters stopwords and returns unique tokens; LLM mode uses Claude API
- **MCP Protocol**: JSON-RPC 2.0 with "jsonrpc": "2.0", "method": "...", "params": {...}, "id": "..."

## Development Notes

- Always run `./clean.sh` before building after major changes
- CMake doesn't always detect changes correctly
- Never commit `.env` or `src/config_keys.h` (gitignored)
- Output binary is "Mercury" not "answer" (see CMakeLists.txt line 58)
- No testing framework currently - manual testing required
- WebEngine DevTools available in debug builds on port 9222
- NDJSON streaming is critical - don't switch to SSE without updating `ChatBridge::postStream()`
