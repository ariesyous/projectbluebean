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
var _audio_player: AudioStreamPlayer3D
var _player: Node = null
var upgraded: bool = false   ## true once Pack-a-Punched

func _ready() -> void:
	if data == null:
		push_warning("Weapon has no WeaponData assigned")
		return
	_in_mag = data.mag_size
	_reserve = data.reserve_ammo
	_spawn_view_model()
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)
	ammo_changed.emit(_in_mag, _reserve)

func _spawn_view_model() -> void:
	if data.view_model != null:
		_view_model = data.view_model.instantiate()
		add_child(_view_model)
	else:
		_view_model = get_node_or_null("Model")
	if _view_model != null:
		_base_transform = _view_model.transform

## Perk multipliers come from the player (set by perk shrines). Looked up
## lazily because starting weapons are _ready before the player joins its group.
func _get_player() -> Node:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	return _player

func _fire_rate_mult() -> float:
	var p := _get_player()
	if p == null:
		return 1.0
	var m = p.get("fire_rate_mult")
	return float(m) if m != null else 1.0

func _reload_time_mult() -> float:
	var p := _get_player()
	if p == null:
		return 1.0
	var m = p.get("reload_time_mult")
	return float(m) if m != null else 1.0

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
	if data.fire_sound != null:
		_audio_player.stream = data.fire_sound
		_audio_player.play()
	if data.projectile and data.projectile_scene != null:
		_spawn_projectile()
	else:
		var hit_point := _do_hitscan()
		_spawn_tracer(global_position, hit_point)
	get_tree().create_timer(1.0 / maxf(data.fire_rate * _fire_rate_mult(), 0.01)).timeout.connect(
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
	var point: Vector3 = hit.get("position", to)
	var normal: Vector3 = hit.get("normal", Vector3.ZERO)
	var collider = hit.get("collider")
	if collider != null and collider.has_method("take_damage"):
		collider.take_damage(data.damage, point, normal)
		GameState.notify_hit_confirmed()
	_spawn_impact(point)
	return point

func reload() -> void:
	if data == null or _reloading:
		return
	if _in_mag >= data.mag_size or _reserve <= 0:
		return
	_reloading = true
	reload_changed.emit(true)
	var rtime := data.reload_time * _reload_time_mult()
	_play_reload_animation(rtime)
	if data.reload_sound != null:
		_audio_player.stream = data.reload_sound
		_audio_player.play()
	await get_tree().create_timer(rtime).timeout
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

func is_upgraded() -> bool:
	return upgraded

## Pack-a-Punch: upgrade this weapon. Duplicates the WeaponData first so the
## shared .tres resource is never mutated, then boosts the copy.
func pack_a_punch() -> bool:
	if data == null or upgraded:
		return false
	data = data.duplicate()
	data.damage *= 2.0
	data.mag_size = int(round(data.mag_size * 1.5))
	data.reserve_ammo = int(round(data.reserve_ammo * 1.5))
	data.fire_rate *= 1.15
	data.display_name = data.display_name + " +"
	data.muzzle_color = Color(0.65, 0.4, 1.0)   ## upgraded glow (violet)
	upgraded = true
	refill_ammo()
	return true

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

func _play_reload_animation(r_time: float = -1.0) -> void:
	if _view_model != null:
		if _anim_tween != null and _anim_tween.is_valid():
			_anim_tween.kill()
		_view_model.transform = _base_transform

		if r_time < 0.0:
			r_time = data.reload_time
		_anim_tween = create_tween()
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

	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.amount = 12
	particles.lifetime = 0.3
	particles.one_shot = true
	particles.explosiveness = 1.0
	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 180.0
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 6.0
	pmat.gravity = Vector3(0, -9.8, 0)
	pmat.scale_min = 0.03
	pmat.scale_max = 0.08
	particles.process_material = pmat
	
	var pass_mat := StandardMaterial3D.new()
	pass_mat.albedo_color = data.muzzle_color
	pass_mat.emission_enabled = true
	pass_mat.emission = data.muzzle_color
	pass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := BoxMesh.new()
	mesh.material = pass_mat
	particles.draw_pass_1 = mesh
	
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	_despawn(particles, 0.4)

	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = load("res://assets/sounds/impact.wav")
	get_tree().current_scene.add_child(sfx)
	sfx.global_position = pos
	sfx.play()
	_despawn(sfx, 1.0)

func _despawn(node: Node, t: float) -> void:
	get_tree().create_timer(t).timeout.connect(node.queue_free)
