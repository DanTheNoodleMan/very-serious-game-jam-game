class_name ScaleOnLandEffect extends SymbolEffect

@export var scale_amount: int = 1
## false = this fight only. true = permanently upgrades the symbol for the run.
@export var permanent: bool = false

func _init() -> void:
	priority = 5 # priority 5 for effects that autoscale on land

func apply_effect(my_index: int, ctx: BattleContext) -> void: pass
func on_commit(my_index: int, ctx: BattleContext) -> void: pass

func on_landed(my_index: int, is_held: bool, ctx: BattleContext) -> void:
	if is_held: return
	ctx.scale_symbol(my_index, "impact", scale_amount, ctx.board[my_index].symbol_name, permanent)
	ctx.popup(my_index, "+%d" % scale_amount)

func get_description() -> String:
	var scope := "" if permanent else " this fight"
	return "[color=#ffd060]Gains +%d Impact when rolled%s[/color]" % [scale_amount, scope]
