#!/bin/bash

# Test script for Statista MCP server
# This helps diagnose session initialization issues

# Load API key from .env
if [ -f .env ]; then
    source .env
fi

API_KEY="${STATISTA_MCP_API_KEY}"
ENDPOINT="${STATISTA_MCP_ENDPOINT:-https://api.statista.ai/v1/mcp}"

if [ -z "$API_KEY" ]; then
    echo "Error: STATISTA_MCP_API_KEY not set"
    exit 1
fi

echo "================================================"
echo "Testing Statista MCP Server"
echo "Endpoint: $ENDPOINT"
echo "================================================"
echo ""

# Step 1: Initialize session
echo "Step 1: Initializing session..."
echo "Request:"
INIT_REQUEST='{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": {},
      "sampling": {}
    },
    "clientInfo": {
      "name": "answer",
      "version": "1.0.0"
    }
  }
}'
echo "$INIT_REQUEST" | jq .

echo ""
echo "Response:"
RESPONSE=$(curl -s -D /tmp/mcp_headers.txt \
  -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "x-api-key: $API_KEY" \
  -d "$INIT_REQUEST")

echo "$RESPONSE"

echo ""
echo "Response Headers:"
cat /tmp/mcp_headers.txt
echo ""

# Extract session ID from headers
SESSION_ID=$(grep -i "mcp-session-id:" /tmp/mcp_headers.txt | cut -d: -f2 | tr -d ' \r\n')

if [ -n "$SESSION_ID" ]; then
    echo "Session ID found: $SESSION_ID"
else
    echo "WARNING: No session ID in response headers!"
fi

echo ""
echo "================================================"
echo ""

# Step 2: List available tools
echo "Step 2: Listing available tools..."
echo "Request:"
TOOLS_REQUEST='{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list",
  "params": {}
}'
echo "$TOOLS_REQUEST" | jq .

echo ""
echo "Response:"
if [ -n "$SESSION_ID" ]; then
    RESPONSE=$(curl -s \
      -X POST "$ENDPOINT" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json, text/event-stream" \
      -H "x-api-key: $API_KEY" \
      -H "mcp-session-id: $SESSION_ID" \
      -d "$TOOLS_REQUEST")
else
    RESPONSE=$(curl -s \
      -X POST "$ENDPOINT" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json, text/event-stream" \
      -H "x-api-key: $API_KEY" \
      -d "$TOOLS_REQUEST")
fi

echo "$RESPONSE"

echo ""
echo "================================================"
echo ""

# Step 3: Try to call search-statistics tool
echo "Step 3: Testing search-statistics tool..."
echo "Request:"
SEARCH_REQUEST='{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "search-statistics",
    "arguments": {
      "query": "population of USA"
    }
  }
}'
echo "$SEARCH_REQUEST" | jq .

echo ""
echo "Response:"
if [ -n "$SESSION_ID" ]; then
    RESPONSE=$(curl -s \
      -X POST "$ENDPOINT" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json, text/event-stream" \
      -H "x-api-key: $API_KEY" \
      -H "mcp-session-id: $SESSION_ID" \
      -d "$SEARCH_REQUEST")
else
    RESPONSE=$(curl -s \
      -X POST "$ENDPOINT" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json, text/event-stream" \
      -H "x-api-key: $API_KEY" \
      -d "$SEARCH_REQUEST")
fi

echo "$RESPONSE"

echo ""
echo "================================================"
echo "Test complete!"
echo "================================================"
