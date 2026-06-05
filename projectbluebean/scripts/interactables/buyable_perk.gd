extends Buyable
## Base for perk shrines (fantasy reskin of Zombies perk-a-colas). A one-time
## Buyable that grants a persistent player buff. Subclasses fill in
## perk_id / cost / prompt_label / perk_color via _setup_perk(); the shrine's
## "Crystal" mesh and "Glow" light are tinted to match, and dimmed once used.

var perk_id: String = ""
var perk_color: Color = Color(0.8, 0.8, 1.0)

func _configure() -> void:
	one_time = true
	_setup_perk()
	_apply_visuals()

## Subclasses set perk_id, cost, prompt_label, and perk_color here.
func _setup_perk() -> void:
	pass

func _apply_visuals() -> void:
	var crystal := get_node_or_null("Crystal") as MeshInstance3D
	if crystal != null:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = perk_color
		mat.emission_enabled = true
		mat.emission = perk_color
		mat.emission_energy_multiplier = 1.5
		crystal.material_override = mat
	var glow := get_node_or_null("Glow") as OmniLight3D
	if glow != null:
		glow.light_color = perk_color

func _on_purchased(player: Node) -> void:
	if player.has_method("grant_perk"):
		player.grant_perk(perk_id)
	_mark_consumed()

func _mark_consumed() -> void:
	var glow := get_node_or_null("Glow") as OmniLight3D
	if glow != null:
		glow.light_energy = 0.4
