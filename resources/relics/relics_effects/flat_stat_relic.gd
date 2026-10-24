# i.e. ("Motivational Poster": +1 [stat] on every symbol that has said stat)
class_name FlatStatRelic extends RelicData
@export_enum("impact", "bandwidth", "morale") var stat: String = "impact"
@export var amount: int = 1

func modify_battle(status: ActiveStatus, ctx: BattleContext) -> void:
	for i in ctx.board.size():
		if ctx.board[i] != null and ctx.buckets[i][stat] > 0:
			ctx.add_stat(i, stat, amount, status_name)
