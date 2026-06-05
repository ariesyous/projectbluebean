extends "res://scripts/interactables/buyable_perk.gd"
## Stamina Brew (Stamin-Up reskin): permanently faster move speed.

func _setup_perk() -> void:
	perk_id = "stamina"
	cost = 1500
	prompt_label = "Stamina Brew (move speed)"
	perk_color = Color(0.4, 1.0, 0.5)
