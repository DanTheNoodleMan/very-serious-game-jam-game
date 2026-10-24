# i.e. ("Expense Account": +5 Petty Cash per fight)
class_name CashBonusRelic extends RelicData
@export var bonus: int = 5

func modify_cash_gain(status: ActiveStatus, amount: int) -> int:
	return amount + bonus
