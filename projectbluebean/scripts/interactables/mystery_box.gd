extends Buyable
class_name MysteryBox
## Fantasy reskin of the Zombies Mystery Box. Repurchasable: pay points to
## "roll" a random weapon from the pool, then press interact again to take the
## presented weapon. Reuses player.equip_weapon() and the existing weapon scenes
## (their KayKit model lives in a "Model" child, shown here as an inert prop).

enum State { IDLE, ROLLING, PRESENTING }

const ROLL_TIME := 3.0          ## seconds the weapons cycle before settling
const PRESENT_TIME := 10.0      ## seconds the settled weapon hovers before it is lost
const DISPLAY_SCALE := 2.5      ## scale applied to the floating weapon prop
const SPIN_SPEED := 1.5         ## radians/sec the prop spins
const BOB_HEIGHT := 0.08        ## metres the prop bobs

## Weapon pool. preload() values are constant, so this const array is valid.
const POOL := [
	{"scene": preload("res://scenes/weapons/Crossbow.tscn"), "name": "Crossbow"},
	{"scene": preload("res://scenes/weapons/Staff.tscn"), "name": "Fire Staff"},
	{"scene": preload("res://scenes/weapons/Axe.tscn"), "name": "Throwing Axe"},
]

var _state: int = State.IDLE
var _chosen_scene: PackedScene = null
var _chosen_name: String = ""
var _present_timer: float = 0.0
var _bob_time: float = 0.0

var _pivot: Node3D = null
var _display: Node3D = null
var _glow: OmniLight3D = null

func _configure() -> void:
	cost = 950
	prompt_label = "Mystery Box"
	one_time = false
	_pivot = get_node_or_null("Pivot")

func get_prompt() -> String:
	match _state:
		State.ROLLING:
			return ""
		State.PRESENTING:
			return "[F]  Take %s" % _chosen_name
		_:
			if Economy.can_afford(cost):
				return "[F]  Mystery Box   (%d pts)" % cost
			return "Mystery Box   (%d pts) - need more points" % cost

func interact(player: Node) -> void:
	match _state:
		State.IDLE:
			if not Economy.try_spend(cost):
				return
			_start_roll()
		State.PRESENTING:
			_grant(player)
		_:
			return  # ROLLING: locked

func _process(delta: float) -> void:
	if _display != null and is_instance_valid(_display):
		_display.rotate_y(delta * SPIN_SPEED)
		_bob_time += delta
		_display.position.y = sin(_bob_time * 3.0) * BOB_HEIGHT
	if _state == State.PRESENTING:
		_present_timer -= delta
		if _present_timer <= 0.0:
			_reset()  # weapon lost, no refund (classic box behaviour)

# --- Roll / present -------------------------------------------------------

func _start_roll() -> void:
	_state = State.ROLLING
	_spawn_glow()
	var elapsed := 0.0
	var step := 0.08
	while elapsed < ROLL_TIME and _state == State.ROLLING:
		_show_display(POOL[randi() % POOL.size()])
		await get_tree().create_timer(step).timeout
		elapsed += step
		step = minf(step * 1.18, 0.45)  # decelerate toward the settle
	if _state != State.ROLLING:
		return  # reset/scene-change happened mid-roll
	var final: Dictionary = POOL[randi() % POOL.size()]
	_chosen_scene = final["scene"]
	_chosen_name = final["name"]
	_show_display(final)
	_state = State.PRESENTING
	_present_timer = PRESENT_TIME

func _grant(player: Node) -> void:
	if _chosen_scene != null and player.has_method("equip_weapon"):
		player.equip_weapon(_chosen_scene)
	_reset()

func _reset() -> void:
	_state = State.IDLE
	_present_timer = 0.0
	_chosen_scene = null
	_chosen_name = ""
	_clear_display()
	_clear_glow()

# --- Visuals --------------------------------------------------------------

func _show_display(entry: Dictionary) -> void:
	_clear_display()
	if _pivot == null:
		return
	var inst := (entry["scene"] as PackedScene).instantiate() as Node3D
	if inst == null:
		return
	inst.process_mode = Node.PROCESS_MODE_DISABLED  # keep the weapon script inert
	_pivot.add_child(inst)
	inst.position = Vector3.ZERO
	inst.scale = Vector3.ONE * DISPLAY_SCALE
	_display = inst
	_bob_time = 0.0

func _clear_display() -> void:
	if _display != null and is_instance_valid(_display):
		_display.queue_free()
	_display = null

func _spawn_glow() -> void:
	_clear_glow()
	if _pivot == null:
		return
	var l := OmniLight3D.new()
	l.light_color = Color(0.55, 0.4, 1.0)
	l.light_energy = 3.0
	l.omni_range = 4.5
	_pivot.add_child(l)
	_glow = l

func _clear_glow() -> void:
	if _glow != null and is_instance_valid(_glow):
		_glow.queue_free()
	_glow = null
