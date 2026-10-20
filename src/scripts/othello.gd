extends Control

const BLACK: int = 1
const WHITE: int = 2
const AI_PLAYER: int = WHITE

const BOARD_SIZE: int = 8
const CELL_SIZE: int = 60
const EMPTY: int = 0
const NO_MOVE: Vector2i = Vector2i(-1, -1)

# Palette (WCAG 2.1 AA contrast verified - see production/playtest/a11y-baseline-2026-10-19.md)
# CELL_COLOR: black disc 3.44:1, white disc 6.10:1 (non-text UI needs 3:1)
# CELL_HINT_COLOR: 3.78:1 vs CELL_COLOR, and distinct in hue AND lightness for colorblind use
const CELL_COLOR: Color = Color(0.16, 0.44, 0.16)
const CELL_HINT_COLOR: Color = Color(0.95, 0.78, 0.25)

# Time budget per difficulty (milliseconds) - for iterative deepening
const TIME_BUDGET_EASY: int = 50
const TIME_BUDGET_MEDIUM: int = 150
const TIME_BUDGET_HARD: int = 400

enum Mode { PLAYER_VS_AI, PLAYER_VS_PLAYER }
enum Difficulty { EASY, MEDIUM, HARD }

const _PlaytestLog := preload("res://scripts/playtest_log.gd")

var board_container_node: MarginContainer
var black_score_label: Label
var white_score_label: Label
var turn_label: Label
var status_label: Label
var board_grid: Control
var restart_button: Button
var mode_option: OptionButton
var difficulty_option: OptionButton
var language_option: OptionButton

# Settings
var game_mode: Mode = Mode.PLAYER_VS_AI
var game_difficulty: Difficulty = Difficulty.MEDIUM
var game_language_idx: int = 0

var board: Array = []
var cells: Array = [] # Array of {cell: Control, bg: ColorRect, disc: TextureRect}
var current_player: int = BLACK
var game_over: bool = false

var black_disc_tex: ImageTexture
var white_disc_tex: ImageTexture

# Audio
var audio_place: AudioStreamPlayer
var audio_flip: AudioStreamPlayer
var audio_invalid: AudioStreamPlayer
var audio_win: AudioStreamPlayer
var audio_lose: AudioStreamPlayer
var master_volume_db: float = 0.0
var playtest_log: RefCounted = null  # PlaytestLog, enabled only with `-- --playtest`

func _ready() -> void:
	_load_translations()
	_create_textures()
	_build_ui()
	if _PlaytestLog.is_requested():
		playtest_log = _PlaytestLog.new()
		print("[Playtest] Session logging enabled")
		# Write the report when the tree shuts down (covers window close and
		# game-over-then-quit without relying on window notifications).
		get_tree().root.tree_exiting.connect(_write_playtest_report)
	_new_game()

func _write_playtest_report() -> void:
	if playtest_log:
		playtest_log.write_report()

func _load_translations() -> void:
	# Parse res://translations/strings.csv directly rather than relying on Godot's
	# csv_translation importer remap, which is not guaranteed to resolve at
	# runtime (and is skipped entirely in headless/CI runs).
	var translation: Translation = _read_translation_csv("res://translations/strings.csv")
	if translation and translation.get_message_count() > 0:
		TranslationServer.add_translation(translation)
		TranslationServer.set_locale("en")
	else:
		print("WARNING: Could not load translations from res://translations/strings.csv; using fallback")
		_add_fallback_translations()

func _read_translation_csv(path: String) -> Translation:
	var translation := Translation.new()
	translation.set_locale("en")
	if not FileAccess.file_exists(path):
		return translation
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return translation
	var header: bool = true
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		if header:
			header = false
			continue
		var parts: PackedStringArray = line.split(",", false, 1)
		if parts.size() < 2:
			continue
		var key: String = parts[0].strip_edges()
		var value: String = parts[1].strip_edges()
		# Strip surrounding quotes from the value.
		if value.length() >= 2 and value.begins_with("\"") and value.ends_with("\""):
			value = value.substr(1, value.length() - 2)
		if not key.is_empty():
			translation.add_message(key, value)
	file.close()
	return translation

func _add_fallback_translations() -> void:
	var fallback = Translation.new()
	fallback.set_locale("en")
	fallback.add_message("MODE_LABEL", "Mode:")
	fallback.add_message("MODE_VS_COMPUTER", "vs Computer")
	fallback.add_message("MODE_VS_PLAYER", "vs Player")
	fallback.add_message("DIFFICULTY_LABEL", "Difficulty:")
	fallback.add_message("DIFFICULTY_EASY", "Easy")
	fallback.add_message("DIFFICULTY_MEDIUM", "Medium")
	fallback.add_message("DIFFICULTY_HARD", "Hard")
	fallback.add_message("LANGUAGE_LABEL", "Language:")
	fallback.add_message("LANGUAGE_ENGLISH", "English")
	fallback.add_message("VOLUME_LABEL", "Volume:")
	fallback.add_message("SCORE_BLACK", "Black: %d")
	fallback.add_message("SCORE_WHITE", "White: %d")
	fallback.add_message("TURN_LABEL", "Turn: %s")
	fallback.add_message("STATUS_YOUR_TURN", "Your turn!")
	fallback.add_message("STATUS_THINKING", "Computer is thinking...")
	fallback.add_message("STATUS_SKIP", "%s has no legal moves! Skipping...")
	fallback.add_message("STATUS_INVALID_MOVE", "Invalid Move!")
	fallback.add_message("STATUS_GAME_OVER", "Game Over: %s (%d-%d)")
	fallback.add_message("WINNER_BLACK", "Black Wins!")
	fallback.add_message("WINNER_WHITE", "White Wins!")
	fallback.add_message("WINNER_DRAW", "Draw!")
	fallback.add_message("RESTART_BUTTON", "Restart Game")
	fallback.add_message("PLAYER_BLACK", "Black")
	fallback.add_message("PLAYER_WHITE", "White")
	fallback.add_message("PLAYER_COMPUTER", "Computer")
	TranslationServer.add_translation(fallback)
	TranslationServer.set_locale("en")

func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "Layout"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vbox)
	
	# Settings Bar
	var settings_hbox: HBoxContainer = HBoxContainer.new()
	settings_hbox.name = "SettingsBar"
	settings_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(settings_hbox)
	
	var mode_label: Label = Label.new()
	mode_label.text = tr("MODE_LABEL")
	settings_hbox.add_child(mode_label)
	
	var mode_opt: OptionButton = OptionButton.new()
	mode_opt.name = "ModeOption"
	mode_option = mode_opt
	mode_opt.add_item(tr("MODE_VS_COMPUTER"), Mode.PLAYER_VS_AI)
	mode_opt.add_item(tr("MODE_VS_PLAYER"), Mode.PLAYER_VS_PLAYER)
	mode_opt.select(mode_opt.get_item_index(game_mode))
	mode_opt.item_selected.connect(
		func(idx):
			game_mode = mode_opt.get_item_id(idx) as Mode
			if playtest_log:
				playtest_log.record_mode_change(int(game_mode))
			_update_ui_state()
	)
	settings_hbox.add_child(mode_opt)
	
	var diff_label: Label = Label.new()
	diff_label.text = tr("DIFFICULTY_LABEL")
	settings_hbox.add_child(diff_label)
	
	var diff_opt: OptionButton = OptionButton.new()
	diff_opt.name = "DifficultyOption"
	difficulty_option = diff_opt
	diff_opt.add_item(tr("DIFFICULTY_EASY"), Difficulty.EASY)
	diff_opt.add_item(tr("DIFFICULTY_MEDIUM"), Difficulty.MEDIUM)
	diff_opt.add_item(tr("DIFFICULTY_HARD"), Difficulty.HARD)
	diff_opt.select(diff_opt.get_item_index(game_difficulty))
	diff_opt.item_selected.connect(
		func(idx):
			game_difficulty = diff_opt.get_item_id(idx) as Difficulty
			if playtest_log:
				playtest_log.record_difficulty_change(int(game_difficulty))
	)
	settings_hbox.add_child(diff_opt)
	
	var lang_label: Label = Label.new()
	lang_label.text = tr("LANGUAGE_LABEL")
	settings_hbox.add_child(lang_label)
	
	var lang_opt: OptionButton = OptionButton.new()
	lang_opt.name = "LanguageOption"
	language_option = lang_opt
	lang_opt.add_item(tr("LANGUAGE_ENGLISH"), 0)
	lang_opt.select(game_language_idx)
	lang_opt.item_selected.connect(
		func(idx):
			game_language_idx = idx
			TranslationServer.set_locale("en")
			_update_ui_state()
	)
	settings_hbox.add_child(lang_opt)
	
	# Volume slider
	var vol_label: Label = Label.new()
	vol_label.text = tr("VOLUME_LABEL")
	settings_hbox.add_child(vol_label)
	
	var vol_slider: HSlider = HSlider.new()
	vol_slider.min_value = -60.0
	vol_slider.max_value = 0.0
	vol_slider.value = master_volume_db
	vol_slider.step = 1.0
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.value_changed.connect(
		func(val: float):
			master_volume_db = val
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), val)
	)
	settings_hbox.add_child(vol_slider)
	
	# Stats
	var stats: HBoxContainer = HBoxContainer.new()
	stats.name = "StatsBar"
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(stats)
	
	black_score_label = Label.new()
	black_score_label.text = tr("SCORE_BLACK") % 2
	stats.add_child(black_score_label)
	
	white_score_label = Label.new()
	white_score_label.text = tr("SCORE_WHITE") % 2
	stats.add_child(white_score_label)
	
	turn_label = Label.new()
	turn_label.text = tr("TURN_LABEL") % tr("PLAYER_BLACK")
	stats.add_child(turn_label)
	
	# Board - manual layout with pixel-perfect cell alignment
	board_container_node = MarginContainer.new()
	board_container_node.name = "BoardContainer"
	board_container_node.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.add_child(board_container_node)
	
	board_grid = Control.new()
	board_grid.name = "BoardGrid"
	board_grid.custom_minimum_size = Vector2(CELL_SIZE * BOARD_SIZE, CELL_SIZE * BOARD_SIZE)
	board_container_node.add_child(board_grid)
	
	for r in range(BOARD_SIZE):
		var row: Array = []
		for c in range(BOARD_SIZE):
			var pos: Vector2 = Vector2(c * CELL_SIZE, r * CELL_SIZE)
			
			# Cell container - plain Control (no button theming)
			var cell: Control = Control.new()
			cell.name = "Cell_%d_%d" % [r, c]
			cell.custom_minimum_size = Vector2i(CELL_SIZE, CELL_SIZE)
			cell.position = pos
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			cell.focus_mode = Control.FOCUS_ALL
			cell.gui_input.connect(_on_cell_input.bind(r, c))
			# Arrow-key navigation across the grid (a11y: keyboard-only play)
			cell.focus_neighbor_left = _cell_path(c - 1, r)
			cell.focus_neighbor_right = _cell_path(c + 1, r)
			cell.focus_neighbor_top = _cell_path(c, r - 1)
			cell.focus_neighbor_bottom = _cell_path(c, r + 1)
			
			# Cell background
			var bg: ColorRect = ColorRect.new()
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bg.color = CELL_COLOR
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(bg)
			
			# Disc (TextureRect) - exact pixel centering inside the 60x60 cell
			var disc: TextureRect = TextureRect.new()
			var disc_size: int = int(CELL_SIZE * 0.8)
			var disc_margin: int = int((CELL_SIZE - disc_size) / 2.0)
			disc.size = Vector2(disc_size, disc_size)
			disc.position = Vector2(disc_margin, disc_margin)
			disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(disc)
			
			# Add the cell to the board exactly once (children must be attached
			# before their sub-nodes are added, so the cell is added last).
			board_grid.add_child(cell)
			row.append({"cell": cell, "bg": bg, "disc": disc})
		cells.append(row)
	
	# Status
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_label)
	
	# Restart
	restart_button = Button.new()
	restart_button.name = "RestartButton"
	restart_button.text = tr("RESTART_BUTTON")
	vbox.add_child(restart_button)
	restart_button.pressed.connect(_new_game)

func _create_textures() -> void:
	black_disc_tex = _make_disc_texture(Color.BLACK)
	white_disc_tex = _make_disc_texture(Color.WHITE)

func _make_disc_texture(color: Color) -> ImageTexture:
	var tex_size: int = 50
	var img: Image = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center: float = tex_size / 2.0
	var radius: float = tex_size / 2.0 - 4.0
	for y in range(tex_size):
		for x in range(tex_size):
			var dx: float = x - center
			var dy: float = y - center
			if dx * dx + dy * dy <= radius * radius:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

func _create_audio() -> void:
	audio_place = AudioStreamPlayer.new()
	audio_place.stream = load("res://assets/audio/disc_place.wav")
	add_child(audio_place)
	
	audio_flip = AudioStreamPlayer.new()
	audio_flip.stream = load("res://assets/audio/disc_flip.wav")
	add_child(audio_flip)
	
	audio_invalid = AudioStreamPlayer.new()
	audio_invalid.stream = load("res://assets/audio/invalid_move.wav")
	add_child(audio_invalid)
	
	audio_win = AudioStreamPlayer.new()
	audio_win.stream = load("res://assets/audio/game_over_win.wav")
	add_child(audio_win)
	
	audio_lose = AudioStreamPlayer.new()
	audio_lose.stream = load("res://assets/audio/game_over_lose.wav")
	add_child(audio_lose)
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_volume_db)

func _new_game() -> void:
	board = []
	for r in range(BOARD_SIZE):
		var row: Array = []
		for c in range(BOARD_SIZE):
			row.append(EMPTY)
		board.append(row)
	
	board[3][3] = BLACK
	board[4][4] = BLACK
	board[3][4] = WHITE
	board[4][3] = WHITE
	
	current_player = BLACK
	game_over = false
	if playtest_log and not _is_first_new_game():
		playtest_log.record_restart()
	_refresh_board_visuals()
	_refresh_legal_hints()
	_update_ui_state()

func _is_first_new_game() -> bool:
	# The first _new_game() call is part of setup, not a player restart.
	return playtest_log != null and playtest_log.moves_placed == 0 and playtest_log.restarts == 0

func _save_game() -> void:
	var save_data: Dictionary = {
		"version": 1,
		"board": board,
		"current_player": current_player,
		"game_over": game_over,
		"game_mode": int(game_mode),
		"game_difficulty": int(game_difficulty),
		"game_language_idx": game_language_idx,
		"master_volume_db": master_volume_db,
	}
	var json_text: String = JSON.stringify(save_data)
	var file: FileAccess = FileAccess.open("user://othello_save_v1.json", FileAccess.WRITE)
	if file:
		file.store_string(json_text)
		file.close()
	else:
		print("WARNING: Could not save game")

func _load_game() -> bool:
	var file: FileAccess = FileAccess.open("user://othello_save_v1.json", FileAccess.READ)
	if not file:
		return false
	
	var json_text: String = file.get_as_text()
	file.close()
	
	var save_data: Dictionary = JSON.parse_string(json_text)
	if not save_data or save_data.get("version", 0) != 1:
		print("WARNING: Invalid or outdated save file")
		return false
	
	board = save_data["board"]
	current_player = save_data["current_player"]
	game_over = save_data["game_over"]
	game_mode = save_data["game_mode"]
	game_difficulty = save_data["game_difficulty"]
	game_language_idx = save_data.get("game_language_idx", 0)
	master_volume_db = save_data.get("master_volume_db", 0.0)
	
	if mode_option:
		mode_option.select(mode_option.get_item_index(game_mode))
	if difficulty_option:
		difficulty_option.select(difficulty_option.get_item_index(game_difficulty))
	if language_option:
		language_option.select(game_language_idx)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), master_volume_db)
	
	_refresh_board_visuals()
	_refresh_legal_hints()
	_update_ui_state()
	return true

func _notification(_what: int) -> void:
	# Reserved for future engine notifications (e.g. auto-save on quit).
	pass

func _on_cell_input(event: InputEvent, r: int, c: int) -> void:
	# NOTE: `gui_input` is connected with .bind(r, c), so Godot calls this as
	# (event, r, c) - the signal argument comes FIRST, bound args after.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_cell_pressed(r, c)
	elif event is InputEventKey and event.pressed and not event.echo:
		# Keyboard activation (Enter / Space) on a focused cell.
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_on_cell_pressed(r, c)

func _cell_path(c: int, r: int) -> NodePath:
	# NodePath of the cell at (c, r) for focus-neighbor wiring. Godot resolves
	# focus_neighbor_* relative to the focused node itself, so siblings are
	# addressed as "../Cell_r_c". Out-of-range coordinates return an empty
	# path, which Godot treats as "no neighbor".
	if c < 0 or c >= BOARD_SIZE or r < 0 or r >= BOARD_SIZE:
		return NodePath("")
	return NodePath("../Cell_%d_%d" % [r, c])

func _on_cell_pressed(r: int, c: int) -> void:
	if game_over or current_player == AI_PLAYER:
		return

	if board[r][c] != EMPTY or not _is_legal_move(r, c, current_player):
		status_label.text = tr("STATUS_INVALID_MOVE")
		if playtest_log:
			playtest_log.record_invalid_click()
		if audio_invalid and audio_invalid.stream:
			audio_invalid.play()
		if is_inside_tree():
			await get_tree().create_timer(0.5).timeout
		_update_ui_state()
		return

	if playtest_log:
		playtest_log.record_move()
	_execute_move(r, c, current_player)
	_advance_turn()

func _is_legal_move(r: int, c: int, player: int) -> bool:
	if board[r][c] != EMPTY:
		return false
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0: continue
			if _check_direction(r, c, player, dr, dc):
				return true
	return false

func _check_direction(r: int, c: int, player: int, dr: int, dc: int) -> bool:
	var nr: int = r + dr
	var nc: int = c + dc
	var found_opponent: bool = false
	while _in_bounds(nr, nc) and board[nr][nc] == _get_opponent(player):
		found_opponent = true
		nr += dr
		nc += dc
	return found_opponent and _in_bounds(nr, nc) and board[nr][nc] == player

func _execute_move(r: int, c: int, player: int) -> void:
	board[r][c] = player
	var flipped_any: bool = false
	for dr in [-1, 0, 1]:
		for dc in [-1, 0, 1]:
			if dr == 0 and dc == 0: continue
			if _flip_in_direction(r, c, player, dr, dc):
				flipped_any = true
	
	if audio_place and audio_place.stream:
		audio_place.play()
	if flipped_any and audio_flip and audio_flip.stream:
		audio_flip.play()
	
	_refresh_board_visuals()

func _flip_in_direction(r: int, c: int, player: int, dr: int, dc: int) -> bool:
	var nr: int = r + dr
	var nc: int = c + dc
	var to_flip: Array = []
	while _in_bounds(nr, nc) and board[nr][nc] == _get_opponent(player):
		to_flip.append(Vector2i(nr, nc))
		nr += dr
		nc += dc
	if _in_bounds(nr, nc) and board[nr][nc] == player:
		for pos in to_flip:
			board[pos.x][pos.y] = player
		return true
	return false

func _in_bounds(r: int, c: int) -> bool:
	return r >= 0 and r < BOARD_SIZE and c >= 0 and c < BOARD_SIZE

func _get_opponent(player: int) -> int:
	return WHITE if player == BLACK else BLACK

func _display_name(player: int) -> String:
	if game_mode == Mode.PLAYER_VS_AI and player == AI_PLAYER:
		return tr("PLAYER_COMPUTER")
	return tr("PLAYER_BLACK") if player == BLACK else tr("PLAYER_WHITE")

func _refresh_board_visuals() -> void:
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var cell_data: Dictionary = cells[r][c]
			var disc: TextureRect = cell_data.disc
			var val: int = board[r][c]
			if val == BLACK:
				disc.texture = black_disc_tex
			elif val == WHITE:
				disc.texture = white_disc_tex
			else:
				disc.texture = null

func _refresh_legal_hints() -> void:
	var human_turn: bool = not game_over and not (game_mode == Mode.PLAYER_VS_AI and current_player == AI_PLAYER)
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var cell_data: Dictionary = cells[r][c]
			var bg: ColorRect = cell_data.bg
			if human_turn and board[r][c] == EMPTY and _is_legal_move(r, c, current_player):
				bg.color = CELL_HINT_COLOR
			else:
				bg.color = CELL_COLOR

func _advance_turn() -> void:
	current_player = _get_opponent(current_player)
	_update_ui_state()
	
	if game_over: return

	if not _has_any_legal_moves(current_player):
		status_label.text = tr("STATUS_SKIP") % _display_name(current_player)
		if playtest_log:
			playtest_log.record_skip()
		if is_inside_tree():
			await get_tree().create_timer(1.0).timeout
		current_player = _get_opponent(current_player)
		if not _has_any_legal_moves(current_player):
			_end_game()
			return
		_update_ui_state()

	if game_mode == Mode.PLAYER_VS_AI and current_player == WHITE:
		status_label.text = tr("STATUS_THINKING")
		if is_inside_tree():
			await get_tree().create_timer(0.8).timeout
		_ai_move()

func _ai_move() -> void:
	var best_move: Vector2i = _get_best_move()
	if best_move == NO_MOVE:
		_advance_turn()
		return
	_execute_move(best_move.x, best_move.y, AI_PLAYER)
	_advance_turn()

func _get_best_move() -> Vector2i:
	var diff: int = game_difficulty
	var max_depth: int = _match_difficulty(diff)
	
	if diff == Difficulty.HARD:
		return _get_best_move_iterative_deepening(max_depth)
	
	var best_score = -999999
	var best_move: Vector2i = NO_MOVE
	var alpha = -1000000
	var beta = 1000000
	
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if _is_legal_move(r, c, AI_PLAYER):
				var original_board = []
				for row in board: original_board.append(row.duplicate())
				
				_execute_move(r, c, AI_PLAYER)
				var score = _minimax(max_depth - 1, alpha, beta, false)
				
				board = original_board
				
				if score > best_score:
					best_score = score
					best_move = Vector2i(r, c)
				
				alpha = max(alpha, score)
				if beta <= alpha:
					break
					
	return best_move

func _get_best_move_iterative_deepening(max_depth: int) -> Vector2i:
	var start_time: int = Time.get_ticks_msec()
	var time_budget: int = TIME_BUDGET_HARD
	
	var best_move: Vector2i = NO_MOVE
	
	var greedy_move: Vector2i = _get_greedy_move()
	if greedy_move != NO_MOVE:
		best_move = greedy_move
	
	for depth in range(2, max_depth + 1):
		var elapsed: int = Time.get_ticks_msec() - start_time
		if elapsed >= time_budget:
			break
		
		var depth_best_move: Vector2i = NO_MOVE
		var depth_best_score: int = -999999
		var alpha = -1000000
		var beta = 1000000
		
		for r in range(BOARD_SIZE):
			for c in range(BOARD_SIZE):
				if _is_legal_move(r, c, AI_PLAYER):
					var original_board = []
					for row in board: original_board.append(row.duplicate())
					
					_execute_move(r, c, AI_PLAYER)
					var score = _minimax_timed(depth - 1, alpha, beta, false, start_time, time_budget)
					
					board = original_board
					
					if Time.get_ticks_msec() - start_time >= time_budget:
						break
					
					if score > depth_best_score:
						depth_best_score = score
						depth_best_move = Vector2i(r, c)
					
					alpha = max(alpha, score)
					if beta <= alpha:
						break
		
		if depth_best_move != NO_MOVE and Time.get_ticks_msec() - start_time < time_budget:
			best_move = depth_best_move
		else:
			break
	
	return best_move

func _get_greedy_move() -> Vector2i:
	var best_score: int = -100000000
	var best: Vector2i = NO_MOVE
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if _is_legal_move(r, c, WHITE):
				var original: Array = []
				for row in board: original.append(row.duplicate())
				_execute_move(r, c, WHITE)
				var score: int = _evaluate_board()
				board = original
				if score > best_score:
					best_score = score
					best = Vector2i(r, c)
	return best

func _minimax_timed(depth: int, alpha: int, beta: int, maximizing: bool, start_time: int, time_budget: int) -> int:
	if Time.get_ticks_msec() - start_time >= time_budget:
		return _evaluate_board()
	
	if depth == 0:
		return _evaluate_board()
	
	var player = AI_PLAYER if maximizing else BLACK
	var moves = _get_all_legal_moves(player)
	
	if moves.size() == 0:
		if _has_any_legal_moves(_get_opponent(player)):
			return _minimax_timed(depth - 1, alpha, beta, !maximizing, start_time, time_budget)
		else:
			return _evaluate_board()
	
	if maximizing:
		var max_eval = -1000000
		for move in moves:
			var original_board = []
			for row in board: original_board.append(row.duplicate())
			_execute_move(move.x, move.y, player)
			var eval = _minimax_timed(depth - 1, alpha, beta, false, start_time, time_budget)
			board = original_board
			max_eval = max(max_eval, eval)
			alpha = max(alpha, eval)
			if beta <= alpha: break
		return max_eval
	else:
		var min_eval = 1000000
		for move in moves:
			var original_board = []
			for row in board: original_board.append(row.duplicate())
			_execute_move(move.x, move.y, player)
			var eval = _minimax_timed(depth - 1, alpha, beta, true, start_time, time_budget)
			board = original_board
			min_eval = min(min_eval, eval)
			beta = min(beta, eval)
			if beta <= alpha: break
		return min_eval

func _minimax(depth: int, alpha: int, beta: int, maximizing: bool) -> int:
	if depth == 0:
		return _evaluate_board()
	
	var player = AI_PLAYER if maximizing else BLACK
	var moves = _get_all_legal_moves(player)
	
	if moves.size() == 0:
		if _has_any_legal_moves(_get_opponent(player)):
			return _minimax(depth - 1, alpha, beta, !maximizing)
		else:
			return _evaluate_board()
	
	if maximizing:
		var max_eval = -1000000
		for move in moves:
			var original_board = []
			for row in board: original_board.append(row.duplicate())
			_execute_move(move.x, move.y, player)
			var eval = _minimax(depth - 1, alpha, beta, false)
			board = original_board
			max_eval = max(max_eval, eval)
			alpha = max(alpha, eval)
			if beta <= alpha: break
		return max_eval
	else:
		var min_eval = 1000000
		for move in moves:
			var original_board = []
			for row in board: original_board.append(row.duplicate())
			_execute_move(move.x, move.y, player)
			var eval = _minimax(depth - 1, alpha, beta, true)
			board = original_board
			min_eval = min(min_eval, eval)
			beta = min(beta, eval)
			if beta <= alpha: break
		return min_eval

func _get_all_legal_moves(player: int) -> Array:
	var moves: Array = []
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if _is_legal_move(r, c, player):
				moves.append(Vector2i(r, c))
	return moves

func _evaluate_board() -> int:
	var score = 0
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			var val = board[r][c]
			if val == WHITE:
				score += 10
				if (r == 0 or r == 7) and (c == 0 or c == 7): score += 100
				elif r == 0 or r == 7 or c == 0 or c == 7: score += 5
			elif val == BLACK:
				score -= 10
				if (r == 0 or r == 7) and (c == 0 or c == 7): score -= 100
				elif r == 0 or r == 7 or c == 0 or c == 7: score -= 5
	
	score += _get_mobility(WHITE) * 2
	score -= _get_mobility(BLACK) * 2
	return score

func _get_mobility(player: int) -> int:
	var moves = 0
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if _is_legal_move(r, c, player):
				moves += 1
	return moves

func _has_any_legal_moves(player: int) -> bool:
	return _get_all_legal_moves(player).size() > 0

func _end_game() -> void:
	game_over = true
	var b: int = 0
	var w: int = 0
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if board[r][c] == BLACK: b += 1
			elif board[r][c] == WHITE: w += 1
	var winner: String = tr("WINNER_DRAW")
	if b > w: winner = tr("WINNER_BLACK")
	elif w > b: winner = tr("WINNER_WHITE")
	status_label.text = tr("STATUS_GAME_OVER") % [winner, b, w]
	if playtest_log:
		playtest_log.record_game_over(winner, b, w)
		playtest_log.write_report()
	
	if b > w:
		if audio_win and audio_win.stream:
			audio_win.play()
	elif w > b:
		if audio_lose and audio_lose.stream:
			audio_lose.play()
	else:
		if audio_win and audio_win.stream:
			audio_win.play()
	
	_refresh_legal_hints()

func _update_ui_state() -> void:
	var b: int = 0
	var w: int = 0
	for r in range(BOARD_SIZE):
		for c in range(BOARD_SIZE):
			if board[r][c] == BLACK: b += 1
			elif board[r][c] == WHITE: w += 1
			
	black_score_label.text = tr("SCORE_BLACK") % b
	white_score_label.text = tr("SCORE_WHITE") % w
	turn_label.text = tr("TURN_LABEL") % _display_name(current_player)
	if not game_over:
		if game_mode == Mode.PLAYER_VS_AI and current_player == WHITE:
			status_label.text = tr("STATUS_THINKING")
		else:
			status_label.text = tr("STATUS_YOUR_TURN")
	else:
		pass
	_refresh_legal_hints()

func _match_difficulty(diff: Difficulty) -> int:
	match diff:
		Difficulty.EASY: return 1
		Difficulty.MEDIUM: return 3
		Difficulty.HARD: return 5
		_: return 3