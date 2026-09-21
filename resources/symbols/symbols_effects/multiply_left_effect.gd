class_name MultiplyLeftEffect extends SymbolEffect

@export var base_multiplier: int = 2

func _init() -> void:
	priority = 20

func apply_effect(my_index: int, ctx: BattleContext) -> void:
	if my_index > 0 and ctx.board[my_index - 1] != null:
		var target_bucket = ctx.buckets[my_index - 1]
		
		var bonus = ctx.buckets[my_index].get("multiplier_bonus", 0)
		var scale = ctx.buckets[my_index].get("multiplier_scale", 1)
		var my_power = (base_multiplier + bonus) * scale
		
		if ctx.board[my_index - 1].effect_type == SymbolData.EffectType.MULTIPLIER:
			target_bucket["multiplier_scale"] *= my_power
		else:
			target_bucket["impact"] *= my_power
			target_bucket["bandwidth"] *= my_power
			target_bucket["morale"] *= my_power


func get_description() -> String:
	return "[wave amp=6 freq=4][color=#ffd060][b]×" + str(base_multiplier) + " ← [/b][/color][/wave]"

func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	var bonus = ctx.buckets[my_index].get("multiplier_bonus", 0)
	var scale = ctx.buckets[my_index].get("multiplier_scale", 1)
	var power = (base_multiplier + bonus) * scale
	
	var ibm = " [font_size=10][color=#ff6060]I[/color][color=#60ccff]B[/color][color=#60ee80]M[/color][/font_size]"
	
	if my_index == 0: return "[color=#555566]×" + str(power) + " ←" + ibm + " (miss)[/color]"
	
	var left = ctx.board[my_index - 1]
	if left != null and left.effect_type == SymbolData.EffectType.MULTIPLIER:
		if left.id == "ai": return "[color=#555566]×" + str(power) + " ←" + ibm + " (spent on " + left.symbol_name.to_upper() + ")[/color]"
		else: return "[color=#555566]×" + str(power) + " ←" + ibm + " (wasted)[/color]"
			
	if bonus > 0 or scale > 1:
		return "[b][color=#ffd060]×" + str(power) + " ←" + ibm + "[/color][/b][color=#ffd060] (+LEV)[/color]"
		
	return "[b][color=#ffd060]×" + str(power) + " ←" + ibm + "[/color][/b]"
