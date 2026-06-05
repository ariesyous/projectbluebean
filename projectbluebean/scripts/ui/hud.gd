extends CanvasLayer
## Signal-driven HUD: health, points, ammo, interaction prompt, and the
## game-over overlay. Finds the player via the "player" group.

@onready var health_bar: ProgressBar = $Root/HealthBar
@onready var stamina_bar: ProgressBar = $Root/StaminaBar
@onready var points_label: Label = $Root/PointsLabel
@onready var round_label: Label = $Root/RoundLabel
@onready var enemies_label: Label = $Root/EnemiesLabel
@onready var ammo_label: Label = $Root/AmmoLabel
@onready var hit_marker: Label = $Root/HitMarker
@onready var prompt_label: Label = $Root/PromptLabel
@onready var perks_label: Label = $Root/PerksLabel
@onready var game_over: Control = $Root/GameOver
@onready var restart_button: Button = $Root/GameOver/RestartButton

const HIT_MARKER_DURATION := 0.14

var _player: Node = null
var _target = null
var _tracked_weapon: Node = null
var _last_ammo := Vector2i.ZERO
var _hit_marker_time: float = 0.0

func _ready() -> void:
	game_over.visible = false
	prompt_label.visible = false
	hit_marker.visible = false
	Economy.points_changed.connect(_on_points_changed)
	GameState.player_died.connect(_on_player_died)
	GameState.round_changed.connect(_on_round_changed)
	GameState.round_status_changed.connect(_on_round_status_changed)
	GameState.hit_confirmed.connect(_on_hit_confirmed)
	restart_button.pressed.connect(_on_restart)
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		_player.health_changed.connect(_on_health_changed)
		_player.weapon_changed.connect(_on_weapon_changed)
		_player.interact_target_changed.connect(_on_interact_target_changed)
		_player.perks_changed.connect(_on_perks_changed)
		_player.stamina_changed.connect(_on_stamina_changed)
		_on_weapon_changed(_player.get("_current_weapon"))
		_on_perks_changed([])
		_on_stamina_changed(_player.get("stamina"), _player.get("max_stamina"), false)
	_on_points_changed(Economy.points)
	_on_round_changed(GameState.current_round)
	_on_round_status_changed(
		GameState.current_round,
		GameState.enemies_remaining,
		GameState.is_between_round,
		GameState.round_countdown)

func _process(delta: float) -> void:
	if _hit_marker_time > 0.0:
		_hit_marker_time = maxf(_hit_marker_time - delta, 0.0)
		if _hit_marker_time <= 0.0:
			hit_marker.visible = false
	if _target != null and is_instance_valid(_target) and _target.has_method("get_prompt"):
		var text: String = _target.get_prompt()
		prompt_label.text = text
		prompt_label.visible = text != ""
	else:
		prompt_label.visible = false

func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current

const STAMINA_COLOR := Color(0.55, 0.85, 0.5, 0.95)
const STAMINA_TIRED := Color(0.9, 0.4, 0.3, 0.95)

func _on_stamina_changed(current: float, maximum: float, exhausted: bool) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_bar.modulate = STAMINA_TIRED if exhausted else STAMINA_COLOR

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
	if _tracked_weapon != null and is_instance_valid(_tracked_weapon):
		if _tracked_weapon.has_signal("ammo_changed") and _tracked_weapon.ammo_changed.is_connected(_on_ammo_changed):
			_tracked_weapon.ammo_changed.disconnect(_on_ammo_changed)
		if _tracked_weapon.has_signal("reload_changed") and _tracked_weapon.reload_changed.is_connected(_on_reload_changed):
			_tracked_weapon.reload_changed.disconnect(_on_reload_changed)
	_tracked_weapon = weapon
	if weapon != null and weapon.has_signal("ammo_changed"):
		weapon.ammo_changed.connect(_on_ammo_changed)
	if weapon != null and weapon.has_signal("reload_changed"):
		weapon.reload_changed.connect(_on_reload_changed)
	if weapon != null:
		if weapon.has_method("get_ammo"):
			var a: Vector2i = weapon.get_ammo()
			_on_ammo_changed(a.x, a.y)
		if weapon.has_method("is_reloading"):
			_on_reload_changed(weapon.is_reloading())
	else:
		ammo_label.text = "-- / --"
		_update_ammo_style()

func _on_ammo_changed(in_mag: int, reserve: int) -> void:
	_last_ammo = Vector2i(in_mag, reserve)
	ammo_label.text = "%d / %d" % [in_mag, reserve]
	_update_ammo_style()

## Tint the ammo readout violet when the held weapon is Pack-a-Punched.
func _update_ammo_style() -> void:
	var up: bool = _tracked_weapon != null and is_instance_valid(_tracked_weapon) \
		and _tracked_weapon.has_method("is_upgraded") and _tracked_weapon.is_upgraded()
	ammo_label.modulate = Color(0.75, 0.55, 1.0) if up else Color(1, 1, 1)

func _on_reload_changed(is_reloading: bool) -> void:
	if is_reloading:
		ammo_label.text = "Reloading"
	else:
		ammo_label.text = "%d / %d" % [_last_ammo.x, _last_ammo.y]

func _on_hit_confirmed() -> void:
	_hit_marker_time = HIT_MARKER_DURATION
	hit_marker.visible = true

const PERK_NAMES := {"stamina": "Stamina", "speed_cola": "Quick Hands", "double_tap": "Frenzy"}

func _on_perks_changed(perk_ids: Array) -> void:
	if perk_ids.is_empty():
		perks_label.text = ""
		return
	var parts := []
	for id in perk_ids:
		parts.append(PERK_NAMES.get(id, id))
	perks_label.text = "Perks: " + ", ".join(parts)

func _on_interact_target_changed(target) -> void:
	_target = target

func _on_player_died() -> void:
	game_over.visible = true

func _on_restart() -> void:
	get_tree().reload_current_scene()
