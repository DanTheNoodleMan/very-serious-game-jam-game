class_name EffectUpgrade extends SymbolUpgrade
## Upgrade for symbols whose power lives in their SymbolEffect (multipliers, buffs...).
## The effect decides what "upgrade" means, so there's no `is MultiplyLeftEffect` chain anywhere.


func can_apply(sym: SymbolData) -> bool:
	return sym.effect != null and sym.effect.can_upgrade()


func apply(sym: SymbolData) -> void:
	sym.effect.upgrade()
	sym.upgrade_level += 1


func preview(sym: SymbolData) -> String:
	return sym.effect.get_upgrade_preview()
