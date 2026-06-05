extends Node3D
## Arena: bakes the navigation mesh at startup and runs discrete escalating
## rounds with short breathers between them.

const ORC_SCENE := preload("res://scenes/enemies/Orc.tscn")
const DungeonAmbience := preload("res://scripts/fx/dungeon_ambience.gd")

# Dungeon geometry: KayKit Dungeon Remastered, built on a 4-unit grid.
const KIT := "res://assets/dungeon/KayKit_DungeonRemastered_1.1_FREE/Assets/gltf/"
const TILE := 4.0
const WALL_H := 4.0

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
var _floor_cells: Dictionary = {}

func _ready() -> void:
	randomize()
	GameState.reset()
	Economy.reset()
	_build_dungeon()
	_start_ambient_audio()
	await _bake_navigation()
	_start_round()

# Lays floor tiles + perimeter walls (with collision) from a few room rects on
# the 4-unit grid. A wall is placed on any cell edge whose neighbour is empty,
# so room boundaries are walled and corridors stay open automatically.
func _build_dungeon() -> void:
	_collect_cells()
	var floor_scene: PackedScene = load(KIT + "floor_tile_large.gltf")
	var wall_scene: PackedScene = load(KIT + "wall.gltf")

	var props := Node3D.new()
	props.name = "DungeonProps"
	add_child(props)   # under Arena, not the nav region, so torches don't affect nav
	var floors := Node3D.new()
	floors.name = "DungeonFloors"
	nav_region.add_child(floors)
	var walls := Node3D.new()
	walls.name = "DungeonWalls"
	nav_region.add_child(walls)
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorCollision"
	nav_region.add_child(floor_body)
	var wall_body := StaticBody3D.new()
	wall_body.name = "WallCollision"
	nav_region.add_child(wall_body)

	for cell in _floor_cells:
		var wx: float = cell.x * TILE
		var wz: float = cell.y * TILE
		var tile: Node3D = floor_scene.instantiate()
		floors.add_child(tile)
		tile.position = Vector3(wx, 0.0, wz)
		var fcol := CollisionShape3D.new()
		var fbox := BoxShape3D.new()
		fbox.size = Vector3(TILE, 0.2, TILE)
		fcol.shape = fbox
		floor_body.add_child(fcol)
		fcol.position = Vector3(wx, -0.1, wz)

	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var torch_i := 0
	for cell in _floor_cells:
		for dir in dirs:
			if _floor_cells.has(cell + dir):
				continue
			var wx: float = cell.x * TILE + dir.x * TILE * 0.5
			var wz: float = cell.y * TILE + dir.y * TILE * 0.5
			var yaw := PI * 0.5 if dir.x != 0 else 0.0
			var wall: Node3D = wall_scene.instantiate()
			walls.add_child(wall)
			wall.position = Vector3(wx, 0.0, wz)
			wall.rotation.y = yaw
			var wcol := CollisionShape3D.new()
			var wbox := BoxShape3D.new()
			wbox.size = Vector3(TILE, WALL_H, 1.0)
			wcol.shape = wbox
			wall_body.add_child(wcol)
			wcol.position = Vector3(wx, WALL_H * 0.5, wz)
			wcol.rotation.y = yaw
			torch_i += 1
			if torch_i % 3 == 0:
				_place_torch(Vector3(wx, 0.0, wz), dir, props)

	_place_dungeon_props(props)

func _start_ambient_audio() -> void:
	var ambience := DungeonAmbience.new()
	ambience.name = "DungeonAmbience"
	add_child(ambience)

func _place_torch(wall_pos: Vector3, dir: Vector2i, props: Node3D) -> void:
	var inner := Vector3(-dir.x, 0.0, -dir.y)   # toward the room interior
	var torch: Node3D = load(KIT + "torch_mounted.gltf").instantiate()
	props.add_child(torch)
	torch.global_position = wall_pos + inner * 0.45 + Vector3(0.0, 2.3, 0.0)
	torch.look_at(torch.global_position + inner, Vector3.UP)
	var light := OmniLight3D.new()
	light.set_script(load("res://scripts/fx/torch_flicker.gd"))
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 3.2
	light.omni_range = 9.0
	light.shadow_enabled = false
	props.add_child(light)
	light.global_position = wall_pos + inner * 0.6 + Vector3(0.0, 2.7, 0.0)

func _place_dungeon_props(props: Node3D) -> void:
	# Start room: readable silhouettes near the side walls, leaving the lane clear.
	_place_prop("barrel_large_decorated.gltf", Vector3(-7.2, 0.0, 22.7), deg_to_rad(24.0), props)
	_place_prop("crates_stacked.gltf", Vector3(7.2, 0.0, 22.4), deg_to_rad(-18.0), props)
	_place_wall_prop("banner_shield_blue.gltf", Vector3(0.0, 0.0, 26.0), Vector2i(0, 1), props, 2.25)

	# Combat room: clutter the edges only so orc routes stay clean.
	_place_prop("table_medium_broken.gltf", Vector3(-8.5, 0.0, -5.5), deg_to_rad(55.0), props)
	_place_prop("barrel_small_stack.gltf", Vector3(10.5, 0.0, 5.7), deg_to_rad(-30.0), props)
	_place_prop("pillar_decorated.gltf", Vector3(-10.0, 0.0, 6.0), 0.0, props)
	_place_prop("pillar_decorated.gltf", Vector3(10.0, 0.0, -6.0), PI, props)
	_place_wall_prop("banner_patternA_red.gltf", Vector3(-14.0, 0.0, 0.0), Vector2i(-1, 0), props, 2.25)
	_place_wall_prop("banner_patternA_green.gltf", Vector3(14.0, 0.0, 0.0), Vector2i(1, 0), props, 2.25)

	# Vault room: richer dressing around the perk and Pack-a-Punch machines.
	_place_prop("table_long_decorated_A.gltf", Vector3(0.0, 0.0, -21.2), PI, props)
	_place_prop("barrel_large.gltf", Vector3(-6.8, 0.0, -22.5), deg_to_rad(12.0), props)
	_place_prop("barrel_small.gltf", Vector3(6.5, 0.0, -22.0), deg_to_rad(-8.0), props)
	_place_wall_prop("banner_triple_yellow.gltf", Vector3(0.0, 0.0, -26.0), Vector2i(0, -1), props, 2.25)

func _place_prop(model: String, position: Vector3, yaw: float, props: Node3D) -> void:
	var scene := load(KIT + model) as PackedScene
	if scene == null:
		push_warning("Missing dungeon prop: " + model)
		return
	var prop := scene.instantiate() as Node3D
	if prop == null:
		return
	props.add_child(prop)
	prop.position = position
	prop.rotation.y = yaw

func _place_wall_prop(model: String, wall_pos: Vector3, dir: Vector2i, props: Node3D, height: float) -> void:
	var inner := Vector3(-dir.x, 0.0, -dir.y)
	var scene := load(KIT + model) as PackedScene
	if scene == null:
		push_warning("Missing dungeon wall prop: " + model)
		return
	var prop := scene.instantiate() as Node3D
	if prop == null:
		return
	props.add_child(prop)
	prop.global_position = wall_pos + inner * 0.42 + Vector3(0.0, height, 0.0)
	prop.look_at(prop.global_position + inner, Vector3.UP)

func _collect_cells() -> void:
	_add_room(Rect2i(-2, 4, 5, 3))     # Room A (start)
	_add_room(Rect2i(-3, -2, 7, 5))    # Room B (combat)
	_add_room(Rect2i(-2, -6, 5, 3))    # Room C (vault)
	_floor_cells[Vector2i(0, 3)] = true     # corridor A <-> B
	_floor_cells[Vector2i(0, -3)] = true    # corridor B <-> C

func _add_room(r: Rect2i) -> void:
	for tx in range(r.position.x, r.position.x + r.size.x):
		for tz in range(r.position.y, r.position.y + r.size.y):
			_floor_cells[Vector2i(tx, tz)] = true

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
