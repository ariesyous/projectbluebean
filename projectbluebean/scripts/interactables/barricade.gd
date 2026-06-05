extends Area3D
class_name Barricade
## Breakable + repairable window boards for M8 entry points. Orcs damage one
## board per hit; players repair one board per interact for a small point reward.

const ENTRY_FRAME_SCENE := preload("res://assets/dungeon/KayKit_DungeonRemastered_1.1_FREE/Assets/gltf/wall_archedwindow_gated.gltf")
const PLAYER_ENTRY_BLOCKER_LAYER := 32

@export var max_boards: int = 5
@export var repair_reward: int = 10
@export var repair_time: float = 0.75
@export var board_width: float = 3.25
@export var board_spacing: float = 0.32
@export var board_start_height: float = 0.72
@export var blocker_height: float = 2.35
@export var blocker_depth: float = 0.36

var label: String = "Barricade"
var _intact_boards: int = 0
var _repairing: bool = false
var _repair_progress: float = 0.0
var _boards: Array[MeshInstance3D] = []
var _board_root: Node3D = null
var _blocker_shape: CollisionShape3D = null
var _player_blocker_shape: CollisionShape3D = null
var _hit_audio: AudioStreamPlayer3D = null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("barricade")
	collision_layer = 8
	collision_mask = 0
	if _board_root == null:
		_build_visuals()
	_refresh_state()

## The arena builder calls this after creating the node. `outside_dir` points
## from the room through the opening toward the orc spawn alcove.
func setup(entry_label: String, outside_dir: Vector2i) -> void:
	label = entry_label
	rotation.y = _yaw_for_dir(outside_dir)
	_build_visuals()
	_intact_boards = max_boards
	_refresh_state()

func get_prompt() -> String:
	if _intact_boards >= max_boards:
		return ""
	if _repairing:
		return "Repairing %s..." % label
	return "Hold [F]  Repair %s   (+%d pts)" % [label, repair_reward]

func uses_hold_interact() -> bool:
	return true

func hold_interact(_player: Node, delta: float) -> void:
	if _intact_boards >= max_boards:
		_cancel_repair()
		return
	if not _repairing:
		_repairing = true
		_repair_progress = 0.0
		_play_hit_feedback(-0.035)
	_repair_progress += delta
	if _repair_progress >= repair_time:
		_complete_repair_board()

func cancel_hold_interact() -> void:
	_cancel_repair()

func get_interact_progress() -> float:
	if not _repairing:
		return 0.0
	return clampf(_repair_progress / maxf(repair_time, 0.01), 0.0, 1.0)

func interact(player: Node) -> void:
	hold_interact(player, repair_time)

func _complete_repair_board() -> void:
	_repair_progress = 0.0
	if not is_inside_tree() or _intact_boards >= max_boards:
		_cancel_repair()
		return
	_intact_boards += 1
	Economy.add_points(repair_reward)
	_refresh_state()
	_play_hit_feedback(-0.06)
	if _intact_boards >= max_boards:
		_repairing = false

func _cancel_repair() -> void:
	_repairing = false
	_repair_progress = 0.0

func is_broken() -> bool:
	return _intact_boards <= 0

func damage_from_orc(_orc: Node) -> void:
	if _intact_boards <= 0:
		return
	_intact_boards -= 1
	_refresh_state()
	_play_hit_feedback(0.12)

func get_orc_attack_position() -> Vector3:
	return global_position + global_transform.basis.z * 1.15 + Vector3(0.0, 0.05, 0.0)

func _build_visuals() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_boards.clear()
	_blocker_shape = null
	_player_blocker_shape = null
	_hit_audio = null

	var area_shape := CollisionShape3D.new()
	area_shape.name = "InteractShape"
	var area_box := BoxShape3D.new()
	area_box.size = Vector3(board_width + 0.55, blocker_height + 0.35, 1.35)
	area_shape.shape = area_box
	area_shape.position = Vector3(0.0, blocker_height * 0.5, 0.0)
	add_child(area_shape)

	var blocker := StaticBody3D.new()
	blocker.name = "Blocker"
	blocker.collision_layer = 16   # movement-only barricade layer; weapon rays ignore it
	blocker.collision_mask = 0
	add_child(blocker)
	_blocker_shape = CollisionShape3D.new()
	_blocker_shape.name = "BlockerShape"
	var blocker_box := BoxShape3D.new()
	blocker_box.size = Vector3(board_width, blocker_height, blocker_depth)
	_blocker_shape.shape = blocker_box
	_blocker_shape.position = Vector3(0.0, blocker_height * 0.5, 0.0)
	blocker.add_child(_blocker_shape)

	var player_blocker := StaticBody3D.new()
	player_blocker.name = "PlayerEntryBlocker"
	player_blocker.collision_layer = PLAYER_ENTRY_BLOCKER_LAYER
	player_blocker.collision_mask = 0
	add_child(player_blocker)
	_player_blocker_shape = CollisionShape3D.new()
	_player_blocker_shape.name = "PlayerEntryBlockerShape"
	var player_blocker_box := BoxShape3D.new()
	player_blocker_box.size = Vector3(board_width, blocker_height + 0.55, blocker_depth)
	_player_blocker_shape.shape = player_blocker_box
	_player_blocker_shape.position = Vector3(0.0, blocker_height * 0.5, 0.0)
	player_blocker.add_child(_player_blocker_shape)

	var entry_frame := ENTRY_FRAME_SCENE.instantiate() as Node3D
	if entry_frame != null:
		entry_frame.name = "EnemyEntryFrame"
		add_child(entry_frame)
		entry_frame.position = Vector3(0.0, 0.0, 0.08)
		_disable_collision_nodes(entry_frame)

	_board_root = Node3D.new()
	_board_root.name = "Boards"
	add_child(_board_root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.27, 0.13)
	mat.roughness = 0.9
	for i in range(max_boards):
		var board := MeshInstance3D.new()
		board.name = "Board%d" % (i + 1)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(board_width, 0.18, 0.16)
		mesh.material = mat
		board.mesh = mesh
		_board_root.add_child(board)
		board.position = Vector3(0.0, board_start_height + float(i) * board_spacing, 0.0)
		board.rotation.z = deg_to_rad(-7.0 + float(i % 3) * 7.0)
		_boards.append(board)

	_hit_audio = AudioStreamPlayer3D.new()
	_hit_audio.name = "WoodHit"
	_hit_audio.stream = load("res://assets/sounds/impact.wav")
	_hit_audio.unit_size = 4.0
	_hit_audio.volume_db = -4.0
	add_child(_hit_audio)
	_hit_audio.position = Vector3(0.0, 1.25, 0.0)

func _disable_collision_nodes(root: Node) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back() as Node
		if n == null:
			continue
		var body := n as CollisionObject3D
		if body != null:
			body.collision_layer = 0
			body.collision_mask = 0
		for child in n.get_children():
			stack.push_back(child)

func _refresh_state() -> void:
	if _intact_boards <= 0:
		_intact_boards = 0
	if _intact_boards > max_boards:
		_intact_boards = max_boards
	for i in range(_boards.size()):
		_boards[i].visible = i < _intact_boards
	if _blocker_shape != null:
		_blocker_shape.disabled = _intact_boards <= 0

func _play_hit_feedback(z_offset: float) -> void:
	if _hit_audio != null:
		_hit_audio.pitch_scale = randf_range(0.82, 1.08)
		_hit_audio.play()
	if _board_root == null or not is_inside_tree():
		return
	_board_root.position = Vector3.ZERO
	var tween := create_tween()
	tween.tween_property(_board_root, "position", Vector3(0.0, 0.0, z_offset), 0.045)
	tween.tween_property(_board_root, "position", Vector3.ZERO, 0.095)

func _yaw_for_dir(dir: Vector2i) -> float:
	if dir == Vector2i(1, 0):
		return PI * 0.5
	if dir == Vector2i(0, -1):
		return PI
	if dir == Vector2i(-1, 0):
		return -PI * 0.5
	return 0.0
