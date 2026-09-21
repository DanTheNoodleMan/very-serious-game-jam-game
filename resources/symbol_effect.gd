class_name SymbolEffect extends Resource

## Priority determines what symbol effect happens first. 
## Flat buffs should be Priority 10.
## Multipliers should be Priority 20 so they multiply the buffed numbers.
@export var priority: int = 10

# Runs constantly to preview math for the UI. NEVER permanently change variables here
func apply_effect(my_index: int, ctx: BattleContext) -> void:
	pass

# Runs ONCE time when the player hits "Lock In"
func on_commit(my_index: int, ctx: BattleContext) -> void:
	pass
	
# Runs ONCE when a reel physically stops spinning
func on_landed(my_index: int, is_held: bool, ctx: BattleContext) -> String:
	return ""

# --------- Aux functions ---------

# Used when hovering or first landing
func get_description() -> String:
	return ""

# Used for the final calculated label
func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	return get_description()
