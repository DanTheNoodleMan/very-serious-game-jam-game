# i.e. ("Quarterly Bonus")  -> get money every N nodes, per-run state
class_name QuarterlyBonusRelic extends RelicData
@export var every: int = 3
@export var cash: int = 15
func on_combat_end(status: ActiveStatus, combat: CombatContext, victory: bool) -> void:
	if not victory: return
	var n: int = get_value(combat.run, "fights") + 1
	if n >= every:
		combat.run.add_cash(cash)
		n = 0
	set_value(combat.run, "fights", n)
