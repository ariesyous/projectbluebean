extends Node3D
## Arena: bakes the navigation mesh at startup and spawns a continuous trickle
## of orcs from spawn markers. The M1 spawner is a simple cap-limited timer;
## the full round system arrives in M2.

const ORC_SCENE := preload("res://scenes/enemies/Orc.tscn")

@export var spawn_interval: float = 3.0
@export var max_alive: int = 8

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var spawn_points: Node3D = $SpawnPoints
@onready var enemies: Node3D = $Enemies

var _spawn_accum: float = 0.0

func _ready() -> void:
	GameState.reset()
	Economy.reset()
	_bake_navigation()

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
	_spawn_accum += delta
	if _spawn_accum >= spawn_interval:
		_spawn_accum = 0.0
		_try_spawn()

func _try_spawn() -> void:
	if get_tree().get_nodes_in_group("orc").size() >= max_alive:
		return
	var points := spawn_points.get_children()
	if points.is_empty():
		return
	var marker: Node3D = points[randi() % points.size()]
	var orc: Node3D = ORC_SCENE.instantiate()
	enemies.add_child(orc)
	orc.global_position = marker.global_position
