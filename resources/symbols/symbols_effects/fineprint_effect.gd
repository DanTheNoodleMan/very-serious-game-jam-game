class_name FinePrintEffect extends SymbolEffect

@export var base_bandwidth: int = 2
@export var counter_impact: int = 4

#TODO update with new enemy intent system
func apply_effect(my_index: int, ctx: BattleContext) -> void:
	# 1. Always give the base bandwidth
	ctx.symbol_results[my_index].bandwidth += base_bandwidth
	
	# 2. Check the enemy intent from the context!
	# (Assuming you have an enum or string for enemy intent in BattleContext)
	if ctx.enemy_intent == "ATTACK": 
		ctx.symbol_results[my_index].impact += counter_impact

func get_description() -> String:
	return "%d Bandwidth. If enemy intends to attack, deals %d Impact." % [base_bandwidth, counter_impact]

func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	if ctx.enemy_intent == "ATTACK":
		# Shows them both stats if the condition is met!
		return "[color=blue]%d BW[/color] | [color=red]%d IMPACT[/color]" % [base_bandwidth, counter_impact]
	else:
		# Just shows the shield if the enemy isn't attacking
		return "[color=blue]%d BANDWIDTH[/color]" % base_bandwidth
