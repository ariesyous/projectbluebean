extends Node3D
## Fast visible projectile used by the Fire Staff. Movement is ray-stepped so
## the bolt remains reliable even when frame time spikes.

var damage: float = 30.0
var speed: float = 28.0
var max_range: float = 100.0
var _direction: Vector3 = Vector3.ZERO
var _distance_travelled: float = 0.0
var _bolt_color: Color = Color(1.0, 0.45, 0.1)

@onready var mesh: MeshInstance3D = $Mesh
@onready var light: OmniLight3D = $Light

func setup(direction: Vector3, shot_damage: float, shot_range: float, shot_speed: float, color: Color) -> void:
	_direction = direction.normalized()
	damage = shot_damage
	max_range = shot_range
	speed = shot_speed
	_bolt_color = color

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _bolt_color
	mat.emission_enabled = true
	mat.emission = _bolt_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	light.light_color = _bolt_color

func _physics_process(delta: float) -> void:
	if _direction == Vector3.ZERO:
		queue_free()
		return
	var step := minf(speed * delta, max_range - _distance_travelled)
	if step <= 0.0:
		queue_free()
		return

	var from := global_position
	var to := from + _direction * step
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 4   # world + enemies
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_distance_travelled += step
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
	flash.light_color = _bolt_color
	flash.light_energy = 3.5
	flash.omni_range = 2.2
	get_tree().current_scene.add_child(flash)
	flash.global_position = pos
	get_tree().create_timer(0.08).timeout.connect(flash.queue_free)
