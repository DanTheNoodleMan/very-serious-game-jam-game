extends Node

signal dictionary_updated

@export var all_symbols: Array[SymbolData] = []

# Combos now provide a flat BONUS on top of the multiplied individual symbols!
const COMBOS: Array = [
	{
		"name": "Quarterly Report",
		"symbol_ids": ["roi", "roi", "roi"],
		"bonus_impact": 13, "bonus_bandwidth": 0, "bonus_morale": 0
		# Math: (4+4+4) + 13 = 25 Damage
	},
	{
		"name": "Team Building Exercise",
		"symbol_ids": ["synergy", "synergy", "synergy"],
		"bonus_impact": 5, "bonus_bandwidth": 11, "bonus_morale": 5
		# Math: (3+3+3 BW) + 11 BW = 20 Shield + 5 Damage + 5 Heal. Great utility
	},
	{
		"name": "Filibuster",
		"symbol_ids": ["circle_back", "circle_back", "circle_back"],
		"bonus_impact": 0, "bonus_bandwidth": 25, "bonus_morale": 10
		# Math: (6+6+6) + 22 = 40 Shield + 10 Heal
	},
	{
		"name": "Pizza Friday",
		"symbol_ids": ["pizza", "pizza", "pizza"],
		"bonus_impact": 10, "bonus_bandwidth": 0, "bonus_morale": 15
		# Math: (5+5+5) + 15 = 30 Heal + 10 Damage. 
	},
	{
		"name": "Hostile Takeover",
		"symbol_ids": ["disruptor", "pain_point", "roi"],
		"bonus_impact": 19, "bonus_bandwidth": 0, "bonus_morale": 0
		# Math: (10+7+4) + 19 = 40 Damage. A massive, hard-to-roll straight.
	},
	{
		"name": "Tech Startup Pitch",
		"symbol_ids": ["disruptor", "ai", "ai"],
		"bonus_impact": 20, "bonus_bandwidth": 0, "bonus_morale": 0
		# Math: Disruptor(10) * AI(2) * AI(2) = 40. + 20 Bonus = 60 Damage. The Holy Grail of damage
	},
	{
		"name": "Q3 Earnings Call",
		"symbol_ids": ["leverage", "roi", "synergy"],
		"bonus_impact": 12, "bonus_bandwidth": 5, "bonus_morale": 0
		# Math: ROI(4+4=8), Syn(3+4=7). Bonus (+12 Im, +5 BW). Total = 20 Damage, 12 Shield.
	},
]

# ── Public entry point ────────────────────────────────────────────────────────
func calculate(results: Array[SymbolData]) -> Dictionary:
	var raw_buckets = _compute_raw_buckets(results)
	var buffed_buckets = _compute_buffed_buckets(results)
	var combo = _check_combos(results)

	var base_impact = 0; var base_bw = 0; var base_mo = 0
	for b in raw_buckets:
		base_impact += b.impact; base_bw += b.bandwidth; base_mo += b.morale

	var final_impact = 0; var final_bw = 0; var final_mo = 0
	for b in buffed_buckets:
		final_impact += b.impact; final_bw += b.bandwidth; final_mo += b.morale

	var final_name = ""
	if combo.is_combo:
		final_name = combo.name
		# Add the combo bonus on top of the multipliers!
		final_impact += combo.bonus_impact
		final_bw += combo.bonus_bandwidth
		final_mo += combo.bonus_morale

	return {
		"is_combo": combo.is_combo,
		"name": final_name,
		"impact": final_impact, "base_impact": base_impact,
		"bandwidth": final_bw, "base_bandwidth": base_bw,
		"morale": final_mo, "base_morale": base_mo
	}

func get_all_combos() -> Array:
	return COMBOS

# ── Combo checking ────────────────────────────────────────────────────────────
func _check_combos(results: Array[SymbolData]) -> Dictionary:
	var ids = results.map(func(s): return s.id if s != null else "")
	ids.sort()
	for combo in COMBOS:
		var combo_ids: Array = combo["symbol_ids"].duplicate()
		combo_ids.sort()
		if ids == combo_ids:
			return {
				"is_combo": true, "name": combo["name"],
				"bonus_impact": combo["bonus_impact"],
				"bonus_bandwidth": combo["bonus_bandwidth"],
				"bonus_morale": combo["bonus_morale"]
			}
	return { "is_combo": false }

# ── Bucket computation (The Math Fix) ─────────────────────────────────────────
func _compute_raw_buckets(results: Array[SymbolData]) -> Array:
	var buckets := [
		{ "impact": 0, "bandwidth": 0, "morale": 0 },
		{ "impact": 0, "bandwidth": 0, "morale": 0 },
		{ "impact": 0, "bandwidth": 0, "morale": 0 },
	]
	for i in 3:
		if results[i] == null: continue
		match results[i].effect_type:
			SymbolData.EffectType.DAMAGE:     buckets[i]["impact"]    = results[i].base_value
			SymbolData.EffectType.SHIELD:     buckets[i]["bandwidth"] = results[i].base_value
			SymbolData.EffectType.HEAL:       buckets[i]["morale"]    = results[i].base_value
			SymbolData.EffectType.MULTIPLIER: pass
	return buckets

func _compute_buffed_buckets(results: Array[SymbolData]) -> Array:
	var buckets = _compute_raw_buckets(results) # Start with base values

	# Leverage adds to all non-multiplier buckets (AI boost handled in _compute_ai_powers)
	for i in 3:
		if results[i] != null and results[i].id == "leverage":
			var lev_buff = results[i].base_value
			for j in 3:
				if j != i and results[j] != null:
					match results[j].effect_type:
						SymbolData.EffectType.DAMAGE: buckets[j]["impact"] += lev_buff
						SymbolData.EffectType.SHIELD: buckets[j]["bandwidth"] += lev_buff
						SymbolData.EffectType.HEAL:   buckets[j]["morale"] += lev_buff
						SymbolData.EffectType.MULTIPLIER: pass  # AI handled separately

	# AI doubles its immediate left neighbor, if Leverage, it's wasted
	var ai_power := _compute_ai_powers(results)
	for i in range(1, 3):
		if results[i] != null and results[i].id == "ai":
			var left := results[i - 1]
			if left != null and left.effect_type != SymbolData.EffectType.MULTIPLIER:
				buckets[i-1]["impact"]    = int(buckets[i-1]["impact"]    * ai_power[i])
				buckets[i-1]["bandwidth"] = int(buckets[i-1]["bandwidth"] * ai_power[i])
				buckets[i-1]["morale"]    = int(buckets[i-1]["morale"]    * ai_power[i])
	
	return buckets

func _compute_ai_powers(results: Array[SymbolData]) -> Array[float]:
	var ai_power: Array[float] = [1.0, 1.0, 1.0]
	# Base AI power
	for i in 3:
		if results[i] != null and results[i].id == "ai":
			ai_power[i] = float(results[i].base_value)
			
	# Leverage anywhere boosts ALL AIs
	for i in 3:
		if results[i] != null and results[i].id == "leverage":
			for j in 3:
				if j != i and results[j] != null and results[j].id == "ai":
					ai_power[j] += float(results[i].base_value)
	# Chain AI×AI right-to-left (after leverage is applied)
	for i in range(2, 0, -1):
		if results[i] != null and results[i-1] != null:
			if results[i].id == "ai" and results[i-1].id == "ai":
				ai_power[i-1] *= ai_power[i]
	return ai_power

# ── Label Generation ──────────────────────────────────────────────────────────
func describe_symbol(sym: SymbolData) -> String:
	match sym.effect_type:
		SymbolData.EffectType.DAMAGE:
			return "[b][color=#ff6060]" + str(sym.base_value) + "[/color][/b][color=#cc4040] IMPACT[/color]"
		SymbolData.EffectType.SHIELD:
			return "[b][color=#60ccff]" + str(sym.base_value) + "[/color][/b][color=#4099bb] BW[/color]"
		SymbolData.EffectType.HEAL:
			return "[b][color=#60ee80]+" + str(sym.base_value) + "[/color][/b][color=#40aa60] MORALE[/color]"
		SymbolData.EffectType.MULTIPLIER:
			match sym.id:
				"ai":       return "[wave amp=6 freq=4][color=#ffd060][b]×" + str(sym.base_value) \
				+ " ← [/b][/color][color=#ff6060]I[/color][color=#60ccff]B[/color][color=#60ee80]M[/color][/wave]"
				"leverage": return "[wave amp=6 freq=4][color=#ffd060][b]+" + str(sym.base_value) + " ALL[/b][/color][/wave]"
				_:          return "[color=#ffd060]MOD[/color]"
		_: return "[color=#888888]???[/color]"

func get_label_for_position(results: Array[SymbolData], index: int) -> String:
	var sym: SymbolData = results[index]
	if sym == null: return ""

	if sym.effect_type == SymbolData.EffectType.MULTIPLIER:
		return _describe_multiplier_in_context(results, index)

	var buckets := _compute_raw_buckets(results)
	var b: Dictionary = buckets[index]

	var parts: Array[String] = []
	if b["impact"] > 0:
		parts.append("[b][color=#ff6060]" + str(b["impact"]) + "[/color][/b][color=#cc4040] IMPACT[/color]")
	if b["bandwidth"] > 0:
		parts.append("[b][color=#60ccff]" + str(b["bandwidth"]) + "[/color][/b][color=#4099bb] BW[/color]")
	if b["morale"] > 0:
		parts.append("[b][color=#60ee80]" + str(b["morale"]) + "[/color][/b][color=#40aa60] MORALE[/color]")

	return " + ".join(parts) if not parts.is_empty() else "[color=#444455]—[/color]"

func _describe_multiplier_in_context(results: Array[SymbolData], index: int) -> String:
	match results[index].id:
		"ai":
			if index == 0:       
				return "[color=#555566]×2 ← [color=#ff6060]I[/color][color=#60ccff]B[/color][color=#60ee80]M[/color] (miss)[/color]"
			var ai_power := _compute_ai_powers(results)
			var power := int(ai_power[index])
			var left := results[index - 1]
			var ibm := " [font_size=10][color=#ff6060]I[/color][color=#60ccff]B[/color][color=#60ee80]M[/color][/font_size]"
			if left != null and left.effect_type == SymbolData.EffectType.MULTIPLIER:
				if left.id == "ai":
					return "[color=#555566]×" + str(power) + " ←" + ibm + " (spent on " + left.symbol_name.to_upper() + ")[/color]"
				else:
					return "[color=#555566]×" + str(power) + " ←" + ibm + " (wasted on " + left.symbol_name.to_upper() + ")[/color]"
			var boosted_by_lev := false
			for j in 3:
				if j != index and results[j] != null and results[j].id == "leverage":
					boosted_by_lev = true
			if boosted_by_lev and power != int(results[index].base_value):
				return "[b][color=#ffd060]×" + str(power) + " ←" + ibm + "[/color][/b][color=#ffd060] (+LEV)[/color]"
			return "[b][color=#ffd060]×" + str(power) + " ←" + ibm + "[/color][/b]"
		"leverage":
			var lev_buff := results[index].base_value
			var has_any_target := false
			for j in 3:
				if j != index and results[j] != null:
					has_any_target = true
			if not has_any_target:
				return "[color=#555566]+" + str(lev_buff) + " (miss)[/color]"
			return "[b][color=#ffd060]+" + str(lev_buff) + " ALL[/color][/b]"
		_:
			return "[color=#ffd060]MOD[/color]"
