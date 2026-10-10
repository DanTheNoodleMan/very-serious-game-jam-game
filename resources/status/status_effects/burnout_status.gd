class_name BurnoutStatus extends StatusEffect
@export var impact_penalty_per_stack: int = 1

func modify_battle(status: ActiveStatus, ctx: BattleContext) -> void:
	for i in ctx.board.size():
		if ctx.board[i] == null: continue
		var cut := mini(impact_penalty_per_stack * status.stacks, ctx.buckets[i]["impact"])
		ctx.add_stat(i, "impact", -cut, status_name)
