class_name ExposedStatus extends StatusEffect
@export var bonus_percent: int = 50

func modify_damage_taken(status: ActiveStatus, amount: int) -> int:
	return amount + amount * bonus_percent / 100
