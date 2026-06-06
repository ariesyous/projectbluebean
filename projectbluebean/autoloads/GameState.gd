extends Node
## Global run state + cross-system signals. Autoloaded as "GameState".

signal player_died
signal round_changed(round_number: int)
signal round_status_changed(round_number: int, enemies_remaining: int, between_round: bool, seconds_left: float)
signal hit_confirmed
signal game_restarted

var current_round: int = 0
var enemies_remaining: int = 0
var is_between_round: bool = false
var round_countdown: float = 0.0
var is_game_over: bool = false
var high_score_round: int = 0

const SAVE_PATH := "user://save.dat"

func _ready() -> void:
	_load_high_score()

func _load_high_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			high_score_round = file.get_32()

func _save_high_score() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(high_score_round)

func reset() -> void:
	current_round = 0
	enemies_remaining = 0
	is_between_round = false
	round_countdown = 0.0
	is_game_over = false
	round_status_changed.emit(current_round, enemies_remaining, is_between_round, round_countdown)
	game_restarted.emit()

func notify_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true
	if current_round > high_score_round:
		high_score_round = current_round
		_save_high_score()
	player_died.emit()

func notify_hit_confirmed() -> void:
	hit_confirmed.emit()

func set_round(n: int) -> void:
	current_round = n
	round_changed.emit(n)

func set_round_status(remaining: int, between_round: bool, seconds_left: float = 0.0) -> void:
	enemies_remaining = max(remaining, 0)
	is_between_round = between_round
	round_countdown = max(seconds_left, 0.0)
	round_status_changed.emit(current_round, enemies_remaining, is_between_round, round_countdown)
