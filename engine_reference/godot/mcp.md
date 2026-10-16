reviewer: Codex Game Studio seed review
date: 2026-10-14
source-link: https://github.com/WindSeries83/godot-mcp
engine: godot
version-reviewed: 4.7.2
tags: godot,mcp,debugging
roles: godot-specialist,tools-programmer
workflows: prototype,bugfix,qa-plan

# Godot MCP Integration

## Purpose
Debug Godot projects via Model Context Protocol (MCP) instead of broken `--headless -s` mode.

## Working Setup
- **MCP Server**: `godot-hands` (Node.js) from `/home/nicolas/project/godot-mcp`
- **Godot Plugin**: `godot_mcp` in `addons/godot_mcp/`
- **Transport**: stdio → MCP server → WebSocket:6505 → Godot editor

## Required Fixes (applied)
1. Add `@tool` to `addons/godot_mcp/plugin.gd`
2. Skip GUI in headless: `if not DisplayServer.get_name() == "headless":`
3. Use `--editor` mode (not `--headless -s` which hangs)
4. Enable only `godot_mcp` plugin in project.godot

## MCP Config
```json
"godot-hands": {
  "command": "node",
  "args": ["/home/nicolas/project/godot-mcp/dist/index.js"]
}
```

## Usage
```bash
# Terminal 1
cd /home/nicolas/project/godot-mcp && node dist/index.js

# Terminal 2
godot --editor --path <project>
```

## Available Tools
- 210 methods via `godot_call` (scene, nodes, 3D, physics, animation, shaders, etc.)
- `execute_editor_script` with `confirm: true` for running GDScript