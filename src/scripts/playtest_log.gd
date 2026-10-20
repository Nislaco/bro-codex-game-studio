extends RefCounted

# Playtest session logger.
#
# Opt-in: enabled by launching the game with `-- --playtest` (the flag after
# `--` is read via `OS.get_cmdline_user_args()`). When disabled this class is
# never instantiated, so a normal build has zero overhead and writes nothing.
#
# The log answers the questions the QA plan's playtest scenarios ask:
#   - how long until the first legal move?        (time_to_first_move_ms)
#   - did the player finish the match?            (game_over / completed)
#   - how often did they hit an invalid cell?     (invalid_clicks)
#   - how often did they pass a turn?             (skips)
#   - did they discover the settings?             (mode_changes/difficulty_changes)
#   - did they find restart?                      (restarts)
#
# Written to `user://playtest_<session_id>.json` on game over and on quit.

const SESSION_PREFIX := "playtest_"

var enabled: bool = false
var session_id: String = ""
var started_at_ms: int = 0
var events: Array = []

# Counters
var moves_placed: int = 0
var invalid_clicks: int = 0
var skipped_turns: int = 0
var restarts: int = 0
var mode_changes: int = 0
var difficulty_changes: int = 0
var first_legal_move_ms: int = -1
var game_over: bool = false
var completed: bool = false
var outcome: String = ""


static func is_requested() -> bool:
	# Two ways to enable:
	#  1. `godot --path src -- --playtest` — the flag after `--` is read via
	#     `OS.get_cmdline_user_args()` (used for manual sessions).
	#  2. `GODOT_PLAYTEST=1` in the environment — inherited by the game process
	#     when the editor (or a tool) launches it, so automated sessions work.
	for arg in OS.get_cmdline_user_args():
		if arg == "--playtest":
			return true
	var env := OS.get_environment("GODOT_PLAYTEST")
	return env == "1" or env.to_lower() == "true"


func _init() -> void:
	enabled = true
	session_id = str(int(Time.get_unix_time_from_system()))
	started_at_ms = Time.get_ticks_msec()
	log_event("session_start", {
		"mode": "playtest",
		"godot": str(Engine.get_version_info().get("string", "")),
	})


func _elapsed_ms() -> int:
	return Time.get_ticks_msec() - started_at_ms


func log_event(event: String, data: Dictionary = {}) -> void:
	var entry: Dictionary = {"event": event, "t_ms": _elapsed_ms()}
	entry.merge(data, true)
	events.append(entry)


func record_first_legal_move() -> void:
	if first_legal_move_ms < 0:
		first_legal_move_ms = _elapsed_ms()
		log_event("first_legal_move", {"t_ms": first_legal_move_ms})


func record_move() -> void:
	record_first_legal_move()
	moves_placed += 1
	log_event("move", {"moves": moves_placed})


func record_invalid_click() -> void:
	invalid_clicks += 1
	log_event("invalid_click", {"invalid_clicks": invalid_clicks})


func record_skip() -> void:
	skipped_turns += 1
	log_event("skip", {"skips": skipped_turns})


func record_restart() -> void:
	restarts += 1
	log_event("restart", {"restarts": restarts})


func record_mode_change(to_mode: int) -> void:
	mode_changes += 1
	log_event("mode_change", {"to": to_mode, "mode_changes": mode_changes})


func record_difficulty_change(to_difficulty: int) -> void:
	difficulty_changes += 1
	log_event("difficulty_change", {"to": to_difficulty, "difficulty_changes": difficulty_changes})


func record_game_over(winner: String, black: int, white: int) -> void:
	game_over = true
	completed = true
	outcome = winner
	log_event("game_over", {"winner": winner, "black": black, "white": white})


func to_dict() -> Dictionary:
	return {
		"session_id": session_id,
		"duration_ms": _elapsed_ms(),
		"moves_placed": moves_placed,
		"invalid_clicks": invalid_clicks,
		"skipped_turns": skipped_turns,
		"restarts": restarts,
		"mode_changes": mode_changes,
		"difficulty_changes": difficulty_changes,
		"first_legal_move_ms": first_legal_move_ms,
		"game_over": game_over,
		"completed": completed,
		"outcome": outcome,
		"events": events,
	}


func write_report() -> void:
	if not enabled:
		return
	var path := "user://%s%s.json" % [SESSION_PREFIX, session_id]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_warning("[Playtest] Could not write report to %s" % path)
		return
	file.store_string(JSON.stringify(to_dict(), "", 2))
	file.close()
	print("[Playtest] Session report written to %s" % path)
