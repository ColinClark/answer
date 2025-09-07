# MicroBrowser — Streaming Chat + Open-in-Tab + Follow-up Queue

Adds:
- **Streaming chat** via NDJSON (`statista.llm.chat.stream`)
  - Supports `delta` tokens, `citation` events (`{title,url}`), and `followups` (`[{query}]`).
- **Open in new tab** buttons for citations and related items.
- **Follow-up queue**: assistant suggests queries; run individually or "Run next ▶".

## Expected stream format (NDJSON)
Each line is a JSON object:
```json
{"type":"delta","text":"partial token ..."}
{"type":"citation","title":"E-commerce revenue in DE","url":"https://.../statistic/..."}
{"type":"followups","items":[{"query":"Market size of ..."},{"query":"Growth by segment ..."}]}
```
Adjust `ChatBridge::postStream()` if your server uses SSE or a different schema.

## Configure and run
```bash
export STATISTA_MCP_ENDPOINT="https://api.statista.ai/v1/mcp"
export STATISTA_MCP_API_KEY="YOUR_KEY"
mkdir build && cd build
cmake .. && cmake --build .
./MicroBrowser
```
Open the **Insights** panel, ask a question, and watch streaming text+citations. Click a citation to **open in a new tab**.

> Swap the NDJSON parser for an SSE parser if your endpoint uses `text/event-stream` (parse lines starting with `data:`).