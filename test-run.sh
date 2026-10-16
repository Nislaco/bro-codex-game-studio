#!/bin/bash
# test-integration.sh - Validates the Godot MCP integration in bro-codex-game-studio

set -e

echo "🚀 Starting Integration Test for godot-mcp..."
cd bro-codex-game-studio
echo "--- [1/3] Checking TypeScript Integrity ---"
npm test || { echo "❌ TypeScript tests failed"; exit 1; }
echo "✅ TypeScript integrity verified."

echo ""
echo "--- [2/3] Verifying Godot Specialist Role ---"
# We check if the CLI can render the role without error
if ./codex-game-studio run godot-specialist "test" | grep -q "Godot Specialist"; then
    echo "✅ Role 'godot-specialist' recognized and rendered."
else
    echo "❌ Role 'godot-specialist' not found or failed to render."
    exit 1
fi

echo ""
echo "--- [3/3] Verifying Godot Implementation Workflow ---"
# We check if the workflow command recognizes the new ID
if ./codex-game-studio godot-implementation | grep -q "godot-implementation"; then
    echo "✅ Workflow 'godot-implementation' recognized and rendered."
else
    echo "❌ Workflow 'godot-implementation' not found or failed to render."
    exit 1
fi

echo ""
echo "🎉 INTEGRATION TEST PASSED: The Brain is now ready to use the Hands."
