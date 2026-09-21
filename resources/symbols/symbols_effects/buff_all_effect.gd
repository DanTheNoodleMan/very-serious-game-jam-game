class_name BuffAllEffect extends SymbolEffect

@export var buff_amount: int = 4

func _init() -> void:
	priority = 10
	
func apply_effect(my_index: int, ctx: BattleContext) -> void:
	for i in 3:
		if i != my_index and ctx.board[i] != null:
			var applied = false
			
			# only buff the stats that the symbol actually uses
			if ctx.board[i].base_impact > 0:
				ctx.buckets[i]["impact"] += buff_amount
				applied = true
			if ctx.board[i].base_bandwidth > 0:
				ctx.buckets[i]["bandwidth"] += buff_amount
				applied = true
			if ctx.board[i].base_morale > 0:
				ctx.buckets[i]["morale"] += buff_amount
				applied = true
			
			if not applied and ctx.board[i].effect_type == SymbolData.EffectType.MULTIPLIER:
				ctx.buckets[i]["multiplier_bonus"] += buff_amount

func get_description() -> String:
	return "[b][color=#ffd060]+" + str(buff_amount) + " ALL[/color][/b]"

func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	var has_any_target: bool = false
	for i in 3:
		if i != my_index and ctx.board[i] != null: has_any_target = true
	if not has_any_target:
		return "[color=#555566]+" + str(buff_amount) + " (miss)[/color]"
	return "[b][color=#ffd060]+" + str(buff_amount) + " ALL[/color][/b]"
