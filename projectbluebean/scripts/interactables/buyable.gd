extends Area3D
class_name Buyable
## Base for point-purchasable interactables (wall weapons, doors). Lives in the
## "interactable" group; the player's interact ray reads get_prompt() and calls
## interact(player) on the F key. Config is set in code via _configure() so no
## editor-assigned exports are required.

var cost: int = 500
var prompt_label: String = "Buy"
var one_time: bool = true
var _purchased: bool = false

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 8   # interactables layer (detected by the interact ray)
	collision_mask = 0
	_configure()

## Subclasses set cost / prompt_label / one_time here.
func _configure() -> void:
	pass

func get_prompt() -> String:
	if one_time and _purchased:
		return ""
	if Economy.can_afford(cost):
		return "[F]  %s   (%d pts)" % [prompt_label, cost]
	return "%s   (%d pts) - need more points" % [prompt_label, cost]

func interact(player: Node) -> void:
	if one_time and _purchased:
		return
	if not Economy.try_spend(cost):
		return
	_purchased = true
	_on_purchased(player)

## Override with the purchase effect.
func _on_purchased(_player: Node) -> void:
	pass
