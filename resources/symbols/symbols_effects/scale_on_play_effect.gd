class_name ScaleOnPlayEffect extends SymbolEffect

@export var scale_amount: int = 1
## false = this fight only. true = permanently upgrades the symbol for the run.
@export var permanent: bool = false

func _init() -> void:
	priority = 30 # priority 30 for effects that don't affect other ones except for itself

func apply_effect(my_index: int, ctx: BattleContext) -> void:
	pass

func on_commit(my_index: int, ctx: BattleContext) -> void:
	ctx.scale_symbol(my_index, "impact", scale_amount, ctx.board[my_index].symbol_name, permanent)
	ctx.popup(my_index, "+%d" % scale_amount)


func get_description() -> String:
	var scope := "" if permanent else " this fight"
	return "[color=#ffd060]Gains +%d Impact when Locked In%s[/color]" % [scale_amount, scope]

# Used for the final calculated label
func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	return get_description()
