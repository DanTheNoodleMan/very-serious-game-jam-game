# i.e ("Ergonomic Mouse": +1 reroll per turn)
class_name ExtraRerollsRelic extends RelicData
@export var extra_rerolls: int = 1

func modify_rerolls(status: ActiveStatus, rerolls: int) -> int:
	return rerolls + extra_rerolls
