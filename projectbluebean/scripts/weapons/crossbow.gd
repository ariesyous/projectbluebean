extends Weapon
## Crossbow: a Weapon preconfigured with crossbow.tres. Assigning in _ready
## (after any scene-stored export override is applied) keeps data reliable.

func _ready() -> void:
	if data == null:
		data = load("res://resources/weapons/crossbow.tres")
	super()
