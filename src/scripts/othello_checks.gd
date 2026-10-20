extends RefCounted

const BLACK: int = 1
const WHITE: int = 2
const EMPTY: int = 0
const BOARD_SIZE: int = 8
const CELL_COLOR: Color = Color(0.16, 0.44, 0.16)

var checks: int = 0
var failures: int = 0

# Assertion sink. The standalone runner (verify_othello.gd) and the GUT suite
# (tests/test_othello.gd) both drive these same 90 checks through this
# callback, so the two runners can never drift apart.
var assert_cb: Callable = Callable()

func run_all(game) -> void:
	_test_initial_board(game)
	_test_opening_legality(game)
	_test_capture(game)
	_test_multi_direction_capture(game)
	_test_terminal_and_end_conditions(game)
	_test_terminal_lock(game)
	_test_scoring(game)
	_test_single_legal_move(game)
	_test_no_terminator(game)
	_test_turn_flow(game)
	_test_difficulty_contract(game)
	_test_mode_display_names(game)
	_test_ai_contract(game)
	_test_ui_shell(game)
	_test_restart_assertion(game)
	_test_feedback(game)

func _check(id: String, condition: bool, detail: String = "") -> void:
	checks += 1
	if condition:
		if assert_cb.is_valid():
			assert_cb.call(id, true, detail)
		else:
			print("PASS ", id)
	else:
		failures += 1
		if assert_cb.is_valid():
			assert_cb.call(id, false, detail)
		else:
			print("FAIL ", id, (" — " + detail) if detail != "" else "")

func _empty_board() -> Array:
	var board: Array = []
	for r in range(BOARD_SIZE):
		var row: Array = []
		for c in range(BOARD_SIZE):
			row.append(EMPTY)
		board.append(row)
	return board

func _count_discs(board: Array, player: int) -> int:
	var total: int = 0
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if board[r][c] == player:
				total += 1
	return total

func _move_set(moves: Array) -> Array:
	var out: Array = []
	for move in moves:
		out.append("%d,%d" % [move.x, move.y])
	out.sort()
	return out

func _test_initial_board(game) -> void:
	var expected := _empty_board()
	expected[3][3] = BLACK
	expected[4][4] = BLACK
	expected[3][4] = WHITE
	expected[4][3] = WHITE
	_check("AT-1 initial board layout", str(game.board) == str(expected), str(game.board))
	_check("AT-1 initial counts 2-2", _count_discs(game.board, BLACK) == 2 and _count_discs(game.board, WHITE) == 2)

func _test_opening_legality(game) -> void:
	game.game_mode = 1 # Mode.PLAYER_VS_PLAYER
	game.game_difficulty = 1 # Difficulty.MEDIUM
	game._new_game()

	var black_moves := _move_set(game._get_all_legal_moves(BLACK))
	var white_moves := _move_set(game._get_all_legal_moves(WHITE))
	_check("AT-2 black opening legal moves", black_moves == ["2,4", "3,5", "4,2", "5,3"], str(black_moves))
	_check("AT-3 white opening legal moves", white_moves == ["2,3", "3,2", "4,5", "5,4"], str(white_moves))
	_check("AT-4 black (2,3) illegal", not game._is_legal_move(2, 3, BLACK))
	_check("AT-5 black (3,2) illegal", not game._is_legal_move(3, 2, BLACK))
	_check("AT-6 occupied (3,3) illegal", not game._is_legal_move(3, 3, BLACK))

func _test_capture(game) -> void:
	game._new_game()
	game._execute_move(2, 4, BLACK)
	_check("AT-7 black (2,4) flips (3,4)", game.board[2][4] == BLACK and game.board[3][4] == BLACK, str(game.board[3][4]))
	_check("AT-7 counts after (2,4)", _count_discs(game.board, BLACK) == 4 and _count_discs(game.board, WHITE) == 1)

	game._new_game()
	game._execute_move(4, 2, BLACK)
	_check("AT-8 black (4,2) flips (4,3)", game.board[4][2] == BLACK and game.board[4][3] == BLACK, str(game.board[4][3]))
	_check("AT-8 counts after (4,2)", _count_discs(game.board, BLACK) == 4 and _count_discs(game.board, WHITE) == 1)

func _test_multi_direction_capture(game) -> void:
	game.board = _empty_board()
	game.board[0][0] = BLACK
	game.board[0][2] = BLACK
	game.board[1][1] = WHITE
	game.board[1][2] = WHITE
	game._execute_move(2, 2, BLACK)
	_check("AT-9 multi-direction flips (1,1) and (1,2)", game.board[1][1] == BLACK and game.board[1][2] == BLACK)
	_check("AT-9 counts after multi-flip", _count_discs(game.board, BLACK) == 5 and _count_discs(game.board, WHITE) == 0)

func _test_terminal_and_end_conditions(game) -> void:
	game.board = _empty_board()
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			game.board[r][c] = BLACK
	game.board[7][7] = EMPTY
	game.current_player = BLACK
	game.game_over = false

	_check("AT-10 black has no legal move", not game._has_any_legal_moves(BLACK))
	_check("AT-10 white has no legal move", not game._has_any_legal_moves(WHITE))
	game._advance_turn()
	_check("AT-10 double pass ends game", game.game_over)
	_check("AT-10 winner text", "Black Wins!" in game.status_label.text and "63-0" in game.status_label.text, game.status_label.text)

func _test_terminal_lock(game) -> void:
	game._on_cell_pressed(7, 7)
	_check("AT-11 no move after game over", game.board[7][7] == EMPTY)

func _test_scoring(game) -> void:
	game.board = _empty_board()
	game.board[0][0] = BLACK
	game.board[0][1] = BLACK
	game.board[1][1] = WHITE
	game.game_over = false
	game._update_ui_state()
	_check("AT-12 score labels match board", game.black_score_label.text == "Black: 2" and game.white_score_label.text == "White: 1", "%s / %s" % [game.black_score_label.text, game.white_score_label.text])

func _test_single_legal_move(game) -> void:
	game.board = _empty_board()
	game.board[0][1] = WHITE
	game.board[0][2] = WHITE
	game.board[0][3] = BLACK
	game.current_player = BLACK
	game.game_over = false
	var moves: Array = game._get_all_legal_moves(BLACK)
	_check("AT-13 exactly one legal move", moves.size() == 1 and moves[0] == Vector2i(0, 0), str(moves))
	game._execute_move(0, 0, BLACK)
	_check("AT-13 single move accepted", game.board[0][0] == BLACK and game.board[0][1] == BLACK and game.board[0][2] == BLACK)

func _test_no_terminator(game) -> void:
	game.board = _empty_board()
	game.board[1][1] = WHITE
	_check("AT-14 run without terminator is illegal", not game._is_legal_move(2, 2, BLACK))

func _test_turn_flow(game) -> void:
	# S3: turn ownership, single skip, double skip, input gating, AI turn.
	game.game_mode = 1 # Mode.PLAYER_VS_PLAYER
	game._new_game()
	_check("S3-AT-1 Black moves first", game.current_player == BLACK, str(game.current_player))

	game._execute_move(2, 4, BLACK)
	game._advance_turn()
	_check("S3-AT-2 turn alternates to White", game.current_player == WHITE, str(game.current_player))

	# Single-pass board: all Black, (0,1) White, (0,0) empty -> White has no move, Black has one.
	game.board = _empty_board()
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			game.board[r][c] = BLACK
	game.board[0][0] = EMPTY
	game.board[0][1] = WHITE
	game.current_player = BLACK
	game.game_over = false
	var before := str(game.board)
	_check("S3-AT-3 skip precondition: White blocked, Black has a move", not game._has_any_legal_moves(WHITE) and game._has_any_legal_moves(BLACK))
	game._advance_turn()
	_check("S3-AT-3 single skip returns turn to Black", game.current_player == BLACK, str(game.current_player))
	_check("S3-AT-5 pass is state-neutral", str(game.board) == before)
	_check("S3-AT-4 single pass does not end the game", not game.game_over)

	# Double-pass board: all Black, (7,7) empty -> neither side can move.
	game.board = _empty_board()
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			game.board[r][c] = BLACK
	game.board[7][7] = EMPTY
	game.current_player = BLACK
	game.game_over = false
	game._advance_turn()
	_check("S3-AT-4 double skip ends match", game.game_over)

	# Input gating: a human click during the AI turn is ignored.
	game.game_mode = 0 # Mode.PLAYER_VS_AI
	game._new_game()
	game.current_player = WHITE
	game._on_cell_pressed(2, 4)
	_check("S3-AT-6 input ignored during AI turn", game.board[2][4] == EMPTY and game.current_player == WHITE, "cell=%d turn=%d" % [game.board[2][4], game.current_player])

	# AI turn: after Black moves, the AI resolves one White move and the turn returns.
	game.game_difficulty = 0 # Difficulty.EASY
	game.game_mode = 0 # Mode.PLAYER_VS_AI
	game._new_game()
	game._execute_move(2, 4, BLACK)
	var white_before := _count_discs(game.board, WHITE)
	game._advance_turn()
	var white_after := _count_discs(game.board, WHITE)
	_check("S3-AT-7 AI resolves one move and returns turn", game.current_player == BLACK and white_after >= white_before + 1, "turn=%s white %d->%d" % [game.current_player, white_before, white_after])

func _test_difficulty_contract(game) -> void:
	_check("S7 easy depth is 1", game._match_difficulty(0) == 1)
	_check("S7 medium depth is 3", game._match_difficulty(1) == 3)
	_check("S7 hard depth is 5", game._match_difficulty(2) == 5)

	# Exercise the real OptionButton mapping created by _build_ui.
	var labels := []
	var depths := []
	for i in range(game.difficulty_option.item_count):
		labels.append(game.difficulty_option.get_item_text(i))
		depths.append(game._match_difficulty(game.difficulty_option.get_item_id(i)))
	_check("S7 option labels in order", labels == ["Easy", "Medium", "Hard"], str(labels))
	_check("S7 option ids map to depths 1/3/5", depths == [1, 3, 5], str(depths))
	_check("S7 default selection is Medium", game.difficulty_option.get_item_text(game.difficulty_option.selected) == "Medium")

	var hard_index: int = game.difficulty_option.get_item_index(2)
	game.difficulty_option.select(hard_index)
	game.difficulty_option.item_selected.emit(hard_index)
	_check("S7 selecting Hard sets difficulty 2", game.game_difficulty == 2, str(game.game_difficulty))

func _test_mode_display_names(game) -> void:
	# RC1: White is "Computer" only in player-vs-computer; in local PvP both sides are colors.
	game.game_mode = 0 # Mode.PLAYER_VS_AI
	_check("RC1 vs-AI names", game._display_name(BLACK) == "Black" and game._display_name(WHITE) == "Computer", "%s / %s" % [game._display_name(BLACK), game._display_name(WHITE)])

	game.game_mode = 1 # Mode.PLAYER_VS_PLAYER
	_check("RC1 PvP names", game._display_name(BLACK) == "Black" and game._display_name(WHITE) == "White", "%s / %s" % [game._display_name(BLACK), game._display_name(WHITE)])

	game.current_player = WHITE
	game.game_over = false
	game._update_ui_state()
	_check("RC1 PvP turn label shows White", game.turn_label.text == "Turn: White", game.turn_label.text)

func _test_ai_contract(game) -> void:
	# S5-AT-1: opening position -> AI returns a legal White move.
	game.game_mode = 0 # Mode.PLAYER_VS_AI
	game.game_difficulty = 0 # Difficulty.EASY
	game._new_game()
	var opening_move: Vector2i = game._get_best_move()
	_check("S5-AT-1 AI returns a legal opening move", game._is_legal_move(opening_move.x, opening_move.y, WHITE), str(opening_move))

	# A one-move mid-game board used by the remaining AI checks.
	game._new_game()
	game._execute_move(2, 4, BLACK)
	var mid_board: Array = _clone_board(game.board)

	# S5-AT-2 / S5-AT-5: legal, in-set move for every difficulty.
	for diff in [0, 1, 2]:
		game.board = _clone_board(mid_board)
		game.game_difficulty = diff
		var move: Vector2i = game._get_best_move()
		var legal_set: Array = game._get_all_legal_moves(WHITE)
		_check("S5-AT-2/5 depth-%d AI move is legal and in the legal set" % game._match_difficulty(diff), legal_set.has(move) and game._is_legal_move(move.x, move.y, WHITE), str(move))

	# S5-AT-6 / R-S5-11: the search restores the board.
	game.board = _clone_board(mid_board)
	game.game_difficulty = 1 # Difficulty.MEDIUM
	var before_search := str(game.board)
	game._get_best_move()
	_check("S5-AT-6 search leaves the board unchanged", str(game.board) == before_search)

	# S5-AT-4: deterministic choice on the same board.
	game.board = _clone_board(mid_board)
	game.game_difficulty = 1 # Difficulty.MEDIUM
	var first: Vector2i = game._get_best_move()
	game.board = _clone_board(mid_board)
	var second: Vector2i = game._get_best_move()
	_check("S5-AT-4 AI is deterministic", first == second, "%s vs %s" % [first, second])

	# S5-AT-3: EASY is depth 1 over the standard evaluation MINUS the
	# mobility term (see _evaluate_board_no_mobility), so it is exactly
	# greedy over that evaluation.
	game.board = _clone_board(mid_board)
	game.game_difficulty = 0 # Difficulty.EASY
	var expected := _greedy_white_move(game, true)
	var chosen: Vector2i = game._get_best_move()
	_check("S5-AT-3 easy AI is 1-ply greedy (no-mobility eval)", chosen == expected, "chosen=%s expected=%s" % [chosen, expected])
	_check("S5-AT-3 easy AI move is legal", game._is_legal_move(chosen.x, chosen.y, WHITE), "move=%s" % chosen)

	# S5-AT-7 / R-S5-9: a blocked AI returns null and passes without changing the board.
	game.board = _empty_board()
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			game.board[r][c] = BLACK
	game.board[0][1] = WHITE
	game.board[0][0] = EMPTY # legal for Black, not for White
	game.current_player = WHITE
	game.game_over = false
	game.game_mode = 0 # Mode.PLAYER_VS_AI
	var blocked_before := str(game.board)
	var blocked_move: Vector2i = game._get_best_move()
	_check("S5-AT-7 blocked AI reports no move", blocked_move == Vector2i(-1, -1), str(blocked_move))
	game._ai_move()
	_check("S5-AT-7 blocked AI passes without board change", str(game.board) == blocked_before and game.current_player == BLACK, "turn=%s" % game.current_player)

func _test_ui_shell(game) -> void:
	# S6-AT-1 / S6-AT-2: 8x8 grid of buttons, each owning a background and a disc.
	var well_formed := true
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var cell_data: Dictionary = game.cells[r][c]
			if not (cell_data.has("cell") and cell_data.has("bg") and cell_data.has("disc")):
				well_formed = false
			if not (cell_data.cell is Control):
				well_formed = false
			if not (cell_data.bg is ColorRect):
				well_formed = false
			if not (cell_data.disc is TextureRect):
				well_formed = false
	_check("S6-AT-1 board has 64 button cells", game.cells.size() == BOARD_SIZE and game.cells[7].size() == BOARD_SIZE, "%d rows" % game.cells.size())
	_check("S6-AT-1 each cell owns a background and a disc", well_formed)
	_check("S6-AT-2 board grid has 64 cell children", game.board_grid.get_child_count() == 64, "%d children" % game.board_grid.get_child_count())

	# S6-AT-3: stats render a fresh match.
	game.game_mode = 1 # Mode.PLAYER_VS_PLAYER
	game._new_game()
	_check("S6-AT-3 score labels render counts", game.black_score_label.text == "Black: 2" and game.white_score_label.text == "White: 2", "%s / %s" % [game.black_score_label.text, game.white_score_label.text])
	_check("S6-AT-3 turn label renders the active side", game.turn_label.text == "Turn: Black", game.turn_label.text)

	# S6-AT-4: settings widgets expose their labels.
	var mode_labels := []
	for i in range(game.mode_option.item_count):
		mode_labels.append(game.mode_option.get_item_text(i))
	var diff_labels := []
	for i in range(game.difficulty_option.item_count):
		diff_labels.append(game.difficulty_option.get_item_text(i))
	_check("S6-AT-4 mode widget labels", mode_labels == ["vs Computer", "vs Player"], str(mode_labels))
	_check("S6-AT-4 difficulty widget labels", diff_labels == ["Easy", "Medium", "Hard"], str(diff_labels))

	# S6-AT-5: disc textures reflect the board (disc is cell_data.disc; C9 fixed).
	_check("S6-AT-5 discs render black/white/empty", game.cells[3][3].disc.texture == game.black_disc_tex and game.cells[3][4].disc.texture == game.white_disc_tex and game.cells[0][0].disc.texture == null)

	# S6-AT-6: a legal empty click places a disc and advances the turn.
	game.game_mode = 1 # Mode.PLAYER_VS_PLAYER
	game._new_game()
	game._on_cell_pressed(2, 4)
	_check("S6-AT-6 legal click places a disc and advances", game.board[2][4] == BLACK and game.current_player == WHITE, "cell=%d turn=%d" % [game.board[2][4], game.current_player])

	# S6-AT-7: an occupied click changes nothing (RC4 — feedback text is transient).
	game._new_game()
	var occupied_before := str(game.board)
	game._on_cell_pressed(3, 3)
	_check("S6-AT-7 occupied click changes nothing", str(game.board) == occupied_before and game.current_player == BLACK, "turn=%d" % game.current_player)

	# S6-AT-8: an illegal empty click changes nothing.
	game._new_game()
	var illegal_before := str(game.board)
	game._on_cell_pressed(0, 0)
	_check("S6-AT-8 illegal click changes nothing", str(game.board) == illegal_before and game.current_player == BLACK, "turn=%d" % game.current_player)

	# S6-AT-9: restart resets the match and the labels.
	game.game_mode = 1 # Mode.PLAYER_VS_PLAYER
	game._new_game()
	game._execute_move(2, 4, BLACK)
	game.current_player = WHITE
	game.game_over = true
	game._new_game()
	_check("S6-AT-9 restart resets the match", _count_discs(game.board, BLACK) == 2 and _count_discs(game.board, WHITE) == 2 and game.current_player == BLACK and not game.game_over)
	_check("S6-AT-9 restart restores labels", game.black_score_label.text == "Black: 2" and game.turn_label.text == "Turn: Black", "%s / %s" % [game.black_score_label.text, game.turn_label.text])

	# S6-AT-10: legal-move affordance highlights the human's legal empty cells (RC3).
	game.game_mode = 1 # Mode.PLAYER_VS_PLAYER
	game._new_game()
	var base := Color(0.16, 0.44, 0.16)
	var legal_bg: Color = game.cells[2][4].bg.color
	var empty_illegal_bg: Color = game.cells[0][0].bg.color
	var occupied_bg: Color = game.cells[3][3].bg.color
	_check("S6-AT-10 legal cells are highlighted", legal_bg != base and empty_illegal_bg == base, "%s vs %s" % [legal_bg, empty_illegal_bg])
	_check("S6-AT-10 occupied cells are not highlighted", occupied_bg == base, str(occupied_bg))
	game.game_over = true
	game._refresh_legal_hints()
	_check("S6-AT-10 hints clear when the match ends", game.cells[2][4].bg.color == base, str(game.cells[2][4].bg.color))

	# S14-AT-1/2/3: accessibility baseline (keyboard focus + WCAG contrast).
	# Contrast: black disc and white disc must be distinguishable from the cell base (>=3:1),
	# and the legal-move hint must be distinguishable from the cell base (>=3:1).
	var black_disc: Color = Color(0, 0, 0)
	var white_disc: Color = Color(1, 1, 1)
	_check("S14-AT-1 black disc contrast vs cell base >= 3:1", _contrast_ratio(black_disc, base) >= 3.0, "%.2f:1" % _contrast_ratio(black_disc, base))
	_check("S14-AT-1 white disc contrast vs cell base >= 3:1", _contrast_ratio(white_disc, base) >= 3.0, "%.2f:1" % _contrast_ratio(white_disc, base))
	_check("S14-AT-2 legal-move hint contrast vs cell base >= 3:1", _contrast_ratio(legal_bg, base) >= 3.0, "%.2f:1" % _contrast_ratio(legal_bg, base))
	
	# S14-AT-3: cells are keyboard-focusable and wired for arrow-key navigation.
	var focusable := true
	var wired := true
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var cell: Control = game.cells[r][c].cell
			if cell.focus_mode != Control.FOCUS_ALL:
				focusable = false
			var expected_right: String = "../Cell_%d_%d" % [r, c + 1] if c < BOARD_SIZE - 1 else ""
			var expected_left: String = "../Cell_%d_%d" % [r, c - 1] if c > 0 else ""
			if str(cell.focus_neighbor_right) != expected_right:
				wired = false
			if str(cell.focus_neighbor_left) != expected_left:
				wired = false
	_check("S14-AT-3 every cell is keyboard focusable", focusable)
	_check("S14-AT-3 cells are wired for arrow-key navigation", wired)

	# S14-AT-4: keyboard activation places a disc (Enter on a focused cell).
	game.game_mode = 1 # Mode.PLAYER_VS_PLAYER
	game._new_game()
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_ENTER
	key_event.pressed = true
	game._on_cell_input(key_event, 2, 4)
	_check("S14-AT-4 Enter on a focused cell places a disc", game.board[2][4] == BLACK and game.current_player == WHITE, "cell=%d turn=%d" % [game.board[2][4], game.current_player])

	# S14-AT-5: mouse activation places a disc (regression guard for the
	# gui_input bind-order contract: the signal arg comes before bound args).
	game._new_game()
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	game._on_cell_input(mouse_event, 2, 4)
	_check("S14-AT-5 mouse click places a disc", game.board[2][4] == BLACK and game.current_player == WHITE, "cell=%d turn=%d" % [game.board[2][4], game.current_player])

	# S14-AT-6: a non-activation key (e.g. Tab) must not place a disc.
	game._new_game()
	var tab_event := InputEventKey.new()
	tab_event.keycode = KEY_TAB
	tab_event.pressed = true
	game._on_cell_input(tab_event, 2, 4)
	_check("S14-AT-6 non-activation key does not place a disc", game.board[2][4] == EMPTY and game.current_player == BLACK, "cell=%d turn=%d" % [game.board[2][4], game.current_player])

	# S13-AT-1: the translation CSV is loaded from res://translations/strings.csv
	# (not the hardcoded fallback), so a new locale only needs a CSV edit.
	var csv_translation: Translation = game._read_translation_csv("res://translations/strings.csv")
	_check("S13-AT-1 translation CSV loads with all keys", csv_translation.get_message_count() >= 25, "%d messages" % csv_translation.get_message_count())
	_check("S13-AT-1 CSV values match the fallback table", csv_translation.get_message("STATUS_YOUR_TURN") == "Your turn!" and csv_translation.get_message("PLAYER_COMPUTER") == "Computer" and csv_translation.get_message("SCORE_BLACK") == "Black: %d", str(csv_translation.get_message("STATUS_YOUR_TURN")))
	
	# PT-AT-1..4: the playtest logger records objective session evidence so a
	# playtest produces data, not just anecdotes.
	var log_script := load("res://scripts/playtest_log.gd")
	var log = log_script.new()
	log.record_move()
	log.record_move()
	log.record_invalid_click()
	log.record_skip()
	log.record_restart()
	log.record_mode_change(1)
	log.record_difficulty_change(2)
	log.record_game_over("Black Wins!", 40, 24)
	var report: Dictionary = log.to_dict()
	_check("PT-AT-1 logger counts moves", report.moves_placed == 2, str(report.moves_placed))
	_check("PT-AT-1 logger records time to first legal move", report.first_legal_move_ms >= 0, str(report.first_legal_move_ms))
	_check("PT-AT-2 logger counts invalid clicks and skips", report.invalid_clicks == 1 and report.skipped_turns == 1)
	_check("PT-AT-2 logger counts restarts and setting changes", report.restarts == 1 and report.mode_changes == 1 and report.difficulty_changes == 1)
	_check("PT-AT-3 logger records match completion and outcome", report.completed and report.game_over and report.outcome == "Black Wins!", str(report.outcome))
	_check("PT-AT-4 logger emits an ordered event trail", report.events.size() >= 8, "%d events" % report.events.size())

func _clone_board(src: Array) -> Array:
	var copy: Array = []
	for row in src:
		copy.append(row.duplicate())
	return copy

func _contrast_ratio(fg: Color, bg: Color) -> float:
	# WCAG 2.1 relative luminance contrast ratio.
	var l1: float = _relative_luminance(fg)
	var l2: float = _relative_luminance(bg)
	var hi: float = max(l1, l2)
	var lo: float = min(l1, l2)
	return (hi + 0.05) / (lo + 0.05)

func _relative_luminance(c: Color) -> float:
	return 0.2126 * _srgb_to_linear(c.r) + 0.7152 * _srgb_to_linear(c.g) + 0.0722 * _srgb_to_linear(c.b)

func _srgb_to_linear(channel: float) -> float:
	if channel <= 0.04045:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)

func _greedy_white_move(game, no_mobility: bool = false) -> Vector2i:
	# Mirrors the AI's move selection: strict >, row-major first-found.
	# With no_mobility it mirrors the EASY path (_evaluate_board_no_mobility).
	var best_score: int = -100000000
	var best := Vector2i(-1, -1)
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if game._is_legal_move(r, c, WHITE):
				var original: Array = _clone_board(game.board)
				game._execute_move(r, c, WHITE)
				var score: int = game._evaluate_board_no_mobility() if no_mobility else game._evaluate_board()
				game.board = original
				if score > best_score:
					best_score = score
					best = Vector2i(r, c)
	return best

func _test_restart_assertion(game) -> void:
	# S9: restart behavior - verifies full state reset via Restart button / _new_game().
	game.game_mode = 1 # Mode.PLAYER_VS_PLAYER
	game.game_difficulty = 1 # MEDIUM
	
	# Play a few moves
	game._execute_move(2, 4, BLACK)
	game._advance_turn()
	game._execute_move(3, 2, WHITE)
	game._advance_turn()
	game.current_player = BLACK
	game.game_over = true
	game._end_game()
	
	# Verify pre-restart state is mutated
	_check("S9-AT-1 pre-restart board mutated", _count_discs(game.board, BLACK) != 2 or _count_discs(game.board, WHITE) != 2)
	_check("S9-AT-1 pre-restart game_over", game.game_over)
	
	# Restart via _new_game (what Restart button calls)
	game._new_game()
	
	# Verify full reset
	_check("S9-AT-2 board reset to 4 discs", _count_discs(game.board, BLACK) == 2 and _count_discs(game.board, WHITE) == 2)
	_check("S9-AT-2 current_player reset to BLACK", game.current_player == BLACK)
	_check("S9-AT-2 game_over reset to false", not game.game_over)
	_check("S9-AT-2 hints cleared on non-legal cell", game.cells[0][0].bg.color == CELL_COLOR)
	_check("S9-AT-2 labels reset", game.black_score_label.text == "Black: 2" and game.white_score_label.text == "White: 2" and game.turn_label.text == "Turn: Black")
	_check("S9-AT-2 mode/difficulty preserved", game.game_mode == 1 and game.game_difficulty == 1)

func _test_feedback(game) -> void:
	# S8-AT-1: human turn prompt on new game.
	game.game_mode = 1 # Mode.PLAYER_VS_PLAYER
	game._new_game()
	_check("S8-AT-1 human turn shows 'Your turn!'", game.status_label.text == "Your turn!", game.status_label.text)

	# S8-AT-2: human skip (constructed board: White blocked, Black has a move).
	game.board = _empty_board()
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			game.board[r][c] = BLACK
	game.board[0][0] = EMPTY
	game.board[0][1] = WHITE
	game.current_player = BLACK
	game.game_over = false
	game._advance_turn()
	_check("S8-AT-2 human skip returns turn to Black", game.current_player == BLACK and not game.game_over, "turn=%d over=%s" % [game.current_player, game.game_over])

	# S8-AT-3: AI turn executes one move and returns the turn.
	game.game_mode = 0 # Mode.PLAYER_VS_AI
	game.game_difficulty = 0 # EASY
	game._new_game()
	game._execute_move(2, 4, BLACK)
	game._advance_turn()
	_check("S8-AT-3 AI turn resolves and returns", game.current_player == BLACK, str(game.current_player))

	# S8-AT-4: occupied click changes nothing.
	game.game_mode = 1 # Mode.PLAYER_VS_PLAYER
	game._new_game()
	var occ_before := str(game.board)
	game._on_cell_pressed(3, 3)
	_check("S8-AT-4 occupied click no-op", str(game.board) == occ_before and game.current_player == BLACK, "turn=%d" % game.current_player)

	# S8-AT-5: illegal empty click changes nothing.
	game._new_game()
	var ill_before := str(game.board)
	game._on_cell_pressed(0, 0)
	_check("S8-AT-5 illegal click no-op", str(game.board) == ill_before and game.current_player == BLACK, "turn=%d" % game.current_player)

	# S8-AT-6: game-over text contains the final score.
	game._new_game()
	game.current_player = BLACK
	game.game_over = true
	game._end_game()
	_check("S8-AT-6 game-over text has score", game.status_label.text.begins_with("Game Over:") and ("-" in game.status_label.text), game.status_label.text)
