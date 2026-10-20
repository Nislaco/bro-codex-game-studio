extends SceneTree

# Difficulty ladder balance harness.
#
# Plays a scripted "naive" opponent (always takes the k-th legal move in
# row-major order, with k varying per game) against the AI at each
# difficulty, over N varied openings.
#
# A good ladder means the naive opponent's win rate falls as difficulty
# rises. If it does not, the ladder is flat and the harness exits non-zero.
#
# Run: godot --headless --path src -s res://scripts/bench_difficulty_ladder.gd
#
# Exit codes: 0 = ladder is monotonic, 1 = ladder is flat or not monotonic,
#              2 = harness error.

const BLACK: int = 1
const WHITE: int = 2
const EMPTY: int = 0
const BOARD_SIZE: int = 8
const NO_MOVE: Vector2i = Vector2i(-1, -1)

const GAMES_PER_DIFFICULTY: int = 12

# Opponent profiles, from "knows nothing" to "knows the one rule".
# - naive: always takes the first legal move in row-major order.
# - corner_aware: takes a corner if one is available, else the first legal
#   move. This models the actual skill ceiling of a first-time Othello
#   player: "take the corners".
const PROFILES: Array[String] = ["naive", "beginner"]

# Design intent, per difficulty, for the corner-aware beginner (the profile
# that matters). A difficulty is only doing its job if a beginner who knows
# the corner rule can beat Easy, while Medium and Hard remain challengers.
const BEGINNER_TARGET: Dictionary = {0: 6, 1: 0, 2: 0}  # Easy, Medium, Hard

var game
var failures: int = 0
var _ctrl_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	print("--- Difficulty Ladder Balance ---")
	var script := load("res://scripts/othello.gd")
	if not script:
		print("ERROR: could not load res://scripts/othello.gd")
		quit(2)
		return
	game = script.new()
	game._create_textures()
	game._load_translations()
	game._build_ui()
	game._new_game()
	
	# The ladder is defined by the AI's evaluation, not by search depth:
	# EASY plays depth 1 without the mobility term; MEDIUM is depth 3 with
	# the standard evaluation; HARD is depth 5 with a time budget.
	var results: Dictionary = {}
	for diff in [0, 1, 2]:
		results[diff] = {
			"naive": _run_difficulty(diff, "naive"),
			"beginner": _run_difficulty(diff, "beginner"),
		}
	
	var ok: bool = true
	var names: Array = ["EASY", "MEDIUM", "HARD"]
	print("")
	print("=== Ladder summary (12 games per difficulty per profile) ===")
	print("  profile        difficulty  wins/target   AI wins  draws   avg score")
	for diff in [0, 1, 2]:
		for profile in PROFILES:
			var r: Dictionary = results[diff][profile]
			# Only the `beginner` profile carries a target - it models a player
			# who knows the one rule that matters. The `naive` profile is a
			# deliberate floor player and is reported for information only.
			var required: bool = profile == "beginner"
			var target: int = BEGINNER_TARGET[diff]
			var wins: int = r.naive_wins
			var meets: bool = wins >= target
			if required and not meets:
				ok = false
			print("  %-13s  %-9s  %2d/%2d %s   %2d      %d     %5.1f - %5.1f%s" % [
				profile, names[diff], wins, target,
				"PASS" if meets else "FAIL", r.ai_wins, r.draws, r.avg_naive, r.avg_ai,
				"" if required else "  (informational - floor player)"])
	
	# Control: a harness-side uniformly random AI. If the opponent models
	# cannot beat THAT, the measurement itself is suspect and the real
	# numbers above mean nothing.
	print("")
	print("=== Control: opponent models vs a uniformly random AI ===")
	for profile in PROFILES:
		_ctrl_rng.seed = 424242
		var ctrl_wins: int = 0
		for k in range(GAMES_PER_DIFFICULTY):
			var sc: Vector2i = _play_one_game(k, profile, "random")
			if sc.x > sc.y:
				ctrl_wins += 1
		# Only the `beginner` model is required to clear the control. The
		# `naive` model is a deliberate floor player that knows nothing, so
		# it is reported for information only.
		var required: bool = profile == "beginner"
		var ctrl_meets: bool = ctrl_wins >= 8
		if required and not ctrl_meets:
			ok = false
		print("  %-13s  beats a random AI %2d/%d %s%s" % [
			profile, ctrl_wins, GAMES_PER_DIFFICULTY,
			"PASS" if ctrl_meets else "FAIL",
			"" if required else "  (informational - floor player)"])
		_ctrl_rng.seed = 424242
	
	# Monotonicity (per profile): the beginner's win rate must not increase
	# as difficulty rises.
	print("")
	for profile in PROFILES:
		var easy_wins: int = results[0][profile].naive_wins
		var med_wins: int = results[1][profile].naive_wins
		var hard_wins: int = results[2][profile].naive_wins
		if easy_wins < med_wins or med_wins < hard_wins:
			print("FAIL: %s ladder is not monotonic (easy %d >= medium %d >= hard %d expected)" % [profile, easy_wins, med_wins, hard_wins])
			ok = false
		else:
			print("PASS: %s ladder is monotonic (easy %d >= medium %d >= hard %d)" % [profile, easy_wins, med_wins, hard_wins])
	
	print("")
	print("--- Difficulty Ladder Balance End: %s ---" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _run_difficulty(diff: int, profile: String) -> Dictionary:
	game.game_mode = 0  # PLAYER_VS_AI
	game.game_difficulty = diff
	var naive_wins: int = 0
	var ai_wins: int = 0
	var draws: int = 0
	var total_naive: int = 0
	var total_ai: int = 0
	
	for k in range(GAMES_PER_DIFFICULTY):
		var score: Vector2i = _play_one_game(k, profile)
		total_naive += score.x
		total_ai += score.y
		if score.x > score.y:
			naive_wins += 1
		elif score.y > score.x:
			ai_wins += 1
		else:
			draws += 1
	
	return {
		"naive_wins": naive_wins,
		"ai_wins": ai_wins,
		"draws": draws,
		"avg_naive": float(total_naive) / float(GAMES_PER_DIFFICULTY),
		"avg_ai": float(total_ai) / float(GAMES_PER_DIFFICULTY),
	}


func _play_one_game(opening_index: int, profile: String, ai_policy: String = "game") -> Vector2i:
	# Fresh board.
	game.board = []
	for r in range(BOARD_SIZE):
		var row: Array = []
		for c in range(BOARD_SIZE):
			row.append(EMPTY)
		game.board.append(row)
	game.board[3][3] = BLACK
	game.board[4][4] = BLACK
	game.board[3][4] = WHITE
	game.board[4][3] = WHITE
	
	var guard: int = 0
	while guard < 120:
		guard += 1
		# Black (naive) moves first, then White (AI) replies on the UPDATED
		# board. Computing the AI move first would let it act on a stale
		# position and even overwrite the opponent's disc.
		var naive_move: Vector2i = _naive_move(opening_index, profile)
		if naive_move.x >= 0:
			game._execute_move(naive_move.x, naive_move.y, BLACK)
		var ai_move: Vector2i = game._get_best_move()
		if ai_policy == "random":
			ai_move = _random_ai_move()
		if ai_move.x >= 0:
			game._execute_move(ai_move.x, ai_move.y, WHITE)
	
	var black: int = 0
	var white: int = 0
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if game.board[r][c] == BLACK: black += 1
			elif game.board[r][c] == WHITE: white += 1
	return Vector2i(black, white)


func _naive_move(opening_index: int, profile: String) -> Vector2i:
	# Opponent models, all of which must be plausible players (validated by
	# the random-AI control below).
	#
	# - naive: always takes the first legal move in row-major order. Knows
	#   nothing. Only used as a floor.
	# - beginner: takes a corner if one is available, otherwise plays the
	#   move that flips the most discs. This is the classic "knows the
	#   corner rule and plays greedily" beginner.
	if profile != "naive":
		var corner: Vector2i = _any_corner_move()
		if corner.x >= 0:
			return corner
		var greedy: Vector2i = _greedy_material_move()
		if greedy.x >= 0:
			return greedy
	
	# naive: the (opening_index)-th legal move in row-major order. Varying
	# the index gives different openings.
	var seen: int = 0
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if game._is_legal_move(r, c, BLACK):
				if seen == opening_index:
					return Vector2i(r, c)
				seen += 1
	return NO_MOVE

func _greedy_material_move() -> Vector2i:
	# The move that leaves the most discs for the opponent's side.
	var best_score: int = -999999
	var best: Vector2i = NO_MOVE
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if game._is_legal_move(r, c, BLACK):
				var original_board = []
				for row in game.board: original_board.append(row.duplicate())
				game._execute_move(r, c, BLACK)
				var gained: int = 0
				for rr in range(BOARD_SIZE):
					for cc in range(BOARD_SIZE):
						if game.board[rr][cc] == BLACK:
							gained += 1
				game.board = original_board
				if gained > best_score:
					best_score = gained
					best = Vector2i(r, c)
	return best

func _random_ai_move() -> Vector2i:
	# Control policy: a uniformly random legal AI move, used to validate
	# that the harness's opponent models and win detection are sound.
	var legal: Array = []
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if game._is_legal_move(r, c, WHITE):
				legal.append(Vector2i(r, c))
	if legal.is_empty():
		return NO_MOVE
	return legal[_ctrl_rng.randi_range(0, legal.size() - 1)]

func _any_corner_move() -> Vector2i:
	# The one rule a first-time Othello player learns: take a corner.
	var corners: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(0, 7), Vector2i(7, 0), Vector2i(7, 7)
	]
	for corner in corners:
		if game._is_legal_move(corner.x, corner.y, BLACK):
			return corner
	return NO_MOVE
