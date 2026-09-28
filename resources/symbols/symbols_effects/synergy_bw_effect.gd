class_name SynergyBWEffect extends SymbolEffect

@export var buff_amount: int = 3

func _init() -> void:
	priority = 10
	
func apply_effect(my_index: int, ctx: BattleContext) -> void:
	var departments := {}
	for i in 3:
		if i == my_index or ctx.board[i] == null:
			continue
		departments[ctx.board[i].department] = true
		
	var bonus = buff_amount * departments.size()
	
	#ctx.buckets[my_index]["bandwidth"] += bonus
	#ctx.buckets[my_index]["bandwidth_add"] += bonus
	#ctx.log_step(my_index, "bandwidth", "+%d (Synergy, +%d for each other distinct department.%%)" % [bonus, buff_amount])
	
	# BattleContext's add_stat/mult_stat replaces the 3 lines above, combining them all into one
	ctx.add_stat(my_index, "bandwidth", bonus, "Synergy")

func get_description() -> String:
	return "Gains " + str(buff_amount) + " Bandwidth for each distinct Department among the other 2 symbols."
	
func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	return ""
