extends Node
## Player points currency. Earn from orc kills, spend on buyables.
## Autoloaded as "Economy".

signal points_changed(new_total: int)

const STARTING_POINTS := 500

var points: int = STARTING_POINTS

func reset() -> void:
	points = STARTING_POINTS
	points_changed.emit(points)

func add_points(amount: int) -> void:
	points += amount
	points_changed.emit(points)

func can_afford(cost: int) -> bool:
	return points >= cost

## Returns true and deducts the cost if affordable, else false.
func try_spend(cost: int) -> bool:
	if points < cost:
		return false
	points -= cost
	points_changed.emit(points)
	return true
