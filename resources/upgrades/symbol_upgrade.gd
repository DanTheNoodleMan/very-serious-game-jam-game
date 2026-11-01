class_name SymbolUpgrade extends Resource
## What "promoting" a symbol does. The base class is the default: a flat bump to the symbol's
## primary stat (Impact / Bandwidth / Morale). Subclass it (see EffectUpgrade) for anything else.
##
## It is a DEFINITION: no per-copy state lives here. apply() mutates the symbol it is given,
## so only ever pass the RUN'S OWN instance, never a library one.

## One entry per promotion level: [2, 1] = the 1st promotion gives +2, the 2nd gives +1.
## The last entry repeats if a symbol allows more levels than there are entries.
## Tune each symbol by giving it its own SymbolUpgrade resource (SymbolData.upgrade).
@export var amounts: PackedInt32Array = [2, 1]


func amount_for(sym: SymbolData) -> int:
	if amounts.is_empty():
		return 0
	return amounts[mini(sym.upgrade_level, amounts.size() - 1)]


func _stat_for(sym: SymbolData) -> String:
	match sym.effect_type:
		SymbolData.EffectType.DAMAGE: return "impact"
		SymbolData.EffectType.SHIELD: return "bandwidth"
		SymbolData.EffectType.HEAL: return "morale"
	return ""


func can_apply(sym: SymbolData) -> bool:
	return _stat_for(sym) != ""


func apply(sym: SymbolData) -> void:
	var prop := "base_" + _stat_for(sym)
	sym.set(prop, sym.get(prop) + amount_for(sym))
	sym.upgrade_level += 1


## BBCode shown on the reward card	
func preview(sym: SymbolData) -> String:
	var stat := _stat_for(sym)
	var old: int = sym.get("base_" + stat)
	return "[color=%s]%s[/color]  [color=#888888]%d[/color][color=#ffd060] → [b]%d[/b][/color]" % [
		ComboDictionary.get_stat_color_hex(stat), stat.to_upper(), old, old + amount_for(sym)]
