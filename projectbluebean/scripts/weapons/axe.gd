extends Weapon
## Throwing Axe: a heavy throwable weapon that arcs due to gravity.

const OVERHAND_UP_BIAS := 0.18
const THROW_RIGHT_OFFSET := 0.22
const THROW_DOWN_OFFSET := -0.12

func _ready() -> void:
	if data == null:
		data = load("res://resources/weapons/axe.tres")
	super()

func _spawn_projectile() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or data == null or data.projectile_scene == null:
		return
	var forward := (-cam.global_transform.basis.z).normalized()
	var direction := (forward + Vector3.UP * OVERHAND_UP_BIAS).normalized()
	var projectile := data.projectile_scene.instantiate() as Node3D
	if projectile == null:
		return
	if projectile.has_method("setup"):
		projectile.setup(direction, data.damage, data.max_range, data.projectile_speed, data.muzzle_color)
	get_tree().current_scene.add_child(projectile)
	var spawn_pos := cam.global_position + forward * 0.55 \
		+ cam.global_transform.basis.x * THROW_RIGHT_OFFSET \
		+ Vector3.UP * THROW_DOWN_OFFSET
	projectile.global_position = spawn_pos
	projectile.look_at(projectile.global_position + direction, Vector3.UP)
