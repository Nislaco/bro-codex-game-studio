extends SceneTree

# Standalone verification runner.
#
# All 90 assertions live in `othello_checks.gd` so that this runner and the
# GUT suite (`tests/test_othello.gd`) execute the exact same checks. This file
# only wires the game instance up and prints a pass/fail summary.
#
# Run: godot --headless --path src -s res://scripts/verify_othello.gd

const ChecksScript := preload("res://scripts/othello_checks.gd")

var checks: int = 0
var failures: int = 0

func _init() -> void:
	print("--- Othello Verification Start ---")
	var game_script := load("res://scripts/othello.gd")
	if not game_script:
		print("ERROR: Could not load res://scripts/othello.gd")
		quit(1)
		return

	var game = game_script.new()
	game._create_textures()
	game._load_translations()
	game._build_ui()
	game._new_game()

	var suite = ChecksScript.new()
	suite.assert_cb = _record_check
	suite.run_all(game)

	print("--- Othello Verification End: %d checks, %d failures ---" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _record_check(id: String, passed: bool, detail: String = "") -> void:
	checks += 1
	if passed:
		print("PASS ", id)
	else:
		failures += 1
		print("FAIL ", id, (" — " + detail) if detail != "" else "")
