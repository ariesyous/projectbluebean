extends "res://scripts/interactables/buyable_perk.gd"
## Frenzy (Double Tap reskin): faster fire rate on every weapon.

func _setup_perk() -> void:
	perk_id = "double_tap"
	cost = 1500
	prompt_label = "Frenzy (fire rate)"
	perk_color = Color(1.0, 0.5, 0.3)
