extends OmniLight3D
## Cheap flame flicker: jitters energy toward a random target each frame.

var _base: float = 0.0

func _ready() -> void:
	_base = light_energy

func _process(delta: float) -> void:
	var target := _base * randf_range(0.7, 1.12)
	light_energy = lerp(light_energy, target, delta * 14.0)
