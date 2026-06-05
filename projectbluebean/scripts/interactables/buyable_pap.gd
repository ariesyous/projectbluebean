extends Buyable
## Pack-a-Punch shrine (fantasy reskin): upgrades the player's currently held
## weapon. Each weapon can be upgraded once; you may return to upgrade other
## weapons, so this is not a one_time buyable.

func _configure() -> void:
	cost = 5000
	prompt_label = "Pack-a-Punch"
	one_time = false

func _held_weapon() -> Node:
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return null
	return p.get("_current_weapon")

func get_prompt() -> String:
	var w := _held_weapon()
	if w == null or not w.has_method("pack_a_punch"):
		return "Pack-a-Punch   (no weapon)"
	if w.is_upgraded():
		return "Pack-a-Punch   (weapon already upgraded)"
	if Economy.can_afford(cost):
		return "[F]  Pack-a-Punch   (%d pts)" % cost
	return "Pack-a-Punch   (%d pts) - need more points" % cost

func interact(player: Node) -> void:
	var w = player.get("_current_weapon")
	if w == null or not w.has_method("pack_a_punch") or w.is_upgraded():
		return
	if not Economy.try_spend(cost):
		return
	w.pack_a_punch()   # refills ammo -> ammo_changed -> HUD restyles automatically
