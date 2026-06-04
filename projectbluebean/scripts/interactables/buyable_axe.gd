extends Buyable
## Wall-buy that grants the Throwing Axe.

const WEAPON_SCENE := preload("res://scenes/weapons/Axe.tscn")

func _configure() -> void:
	cost = 400
	prompt_label = "Throwing Axe"
	one_time = false

func _on_purchased(player: Node) -> void:
	if player.has_method("equip_weapon"):
		player.equip_weapon(WEAPON_SCENE)
