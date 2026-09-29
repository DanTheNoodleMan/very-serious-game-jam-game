class_name ScaleOnPlayEffect extends SymbolEffect

@export var scale_amount: int = 1

func _init() -> void:
	priority = 30 # priority 30 for effects that don't affect other ones except for itself
	

func apply_effect(my_index: int, ctx: BattleContext) -> void:
	pass

func on_commit(my_index: int, ctx: BattleContext) -> void:
	ctx.board[my_index].base_impact += scale_amount
	ctx.log_step(my_index, "impact", "+%d (Stake, +2 when Locked In.%%)" % scale_amount)

func get_description() -> String:
	return "[color=#ffd060]Gains +" + str(scale_amount) + " Impact when Locked In[/color]"

# Used for the final calculated label
func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	return get_description()
