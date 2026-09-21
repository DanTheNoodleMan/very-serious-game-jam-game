class_name ScaleOnPlayEffect extends SymbolEffect

@export var scale_amount: int = 1

func _init() -> void:
	priority = 30 # priority 30 for effects that don't affect other ones except for itself
	

func apply_effect(my_index: int, ctx: BattleContext) -> void:
	pass

# We permanently buff it right as the attack happens!
func on_commit(my_index: int, ctx: BattleContext) -> void:
	ctx.board[my_index].base_impact += scale_amount

func get_description() -> String:
	return "[color=#ffd060]Gains +" + str(scale_amount) + " Impact when played[/color]"

# Used for the final calculated label
func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	return get_description()
