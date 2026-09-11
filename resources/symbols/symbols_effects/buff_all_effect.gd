class_name BuffAllEffect extends SymbolEffect

@export var buff_amount: int = 4

func _init() -> void:
	priority = 10
	
func apply_effect(my_index: int, ctx: BattleContext) -> void:
	for i in 3:
		if i != my_index and ctx.board[i] != null:
			ctx.buckets[i]["impact"] += buff_amount
			ctx.buckets[i]["bandwidth"] += buff_amount
			ctx.buckets[i]["morale"] += buff_amount
			ctx.buckets[i]["multiplier_power"] += buff_amount

func get_description() -> String:
	return "[wave amp=6 freq=4][color=#ffd060][b]+" + str(buff_amount) + " ALL[/b][/color][/wave]"

func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	var has_any_target: bool = false
	for i in 3:
		if i != my_index and ctx.board[i] != null: has_any_target = true
	if not has_any_target:
		return "[color=#555566]+" + str(buff_amount) + " (miss)[/color]"
	return "[b][color=#ffd060]+" + str(buff_amount) + " ALL[/color][/b]"
