# i.e. ("Catered Lunch")  -> heal on_combat_end
class_name HealOnWinRelic extends RelicData
@export var heal: int = 6
func on_combat_end(status: ActiveStatus, combat: CombatContext, victory: bool) -> void:
	if victory: combat.heal_player(heal)
