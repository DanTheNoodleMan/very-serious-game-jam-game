class_name MultiplyLowestEffect extends SymbolEffect

@export var base_multiplier: int = 2

func _init() -> void:
	priority = 20

func apply_effect(my_index: int, ctx: BattleContext) -> void:
	var lowest_index: int = -1;
	var lowest_val: int = INF;
	
	for i in ctx.buckets.size():
		if i == my_index:
			continue
		
		# This chooses the LOWEST INDIVIDUAL STAT, could be worth exploring a lowest total value adding the stats all togetehr #TODO
		var value = get_minimum_value(ctx.board[i], ctx.buckets[i])
		if value == -1:
			continue # symbol has no active combat stats at all — not a valid target
		
		if value < lowest_val:
			lowest_val = value
			lowest_index = i
	
	if lowest_index == -1:
		return
		
	var target_bucket = ctx.buckets[lowest_index]
	
	var bonus = ctx.buckets[my_index].get("multiplier_bonus", 0)
	var scale = ctx.buckets[my_index].get("multiplier_scale", 1)
	var my_power = (base_multiplier + bonus) * scale
	
	if ctx.board[lowest_index] != null and ctx.board[lowest_index].effect_type == SymbolData.EffectType.MULTIPLIER:
		target_bucket["multiplier_scale"] *= my_power
	else:
		target_bucket["impact"] *= my_power
		target_bucket["bandwidth"] *= my_power
		target_bucket["morale"] *= my_power
		target_bucket["impact_mult"] *= my_power
		target_bucket["bandwidth_mult"] *= my_power
		target_bucket["morale_mult"] *= my_power

func get_minimum_value(symbol: SymbolData, bucket: Dictionary) -> int:
	var active: Array = []
	if symbol.base_impact > 0: active.append(bucket.get("impact", 0))
	if symbol.base_bandwidth > 0: active.append(bucket.get("bandwidth", 0))
	if symbol.base_morale > 0: active.append(bucket.get("morale", 0))
	return active.min() if !active.is_empty() else -1 

func get_description() -> String:
	return "[wave amp=6 freq=4][color=#ffd060][b]×" + str(base_multiplier) + " Min [/b][/color][/wave]"

func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	var bonus = ctx.buckets[my_index].get("multiplier_bonus", 0)
	var scale = ctx.buckets[my_index].get("multiplier_scale", 1)
	var power = (base_multiplier + bonus) * scale
	
	if bonus > 0 or scale > 1:
		return "[b][color=#ffd060]×" + str(power) + " Min" + "[/color][/b][color=#ffd060] (+LEV)[/color]"
		
	return "[b][color=#ffd060]×" + str(power) + " Min" + "[/color][/b]"
