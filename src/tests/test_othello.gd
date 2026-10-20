extends GutTest

# GUT test suite for the Othello prototype.
#
# This runs the SAME 90 assertions as the standalone runner
# (`res://scripts/verify_othello.gd`) via the shared `othello_checks.gd`
# suite, so the two runners can never drift apart.
#
# Run: godot --headless -s res://addons/gut/gut_cmdln.gd

const ChecksScript := preload("res://scripts/othello_checks.gd")

var game
var suite

func before_all() -> void:
	var game_script := load("res://scripts/othello.gd")
	game = game_script.new()
	game._create_textures()
	game._load_translations()
	game._build_ui()
	game._new_game()

	suite = ChecksScript.new()
	suite.assert_cb = _assert_check

func after_all() -> void:
	# The game is a Control that was never added to the tree, so its child
	# nodes (64 cells + labels) would be reported as GUT orphans. Free the
	# whole tree explicitly.
	if is_instance_valid(game):
		game.free()
	game = null
	suite = null

func test_othello_rule_and_ui_contract() -> void:
	# One GUT test drives all 90 shared assertions so the reported count and
	# the standalone runner stay identical. Each assertion is reported
	# individually by GUT.
	suite.run_all(game)

func _assert_check(id: String, passed: bool, detail: String = "") -> void:
	if passed:
		pass_test(id)
	else:
		fail_test(id if detail.is_empty() else "%s — %s" % [id, detail])
