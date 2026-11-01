class_name SymbolEffect extends Resource

## Priority determines what symbol effect happens first. 
## Flat buffs should be Priority 10.
## Multipliers should be Priority 20 so they multiply the buffed numbers.
@export var priority: int = 10

@export_group("Upgrade")
## Exported number on THIS effect that promotions raise (e.g. base_multiplier). Empty = not upgradable.
@export var upgrade_property: StringName = &""
@export var upgrade_step: int = 1
@export var upgrade_label: String = ""    # shown on the card, e.g. "MULTIPLIER"
@export var upgrade_prefix: String = ""   # "×" or "+"

# Runs constantly to preview math for the UI. NEVER permanently change variables here
func apply_effect(my_index: int, ctx: BattleContext) -> void:
	pass

# Runs ONCE time when the player hits "Lock In"
func on_commit(my_index: int, ctx: BattleContext) -> void:
	pass
	
# Runs ONCE when a reel physically stops spinning
func on_landed(my_index: int, is_held: bool, ctx: BattleContext) -> void:
	pass

# --------- Upgrade  ---------------

func can_upgrade() -> bool:
	return upgrade_property != &"" and upgrade_property in self

func upgrade() -> void:
	set(upgrade_property, get(upgrade_property) + upgrade_step)

func get_upgrade_preview() -> String:
	var v: int = get(upgrade_property)
	return "[color=#ffd060]%s[/color]  [color=#888888]%s%d[/color][color=#ffd060] → [b]%s%d[/b][/color]" % [
		upgrade_label, upgrade_prefix, v, upgrade_prefix, v + upgrade_step]
		
		
# --------- Aux functions ---------

# Used when hovering or first landing
func get_description() -> String:
	return ""

# Used for the final calculated label
func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	return get_description()
