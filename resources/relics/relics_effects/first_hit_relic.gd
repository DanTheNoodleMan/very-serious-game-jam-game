# i.e. ("Plausible Deniability": first hit each fight is reduced) -> per-combat counter
class_name FirstHitRelic extends RelicData
@export var reduction: int = 5
func modify_damage_taken(status: ActiveStatus, amount: int) -> int:   # pure: only reads
	return amount if status.counter > 0 else maxi(amount - reduction, 0)

func on_damage_taken(status: ActiveStatus, combat: CombatContext, result: DamageResult) -> void:
	status.counter = 1
