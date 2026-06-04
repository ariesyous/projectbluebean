extends Buyable
## Buyable door: freeing this node removes its Barrier child, opening the
## doorway to the next room. The navmesh already spans the doorway, so orcs
## and the player can pass once the barrier is gone.

func _configure() -> void:
	cost = 1000
	prompt_label = "Open Door"
	one_time = true

func _on_purchased(_player: Node) -> void:
	queue_free()
