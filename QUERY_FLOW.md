# Theme Click Query Flow

This document describes the complete flow when a user clicks on a theme in the Insights panel to analyze it via chat.

## Overview

When a user clicks on a theme button in the Insights panel, two parallel processes are initiated:
1. **Theme Analysis**: The Analyzer searches for statistics related to the theme
2. **Chat Query**: The ChatBridge sends the query to Claude for natural language processing

## Entry Points

When a theme is clicked, the following components receive and process the theme:

### Primary Entry Points

1. **analyzer.searchTheme(theme)** (src/analyzer.cpp:206)
   - Q_INVOKABLE method exposed to QML
   - Receives theme string directly from Main.qml
   - Initiates MCP search-statistics request

2. **chatBridge.sendMessage(text, context)** (src/chatbridge.cpp:108)
   - Q_INVOKABLE method exposed to QML
   - Receives formatted query: "Search for statistics about: [theme]"
   - Initiates Claude API conversation with context

### Secondary Entry Points

3. **chatBridge.sendThemeQuery(theme)** (src/chatbridge.cpp:141)
   - Alternative method for theme queries
   - Formats theme as: "Tell me about statistics related to [theme]"
   - Currently not used in the click flow but available

## Detailed Flow

### 1. User Interaction (InsightsPanel.qml:90-93)

```qml
onClicked: {
    root.themeClicked(themes[index])
    root.askChat("Search for statistics about: " + themes[index])
}
```

The theme click triggers two signals:
- `themeClicked(theme)` - Initiates theme analysis
- `askChat(text)` - Sends query to chat

### 2. Signal Propagation (Main.qml)

The signals from InsightsPanel are connected to the backend components:

#### Theme Analysis Path (Main.qml - onThemeClicked handler)
```qml
onThemeClicked: (theme) => {
    analyzer.searchTheme(theme)  // Entry point #1
}
```
- **Receives**: Theme string (e.g., "climate change", "GDP growth")
- **Calls**: `analyzer.searchTheme()` directly with the theme

#### Chat Query Path (Main.qml - onAskChat handler)
```qml
onAskChat: (text) => {
    var ctx = { url: currentTab.url, title: currentTab.title }
    chatBridge.sendMessage(text, ctx)  // Entry point #2
    insightsPanel.setLoading(true)
}
```
- **Receives**: Formatted text "Search for statistics about: [theme]"
- **Calls**: `chatBridge.sendMessage()` with query and page context
- **Context**: Includes current tab's URL and title for relevance

### 3. Backend Processing

#### A. Theme Analysis (analyzer.cpp:206-223)

The `searchTheme` function:
1. Constructs MCP request with method "search-statistics"
2. Sends request to Statista MCP endpoint
3. Processes response containing statistical data items
4. Emits `itemsChanged` signal with results

```cpp
void Analyzer::searchTheme(const QString& theme) {
    QJsonObject params;
    params["query"] = theme;
    params["limit"] = 10;
    
    QJsonObject req;
    req["jsonrpc"] = "2.0";
    req["method"] = "search-statistics";
    req["params"] = params;
    req["id"] = QUuid::createUuid().toString();
    
    // Send to MCP endpoint...
}
```

#### B. Chat Processing (chatbridge.cpp)

The `sendMessage` function initiates Claude API interaction:

1. **Message Preparation** (chatbridge.cpp:160-190)
   - Adds user message to conversation
   - Includes page context (URL, title)
   - Configures Claude with Statista MCP tool access

2. **Tool Use** (chatbridge.cpp:515-570)
   - Claude may call `statista_search` tool
   - ChatBridge intercepts tool calls
   - Forwards to Statista MCP via `callStatistaMCP`

3. **Citation Extraction** (chatbridge.cpp:642-672)
   - Extracts citations from tool results
   - Assigns sequential numbers to citations
   - Deduplicates based on URL
   - Emits `citationsUpdated` signal

### 4. Response Streaming

#### Stream Processing (chatbridge.cpp:357-430)
The response is streamed as NDJSON with three event types:

```json
{"type": "delta", "text": "partial response..."}
{"type": "citation", "title": "Source", "url": "https://..."}
{"type": "followups", "items": [{"query": "Follow-up question"}]}
```

Each event type triggers different UI updates:
- **delta**: Updates streaming text in ChatView
- **citation**: Adds numbered citation button
- **followups**: Displays suggested follow-up queries

### 5. UI Updates

#### ChatView Updates (ChatView.qml)
- Displays streaming response text
- Shows numbered citation buttons `[1] Title`
- Lists follow-up suggestions

#### InsightsPanel Updates
- Receives `itemsChanged` signal from Analyzer
- Updates items list with search results
- Shows loading state during processing

## Data Flow Summary

```
User clicks theme
    ├── themeClicked(theme)
    │   └── analyzer.searchTheme(theme)
    │       └── MCP: search-statistics
    │           └── itemsChanged signal
    │               └── Update InsightsPanel items
    │
    └── askChat("Search for statistics about: " + theme)
        └── chatBridge.sendMessage(text, context)
            └── Claude API with MCP tools
                ├── Tool calls → Statista MCP
                ├── Stream deltas → Update chat text
                ├── Citations → Numbered buttons
                └── Follow-ups → Suggestion list
```

## Key Components

- **InsightsPanel.qml**: Initiates the flow with theme click
- **Main.qml**: Routes signals between components
- **ChatBridge**: Manages Claude API and streaming responses
- **Analyzer**: Handles direct MCP searches
- **ChatView.qml**: Displays chat responses with citations

## Citation Numbering

Citations are automatically numbered as they're discovered:
1. Each unique URL gets a sequential number (1, 2, 3...)
2. Duplicate URLs reuse the same number
3. Numbers persist throughout the conversation
4. Citations appear as clickable buttons `[n] Title`