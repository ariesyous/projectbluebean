extends Node3D
## Arena: bakes the navigation mesh at startup and runs discrete escalating
## rounds with short breathers between them.

const ORC_SCENE := preload("res://scenes/enemies/Orc.tscn")
const SHAMAN_SCENE := preload("res://scenes/enemies/Shaman.tscn")
const BRUTE_SCENE := preload("res://scenes/enemies/Brute.tscn")
const BOSS_SCENE := preload("res://scenes/enemies/Boss.tscn")
const DungeonAmbience := preload("res://scripts/fx/dungeon_ambience.gd")
const BarricadeScript := preload("res://scripts/interactables/barricade.gd")

# Dungeon geometry: KayKit Dungeon Remastered, built on a 4-unit grid.
const KIT := "res://assets/dungeon/KayKit_DungeonRemastered_1.1_FREE/Assets/gltf/"
const TILE := 4.0
const WALL_H := 4.0

# Floor styles per cell — each style renders as its own floor MultiMesh so
# areas read differently (stone chapel/hall/gallery, wood annex, dirt crypt).
const STYLE_STONE := 0
const STYLE_WOOD := 1
const STYLE_DIRT := 2

const DoorScript := preload("res://scripts/interactables/buyable_door.gd")

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
var _is_boss_round: bool = false
var _floor_cells: Dictionary = {}
var _entry_points: Array = []
# Stage 0 = Chapel (always open); 1 = Hall+Annex (Door 1); 2 = Gallery+Crypt
# (Door 2 or 3). Barricade entries in locked stages receive no spawns.
var _stage_unlocked: Array[bool] = [true, false, false]
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
	var floor_scenes := {
		STYLE_STONE: load(KIT + "floor_tile_large.gltf"),
		STYLE_WOOD: load(KIT + "floor_wood_large.gltf"),
		STYLE_DIRT: load(KIT + "floor_dirt_large.gltf"),
	}
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

	# One placements bucket per floor style; each style draws as one MultiMesh.
	var floor_placements := {STYLE_STONE: [], STYLE_WOOD: [], STYLE_DIRT: []}
	for cell in _floor_cells:
		var wx: float = cell.x * TILE
		var wz: float = cell.y * TILE
		floor_placements[_floor_cells[cell]].append(Transform3D(Basis(), Vector3(wx, 0.0, wz)))
		var fcol := CollisionShape3D.new()
		var fbox := BoxShape3D.new()
		fbox.size = Vector3(TILE, 0.2, TILE)
		fcol.shape = fbox
		floor_body.add_child(fcol)
		fcol.position = Vector3(wx, -0.1, wz)
	for style in floor_placements:
		var style_scene := floor_scenes[style] as PackedScene
		if style_scene == null:
			push_warning("Missing floor tile scene for style %d" % style)
			continue
		var floor_data := _extract_tile_mesh(style_scene)
		_add_tile_multimesh(floors, "FloorMultiMesh%d" % style, floor_data["mesh"], floor_data["xform"], floor_placements[style])

	var wall_data := _extract_tile_mesh(wall_scene)
	var wall_placements: Array = []
	var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var torch_i := 0
	for cell in _floor_cells:
		for dir in dirs:
			if _floor_cells.has(cell + dir):
				continue
			var wx: float = cell.x * TILE + dir.x * TILE * 0.5
			var wz: float = cell.y * TILE + dir.y * TILE * 0.5
			var yaw := PI * 0.5 if dir.x != 0 else 0.0
			wall_placements.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(wx, 0.0, wz)))
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
	_add_tile_multimesh(walls, "WallMultiMesh", wall_data["mesh"], wall_data["xform"], wall_placements)

	_build_ceiling(props)
	_build_corner_pillars(props)
	_place_dungeon_props(props)
	_create_buyable_doors()
	_create_barricade_entries()

func _start_ambient_audio() -> void:
	var ambience := DungeonAmbience.new()
	ambience.name = "DungeonAmbience"
	add_child(ambience)

## Pull the renderable Mesh (and its transform within the glTF scene) out of a
## KayKit tile so the dungeon can be drawn by a few MultiMeshInstance3D nodes
## instead of hundreds of separate MeshInstance3D nodes. On the single-threaded
## web build, draw-call submission is the bottleneck, and this collapses ~300
## static-tile draw calls down to ~4. Collision stays as individual shapes (the
## navmesh bake parses static colliders, not visuals), so nav is unaffected.
func _extract_tile_mesh(scene: PackedScene) -> Dictionary:
	var inst := scene.instantiate() as Node3D
	var out := {"mesh": null, "xform": Transform3D.IDENTITY}
	var mi := _first_mesh_instance(inst)
	if mi != null:
		out["mesh"] = mi.mesh
		var x: Transform3D = mi.transform
		var n: Node = mi.get_parent()
		while n != null and n != inst:
			x = (n as Node3D).transform * x
			n = n.get_parent()
		out["xform"] = inst.transform * x
	inst.free()
	return out

func _first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var r := _first_mesh_instance(c)
		if r != null:
			return r
	return null

## Draw one copy of `mesh` per entry in `placements` (each pre-multiplied by the
## mesh's in-scene `base` transform) as a single MultiMeshInstance3D.
func _add_tile_multimesh(parent: Node3D, mm_name: String, mesh: Mesh, base: Transform3D, placements: Array) -> void:
	if mesh == null or placements.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = placements.size()
	for i in placements.size():
		mm.set_instance_transform(i, (placements[i] as Transform3D) * base)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = mm_name
	mmi.multimesh = mm
	parent.add_child(mmi)

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
	var ceil_data := _extract_tile_mesh(ceil_scene)
	var ceil_placements: Array = []
	for cell in _floor_cells:
		ceil_placements.append(Transform3D(Basis(), Vector3(cell.x * TILE, WALL_H, cell.y * TILE)))
	_add_tile_multimesh(ceiling, "CeilingMultiMesh", ceil_data["mesh"], ceil_data["xform"], ceil_placements)

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
	var pillar_data := _extract_tile_mesh(scene)
	var pillar_placements: Array = []
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
			pillar_placements.append(Transform3D(Basis(Vector3.UP, _corner_yaw(d)), Vector3(jx, 0.0, jz)))
	_add_tile_multimesh(pillars, "CornerMultiMesh", pillar_data["mesh"], pillar_data["xform"], pillar_placements)

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

## Build the three staged buyable doors in code. Each door cell is the only
## opening between its two areas, so its barrier is the actual gate. Doors sit
## under Arena (NOT the nav region): the navmesh must span the doorway so
## agents can path through once the barrier frees.
func _create_buyable_doors() -> void:
	_create_buyable_door(Vector2i(0, 3), &"door1", 1000, "Open the Great Hall")
	_create_buyable_door(Vector2i(-3, -3), &"door2", 1750, "Open the Long Gallery")
	_create_buyable_door(Vector2i(5, -3), &"door3", 2500, "Open the Storage Gate")

func _create_buyable_door(cell: Vector2i, id: StringName, price: int, label: String) -> void:
	var door := Area3D.new()
	door.name = "BuyableDoor_%s" % id
	door.set_script(DoorScript)
	door.set("door_id", id)
	door.set("door_cost", price)
	door.set("door_label", label)
	add_child(door)
	door.global_position = Vector3(cell.x * TILE, 2.0, cell.y * TILE)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TILE, WALL_H, 1.0)
	shape.shape = box
	door.add_child(shape)
	var barrier := StaticBody3D.new()
	barrier.name = "Barrier"
	door.add_child(barrier)
	var bcol := CollisionShape3D.new()
	bcol.name = "BarrierCol"
	var bbox := BoxShape3D.new()
	bbox.size = Vector3(TILE, WALL_H, 1.0)
	bcol.shape = bbox
	barrier.add_child(bcol)
	var model_scene: PackedScene = load(KIT + "wall_doorway.gltf")
	if model_scene != null:
		var model: Node3D = model_scene.instantiate()
		model.name = "DoorModel"
		barrier.add_child(model)
		# Door node sits at y=2; the model's origin is at its base, so drop it
		# 2 units to stand on the floor. All three door cells connect north-
		# south, so the default yaw (spanning x) blocks the z passage.
		model.position = Vector3(0.0, -2.0, 0.0)
	door.connect("opened", _on_door_opened)

func _on_door_opened(id: StringName) -> void:
	# Any door needs stage 1 open to be reachable; doors 2 and 3 open stage 2.
	_stage_unlocked[1] = true
	if id != &"door1":
		_stage_unlocked[2] = true

func _create_barricade_entries() -> void:
	_entry_points.clear()
	var root := Node3D.new()
	root.name = "EntryPoints"
	add_child(root)
	_add_barricade_entry(root, "Chapel Window", Vector2i(0, 7), Vector2i(0, 1), 0)
	_add_barricade_entry(root, "West Breach", Vector2i(-8, 0), Vector2i(-1, 0), 1)
	_add_barricade_entry(root, "Storage Window", Vector2i(8, 0), Vector2i(1, 0), 1)
	_add_barricade_entry(root, "Gallery Breach", Vector2i(-9, -5), Vector2i(-1, 0), 2)
	_add_barricade_entry(root, "Crypt Breach", Vector2i(4, -12), Vector2i(0, -1), 2)

func _add_barricade_entry(root: Node3D, entry_label: String, cell: Vector2i, dir: Vector2i, stage: int) -> void:
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
		"stage": stage,
	})

## Entries only feed spawns once their stage's door has been bought.
func _active_entries() -> Array:
	return _entry_points.filter(func(e): return _stage_unlocked[e["stage"]])

## The boss spawns in the deepest UNLOCKED area so it never lands behind a
## locked door. All three points are kept prop-free by _place_dungeon_props.
func _boss_spawn_position() -> Vector3:
	if _stage_unlocked[2]:
		return Vector3(-4.0, 0.0, -40.0)   # crypt centre
	if _stage_unlocked[1]:
		return Vector3(-14.0, 0.0, 0.0)    # great hall centre
	return Vector3(0.0, 0.0, 26.0)         # chapel south end

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
	# Prop colliders carve the navmesh, so every door lane, corridor mouth,
	# alcove mouth, and machine-nub mouth below is deliberately left clear.

	# Chapel (stage 0, blue): silhouettes by the side walls, exit lane clear.
	_place_prop("barrel_large_decorated.gltf", Vector3(-7.2, 0.0, 22.7), deg_to_rad(24.0), props)
	_place_prop("crates_stacked.gltf", Vector3(7.2, 0.0, 22.4), deg_to_rad(-18.0), props)
	_place_wall_prop("banner_shield_blue.gltf", Vector3(-6.0, 0.0, 30.0), Vector2i(0, 1), props, 2.25)
	_place_wall_prop("banner_thin_blue.gltf", Vector3(6.0, 0.0, 30.0), Vector2i(0, 1), props, 2.25)

	# Great Hall (stage 1, red): feast tables + freestanding cover. Door-1 lane
	# (x -2..2, z 6..10) and door-2 lane (x -14..-10, z -10..-6) stay clear.
	_place_prop("table_long_decorated_A.gltf", Vector3(-20.0, 0.0, 4.0), PI * 0.5, props)
	_place_prop("table_long_tablecloth.gltf", Vector3(-20.0, 0.0, -4.0), PI * 0.5, props)
	_place_prop("keg.gltf", Vector3(-32.0, 0.0, 8.0), deg_to_rad(30.0), props)
	_place_prop("column.gltf", Vector3(-24.0, 0.0, 0.0), 0.0, props)
	_place_prop("column.gltf", Vector3(-4.0, 0.0, 0.0), 0.0, props)
	_place_prop("barrier.gltf", Vector3(-16.0, 0.0, -6.0), 0.0, props)
	_place_wall_prop("banner_patternA_red.gltf", Vector3(-24.0, 0.0, -10.0), Vector2i(0, -1), props, 2.25)
	_place_wall_prop("banner_patternA_red.gltf", Vector3(-4.0, 0.0, -10.0), Vector2i(0, -1), props, 2.25)

	# Storage Annex (stage 1, green): kegs/crates/shelves. The arch lane
	# (x 6..10) and door-3 lane (x 18..22, z -10..-6) stay clear.
	_place_prop("keg.gltf", Vector3(12.0, 0.0, -8.0), deg_to_rad(-15.0), props)
	_place_prop("keg_decorated.gltf", Vector3(14.5, 0.0, -7.5), deg_to_rad(40.0), props)
	_place_prop("crates_stacked.gltf", Vector3(31.0, 0.0, -8.0), deg_to_rad(12.0), props)
	_place_prop("barrel_small_stack.gltf", Vector3(12.0, 0.0, 8.0), deg_to_rad(-30.0), props)
	_place_prop("shelf_large.gltf", Vector3(20.0, 0.0, 9.2), PI, props)
	_place_prop("chest.gltf", Vector3(31.0, 0.0, 8.0), deg_to_rad(-100.0), props)
	_place_wall_prop("banner_patternA_green.gltf", Vector3(12.0, 0.0, -10.0), Vector2i(0, -1), props, 2.25)
	_place_wall_prop("banner_shield_green.gltf", Vector3(20.0, 0.0, 10.0), Vector2i(0, 1), props, 2.25)

	# Long Gallery (stage 2, yellow): centreline columns break up the 76 m
	# sightline without blocking the door lanes or the crypt corridor.
	_place_prop("column.gltf", Vector3(-28.0, 0.0, -20.0), 0.0, props)
	_place_prop("column.gltf", Vector3(-16.0, 0.0, -20.0), 0.0, props)
	_place_prop("column.gltf", Vector3(8.0, 0.0, -20.0), 0.0, props)
	_place_prop("column.gltf", Vector3(28.0, 0.0, -20.0), 0.0, props)
	_place_prop("rubble_large.gltf", Vector3(34.0, 0.0, -24.0), deg_to_rad(70.0), props)
	_place_prop("rubble_half.gltf", Vector3(-32.0, 0.0, -15.5), deg_to_rad(-25.0), props)
	_place_wall_prop("banner_triple_yellow.gltf", Vector3(-24.0, 0.0, -26.0), Vector2i(0, -1), props, 2.25)
	_place_wall_prop("banner_triple_yellow.gltf", Vector3(12.0, 0.0, -26.0), Vector2i(0, -1), props, 2.25)
	_place_wall_prop("banner_thin_yellow.gltf", Vector3(0.0, 0.0, -14.0), Vector2i(0, 1), props, 2.25)

	# Crypt (stage 2, white/gold): pillar colonnade + treasure by the apse.
	# Corridor mouth (x -10..2 at z -30) and apse approach (z -50..-46) clear.
	_place_prop("pillar_decorated.gltf", Vector3(-16.0, 0.0, -36.0), 0.0, props)
	_place_prop("pillar_decorated.gltf", Vector3(8.0, 0.0, -36.0), 0.0, props)
	_place_prop("pillar_decorated.gltf", Vector3(-16.0, 0.0, -44.0), 0.0, props)
	_place_prop("pillar_decorated.gltf", Vector3(8.0, 0.0, -44.0), 0.0, props)
	_place_prop("trunk_large_A.gltf", Vector3(-24.0, 0.0, -32.0), deg_to_rad(20.0), props)
	_place_prop("chest.gltf", Vector3(16.0, 0.0, -32.0), PI, props)
	_place_prop("table_long_broken.gltf", Vector3(-24.0, 0.0, -46.0), deg_to_rad(85.0), props)
	_place_prop("chest_gold.gltf", Vector3(1.0, 0.0, -52.6), deg_to_rad(-135.0), props)
	_place_wall_prop("banner_patternB_white.gltf", Vector3(8.0, 0.0, -50.0), Vector2i(0, -1), props, 2.25)
	_place_wall_prop("banner_patternB_white.gltf", Vector3(-26.0, 0.0, -32.0), Vector2i(-1, 0), props, 2.25)

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
	# "The Undercroft" — a three-stage layout unlocked by buyable doors.
	# Stage 0: Chapel (start). Stage 1: Great Hall + Storage Annex (Door 1).
	# Stage 2: Long Gallery + Crypt + PaP apse (Doors 2 and 3 — opening BOTH
	# completes the kiting loop Hall -> Arch -> Annex -> Gallery -> Hall).
	_add_room(Rect2i(-2, 4, 5, 4), STYLE_STONE)      # Chapel (start)
	_add_room(Rect2i(-8, -2, 10, 5), STYLE_STONE)    # Great Hall
	_add_room(Rect2i(3, -2, 6, 5), STYLE_WOOD)       # Storage Annex
	_add_room(Rect2i(-9, -6, 19, 3), STYLE_STONE)    # Long Gallery
	_add_room(Rect2i(-6, -12, 11, 5), STYLE_DIRT)    # Crypt

	# Door cells — each is the ONLY opening between its two areas, so the
	# door barrier is the actual gate (walls auto-fill every other edge).
	_floor_cells[Vector2i(0, 3)] = STYLE_STONE       # Door 1: Chapel -> Hall
	_floor_cells[Vector2i(-3, -3)] = STYLE_STONE     # Door 2: Hall -> Gallery
	_floor_cells[Vector2i(5, -3)] = STYLE_STONE      # Door 3: Annex -> Gallery

	# Arch joining Hall and Annex (2 wide, open from the moment stage 1 is).
	_floor_cells[Vector2i(2, 0)] = STYLE_WOOD
	_floor_cells[Vector2i(2, 1)] = STYLE_WOOD

	# Corridor Gallery -> Crypt (3 wide) and the Pack-a-Punch apse.
	for x in range(-2, 1):
		_floor_cells[Vector2i(x, -7)] = STYLE_DIRT
		_floor_cells[Vector2i(x, -13)] = STYLE_DIRT

	# Machine nubs: PerkReload (hall west), PerkFireRate / PerkSpeed (crypt).
	_floor_cells[Vector2i(-9, -2)] = STYLE_STONE
	_floor_cells[Vector2i(-7, -10)] = STYLE_DIRT
	_floor_cells[Vector2i(5, -10)] = STYLE_DIRT

	# One-cell barricade entry alcoves behind repairable boards. They are part
	# of the navmesh so orcs route through naturally once the boards break.
	_floor_cells[Vector2i(0, 8)] = STYLE_STONE       # Chapel Window (stage 0)
	_floor_cells[Vector2i(-9, 0)] = STYLE_STONE      # West Breach (stage 1)
	_floor_cells[Vector2i(9, 0)] = STYLE_WOOD        # Storage Window (stage 1)
	_floor_cells[Vector2i(-10, -5)] = STYLE_STONE    # Gallery Breach (stage 2)
	_floor_cells[Vector2i(4, -13)] = STYLE_DIRT      # Crypt Breach (stage 2)

func _add_room(r: Rect2i, style: int) -> void:
	for tx in range(r.position.x, r.position.x + r.size.x):
		for tz in range(r.position.y, r.position.y + r.size.y):
			_floor_cells[Vector2i(tx, tz)] = style

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
	
	if next_round > 0 and next_round % 10 == 0:
		_remaining_to_spawn = 1
		_is_boss_round = true
	else:
		_remaining_to_spawn = first_round_enemy_count + (next_round - 1) * enemies_added_per_round
		_is_boss_round = false
		
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
	if _alive_orcs() >= max_alive and not _is_boss_round:
		return
		
	if _is_boss_round:
		var boss = BOSS_SCENE.instantiate()
		enemies.add_child(boss)
		boss.global_position = _boss_spawn_position()
		_remaining_to_spawn -= 1
		_update_round_status()
		return
		
	var is_shaman := false
	var is_brute := false
	if GameState.current_round >= 5 and randf() < 0.1:
		is_brute = true
	elif GameState.current_round >= 3 and randf() < 0.2:
		is_shaman = true
		
	var enemy: Node3D
	if is_brute:
		enemy = BRUTE_SCENE.instantiate()
	elif is_shaman:
		enemy = SHAMAN_SCENE.instantiate()
	else:
		enemy = ORC_SCENE.instantiate()
		
	var round_index := float(GameState.current_round - 1)
	enemy.set("max_health", float(enemy.get("max_health")) * (1.0 + health_scale_per_round * round_index))
	enemy.set("move_speed", float(enemy.get("move_speed")) * (1.0 + speed_scale_per_round * round_index))
	enemies.add_child(enemy)

	var entries := _active_entries()
	if not entries.is_empty():
		var entry: Dictionary = entries[randi() % entries.size()]
		var spawn_position: Vector3 = entry.get("spawn_position", Vector3.ZERO)
		var barricade: Node = entry.get("barricade", null) as Node
		enemy.global_position = spawn_position
		if barricade != null and is_instance_valid(barricade) and enemy.has_method("assign_barricade"):
			enemy.assign_barricade(barricade)
	else:
		var points := spawn_points.get_children()
		if points.is_empty():
			enemy.queue_free()
			return
		var marker: Node3D = points[randi() % points.size()]
		enemy.global_position = marker.global_position

	_remaining_to_spawn -= 1
	_update_round_status()

func _alive_orcs() -> int:
	return get_tree().get_nodes_in_group("orc").size()

func _update_round_status() -> void:
	var remaining := _remaining_to_spawn + _alive_orcs()
	GameState.set_round_status(remaining, false)

func _spawn_orc_at(pos: Vector3) -> void:
	var enemy = ORC_SCENE.instantiate()
	var round_index := float(GameState.current_round - 1)
	enemy.set("max_health", float(enemy.get("max_health")) * (1.0 + health_scale_per_round * round_index))
	enemy.set("move_speed", float(enemy.get("move_speed")) * (1.0 + speed_scale_per_round * round_index))
	enemies.add_child(enemy)
	enemy.global_position = pos
	_update_round_status()
