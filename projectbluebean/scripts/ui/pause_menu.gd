extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$ColorRect/VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$ColorRect/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not GameState.is_game_over:
		_toggle_pause()

func _toggle_pause() -> void:
	var tree := get_tree()
	tree.paused = not tree.paused
	visible = tree.paused
	if tree.paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
