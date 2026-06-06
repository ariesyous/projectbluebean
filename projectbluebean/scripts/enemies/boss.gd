extends CharacterBody3D
class_name Boss

signal boss_health_changed(current: float, max_h: float)

const PUNCH_LEN := 0.75
const DEATH_LEN := 2.0
const BARRICADE_COLLISION_LAYER := 16
const VAULT_DURATION := 0.65
const SPAWN_INTERVAL := 1.0

@export var max_health: float = 2000.0
@export var base_move_speed: float = 3.2
@export var attack_damage: float = 50.0
@export var attack_range: float = 2.5
@export var attack_cooldown: float = 1.5
@export var point_reward: int = 2500

var health: float
var move_speed: float
var _attack_timer: float = 0.0
var _player: Node3D = null
var _dead: bool = false
var _current_anim: String = ""
var _barricade_target: Node = null

var _phase: int = 1
var _is_summoning: bool = false
var _summon_count: int = 0
var _summon_timer: float = 0.0
var _vaulting: bool = false
var _vault_timer: float = 0.0
var _vault_start_pos: Vector3 = Vector3.ZERO
var _vault_end_pos: Vector3 = Vector3.ZERO
var _attack_audio: AudioStreamPlayer3D
var _hurt_audio: AudioStreamPlayer3D
var _death_audio: AudioStreamPlayer3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _anim: AnimationPlayer = $Viking_Male/AnimationPlayer
@onready var _collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("orc") # so arena counts it for round completion
	add_to_group("boss")
	collision_mask |= BARRICADE_COLLISION_LAYER
	
	# Scale health by round
	var round_scale := float(GameState.current_round) / 10.0
	max_health *= round_scale
	
	health = max_health
	move_speed = base_move_speed
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = attack_range * 0.75
	for a in ["Idle", "Walk", "Run", "Run_Carry"]:
		if _anim.has_animation(a):
			var clip := _anim.get_animation(a)
			clip.loop_mode = Animation.LOOP_LINEAR
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	
	_attack_audio = AudioStreamPlayer3D.new()
	_attack_audio.stream = preload("res://assets/orc_attack.wav")
	add_child(_attack_audio)
	_hurt_audio = AudioStreamPlayer3D.new()
	_hurt_audio.stream = preload("res://assets/orc_hurt.wav")
	add_child(_hurt_audio)
	_death_audio = AudioStreamPlayer3D.new()
	_death_audio.stream = preload("res://assets/orc_death.wav")
	add_child(_death_audio)

	_equip_weapon()
	_acquire_player()
	_play("Idle")
	
	call_deferred("_update_hud")

func _update_hud() -> void:
	# Inform HUD or anything listening
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("update_boss_health"):
		hud.update_boss_health(health, max_health)

func _acquire_player() -> void:
	_player = get_tree().get_first_node_in_group("player")

## Attaches a weapon mesh to the model's right-hand bone (Fist.R).
const WEAPON_SCENE := preload("res://assets/weapons/kaykit/axe_1handed.gltf")
const WEAPON_GRIP_POS := Vector3(0.0, -0.15, 0.0)
const WEAPON_GRIP_ROT := Vector3(180.0, 0.0, 0.0)
const WEAPON_GRIP_SCALE := 0.55

func _equip_weapon() -> void:
	var skel := _find_skeleton(self)
	if skel == null:
		return
	if skel.find_bone("Fist.R") == -1:
		return
	var attach := BoneAttachment3D.new()
	attach.name = "WeaponAttach"
	skel.add_child(attach)
	attach.bone_name = "Fist.R"
	var weapon := WEAPON_SCENE.instantiate() as Node3D
	attach.add_child(weapon)
	weapon.position = WEAPON_GRIP_POS
	weapon.rotation_degrees = WEAPON_GRIP_ROT
	weapon.scale = Vector3.ONE * WEAPON_GRIP_SCALE

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for c in node.get_children():
		var r := _find_skeleton(c)
		if r != null:
			return r
	return null

func _play(anim: String) -> void:
	if _current_anim == anim:
		return
	_current_anim = anim
	if _anim.has_animation(anim):
		_anim.play(anim)
	elif anim == "Run" and _anim.has_animation("Running_A"):
		_anim.play("Running_A")

func _play_oneshot(anim: String) -> void:
	_current_anim = anim
	if _anim.has_animation(anim):
		_anim.play(anim)
	elif anim == "Punch" and _anim.has_animation("1H_Melee_Attack_Chop"):
		_anim.play("1H_Melee_Attack_Chop")
	elif anim == "Death" and _anim.has_animation("Death_A"):
		_anim.play("Death_A")

func _physics_process(delta: float) -> void:
	if _dead:
		return
		
	if _is_summoning:
		velocity = Vector3.ZERO
		_summon_timer -= delta
		if _summon_timer <= 0.0:
			_spawn_minion()
			_summon_count -= 1
			if _summon_count <= 0:
				_is_summoning = false
			else:
				_summon_timer = SPAWN_INTERVAL
		move_and_slide()
		return
		
	if _vaulting:
		_vault_timer -= delta
		if _vault_timer <= 0.0:
			_vaulting = false
		else:
			var t := 1.0 - (_vault_timer / VAULT_DURATION)
			var current_pos := _vault_start_pos.lerp(_vault_end_pos, t)
			current_pos.y += sin(t * PI) * 1.35
			global_position = current_pos
			_face_toward(_vault_end_pos)
		return

	_attack_timer -= delta
	if GameState.is_game_over:
		_play("Idle")
		return
	if _barricade_target != null and is_instance_valid(_barricade_target):
		if _barricade_target.has_method("is_broken") and not _barricade_target.is_broken():
			_update_barricade_attack()
			return
		_start_vault(_barricade_target)
		_barricade_target = null
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
		_play("Run_Carry")

	if nav_agent.avoidance_enabled:
		nav_agent.velocity = velocity
	else:
		move_and_slide()

func _update_barricade_attack() -> void:
	velocity = Vector3.ZERO
	_face_toward(_barricade_target.global_position)
	if _attack_timer <= 0.0:
		_attack_timer = attack_cooldown
		_play_oneshot("SwordSlash")
		_barricade_target.damage_from_orc(self)

func _start_vault(barricade: Node) -> void:
	_vaulting = true
	_vault_timer = VAULT_DURATION
	_play_oneshot("Jump")
	_vault_start_pos = global_position
	_vault_end_pos = barricade.global_position + (barricade.global_transform.basis.z * -1.6)
	_vault_end_pos.y = global_position.y

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if _dead:
		return
	velocity = safe_velocity
	move_and_slide()

func _face_toward(target: Vector3) -> void:
	var flat := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if flat.length() > 0.05:
		look_at(global_position + flat, Vector3.UP)

func assign_barricade(barricade: Node) -> void:
	_barricade_target = barricade
	if barricade.has_method("is_broken") and barricade.is_broken():
		_start_vault(barricade)
		_barricade_target = null

func _attack() -> void:
	_attack_timer = attack_cooldown
	_play_oneshot("SwordSlash")
	_attack_audio.play()
	get_tree().create_timer(PUNCH_LEN * 0.5).timeout.connect(
		func() -> void:
			if _dead or GameState.is_game_over:
				return
			if _player == null or not is_instance_valid(_player):
				return
			var d := global_position.distance_to(_player.global_position)
			if d <= attack_range + 0.5:
				_player.take_damage(attack_damage)
	)

func take_damage(amount: float, hit_position: Variant = null, hit_normal: Vector3 = Vector3.ZERO) -> void:
	if _dead or _is_summoning:
		return
	health -= amount
	_hurt_audio.play()
	_update_hud()
	
	_check_phases()
	
	if health <= 0.0:
		_die()

func _check_phases() -> void:
	var pct := health / max_health
	if _phase == 1 and pct <= 0.75:
		_trigger_summon_phase(2)
	elif _phase == 2 and pct <= 0.50:
		_trigger_summon_phase(3)
	elif _phase == 3 and pct <= 0.25:
		_trigger_enrage_phase(4)

func _trigger_summon_phase(next_phase: int) -> void:
	_phase = next_phase
	_is_summoning = true
	_summon_count = 3
	_summon_timer = SPAWN_INTERVAL
	_play("Idle")

func _trigger_enrage_phase(next_phase: int) -> void:
	_phase = next_phase
	_is_summoning = true
	_summon_count = 5
	_summon_timer = SPAWN_INTERVAL
	move_speed = base_move_speed * 1.5
	attack_cooldown *= 0.6
	_play("Idle")

func _spawn_minion() -> void:
	var arena = get_tree().current_scene
	if arena.has_method("_spawn_orc_at"):
		arena._spawn_orc_at(global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))

func _die() -> void:
	_dead = true
	remove_from_group("orc")
	Economy.add_points(point_reward)
	_update_hud()
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("hide_boss_health"):
		hud.hide_boss_health()
	velocity = Vector3.ZERO
	_collision.disabled = true
	_play_oneshot("Death")
	_death_audio.play()
	await get_tree().create_timer(DEATH_LEN).timeout
	queue_free()
