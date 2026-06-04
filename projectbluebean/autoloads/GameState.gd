extends Node
## Global run state + cross-system signals. Autoloaded as "GameState".

signal player_died
signal round_changed(round_number: int)
signal game_restarted

var current_round: int = 0
var is_game_over: bool = false

func reset() -> void:
	current_round = 0
	is_game_over = false
	game_restarted.emit()

func notify_player_died() -> void:
	if is_game_over:
		return
	is_game_over = true
	player_died.emit()

func set_round(n: int) -> void:
	current_round = n
	round_changed.emit(n)
