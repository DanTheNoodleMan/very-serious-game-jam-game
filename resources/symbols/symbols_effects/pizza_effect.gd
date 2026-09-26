class_name PizzaEffect extends SymbolEffect

@export var heal_amount: int = 2
@export var hp_threshold: float = 0.5

func _init() -> void:
	priority = 10 
	
# If health is <50% heal heal_amount
func apply_effect(my_index: int, ctx: BattleContext) -> void:
	if ctx.player_max_hp <= 0:
		return
	var hp_ratio := float(ctx.player_hp) / float(ctx.player_max_hp)
	if hp_ratio <= hp_threshold:
		ctx.buckets[my_index]["morale"] += heal_amount
		ctx.buckets[my_index]["morale_add"] += heal_amount


func get_description() -> String:
	return "4 Bandwidth. If HP is below 50%, also Heal " + str(heal_amount) + " HP."
	
# Used for the final calculated label
func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	return get_description()
