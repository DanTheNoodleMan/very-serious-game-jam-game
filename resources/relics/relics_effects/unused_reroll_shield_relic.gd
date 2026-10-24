# i.e. ("Stress Ball": lock in with rerolls left, gain shield per reroll)
class_name UnusedRerollShieldRelic extends RelicData
@export var shield_per_reroll: int = 3

func on_lock_in(status: ActiveStatus, ctx: BattleContext) -> void:
	print("here")
	if ctx.combat == null or ctx.combat.rerolls_left <= 0: return
	print( ctx.combat.rerolls_left)
	var shield := ctx.combat.rerolls_left * shield_per_reroll
	ctx.combat.add_player_shield(shield)
	ctx.popup(-1, "+%d BW" % shield, ReelPopup.Style.SHIELD)
