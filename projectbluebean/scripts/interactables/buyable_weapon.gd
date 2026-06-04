extends Buyable
## Wall-buy that grants (and refills) the Fire Staff. Repurchasable, mirroring
## Zombies wall weapons.

const WEAPON_SCENE := preload("res://scenes/weapons/Staff.tscn")

func _configure() -> void:
	cost = 750
	prompt_label = "Fire Staff"
	one_time = false

func _on_purchased(player: Node) -> void:
	if player.has_method("equip_weapon"):
		player.equip_weapon(WEAPON_SCENE)
