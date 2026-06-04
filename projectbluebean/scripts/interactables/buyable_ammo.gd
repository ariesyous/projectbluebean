extends Buyable
## Buyable that completely refills the current weapon's ammo.

func _configure() -> void:
	cost = 250
	prompt_label = "Refill Ammo"
	one_time = false

func interact(player: Node) -> void:
	var weapon = player.get("_current_weapon")
	if weapon == null or not weapon.has_method("refill_ammo"):
		return
	if weapon.data != null:
		var ammo = weapon.get_ammo()
		if ammo.x == weapon.data.mag_size and ammo.y == weapon.data.reserve_ammo:
			return # Already full
	super(player)

func _on_purchased(player: Node) -> void:
	var weapon = player.get("_current_weapon")
	if weapon != null and weapon.has_method("refill_ammo"):
		weapon.refill_ammo()
