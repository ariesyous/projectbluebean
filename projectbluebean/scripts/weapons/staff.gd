extends Weapon
## Fire Staff: automatic fantasy weapon. Hitscan in M1; becomes a fire-bolt
## projectile in M3.

func _ready() -> void:
	if data == null:
		data = load("res://resources/weapons/staff.tres")
	super()
