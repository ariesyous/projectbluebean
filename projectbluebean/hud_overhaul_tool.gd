extends SceneTree

func _init() -> void:
	var path := "res://scenes/ui/HUD.tscn"
	var packed := load(path) as PackedScene
	var root = packed.instantiate()
	var r = root.get_node("Root")

	# Add shadows and outlines to Labels
	_style_label(r.get_node("PointsLabel"), 36, Color(1, 0.85, 0.3)) # Gold points
	_style_label(r.get_node("RoundLabel"), 42, Color(1, 1, 1))
	_style_label(r.get_node("EnemiesLabel"), 28, Color(0.85, 0.85, 0.85))
	_style_label(r.get_node("AmmoLabel"), 64, Color(1, 1, 1))
	_style_label(r.get_node("PerksLabel"), 22, Color(0.6, 0.9, 1.0))
	_style_label(r.get_node("PromptLabel"), 36, Color(1, 0.95, 0.6))
	
	# Layout Points/Round (Top Left)
	var p_lbl = r.get_node("PointsLabel")
	p_lbl.anchor_left = 0
	p_lbl.anchor_right = 0
	p_lbl.offset_left = 40
	p_lbl.offset_top = 30
	var r_lbl = r.get_node("RoundLabel")
	r_lbl.anchor_left = 0
	r_lbl.anchor_right = 0
	r_lbl.offset_left = 40
	r_lbl.offset_top = 80
	r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var e_lbl = r.get_node("EnemiesLabel")
	e_lbl.anchor_left = 0
	e_lbl.anchor_right = 0
	e_lbl.offset_left = 40
	e_lbl.offset_top = 130
	e_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Ammo Label (Bottom Right)
	var a_lbl = r.get_node("AmmoLabel")
	a_lbl.offset_right = -50
	a_lbl.offset_bottom = -50
	# Can't easily set italic via theme overrides without a font, so we just use size

	# Perks Label (Above Ammo)
	var perk_lbl = r.get_node("PerksLabel")
	perk_lbl.anchor_left = 1.0
	perk_lbl.anchor_right = 1.0
	perk_lbl.offset_left = -500
	perk_lbl.offset_right = -50
	perk_lbl.offset_top = -140
	perk_lbl.offset_bottom = -110
	perk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	# Health and Stamina Bars (Bottom Left)
	var hb = r.get_node("HealthBar") as ProgressBar
	hb.anchor_top = 1.0
	hb.anchor_bottom = 1.0
	hb.offset_left = 50
	hb.offset_top = -100
	hb.offset_right = 450
	hb.offset_bottom = -70
	_style_bar(hb, Color(0.2, 0.85, 0.2))

	var sb = r.get_node("StaminaBar") as ProgressBar
	sb.anchor_top = 1.0
	sb.anchor_bottom = 1.0
	sb.offset_left = 50
	sb.offset_top = -60
	sb.offset_right = 350
	sb.offset_bottom = -40
	sb.modulate = Color(1, 1, 1, 1) # reset modulate
	_style_bar(sb, Color(0.2, 0.75, 0.95))

	# Crosshair (Center)
	var ch = r.get_node("Crosshair") as Label
	ch.text = "⊹"
	ch.offset_left = -20
	ch.offset_top = -20
	ch.offset_right = 20
	ch.offset_bottom = 20
	_style_label(ch, 36, Color(1, 1, 1, 0.8))

	# Hit Marker
	var hm = r.get_node("HitMarker") as Label
	hm.text = "✕"
	hm.offset_left = -20
	hm.offset_top = -20
	hm.offset_right = 20
	hm.offset_bottom = 20
	_style_label(hm, 42, Color(1, 0.15, 0.1))

	var new_packed := PackedScene.new()
	new_packed.pack(root)
	ResourceSaver.save(new_packed, path)
	print("HUD Overhauled Successfully!")
	quit()

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
	bar.show_percentage = false
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
