extends Node3D
## Arena: bakes the navigation mesh at startup and runs discrete escalating
## rounds with short breathers between them.

const ORC_SCENE := preload("res://scenes/enemies/Orc.tscn")
const DungeonAmbience := preload("res://scripts/fx/dungeon_ambience.gd")
const BarricadeScript := preload("res://scripts/interactables/barricade.gd")

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
var _entry_points: Array = []
var _prop_collision: StaticBody3D = null

func _ready() -> void:
	randomize()
	GameState.reset()
	Economy.reset()
	_build_dungeon()
	_tune_environment()
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
	var prop_body := StaticBody3D.new()
	prop_body.name = "PropCollision"
	nav_region.add_child(prop_body)
	_prop_collision = prop_body

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

	_build_ceiling(props)
	_build_corner_pillars(props)
	_place_dungeon_props(props)
	_decorate_buyable_door()
	_create_barricade_entries()

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
	light.light_energy = 4.2
	light.omni_range = 12.0
	light.shadow_enabled = false
	props.add_child(light)
	light.global_position = wall_pos + inner * 0.6 + Vector3(0.0, 2.7, 0.0)

## Cap the dungeon with a ceiling so the dark void above the 4-tall walls is hidden.
func _build_ceiling(parent: Node3D) -> void:
	var ceil_scene: PackedScene = load(KIT + "ceiling_tile.gltf")
	if ceil_scene == null:
		push_warning("Missing ceiling_tile.gltf")
		return
	var ceiling := Node3D.new()
	ceiling.name = "DungeonCeiling"
	parent.add_child(ceiling)
	for cell in _floor_cells:
		var tile: Node3D = ceil_scene.instantiate()
		ceiling.add_child(tile)
		tile.position = Vector3(cell.x * TILE, WALL_H, cell.y * TILE)

## Place a corner buttress pillar at every convex corner (a cell whose two
## perpendicular edges are both walls and whose diagonal neighbour is empty), so
## corners read as columns instead of two straight walls poking through each other.
func _build_corner_pillars(parent: Node3D) -> void:
	var scene: PackedScene = load(KIT + "wall_corner.gltf")
	if scene == null:
		push_warning("Missing wall_corner.gltf")
		return
	var pillars := Node3D.new()
	pillars.name = "CornerPillars"
	parent.add_child(pillars)
	var diags := [Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1)]
	for cell in _floor_cells:
		for d in diags:
			if _floor_cells.has(cell + Vector2i(d.x, 0)):
				continue
			if _floor_cells.has(cell + Vector2i(0, d.y)):
				continue
			if _floor_cells.has(cell + d):
				continue
			var jx: float = cell.x * TILE + d.x * TILE * 0.5
			var jz: float = cell.y * TILE + d.y * TILE * 0.5
			var pil: Node3D = scene.instantiate()
			pillars.add_child(pil)
			pil.position = Vector3(jx, 0.0, jz)
			pil.rotation.y = _corner_yaw(d)

## Maps a convex-corner's exterior diagonal to the wall_corner yaw that tucks the
## buttress into that corner. Calibrated from the piece's local AABB.
func _corner_yaw(d: Vector2i) -> float:
	if d == Vector2i(-1, 1):
		return 0.0
	if d == Vector2i(-1, -1):
		return PI * 0.5
	if d == Vector2i(1, -1):
		return PI
	return PI * 1.5

## Swap the gated door's plain emissive box for a real KayKit door model. The box
## collider stays (it's the gate); the whole BuyableDoor frees on purchase so the
## door model disappears with it.
func _decorate_buyable_door() -> void:
	var door := get_node_or_null("BuyableDoor")
	if door == null:
		return
	var barrier := door.get_node_or_null("Barrier")
	if barrier == null:
		return
	var mesh := barrier.get_node_or_null("BarrierMesh") as MeshInstance3D
	if mesh != null:
		mesh.visible = false
	var scene: PackedScene = load(KIT + "wall_doorway.gltf")
	if scene == null:
		push_warning("Missing wall_doorway.gltf")
		return
	var model: Node3D = scene.instantiate()
	model.name = "DoorModel"
	barrier.add_child(model)
	# BuyableDoor sits at y=2; the door model's origin is at its base, so drop it
	# 2 units to stand on the floor. Default yaw spans x and blocks the z corridor.
	model.position = Vector3(0.0, -2.0, 0.0)

func _create_barricade_entries() -> void:
	_entry_points.clear()
	var root := Node3D.new()
	root.name = "EntryPoints"
	add_child(root)
	_add_barricade_entry(root, "Start Window", Vector2i(0, 6), Vector2i(0, 1))
	_add_barricade_entry(root, "East Breach", Vector2i(4, -2), Vector2i(1, 0))
	_add_barricade_entry(root, "West Breach", Vector2i(-4, 2), Vector2i(-1, 0))

func _add_barricade_entry(root: Node3D, entry_label: String, cell: Vector2i, dir: Vector2i) -> void:
	var outside := Vector3(float(dir.x), 0.0, float(dir.y))
	var pos := Vector3(
		float(cell.x) * TILE + outside.x * TILE * 0.5,
		0.0,
		float(cell.y) * TILE + outside.z * TILE * 0.5
	)
	var barricade := BarricadeScript.new() as Barricade
	if barricade == null:
		return
	barricade.name = entry_label.replace(" ", "")
	root.add_child(barricade)
	barricade.global_position = pos
	barricade.setup(entry_label, dir)
	_entry_points.append({
		"barricade": barricade,
		"spawn_position": pos + outside * (TILE * 0.5),
	})

## Lift the dark dungeon a touch now that a ceiling encloses it, keeping the mood
## while making orc silhouettes readable during kiting.
func _tune_environment() -> void:
	var we := $WorldEnvironment as WorldEnvironment
	if we == null or we.environment == null:
		return
	var env := we.environment
	env.ambient_light_energy = 0.85
	env.fog_density = 0.013

func _place_dungeon_props(props: Node3D) -> void:
	# Start room: readable silhouettes near the side walls, leaving the lane clear.
	_place_prop("barrel_large_decorated.gltf", Vector3(-7.2, 0.0, 22.7), deg_to_rad(24.0), props)
	_place_prop("crates_stacked.gltf", Vector3(7.2, 0.0, 22.4), deg_to_rad(-18.0), props)
	_place_wall_prop("banner_shield_blue.gltf", Vector3(0.0, 0.0, 26.0), Vector2i(0, 1), props, 2.25)

	# Combat room: clutter the edges only so orc routes stay clean.
	_place_prop("table_medium_broken.gltf", Vector3(-8.5, 0.0, -5.5), deg_to_rad(55.0), props)
	_place_prop("barrel_small_stack.gltf", Vector3(14.0, 0.0, 5.7), deg_to_rad(-30.0), props)
	_place_prop("pillar_decorated.gltf", Vector3(-14.0, 0.0, 6.0), 0.0, props)
	_place_prop("pillar_decorated.gltf", Vector3(14.0, 0.0, -6.0), PI, props)
	# Barrels relocated here from the narrow vault arms (which they choked); the
	# combat room is wide enough that their carved colliders don't sever paths.
	_place_prop("barrel_large.gltf", Vector3(13.0, 0.0, 5.0), deg_to_rad(12.0), props)
	_place_prop("barrel_small.gltf", Vector3(-13.0, 0.0, 5.0), deg_to_rad(-8.0), props)
	_place_wall_prop("banner_patternA_red.gltf", Vector3(-18.0, 0.0, 0.0), Vector2i(-1, 0), props, 2.25)
	_place_wall_prop("banner_patternA_green.gltf", Vector3(18.0, 0.0, 0.0), Vector2i(1, 0), props, 2.25)

	# Vault: keep the ring and arms clear so the navmesh stays connected and kiting
	# is clean. Only a table tucked against the back-nub wall, clear of the Pack-a-
	# Punch approach (x=0) and the nub's loop connections (x=-4/0/4 at the north edge).
	_place_prop("table_long_decorated_A.gltf", Vector3(-4.0, 0.0, -37.2), 0.0, props)
	_place_wall_prop("banner_triple_yellow.gltf", Vector3(0.0, 0.0, -38.0), Vector2i(0, -1), props, 2.25)

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
	_add_prop_collider(prop, position, yaw)

## Give a floor prop a box collider sized to its mesh AABB, parented under the nav
## region so the bake carves around it and the player/orcs can't walk through it.
func _add_prop_collider(prop: Node3D, world_pos: Vector3, yaw: float) -> void:
	if _prop_collision == null:
		return
	var local := AABB()
	var first := true
	var stack: Array = [prop]
	while not stack.is_empty():
		var n = stack.pop_back()
		for c in n.get_children():
			stack.push_back(c)
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			var t: Transform3D = prop.global_transform.affine_inverse() * mi.global_transform
			var a: AABB = t * mi.mesh.get_aabb()
			if first:
				local = a
				first = false
			else:
				local = local.merge(a)
	if first:
		return
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(maxf(local.size.x, 0.2), maxf(local.size.y, 0.2), maxf(local.size.z, 0.2))
	col.shape = shape
	_prop_collision.add_child(col)
	var center := local.position + local.size * 0.5
	col.position = world_pos + Basis(Vector3.UP, yaw) * center
	col.rotation.y = yaw

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
	_add_room(Rect2i(-4, -2, 9, 5))    # Room B (combat)
	_floor_cells[Vector2i(0, 3)] = true     # corridor A <-> B
	_floor_cells[Vector2i(0, -3)] = true    # buyable door into the vault loop
	_add_barricade_alcoves()
	_add_vault_loop()

func _add_barricade_alcoves() -> void:
	# One-cell entry alcoves behind repairable boards. They are part of the
	# navmesh so orcs can route through naturally once the boards are broken.
	_floor_cells[Vector2i(0, 7)] = true
	_floor_cells[Vector2i(5, -2)] = true
	_floor_cells[Vector2i(-5, 2)] = true

func _add_vault_loop() -> void:
	# A gated ring for late-round kiting. Only the centre top cell touches the
	# combat room, so the existing buyable door remains the loop unlock.
	for tx in range(-4, 5):
		_floor_cells[Vector2i(tx, -4)] = true
		_floor_cells[Vector2i(tx, -8)] = true
	for tz in range(-8, -3):
		_floor_cells[Vector2i(-4, tz)] = true
		_floor_cells[Vector2i(4, tz)] = true
	_floor_cells[Vector2i(-5, -6)] = true
	_floor_cells[Vector2i(5, -6)] = true
	_floor_cells[Vector2i(-1, -9)] = true
	_floor_cells[Vector2i(0, -9)] = true
	_floor_cells[Vector2i(1, -9)] = true

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
	var orc: Node3D = ORC_SCENE.instantiate()
	var round_index := float(GameState.current_round - 1)
	orc.set("max_health", float(orc.get("max_health")) * (1.0 + health_scale_per_round * round_index))
	orc.set("move_speed", float(orc.get("move_speed")) * (1.0 + speed_scale_per_round * round_index))
	enemies.add_child(orc)

	if not _entry_points.is_empty():
		var entry: Dictionary = _entry_points[randi() % _entry_points.size()]
		var spawn_position: Vector3 = entry.get("spawn_position", Vector3.ZERO)
		var barricade: Node = entry.get("barricade", null) as Node
		orc.global_position = spawn_position
		if barricade != null and is_instance_valid(barricade) and barricade.has_method("is_broken") \
				and not barricade.is_broken() and orc.has_method("assign_barricade"):
			orc.assign_barricade(barricade)
	else:
		var points := spawn_points.get_children()
		if points.is_empty():
			orc.queue_free()
			return
		var marker: Node3D = points[randi() % points.size()]
		orc.global_position = marker.global_position

	_remaining_to_spawn -= 1
	_update_round_status()

func _alive_orcs() -> int:
	return get_tree().get_nodes_in_group("orc").size()

func _update_round_status() -> void:
	var remaining := _remaining_to_spawn + _alive_orcs()
	GameState.set_round_status(remaining, false)
