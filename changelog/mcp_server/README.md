# Changelog - mcp_server

## 2026-02-06
- Added runtime MCP handling path in voice session coordinator for incoming `type: mcp` messages and JSON-RPC replies.
- Added MCP capability flag in both WebSocket and MQTT hello payloads (`features.mcp = true`).
- Added Flutter MCP server module with tool registration, JSON-RPC dispatch, argument validation, and tool result/error responses.
- Added MCP manager page to display available tools, audience scope (common vs user-only), and per-tool `tools/call` usage examples.
- Added routing for `/mcp-flow` and fixed router builder to use non-const `McpFlowPage()`.
- Added entry points to MCP manager from server form and home settings sheet, plus back navigation to home.
