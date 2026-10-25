# i.e.  ("PR Spin")  -> Whenever your shield perfectly absorbs an attack, gain +$5 Petty Cash
class_name PerfectShieldAbsorbRelic extends RelicData
@export var cash_gain: int = 5

func on_damage_taken(status: ActiveStatus, combat: CombatContext, result: DamageResult) -> void:
	if result.exact_break == true:
		combat.run.add_cash(cash_gain)
		combat.popup_requested.emit("[b][color=#ffd060]+$%d![/color][/b]" % cash_gain, 0)
