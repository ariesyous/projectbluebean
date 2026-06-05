extends Buyable
## Buyable door: on purchase the barrier collider is freed immediately (so the
## path opens at once) and the door model swings open on a hinge with a heavy
## thunk before the whole node frees. The navmesh already spans the doorway, so
## orcs and the player can pass once the barrier is gone.

func _configure() -> void:
	cost = 1000
	prompt_label = "Open Door"
	one_time = true

func _on_purchased(_player: Node) -> void:
	var barrier := get_node_or_null("Barrier")
	if barrier == null:
		queue_free()
		return
	# Open the path right away, then play the swing for flavour.
	var col := barrier.get_node_or_null("BarrierCol")
	if col != null:
		col.set_deferred("disabled", true)
	var door := barrier.get_node_or_null("DoorModel") as Node3D
	if door == null:
		queue_free()
		return
	_play_open_sound()
	# Re-hinge the door at its left edge so it swings like a real door instead of
	# spinning about its centre.
	var pivot := Node3D.new()
	barrier.add_child(pivot)
	pivot.global_position = door.global_position + Vector3(-2.0, 0.0, 0.0)
	door.reparent(pivot, true)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(pivot, "rotation:y", -PI * 0.6, 0.8)
	tween.tween_callback(queue_free)

func _play_open_sound() -> void:
	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = load("res://assets/sounds/impact.wav")
	get_tree().current_scene.add_child(sfx)
	sfx.global_position = global_position
	sfx.play()
	get_tree().create_timer(1.5).timeout.connect(sfx.queue_free)
