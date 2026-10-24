# i.e. ("Rolodex": +$1 whenever a [stat] symbol lands fresh)
class_name LandCashRelic extends RelicData
@export var department: SymbolData.Department = SymbolData.Department.FINANCE
@export var cash: int = 1

func on_symbol_landed(status: ActiveStatus, index: int, was_held: bool, ctx: BattleContext) -> void:
	if was_held or ctx.combat == null or ctx.board[index] == null: return
	if ctx.board[index].department != department: return
	ctx.combat.run.add_cash(cash)
	ctx.popup(index, "+$%d" % cash)
