extends CharacterBody3D
## First-person player: movement, mouse-look, health/regen, interaction, and
## weapon control. Lives in the "player" group so orcs can target it.

@export var move_speed: float = 5.5
@export var jump_velocity: float = 4.8
@export var mouse_sensitivity: float = 0.0025
@export var max_health: float = 100.0
@export var health_regen_delay: float = 5.0   ## seconds after last hit before regen
@export var health_regen_rate: float = 25.0   ## hp per second once regen starts
@export var melee_damage: float = 55.0
@export var melee_range: float = 2.2
@export var melee_cooldown: float = 0.65

## Weapon feel polish
@export var sway_amount: float = 2.5
@export var sway_lerp: float = 5.0
@export var bob_frequency: float = 2.4
@export var bob_amplitude: float = 0.06

const STAMINA_SPEED_MULT := 1.35       ## Stamin-Up: faster movement
const SPEED_COLA_RELOAD_MULT := 0.5    ## Speed Cola: reload_time multiplier (<1 = faster)
const DOUBLE_TAP_FIRE_MULT := 1.5      ## Double Tap: fire_rate multiplier (>1 = faster)

signal health_changed(current: float, maximum: float)
signal weapon_changed(weapon: Node)
signal interact_target_changed(target)  ## the interactable Node, or null
signal perks_changed(perk_ids: Array)   ## owned perk ids, for the HUD

var health: float
var _time_since_damage: float = 999.0
var _current_weapon: Node = null
var _current_weapon_slot: int = -1
var _weapon_slots: Array[Node3D] = []
var _weapon_scene_paths: Array[String] = []
var _current_interactable = null
var _melee_timer: float = 0.0
var _mouse_input: Vector2 = Vector2.ZERO
var _bob_time: float = 0.0

## Perk modifiers (1.0 = no perk). Weapons read these so future weapons benefit too.
var fire_rate_mult: float = 1.0
var reload_time_mult: float = 1.0
var _perks: Dictionary = {}

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_holder: Node3D = $Head/Camera3D/WeaponHolder
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var _initial_weapon_holder_pos: Vector3 = weapon_holder.position

func _ready() -> void:
	add_to_group("player")
	health = max_health
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_register_starting_weapons()
	health_changed.emit(health, max_health)
	GameState.player_died.connect(_on_player_died)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_mouse_input = event.relative
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	if event.is_action_pressed("pause"):
		_toggle_mouse()
		return
	if GameState.is_game_over:
		return
	if event.is_action_pressed("weapon_1"):
		_switch_weapon_slot(0)
	elif event.is_action_pressed("weapon_2"):
		_switch_weapon_slot(1)
	elif event.is_action_pressed("weapon_3"):
		_switch_weapon_slot(2)
	elif event.is_action_pressed("melee"):
		_try_melee()
	elif event.is_action_pressed("reload") and _current_weapon != null \
			and _current_weapon.has_method("reload"):
		_current_weapon.reload()
	elif event.is_action_pressed("fire"):
		# If the cursor was freed (alt-tab / pause), the first click just
		# re-captures it instead of also firing.
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif _current_weapon != null and _current_weapon.has_method("try_fire") \
				and not _current_weapon.is_automatic():
			_current_weapon.try_fire()

func _register_starting_weapons() -> void:
	_weapon_slots.clear()
	_weapon_scene_paths.clear()
	for child in weapon_holder.get_children():
		var weapon := child as Node3D
		if weapon == null:
			continue
		_weapon_slots.append(weapon)
		_weapon_scene_paths.append(weapon.scene_file_path)
	if not _weapon_slots.is_empty():
		_switch_weapon_slot(0)
	else:
		weapon_changed.emit(null)

func _switch_weapon_slot(slot: int) -> void:
	if slot < 0 or slot >= _weapon_slots.size():
		return
	var weapon := _weapon_slots[slot]
	if weapon == null or not is_instance_valid(weapon):
		return
	_current_weapon_slot = slot
	_current_weapon = weapon
	for i in _weapon_slots.size():
		if _weapon_slots[i] != null and is_instance_valid(_weapon_slots[i]):
			_weapon_slots[i].visible = i == _current_weapon_slot
	weapon_changed.emit(_current_weapon)

func _find_weapon_slot(scene_path: String) -> int:
	for i in _weapon_scene_paths.size():
		if _weapon_scene_paths[i] == scene_path:
			return i
	return -1

func _add_or_refill_weapon(weapon_scene: PackedScene) -> int:
	var scene_path := weapon_scene.resource_path
	var slot := _find_weapon_slot(scene_path)
	var weapon := weapon_scene.instantiate() as Node3D
	if weapon == null:
		return -1
	if slot == -1:
		weapon_holder.add_child(weapon)
		_weapon_slots.append(weapon)
		_weapon_scene_paths.append(scene_path)
		return _weapon_slots.size() - 1
	var old_weapon := _weapon_slots[slot]
	if old_weapon != null and is_instance_valid(old_weapon):
		weapon_holder.remove_child(old_weapon)
		old_weapon.queue_free()
	weapon_holder.add_child(weapon)
	weapon_holder.move_child(weapon, slot)
	_weapon_slots[slot] = weapon
	_weapon_scene_paths[slot] = scene_path
	return slot

func _try_melee() -> void:
	if _melee_timer > 0.0:
		return
	_melee_timer = melee_cooldown
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z) * melee_range
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 4   # world + enemies
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_spawn_melee_feedback(to, false)
		return
	var point: Vector3 = hit.get("position", to)
	var collider = hit.get("collider")
	if collider != null and collider.has_method("take_damage"):
		collider.take_damage(melee_damage)
		GameState.notify_hit_confirmed()
		_spawn_melee_feedback(point, true)
	else:
		_spawn_melee_feedback(point, false)

func _spawn_melee_feedback(pos: Vector3, hit_enemy: bool) -> void:
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.35, 0.15) if hit_enemy else Color(0.8, 0.8, 0.8)
	light.light_energy = 2.4 if hit_enemy else 1.2
	light.omni_range = 1.4
	get_tree().current_scene.add_child(light)
	light.global_position = pos
	get_tree().create_timer(0.06).timeout.connect(light.queue_free)

func _toggle_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if GameState.is_game_over:
		return
	_melee_timer = maxf(_melee_timer - delta, 0.0)
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
	move_and_slide()

	_handle_weapon_input()
	_update_interaction()
	_update_health_regen(delta)
	_update_weapon_visuals(delta)

func _update_weapon_visuals(delta: float) -> void:
	if weapon_holder == null:
		return
	
	# 1. Weapon Sway (Mouse)
	var sway_target_rotation := Vector3(
		_mouse_input.y * sway_amount * 0.001,
		_mouse_input.x * sway_amount * 0.001,
		0.0
	)
	weapon_holder.rotation.x = lerp_angle(weapon_holder.rotation.x, sway_target_rotation.x, delta * sway_lerp)
	weapon_holder.rotation.y = lerp_angle(weapon_holder.rotation.y, sway_target_rotation.y, delta * sway_lerp)
	_mouse_input = Vector2.ZERO # Reset for next frame
	
	# 2. Weapon Bob (Movement)
	var speed := velocity.length()
	if is_on_floor() and speed > 0.1:
		_bob_time += delta * speed * bob_frequency
	else:
		_bob_time = lerp(_bob_time, 0.0, delta * 10.0)
	
	var bob_offset := Vector3(
		cos(_bob_time * 0.5) * bob_amplitude * 0.5,
		abs(sin(_bob_time)) * -bob_amplitude,
		0.0
	)
	
	var target_pos := _initial_weapon_holder_pos + bob_offset
	weapon_holder.position = weapon_holder.position.lerp(target_pos, delta * 10.0)

func _handle_weapon_input() -> void:
	if _current_weapon == null:
		return
# Automatic weapons fire while the button is held; semi-auto fire is handled
# per-click in _unhandled_input.
	if _current_weapon.has_method("try_fire") and _current_weapon.is_automatic() \
			and Input.is_action_pressed("fire"):
		_current_weapon.try_fire()

func _update_interaction() -> void:
	var target = null
	if interact_ray.is_colliding():
		var collider = interact_ray.get_collider()
		if collider and collider.is_in_group("interactable"):
			target = collider
	if target != _current_interactable:
		_current_interactable = target
		interact_target_changed.emit(target)
	if _current_interactable != null and Input.is_action_just_pressed("interact"):
		if _current_interactable.has_method("interact"):
			_current_interactable.interact(self)

func _update_health_regen(delta: float) -> void:
	_time_since_damage += delta
	if _time_since_damage >= health_regen_delay and health < max_health:
		health = min(max_health, health + health_regen_rate * delta)
		health_changed.emit(health, max_health)

func take_damage(amount: float) -> void:
	if GameState.is_game_over:
		return
	health -= amount
	_time_since_damage = 0.0
	health_changed.emit(health, max_health)
	if health <= 0.0:
		health = 0.0
		GameState.notify_player_died()

## Add/refill a weapon, then switch to that slot. `weapon_scene` is a PackedScene of a Weapon.
func equip_weapon(weapon_scene: PackedScene) -> void:
	var slot := _add_or_refill_weapon(weapon_scene)
	if slot != -1:
		_switch_weapon_slot(slot)

## Perks (fantasy reskin of the Zombies perk-a-colas). One-time per shrine;
## they reset naturally on scene reload since the player is rebuilt.
func has_perk(perk_id: String) -> bool:
	return _perks.has(perk_id)

func grant_perk(perk_id: String) -> void:
	if _perks.has(perk_id):
		return
	_perks[perk_id] = true
	match perk_id:
		"stamina":
			move_speed *= STAMINA_SPEED_MULT
		"speed_cola":
			reload_time_mult = SPEED_COLA_RELOAD_MULT
		"double_tap":
			fire_rate_mult = DOUBLE_TAP_FIRE_MULT
	perks_changed.emit(_perks.keys())

func _on_player_died() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
