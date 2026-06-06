extends Node3D

var damage: float = 20.0
var speed: float = 12.0
var max_range: float = 100.0
var _direction: Vector3 = Vector3.ZERO
var _distance_travelled: float = 0.0
var _bolt_color: Color = Color(0.1, 0.9, 0.2)

@onready var mesh: MeshInstance3D = $Mesh
@onready var light: OmniLight3D = $Light

func setup(direction: Vector3, shot_damage: float) -> void:
	_direction = direction.normalized()
	damage = shot_damage

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
	query.collision_mask = 1 | 2   # world + player
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_distance_travelled += step
		return

	var point: Vector3 = hit.get("position", to)
	var collider = hit.get("collider")
	if collider != null and collider.has_method("take_damage") and collider.is_in_group("player"):
		collider.take_damage(damage)
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
	pass_mat.albedo_color = _bolt_color
	pass_mat.emission_enabled = true
	pass_mat.emission = _bolt_color
	pass_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh_shape := BoxMesh.new()
	mesh_shape.material = pass_mat
	particles.draw_pass_1 = mesh_shape
	
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	get_tree().create_timer(0.4).timeout.connect(particles.queue_free)

	var sfx := AudioStreamPlayer3D.new()
	sfx.stream = load("res://assets/sounds/impact.wav")
	get_tree().current_scene.add_child(sfx)
	sfx.global_position = pos
	sfx.play()
	get_tree().create_timer(1.0).timeout.connect(sfx.queue_free)
