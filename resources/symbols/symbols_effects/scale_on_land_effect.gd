class_name ScaleOnLandEffect extends SymbolEffect

@export var scale_amount: int = 1

func _init() -> void:
	priority = 30 # priority 5 for effects that autoscale on land

func apply_effect(my_index: int, ctx: BattleContext) -> void: pass
func on_commit(my_index: int, ctx: BattleContext) -> void: pass

func on_landed(my_index: int, is_held: bool, ctx: BattleContext) -> String:
	if not is_held:
		ctx.board[my_index].base_impact += scale_amount
		return "+" + str(scale_amount) # Tell the UI to spawn this text
	
	return "" # Held, so do nothing

func get_description() -> String:
	return "[color=#ffd060]Gains +" + str(scale_amount) + " Impact when rolled[/color]"
