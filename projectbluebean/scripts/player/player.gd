extends CharacterBody3D
## First-person player: movement, mouse-look, health/regen, interaction, and
## weapon control. Lives in the "player" group so orcs can target it.

@export var move_speed: float = 5.5
@export var jump_velocity: float = 4.8
@export var mouse_sensitivity: float = 0.0025
@export var max_health: float = 100.0
@export var health_regen_delay: float = 5.0   ## seconds after last hit before regen
@export var health_regen_rate: float = 25.0   ## hp per second once regen starts

signal health_changed(current: float, maximum: float)
signal weapon_changed(weapon: Node)
signal interact_target_changed(target)  ## the interactable Node, or null

var health: float
var _time_since_damage: float = 999.0
var _current_weapon: Node = null
var _current_interactable = null

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var weapon_holder: Node3D = $Head/Camera3D/WeaponHolder
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay

func _ready() -> void:
	add_to_group("player")
	health = max_health
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if weapon_holder.get_child_count() > 0:
		_current_weapon = weapon_holder.get_child(0)
	weapon_changed.emit(_current_weapon)
	health_changed.emit(health, max_health)
	GameState.player_died.connect(_on_player_died)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	if event.is_action_pressed("pause"):
		_toggle_mouse()
		return
	if GameState.is_game_over:
		return
	if event.is_action_pressed("fire"):
		# If the cursor was freed (alt-tab / pause), the first click just
		# re-captures it instead of also firing.
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif _current_weapon != null and _current_weapon.has_method("try_fire") \
				and not _current_weapon.is_automatic():
			_current_weapon.try_fire()
	elif event.is_action_pressed("reload") and _current_weapon != null \
			and _current_weapon.has_method("reload"):
		_current_weapon.reload()

func _toggle_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	if GameState.is_game_over:
		return
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

## Swap the held weapon. `weapon_scene` is a PackedScene of a Weapon.
func equip_weapon(weapon_scene: PackedScene) -> void:
	for c in weapon_holder.get_children():
		c.queue_free()
	var w: Node = weapon_scene.instantiate()
	weapon_holder.add_child(w)
	_current_weapon = w
	weapon_changed.emit(w)

func _on_player_died() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
