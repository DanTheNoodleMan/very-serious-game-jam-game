# i.e. ("Hard Hat": take 2 less from every hit)
class_name DamageReductionRelic extends RelicData
@export var reduction: int = 2

func modify_damage_taken(status: ActiveStatus, amount: int) -> int:
	return maxi(amount - reduction, 0)
