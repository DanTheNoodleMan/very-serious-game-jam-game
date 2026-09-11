class_name SymbolEffect extends Resource

## Priority determines what symbol effect happens first. 
## Flat buffs should be Priority 10.
## Multipliers should be Priority 20 so they multiply the buffed numbers.
@export var priority: int = 10

func apply_effect(my_index: int, ctx: BattleContext) -> void:
	pass

# --------- Aux functions ---------

# Used when hovering or first landing
func get_description() -> String:
	return ""

# Used for the final calculated label
func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	return get_description()
