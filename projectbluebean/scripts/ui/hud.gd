extends CanvasLayer
## Signal-driven HUD: health, points, ammo, interaction prompt, and the
## game-over overlay. Finds the player via the "player" group.

@onready var health_bar: ProgressBar = $Root/HealthBar
@onready var points_label: Label = $Root/PointsLabel
@onready var round_label: Label = $Root/RoundLabel
@onready var enemies_label: Label = $Root/EnemiesLabel
@onready var ammo_label: Label = $Root/AmmoLabel
@onready var prompt_label: Label = $Root/PromptLabel
@onready var game_over: Control = $Root/GameOver
@onready var restart_button: Button = $Root/GameOver/RestartButton

var _player: Node = null
var _target = null

func _ready() -> void:
	game_over.visible = false
	prompt_label.visible = false
	Economy.points_changed.connect(_on_points_changed)
	GameState.player_died.connect(_on_player_died)
	GameState.round_changed.connect(_on_round_changed)
	GameState.round_status_changed.connect(_on_round_status_changed)
	restart_button.pressed.connect(_on_restart)
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		_player.health_changed.connect(_on_health_changed)
		_player.weapon_changed.connect(_on_weapon_changed)
		_player.interact_target_changed.connect(_on_interact_target_changed)
		_on_weapon_changed(_player.get("_current_weapon"))
	_on_points_changed(Economy.points)
	_on_round_changed(GameState.current_round)
	_on_round_status_changed(
		GameState.current_round,
		GameState.enemies_remaining,
		GameState.is_between_round,
		GameState.round_countdown)

func _process(_delta: float) -> void:
	if _target != null and is_instance_valid(_target) and _target.has_method("get_prompt"):
		var text: String = _target.get_prompt()
		prompt_label.text = text
		prompt_label.visible = text != ""
	else:
		prompt_label.visible = false

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

func _on_points_changed(total: int) -> void:
	points_label.text = "%d pts" % total

func _on_round_changed(round_number: int) -> void:
	if round_number <= 0:
		round_label.text = "Round --"
	else:
		round_label.text = "Round %d" % round_number

func _on_round_status_changed(_round_number: int, remaining: int, between_round: bool, seconds_left: float) -> void:
	if between_round:
		enemies_label.text = "Next wave: %ds" % ceili(seconds_left)
	elif remaining > 0:
		enemies_label.text = "%d enemies" % remaining
	else:
		enemies_label.text = "Wave clear"

func _on_weapon_changed(weapon) -> void:
	if weapon != null and weapon.has_signal("ammo_changed"):
		if not weapon.ammo_changed.is_connected(_on_ammo_changed):
			weapon.ammo_changed.connect(_on_ammo_changed)
		if weapon.has_method("get_ammo"):
			var a: Vector2i = weapon.get_ammo()
			_on_ammo_changed(a.x, a.y)

func _on_ammo_changed(in_mag: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [in_mag, reserve]

func _on_interact_target_changed(target) -> void:
	_target = target

func _on_player_died() -> void:
	game_over.visible = true

func _on_restart() -> void:
	get_tree().reload_current_scene()
