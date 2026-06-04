extends Node3D
## Arena: bakes the navigation mesh at startup and runs discrete escalating
## rounds with short breathers between them.

const ORC_SCENE := preload("res://scenes/enemies/Orc.tscn")

@export var spawn_interval: float = 1.5
@export var max_alive: int = 6
@export var first_round_enemy_count: int = 6
@export var enemies_added_per_round: int = 2
@export var between_round_time: float = 6.0
@export var health_scale_per_round: float = 0.12
@export var speed_scale_per_round: float = 0.04

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var spawn_points: Node3D = $SpawnPoints
@onready var enemies: Node3D = $Enemies

var _spawn_accum: float = 0.0
var _remaining_to_spawn: int = 0
var _between_round_left: float = 0.0
var _round_active: bool = false

func _ready() -> void:
	randomize()
	GameState.reset()
	Economy.reset()
	await _bake_navigation()
	_start_round()

func _bake_navigation() -> void:
	# Let the scene/geometry settle a frame, then bake synchronously so the
	# nav map is ready before the first orc spawns.
	await get_tree().physics_frame
	var nm: NavigationMesh = nav_region.navigation_mesh
	if nm == null:
		nm = NavigationMesh.new()
		nav_region.navigation_mesh = nm
	# Match the navigation map cell size and parse collision shapes (cheaper and
	# avoids the GPU mesh-readback warning).
	nm.cell_size = 0.25
	nm.agent_radius = 0.5
	nm.agent_height = 1.6
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_region.bake_navigation_mesh(false)

func _process(delta: float) -> void:
	if GameState.is_game_over:
		return
	if _between_round_left > 0.0:
		_between_round_left = max(_between_round_left - delta, 0.0)
		GameState.set_round_status(0, true, _between_round_left)
		if _between_round_left <= 0.0:
			_start_round()
		return

	if _round_active and _remaining_to_spawn > 0:
		_spawn_accum += delta
		if _spawn_accum >= spawn_interval and _alive_orcs() < max_alive:
			_spawn_accum = 0.0
			_spawn_orc()

	if _round_active and _remaining_to_spawn <= 0 and _alive_orcs() <= 0:
		_finish_round()
	else:
		_update_round_status()

func _start_round() -> void:
	var next_round := GameState.current_round + 1
	GameState.set_round(next_round)
	_remaining_to_spawn = first_round_enemy_count + (next_round - 1) * enemies_added_per_round
	_spawn_accum = spawn_interval
	_between_round_left = 0.0
	_round_active = true
	_update_round_status()

func _finish_round() -> void:
	_round_active = false
	_remaining_to_spawn = 0
	_between_round_left = between_round_time
	GameState.set_round_status(0, true, _between_round_left)

func _spawn_orc() -> void:
	if _alive_orcs() >= max_alive:
		return
	var points := spawn_points.get_children()
	if points.is_empty():
		return
	var marker: Node3D = points[randi() % points.size()]
	var orc: Node3D = ORC_SCENE.instantiate()
	var round_index := float(GameState.current_round - 1)
	orc.set("max_health", float(orc.get("max_health")) * (1.0 + health_scale_per_round * round_index))
	orc.set("move_speed", float(orc.get("move_speed")) * (1.0 + speed_scale_per_round * round_index))
	enemies.add_child(orc)
	orc.global_position = marker.global_position
	_remaining_to_spawn -= 1
	_update_round_status()

func _alive_orcs() -> int:
	return get_tree().get_nodes_in_group("orc").size()

func _update_round_status() -> void:
	var remaining := _remaining_to_spawn + _alive_orcs()
	GameState.set_round_status(remaining, false)
