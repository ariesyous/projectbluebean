extends Resource
class_name WeaponData
## Data-driven weapon definition. New weapons = new .tres, not new code.

@export var display_name: String = "Weapon"
@export var damage: float = 40.0
@export var fire_rate: float = 3.0            ## shots per second
@export var mag_size: int = 8
@export var reserve_ammo: int = 64
@export var reload_time: float = 1.6
@export var max_range: float = 100.0
@export var automatic: bool = false           ## hold-to-fire vs click-per-shot
@export var projectile: bool = false          ## spawn projectile vs hitscan
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 28.0
@export var muzzle_color: Color = Color(1.0, 0.85, 0.4)
@export var view_model: PackedScene           ## optional weapon mesh scene
