# combo_dictionary.gd
extends Node

# ── Public entry point ────────────────────────────────────────────────

func calculate(results: Array[SymbolData]) -> Dictionary:
	# Pass 1: Check for defined combos first — they override everything
	var combo = _check_combos(results)
	if combo["is_combo"]:
		return combo
	
	# Pass 2: Resolve individually with multipliers applied positionally
	return _resolve_individual(results)

# ── Combo definitions ─────────────────────────────────────────────────

func _check_combos(results: Array[SymbolData]) -> Dictionary:
	var ids = results.map(func(s): return s.id)
	ids.sort()  # Order-independent matching
	
	match ids:
		["roi", "roi", "roi"]:
			return _combo("Quarterly Report", 15, 0, 0)
		["synergy", "synergy", "synergy"]:
			return _combo("Team Building Exercise", 0, 20, 0)
		["circle_back", "put_a_pin_in_it", "synergy"]:
			return _combo("Filibuster", 0, 30, 0)
		["pizza", "pizza", "pizza"]:
			return _combo("Employee Retention Initiative", 0, 0, 20)
		["ai", "ai", "pain_point"]:
			return _combo("Tech Startup Pitch", 40, 0, 0)
		["leverage", "roi", "synergy"]:
			return _combo("Q3 Earnings Call", 25, 0, 0)
		_:
			return { "is_combo": false }

# ── Individual resolution (no combo matched) ──────────────────────────

func _resolve_individual(results: Array[SymbolData]) -> Dictionary:
	# Initialise a value bucket per reel position
	# Each bucket: { impact, bandwidth, morale }
	var buckets := [
		{ "impact": 0, "bandwidth": 0, "morale": 0 },
		{ "impact": 0, "bandwidth": 0, "morale": 0 },
		{ "impact": 0, "bandwidth": 0, "morale": 0 },
	]
	
	# PASS 1: Fill base values for non-multiplier symbols
	for i in 3:
		var sym: SymbolData = results[i]
		match sym.effect_type:
			SymbolData.EffectType.DAMAGE:   buckets[i]["impact"]    = sym.base_value
			SymbolData.EffectType.SHIELD:   buckets[i]["bandwidth"] = sym.base_value
			SymbolData.EffectType.HEAL:     buckets[i]["morale"]    = sym.base_value
			SymbolData.EffectType.MULTIPLIER: pass  # Handled in pass 2
	
	# PASS 2: Apply multiplier effects positionally
	for i in 3:
		var sym: SymbolData = results[i]
		if sym.effect_type != SymbolData.EffectType.MULTIPLIER:
			continue
		match sym.id:
			"ai":
				# Double everything in the left neighbor's bucket
				if i > 0:
					buckets[i - 1]["impact"]    *= 2
					buckets[i - 1]["bandwidth"] *= 2
					buckets[i - 1]["morale"]    *= 2
			"leverage":
				# +3 IMPACT to every other non-zero-damage symbol
				for j in 3:
					if j != i and buckets[j]["impact"] > 0:
						buckets[j]["impact"] += 3
	
	# Sum totals across all buckets
	var total_impact    := 0
	var total_bandwidth := 0
	var total_morale    := 0
	for b in buckets:
		total_impact    += b["impact"]
		total_bandwidth += b["bandwidth"]
		total_morale    += b["morale"]
	
	return {
		"is_combo":  false,
		"name":      "",
		"impact":    total_impact,
		"bandwidth": total_bandwidth,
		"morale":    total_morale,
	}

# ── Helpers ───────────────────────────────────────────────────────────

func _combo(name: String, impact: int, bandwidth: int, morale: int) -> Dictionary:
	return { "is_combo": true, "name": name, "impact": impact, "bandwidth": bandwidth, "morale": morale }


func describe_symbol(sym: SymbolData) -> String:
	match sym.effect_type:
		SymbolData.EffectType.DAMAGE:
			return "[b][color=#ff6060]" + str(sym.base_value) + "[/color][/b][color=#cc4040] IMPACT[/color]"
		SymbolData.EffectType.SHIELD:
			return "[b][color=#60ccff]" + str(sym.base_value) + "[/color][/b][color=#4099bb] BANDWIDTH[/color]"
		SymbolData.EffectType.HEAL:
			return "[b][color=#60ee80]+" + str(sym.base_value) + "[/color][/b][color=#40aa60] MORALE[/color]"
		SymbolData.EffectType.MULTIPLIER:
			match sym.id:
				"ai":       return "[wave amp=6 freq=4][color=#ffd060][b]×2 ←[/b][/color][/wave]"
				"leverage": return "[wave amp=6 freq=4][color=#ffd060][b]+3 ALL[/b][/color][/wave]"
				_:          return "[color=#ffd060]MOD[/color]"
		_: return "[color=#888888]???[/color]"
