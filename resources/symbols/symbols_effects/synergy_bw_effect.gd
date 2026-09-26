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
	print("bonus: ", bonus)
	print(ctx.buckets[my_index]["bandwidth_add"])
	ctx.buckets[my_index]["bandwidth"] += bonus
	ctx.buckets[my_index]["bandwidth_add"] += bonus
	print(ctx.buckets[my_index]["bandwidth_add"])

func get_description() -> String:
	return ""

func get_contextual_label(my_index: int, ctx: BattleContext) -> String:
	return ""
