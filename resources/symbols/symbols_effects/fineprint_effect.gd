class_name FinePrintEffect extends SymbolEffect
## Fine Print: shield, plus a counter-hit if the enemy is about to attack.
## The shield comes from the symbol's own base_bandwidth now, so this only adds the conditional part.

@export var counter_impact: int = 4

#TODO update with new enemy intent system
func apply_effect(my_index: int, ctx: BattleContext) -> void:
	if _enemy_will_attack(ctx):
		ctx.add_stat(my_index, "impact", counter_impact, ctx.board[my_index].symbol_name)
	

func _enemy_will_attack(ctx: BattleContext) -> bool:
	var action := ctx.combat.next_action if ctx.combat != null else null
	return action != null and action.damage > 0

func get_description() -> String:
	return "If the enemy intends to attack, deals [b]%d[/b] Impact." % counter_impact
