#!/usr/bin/env bash
# Launch an Othello playtest session with automatic session logging.
#
# Usage:
#   ./run-session.sh [scenario] [extra godot args...]
#     e.g. ./run-session.sh PT-2
#     e.g. ./run-session.sh PT-1 --headless --quit-after 60   (smoke test)
#
# The scenario name is metadata for the facilitator (printed in the header);
# any extra arguments are passed to Godot as engine arguments.
#
# The game starts with session logging enabled (GODOT_PLAYTEST=1). When the
# match ends (or you close the window) a JSON report is written to:
#   ~/.local/share/godot/app_userdata/othello/playtest_<id>.json
#
# Run ./collect-reports.mjs afterwards to fold every session into a summary.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/opt/godot4/bin/godot}"
REPORT_DIR="${HOME}/.local/share/godot/app_userdata/othello"
SCENARIO="${1:-unspecified}"
if [[ $# -gt 0 ]]; then shift; fi
GODOT_EXTRA_ARGS=("$@")

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "ERROR: Godot not found at $GODOT_BIN" >&2
  echo "       Set GODOT_BIN=/path/to/godot" >&2
  exit 1
fi

mkdir -p "$REPORT_DIR"

echo "=============================================="
echo " Othello playtest session"
echo "=============================================="
echo " Scenario : $SCENARIO"
echo " Build    : $(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
echo " Branch   : $(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo 'unknown')"
echo " Reports  : $REPORT_DIR"
echo "=============================================="
echo ""
echo " Protocol:"
echo "  1. Say only: \"Here's a board game. Play it however you'd like.\""
echo "  2. Observe silently. Do NOT explain the rules."
echo "  3. Wait 15s before rescuing a stuck player."
echo "  4. After the match, ask the debrief questions (§4 of README.md)."
echo "  5. Record quotes VERBATIM."
echo ""
echo " Starting game... (close the window to end the session)"
echo ""

cd "$REPO_ROOT"
GODOT_PLAYTEST=1 "$GODOT_BIN" --path src "${GODOT_EXTRA_ARGS[@]}"

echo ""
echo "=============================================="
echo " Session ended. Report written to:"
ls -t "$REPORT_DIR"/playtest_*.json 2>/dev/null | head -1 | sed 's/^/   /'
echo "=============================================="
echo " Next: ./collect-reports.mjs"
