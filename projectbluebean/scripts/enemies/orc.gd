extends CharacterBody3D
class_name Orc
## Navigates toward the player via NavigationAgent3D, melee-attacks on contact,
## plays goblin animations, and awards points to the Economy on death.

const PUNCH_LEN := 0.75
const DEATH_LEN := 2.0

@export var max_health: float = 100.0
@export var move_speed: float = 3.2
@export var attack_damage: float = 15.0
@export var attack_range: float = 1.9
@export var attack_cooldown: float = 1.2
@export var point_reward: int = 60

var health: float
var _attack_timer: float = 0.0
var _player: Node3D = null
var _dead: bool = false
var _current_anim: String = ""

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _anim: AnimationPlayer = $GoblinModel/AnimationPlayer
@onready var _collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("orc")
	health = max_health
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = attack_range * 0.75
	for a in ["Idle", "Walk", "Run"]:
		var clip := _anim.get_animation(a)
		if clip != null:
			clip.loop_mode = Animation.LOOP_LINEAR
	_acquire_player()
	_play("Idle")

func _acquire_player() -> void:
	_player = get_tree().get_first_node_in_group("player")

## Switch looping/idle animation, ignoring repeat calls for the same clip.
func _play(anim: String) -> void:
	if _current_anim == anim:
		return
	_current_anim = anim
	if _anim.has_animation(anim):
		_anim.play(anim)

## Force-restart a one-shot clip (punch / death).
func _play_oneshot(anim: String) -> void:
	_current_anim = anim
	if _anim.has_animation(anim):
		_anim.play(anim)

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_attack_timer -= delta
	if GameState.is_game_over:
		_play("Idle")
		return
	if _player == null or not is_instance_valid(_player):
		_acquire_player()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	nav_agent.target_position = _player.global_position
	var dist := global_position.distance_to(_player.global_position)
	if dist <= attack_range:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		_face_toward(_player.global_position)
		if _attack_timer <= 0.0:
			_attack()
		elif _attack_timer < attack_cooldown - PUNCH_LEN:
			_play("Idle")
	else:
		var next_point := nav_agent.get_next_path_position()
		var dir := next_point - global_position
		dir.y = 0.0
		dir = dir.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		_face_toward(next_point)
		_play("Run")

	move_and_slide()

func _face_toward(target: Vector3) -> void:
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() > 0.05:
		look_at(global_position + flat, Vector3.UP)

func _attack() -> void:
	_attack_timer = attack_cooldown
	_play_oneshot("Punch")
	if _player != null and _player.has_method("take_damage"):
		_player.take_damage(attack_damage)

func take_damage(amount: float) -> void:
	if _dead:
		return
	health -= amount
	if health <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	remove_from_group("orc")
	Economy.add_points(point_reward)
	velocity = Vector3.ZERO
	_collision.disabled = true
	_play_oneshot("Death")
	await get_tree().create_timer(DEATH_LEN).timeout
	queue_free()
