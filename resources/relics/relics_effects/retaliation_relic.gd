# i.e.  ("Passive-Aggressive Email")  -> basically thorns, on_damage_taken
class_name RetaliationRelic extends RelicData
@export var damage: int = 3

func on_damage_taken(status: ActiveStatus, combat: CombatContext, result: DamageResult) -> void:
	if result.source != "" or result.hp_damage <= 0: return   # ignore status damage, no loops
	combat.damage_enemy(damage, true, status_name)            # source set, so it shows via passive_damage
