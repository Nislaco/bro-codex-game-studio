#!/usr/bin/env gdscript
# Benchmark script for Hard difficulty search time
# Run: godot --headless --path src -s res://scripts/bench_hard_difficulty.gd

extends SceneTree

class_name BenchHardDifficulty

const BOARD_SIZE: int = 8
const BLACK: int = 1
const WHITE: int = 2
const EMPTY: int = 0

var game_script
var game
var results: Array = []

func _init() -> void:
	print("--- Hard Difficulty Benchmark Start ---")
	game_script = load("res://scripts/othello.gd")
	if not game_script:
		print("ERROR: Could not load res://scripts/othello.gd")
		quit(1)
		return
	
	game = game_script.new()
	game._create_textures()
	game._build_ui()
	
	# 10 representative mid-game boards (different move counts)
	var boards: Array = _generate_test_boards()
	
	var difficulties: Dictionary = {"EASY": 0, "MEDIUM": 1, "HARD": 2}
	for diff_name in difficulties:
		var diff_val: int = difficulties[diff_name]
		print("\n=== Difficulty: %s (depth=%d) ===" % [diff_name, game._match_difficulty(diff_val)])
		game.game_difficulty = diff_val
		game.game_mode = 0 # PLAYER_VS_AI
		
		for i in range(boards.size()):
			var board: Array = boards[i]
			game.board = _clone_board(board)
			game.current_player = WHITE
			game.game_over = false
			
			# Warm-up run (not timed)
			game._get_best_move()
			
			# Timed runs: 5 per board
			var times: Array = []
			var nodes_list: Array = []
			for n in range(5):
				var start: int = Time.get_ticks_msec()
				var move: Vector2i = game._get_best_move()
				var elapsed: int = Time.get_ticks_msec() - start
				times.append(elapsed)
			
			var sorted_times := times.duplicate()
			sorted_times.sort()
			var median: int = sorted_times[sorted_times.size() / 2]
			var p95_idx: int = int(sorted_times.size() * 0.95)
			var p95: int = sorted_times[min(p95_idx, sorted_times.size() - 1)]
			var max_t: int = sorted_times[-1]
			
			var board_hash: String = _board_hash(board)
			print("  Board %d (hash=%s): median=%dms p95=%dms max=%dms times=%s" % [i, board_hash, median, p95, max_t, times])
			
			results.append({
				"difficulty": diff_name,
				"depth": game._match_difficulty(diff_val),
				"board_index": i,
				"board_hash": board_hash,
				"median_ms": median,
				"p95_ms": p95,
				"max_ms": max_t,
				"times_ms": times,
			})
	
	_print_summary()
	_save_json()
	quit(0)

func _generate_test_boards() -> Array:
	# Return 10 different mid-game positions
	var boards: Array = []
	
	# Board 0: Opening (after 1 move each)
	var b0: Array = _empty_board()
	b0[3][3] = BLACK; b0[4][4] = BLACK; b0[3][4] = WHITE; b0[4][3] = WHITE
	b0[2][4] = BLACK; b0[2][3] = BLACK; b0[5][3] = WHITE; b0[5][4] = WHITE
	boards.append(b0)
	
	# Board 1: Early mid-game (8 discs each)
	var b1: Array = _empty_board()
	b1[3][3] = BLACK; b1[4][4] = BLACK; b1[3][4] = WHITE; b1[4][3] = WHITE
	b1[2][4] = BLACK; b1[2][3] = BLACK; b1[5][3] = WHITE; b1[5][4] = WHITE
	b1[2][5] = BLACK; b1[3][5] = BLACK; b1[4][5] = WHITE; b1[5][5] = WHITE
	b1[2][2] = BLACK; b1[3][2] = BLACK; b1[4][2] = WHITE; b1[5][2] = WHITE
	boards.append(b1)
	
	# Board 2: Corner-heavy
	var b2: Array = _empty_board()
	b2[0][0] = BLACK; b2[7][7] = BLACK; b2[0][7] = WHITE; b2[7][0] = WHITE
	b2[0][1] = BLACK; b2[1][0] = BLACK; b2[0][6] = WHITE; b2[1][7] = WHITE
	b2[2][2] = BLACK; b2[5][5] = WHITE
	boards.append(b2)
	
	# Board 3: Edge-heavy
	var b3: Array = _empty_board()
	for c in range(8): b3[0][c] = BLACK if c % 2 == 0 else WHITE
	for c in range(8): b3[7][c] = WHITE if c % 2 == 0 else BLACK
	boards.append(b3)
	
	# Board 4: Sparse (12 discs)
	var b4: Array = _empty_board()
	b4[3][3] = BLACK; b4[4][4] = BLACK; b4[3][4] = WHITE; b4[4][3] = WHITE
	b4[2][4] = BLACK; b4[5][3] = WHITE
	b4[2][3] = BLACK; b4[5][4] = WHITE
	b4[3][2] = BLACK; b4[4][5] = WHITE
	b4[5][2] = BLACK; b4[2][5] = WHITE
	boards.append(b4)
	
	# Board 5: Dense center (24 discs)
	var b5: Array = _empty_board()
	for r in range(2, 6):
		for c in range(2, 6):
			b5[r][c] = BLACK if (r + c) % 2 == 0 else WHITE
	boards.append(b5)
	
	# Board 6: One legal move only
	var b6: Array = _empty_board()
	for r in range(8):
		for c in range(8):
			b6[r][c] = BLACK
	b6[0][0] = EMPTY
	b6[0][1] = WHITE
	boards.append(b6)
	
	# Board 7: Many legal moves (open)
	var b7: Array = _empty_board()
	b7[3][3] = BLACK; b7[4][4] = BLACK; b7[3][4] = WHITE; b7[4][3] = WHITE
	boards.append(b7)
	
	# Board 8: Late mid-game (32 discs)
	var b8: Array = _empty_board()
	for r in range(8):
		for c in range(8):
			if (r < 4 and c < 4) or (r >= 4 and c >= 4):
				b8[r][c] = BLACK
			else:
				b8[r][c] = WHITE
	boards.append(b8)
	
	# Board 9: Random-ish (fixed seed pattern)
	var b9: Array = _empty_board()
	for r in range(8):
		for c in range(8):
			if (r * 7 + c * 3) % 3 == 0: b9[r][c] = BLACK
			elif (r * 5 + c * 2) % 3 == 0: b9[r][c] = WHITE
	boards.append(b9)
	
	return boards

func _empty_board() -> Array:
	var board: Array = []
	for r in range(BOARD_SIZE):
		var row: Array = []
		for c in range(BOARD_SIZE):
			row.append(EMPTY)
		board.append(row)
	return board

func _clone_board(src: Array) -> Array:
	var copy: Array = []
	for row in src:
		copy.append(row.duplicate())
	return copy

func _board_hash(board: Array) -> String:
	var s: String = ""
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			s += str(board[r][c])
	return s.substr(0, 16) # Short hash

func _print_summary() -> void:
	print("\n=== SUMMARY ===")
	for diff_name in ["EASY", "MEDIUM", "HARD"]:
		var diff_results: Array = []
		for r in results:
			if r.difficulty == diff_name:
				diff_results.append(r)
		if diff_results.size() == 0: continue
		
		var all_times: Array = []
		for r in diff_results:
			all_times.append_array(r.times_ms)
		all_times.sort()
		
		var median: int = all_times[all_times.size() / 2]
		var p95_idx: int = int(all_times.size() * 0.95)
		var p95: int = all_times[min(p95_idx, all_times.size() - 1)]
		var max_t: int = all_times[-1]
		var min_t: int = all_times[0]
		
		print("%s (depth %d): min=%dms median=%dms p95=%dms max=%dms (n=%d)" % [
			diff_name, diff_results[0].depth, min_t, median, p95, max_t, all_times.size()
		])
		
		# Gate check
		if diff_name == "HARD" and median > 500:
			print("  ⚠ GATE FAIL: Hard median (%dms) > 500ms budget" % median)
		elif diff_name == "HARD":
			print("  ✓ GATE PASS: Hard median (%dms) ≤ 500ms budget" % median)

func _save_json() -> void:
	var json_text: String = JSON.stringify(results, "", 2)
	var file: FileAccess = FileAccess.open("user://bench_results.json", FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()
		print("\nResults saved to user://bench_results.json")
	else:
		print("ERROR: Could not write bench_results.json")

func min(a: int, b: int) -> int:
	return a if a < b else b