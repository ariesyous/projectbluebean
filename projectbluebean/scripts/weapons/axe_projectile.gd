extends Node3D

var damage: float = 65.0
var _velocity: Vector3 = Vector3.ZERO
var _distance_travelled: float = 0.0
var max_range: float = 100.0
var gravity: float = 18.0

@onready var model: Node3D = $Model

func setup(direction: Vector3, shot_damage: float, shot_range: float, shot_speed: float, _color: Color) -> void:
	_velocity = direction.normalized() * shot_speed
	damage = shot_damage
	max_range = shot_range

func _physics_process(delta: float) -> void:
	if _velocity == Vector3.ZERO:
		queue_free()
		return
	
	_velocity.y -= gravity * delta
	var step_vec := _velocity * delta
	var step_dist := step_vec.length()
	
	if _distance_travelled + step_dist > max_range:
		queue_free()
		return

	var from := global_position
	var to := from + step_vec
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 4   # world + enemies
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_distance_travelled += step_dist
		if model != null:
			model.rotate_x(18.0 * delta)
		return

	var point: Vector3 = hit.get("position", to)
	var collider = hit.get("collider")
	if collider != null and collider.has_method("take_damage"):
		collider.take_damage(damage)
		GameState.notify_hit_confirmed()
	_spawn_impact(point)
	queue_free()

func _spawn_impact(pos: Vector3) -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.8, 0.8, 0.8)
	flash.light_energy = 2.0
	flash.omni_range = 1.5
	get_tree().current_scene.add_child(flash)
	flash.global_position = pos
	get_tree().create_timer(0.08).timeout.connect(flash.queue_free)
