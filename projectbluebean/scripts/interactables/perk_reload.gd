extends "res://scripts/interactables/buyable_perk.gd"
## Quick Hands (Speed Cola reskin): faster reloads on every weapon.

func _setup_perk() -> void:
	perk_id = "speed_cola"
	cost = 1500
	prompt_label = "Quick Hands (reload speed)"
	perk_color = Color(0.4, 0.7, 1.0)
