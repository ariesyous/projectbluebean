extends Weapon
## Throwing Axe: a heavy throwable weapon that arcs due to gravity.

func _ready() -> void:
	if data == null:
		data = load("res://resources/weapons/axe.tres")
	super()
