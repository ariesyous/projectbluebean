extends Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)
	$VBoxContainer/QuitButton.pressed.connect(get_tree().quit)
	$VBoxContainer/HighScoreLabel.text = "Highest Round: " + str(GameState.high_score_round)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world/Arena.tscn")
