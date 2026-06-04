extends Node3D
class_name Weapon
## Generic weapon driven by a WeaponData resource. Supports hitscan and
## projectile firing, with muzzle/impact feedback.

@export var data: WeaponData

signal ammo_changed(in_mag: int, reserve: int)
signal reload_changed(is_reloading: bool)

var _in_mag: int = 0
var _reserve: int = 0
var _can_fire: bool = true
var _reloading: bool = false
var _view_model: Node3D = null
var _base_transform: Transform3D
var _anim_tween: Tween

func _ready() -> void:
	if data == null:
		push_warning("Weapon has no WeaponData assigned")
		return
	_in_mag = data.mag_size
	_reserve = data.reserve_ammo
	_spawn_view_model()
	ammo_changed.emit(_in_mag, _reserve)

func _spawn_view_model() -> void:
	if data.view_model != null:
		_view_model = data.view_model.instantiate()
		add_child(_view_model)
	else:
		_view_model = get_node_or_null("Model")
	if _view_model != null:
		_base_transform = _view_model.transform

func is_automatic() -> bool:
	return data != null and data.automatic

func get_ammo() -> Vector2i:
	return Vector2i(_in_mag, _reserve)

func is_reloading() -> bool:
	return _reloading

func try_fire() -> void:
	if data == null or _reloading or not _can_fire:
		return
	if _in_mag <= 0:
		reload()
		return
	_can_fire = false
	_in_mag -= 1
	ammo_changed.emit(_in_mag, _reserve)
	_spawn_muzzle_flash()
	_play_fire_animation()
	if data.projectile and data.projectile_scene != null:
		_spawn_projectile()
	else:
		var hit_point := _do_hitscan()
		_spawn_tracer(global_position, hit_point)
	get_tree().create_timer(1.0 / maxf(data.fire_rate, 0.01)).timeout.connect(
		func() -> void: _can_fire = true)

func _spawn_projectile() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var direction := (-cam.global_transform.basis.z).normalized()
	var projectile := data.projectile_scene.instantiate() as Node3D
	if projectile == null:
		return
	if projectile.has_method("setup"):
		projectile.setup(direction, data.damage, data.max_range, data.projectile_speed, data.muzzle_color)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position + direction * 0.35
	projectile.look_at(projectile.global_position + direction, Vector3.UP)

## Raycasts from the camera; damages a hit orc and returns the impact point
## (or the far end of the ray on a miss) for the tracer.
func _do_hitscan() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return global_position
	var from := cam.global_position
	var to := from + (-cam.global_transform.basis.z) * data.max_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 4   # world + enemies
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return to
	var collider = hit.get("collider")
	if collider != null and collider.has_method("take_damage"):
		collider.take_damage(data.damage)
		GameState.notify_hit_confirmed()
	var point: Vector3 = hit.get("position", to)
	_spawn_impact(point)
	return point

func reload() -> void:
	if data == null or _reloading:
		return
	if _in_mag >= data.mag_size or _reserve <= 0:
		return
	_reloading = true
	reload_changed.emit(true)
	_play_reload_animation()
	await get_tree().create_timer(data.reload_time).timeout
	var needed: int = data.mag_size - _in_mag
	var take: int = mini(needed, _reserve)
	_in_mag += take
	_reserve -= take
	_reloading = false
	reload_changed.emit(false)
	ammo_changed.emit(_in_mag, _reserve)

func refill_ammo() -> void:
	if data == null:
		return
	_reserve = data.reserve_ammo
	_in_mag = data.mag_size
	ammo_changed.emit(_in_mag, _reserve)

# --- Fire feedback ---------------------------------------------------------

func _play_fire_animation() -> void:
	if _view_model != null:
		if _anim_tween != null and _anim_tween.is_valid():
			_anim_tween.kill()
		_view_model.transform = _base_transform
		
		_anim_tween = create_tween()
		_anim_tween.tween_property(_view_model, "position:z", 0.15, 0.05).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_anim_tween.parallel().tween_property(_view_model, "rotation_degrees:x", 8.0, 0.05).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_anim_tween.chain().tween_property(_view_model, "position:z", -0.15, 0.15).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_anim_tween.parallel().tween_property(_view_model, "rotation_degrees:x", -8.0, 0.15).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _play_reload_animation() -> void:
	if _view_model != null:
		if _anim_tween != null and _anim_tween.is_valid():
			_anim_tween.kill()
		_view_model.transform = _base_transform

		_anim_tween = create_tween()
		var r_time := data.reload_time
		_anim_tween.tween_property(_view_model, "rotation_degrees:x", 45.0, r_time * 0.3).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_anim_tween.tween_interval(r_time * 0.4)
		_anim_tween.tween_property(_view_model, "rotation_degrees:x", -45.0, r_time * 0.3).as_relative().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _spawn_muzzle_flash() -> void:
	var light := OmniLight3D.new()
	light.light_color = data.muzzle_color
	light.light_energy = 3.0
	light.omni_range = 4.0
	add_child(light)
	light.position = Vector3(0, 0, -0.3)
	_despawn(light, 0.05)

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)
	if dist < 0.2:
		return
	var tracer := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.02
	mesh.bottom_radius = 0.02
	mesh.height = dist
	tracer.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.muzzle_color
	mat.emission_enabled = true
	mat.emission = data.muzzle_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer.material_override = mat
	get_tree().current_scene.add_child(tracer)
	tracer.global_position = (from + to) * 0.5
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	tracer.look_at(to, up)
	tracer.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	_despawn(tracer, 0.06)

func _spawn_impact(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.light_color = data.muzzle_color
	light.light_energy = 2.0
	light.omni_range = 2.0
	get_tree().current_scene.add_child(light)
	light.global_position = pos
	_despawn(light, 0.05)

func _despawn(node: Node, t: float) -> void:
	get_tree().create_timer(t).timeout.connect(node.queue_free)
