# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Run Commands

```bash
# Set required environment variables
export STATISTA_MCP_ENDPOINT="https://api.statista.ai/v1/mcp"
export STATISTA_MCP_API_KEY="YOUR_KEY"

# Build the application
mkdir build && cd build
cmake .. && cmake --build .

# Run the application
./MicroBrowser
```

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