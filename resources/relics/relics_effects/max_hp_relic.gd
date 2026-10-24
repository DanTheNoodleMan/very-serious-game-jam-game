# i.e.  ("Signing Bonus")  -> get maxhp on_acquired
class_name MaxHpRelic extends RelicData
@export var amount: int = 10
func on_acquired(run: RunState) -> void:
	run.max_hp += amount
	run.heal(amount)
