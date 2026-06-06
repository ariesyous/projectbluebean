extends CharacterBody3D
class_name Brute

const PUNCH_LEN := 0.75
const DEATH_LEN := 2.0
const BARRICADE_COLLISION_LAYER := 16
const VAULT_DURATION := 0.65

@export var max_health: float = 250.0
@export var move_speed: float = 1.6
@export var attack_damage: float = 45.0
@export var attack_range: float = 1.8
@export var attack_cooldown: float = 2.0
@export var barricade_attack_range: float = 1.65
@export var barricade_attack_cooldown: float = 1.45
@export var point_reward: int = 200
@export var blood_color: Color = Color(0.2, 0.0, 0.0, 1.0) # Darker blood

var health: float
var _attack_timer: float = 0.0
var _player: Node3D = null
var _barricade_target: Node = null
var _dead: bool = false
var _current_anim: String = ""
var _vaulting: bool = false
var _vault_timer: float = 0.0
var _vault_start_pos: Vector3 = Vector3.ZERO
var _vault_end_pos: Vector3 = Vector3.ZERO
var _attack_audio: AudioStreamPlayer3D
var _hurt_audio: AudioStreamPlayer3D
var _death_audio: AudioStreamPlayer3D

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var _anim: AnimationPlayer = $Knight_Male/AnimationPlayer
@onready var _collision: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	add_to_group("orc")
	collision_mask |= BARRICADE_COLLISION_LAYER
	health = max_health
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

func assign_barricade(barricade: Node) -> void:
	_barricade_target = barricade
	if barricade.has_method("is_broken") and barricade.is_broken():
		_start_vault(barricade)
		_barricade_target = null

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
	if _player == null or not is_instance_valid(_player):
		_acquire_player()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if _barricade_target != null and is_instance_valid(_barricade_target):
		if _barricade_target.has_method("is_broken") and not _barricade_target.is_broken():
			_update_barricade_attack()
			return
		_start_vault(_barricade_target)
		_barricade_target = null

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
	var target_pos := global_position
	if _barricade_target.has_method("get_orc_attack_position"):
		target_pos = _barricade_target.get_orc_attack_position()
	nav_agent.target_position = target_pos
	var dist := global_position.distance_to(target_pos)
	if dist <= barricade_attack_range:
		velocity.x = move_toward(velocity.x, 0.0, move_speed)
		velocity.z = move_toward(velocity.z, 0.0, move_speed)
		_face_toward(_barricade_target.global_position)
		if _attack_timer <= 0.0:
			_attack_barricade()
		elif _attack_timer < barricade_attack_cooldown - PUNCH_LEN:
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

func _attack_barricade() -> void:
	_attack_timer = barricade_attack_cooldown
	_play_oneshot("SwordSlash")
	_attack_audio.play()
	if _barricade_target != null and is_instance_valid(_barricade_target) \
			and _barricade_target.has_method("damage_from_orc"):
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

func _attack() -> void:
	_attack_timer = attack_cooldown
	_play_oneshot("SwordSlash")
	_attack_audio.play()
	get_tree().create_timer(PUNCH_LEN * 0.4).timeout.connect(
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
	if _dead:
		return
	var impact_pos := global_position + Vector3(0.0, 1.25, 0.0)
	if hit_position is Vector3:
		impact_pos = hit_position
	_spawn_blood_burst(impact_pos, hit_normal)
	health -= amount
	_hurt_audio.play()
	if health <= 0.0:
		_die()

func _spawn_blood_burst(pos: Vector3, normal: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.amount = 22
	particles.lifetime = 0.42
	particles.one_shot = true
	particles.explosiveness = 1.0

	var pmat := ParticleProcessMaterial.new()
	var burst_dir := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	pmat.direction = (burst_dir + Vector3.UP * 0.25).normalized()
	pmat.spread = 72.0
	pmat.initial_velocity_min = 1.8
	pmat.initial_velocity_max = 5.6
	pmat.gravity = Vector3(0.0, -11.0, 0.0)
	pmat.scale_min = 0.035
	pmat.scale_max = 0.09
	pmat.color = blood_color
	particles.process_material = pmat

	var mat := StandardMaterial3D.new()
	mat.albedo_color = blood_color
	mat.roughness = 0.85
	var mesh_shape := BoxMesh.new()
	mesh_shape.size = Vector3(0.08, 0.035, 0.08)
	mesh_shape.material = mat
	particles.draw_pass_1 = mesh_shape

	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	particles.emitting = true
	get_tree().create_timer(0.7).timeout.connect(particles.queue_free)

func _die() -> void:
	_dead = true
	remove_from_group("orc")
	Economy.add_points(point_reward)
	velocity = Vector3.ZERO
	_collision.disabled = true
	_play_oneshot("Death")
	_death_audio.play()
	await get_tree().create_timer(DEATH_LEN).timeout
	queue_free()
