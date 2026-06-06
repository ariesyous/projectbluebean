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
var _repair_progress_label: Label = null
var _boss_health_bar: ProgressBar = null

const PAUSE_SCENE := preload("res://scenes/ui/PauseMenu.tscn")

func _ready() -> void:
	var pause_menu := PAUSE_SCENE.instantiate()
	add_child(pause_menu)
	_apply_hud_overhaul()
	game_over.visible = false
	prompt_label.visible = false
	hit_marker.visible = false
	_create_repair_progress_label()
	_create_boss_health_bar()
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
	_update_repair_progress()

func _create_repair_progress_label() -> void:
	_repair_progress_label = Label.new()
	_repair_progress_label.name = "RepairProgress"
	_repair_progress_label.visible = false
	_repair_progress_label.modulate = Color(0.95, 0.82, 0.45, 0.95)
	_repair_progress_label.add_theme_font_size_override("font_size", 30)
	_repair_progress_label.anchor_left = 0.5
	_repair_progress_label.anchor_top = 0.5
	_repair_progress_label.anchor_right = 0.5
	_repair_progress_label.anchor_bottom = 0.5
	_repair_progress_label.offset_left = -24.0
	_repair_progress_label.offset_top = 102.0
	_repair_progress_label.offset_right = 24.0
	_repair_progress_label.offset_bottom = 142.0
	_repair_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_repair_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	$Root.add_child(_repair_progress_label)

func _update_repair_progress() -> void:
	if _repair_progress_label == null:
		return
	if _target == null or not is_instance_valid(_target) or not _target.has_method("get_interact_progress"):
		_repair_progress_label.visible = false
		return
	var progress: float = _target.get_interact_progress()
	if progress <= 0.0:
		_repair_progress_label.visible = false
		return
	_repair_progress_label.visible = true
	if progress < 0.25:
		_repair_progress_label.text = "."
	elif progress < 0.5:
		_repair_progress_label.text = "o"
	elif progress < 0.75:
		_repair_progress_label.text = "O"
	elif progress < 0.98:
		_repair_progress_label.text = "0"
	else:
		_repair_progress_label.text = "#"

func _apply_hud_overhaul() -> void:
	# Add shadows and outlines to Labels
	_style_label(points_label, 32, Color(1, 0.85, 0.3)) # Gold points
	_style_label(round_label, 36, Color(1, 1, 1))
	_style_label(enemies_label, 24, Color(0.85, 0.85, 0.85))
	_style_label(ammo_label, 52, Color(1, 1, 1))
	_style_label(perks_label, 20, Color(0.6, 0.9, 1.0))
	_style_label(prompt_label, 32, Color(1, 0.95, 0.6))
	
	var ch = $Root/Crosshair as Label
	ch.text = "+"
	ch.offset_left = -20
	ch.offset_top = -20
	ch.offset_right = 20
	ch.offset_bottom = 20
	_style_label(ch, 36, Color(1, 1, 1, 0.8))

	hit_marker.text = "X"
	hit_marker.offset_left = -20
	hit_marker.offset_top = -20
	hit_marker.offset_right = 20
	hit_marker.offset_bottom = 20
	_style_label(hit_marker, 42, Color(1, 0.15, 0.1))

	# Layout Points/Round (Top Left)
	points_label.anchor_left = 0
	points_label.anchor_right = 0
	points_label.offset_left = 40
	points_label.offset_top = 30
	round_label.anchor_left = 0
	round_label.anchor_right = 0
	round_label.offset_left = 40
	round_label.offset_top = 80
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	enemies_label.anchor_left = 0
	enemies_label.anchor_right = 0
	enemies_label.offset_left = 40
	enemies_label.offset_top = 130
	enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Ammo Label (Bottom Right)
	ammo_label.offset_left = -400
	ammo_label.offset_right = -50
	ammo_label.offset_bottom = -50

	# Perks Label (Above Ammo)
	perks_label.anchor_left = 1.0
	perks_label.anchor_right = 1.0
	perks_label.offset_left = -500
	perks_label.offset_right = -50
	perks_label.offset_top = -140
	perks_label.offset_bottom = -110
	perks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	# Health and Stamina Bars (Bottom Left)
	health_bar.anchor_top = 1.0
	health_bar.anchor_bottom = 1.0
	health_bar.offset_left = 50
	health_bar.offset_top = -100
	health_bar.offset_right = 450
	health_bar.offset_bottom = -70
	_style_bar(health_bar, Color(0.2, 0.85, 0.2))

	stamina_bar.anchor_top = 1.0
	stamina_bar.anchor_bottom = 1.0
	stamina_bar.offset_left = 50
	stamina_bar.offset_top = -60
	stamina_bar.offset_right = 350
	stamina_bar.offset_bottom = -40
	stamina_bar.modulate = Color(1, 1, 1, 1) # reset modulate
	_style_bar(stamina_bar, Color(0.2, 0.75, 0.95))

func _style_label(lbl: Label, size: int, color: Color) -> void:
	if lbl == null: return
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("shadow_offset_x", 4)
	lbl.add_theme_constant_override("shadow_offset_y", 4)

func _style_bar(bar: ProgressBar, fill_color: Color) -> void:
	if bar == null: return
	bar.show_percentage = true # Enable percentage text over health/stamina
	var fill = StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	fill.border_width_left = 2
	fill.border_width_top = 2
	fill.border_width_right = 2
	fill.border_width_bottom = 2
	fill.border_color = Color(1,1,1,0.2)
	bar.add_theme_stylebox_override("fill", fill)

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg)

func _create_boss_health_bar() -> void:
	_boss_health_bar = ProgressBar.new()
	_boss_health_bar.name = "BossHealthBar"
	_boss_health_bar.visible = false
	_boss_health_bar.anchor_left = 0.2
	_boss_health_bar.anchor_right = 0.8
	_boss_health_bar.anchor_top = 0.05
	_boss_health_bar.anchor_bottom = 0.05
	_boss_health_bar.offset_bottom = 30.0
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.8, 0.1, 0.1)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	_boss_health_bar.add_theme_stylebox_override("fill", sb)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	_boss_health_bar.add_theme_stylebox_override("background", bg)
	_boss_health_bar.show_percentage = false
	$Root.add_child(_boss_health_bar)

func update_boss_health(current: float, maximum: float) -> void:
	if _boss_health_bar == null:
		return
	_boss_health_bar.max_value = maximum
	_boss_health_bar.value = current
	_boss_health_bar.visible = true

func hide_boss_health() -> void:
	if _boss_health_bar:
		_boss_health_bar.visible = false

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
