class_name MultiplyHighestEffect extends SymbolEffect

@export var base_multiplier: int = 2

func _init() -> void:
	priority = 20

func apply_effect(my_index: int, ctx: BattleContext) -> void:
	var highest_index: int = -1;
	var highest_val: int = 0;
	
	for i in ctx.buckets.size():
		if i == my_index:
			continue
		
		var bucket = ctx.buckets[i]
		# This chooses the HIGHEST INDIVIDUAL STAT, could be worth exploring a highest total value adding the stats all togetehr #TODO
		var value = max( 
			bucket.get("impact", 0),
			bucket.get("morale", 0),
			bucket.get("bandwidth", 0)
		)
		
		if value > highest_val:
			highest_val = value
			highest_index = i
	
	if highest_index == -1:
		return
		
	var bonus = ctx.buckets[my_index].get("multiplier_bonus", 0)
	var scale = ctx.buckets[my_index].get("multiplier_scale", 1)
	var my_power = (base_multiplier + bonus) * scale
	var src_name = ctx.board[my_index].symbol_name
	
	if ctx.board[highest_index] != null and ctx.board[highest_index].effect_type == SymbolData.EffectType.MULTIPLIER:
		ctx.buckets[highest_index]["multiplier_scale"] *= my_power
	else:
		if ctx.board[highest_index].base_impact > 0:
			ctx.mult_stat(highest_index, "impact", my_power, src_name)
		if ctx.board[highest_index].base_bandwidth > 0:
			ctx.mult_stat(highest_index, "bandwidth", my_power, src_name)
		if ctx.board[highest_index].base_morale > 0:
			ctx.mult_stat(highest_index, "morale", my_power, src_name)

func get_description() -> String:
	return "[wave amp=6 freq=4][color=#ffd060][b]×" + str(base_multiplier) + " Max [/b][/color][/wave]"

func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	var bonus = ctx.buckets[my_index].get("multiplier_bonus", 0)
	var scale = ctx.buckets[my_index].get("multiplier_scale", 1)
	var power = (base_multiplier + bonus) * scale
	
	if bonus > 0 or scale > 1:
		return "[b][color=#ffd060]×" + str(power) + " Max" + "[/color][/b][color=#ffd060] (+LEV)[/color]"
		
	return "[b][color=#ffd060]×" + str(power) + " Max" + "[/color][/b]"
