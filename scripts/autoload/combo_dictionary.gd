extends Node

signal dictionary_updated

@export var all_symbols: Array[SymbolData] = []

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
func calculate(ctx: BattleContext) -> Dictionary:
	# 1. Have the effects modify the context's buckets
	_compute_buffed_buckets(ctx)

	# 2. Check for combos
	var combo = _check_combos(ctx.board)
	
	# 3. Tally everything up
	var base_impact = 0; var base_bw = 0; var base_mo = 0
	var final_impact = 0; var final_bw = 0; var final_mo = 0
	
	for i in 3:
		if ctx.board[i] != null:
			base_impact += ctx.board[i].base_impact
			base_bw += ctx.board[i].base_bandwidth
			base_mo += ctx.board[i].base_morale
			
		final_impact += ctx.buckets[i].impact
		final_bw += ctx.buckets[i].bandwidth
		final_mo += ctx.buckets[i].morale
		
	var final_name = ""
	if combo.is_combo:
		final_name = combo.name
		final_impact += combo.bonus_impact
		final_bw += combo.bonus_bandwidth
		final_mo += combo.bonus_morale

	return {
		"is_combo": combo.is_combo, "name": final_name,
		"impact": final_impact, "base_impact": base_impact,
		"bandwidth": final_bw, "base_bandwidth": base_bw,
		"morale": final_mo, "base_morale": base_mo
	}

func get_all_combos() -> Array: return COMBOS

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

# ── Bucket computation ─────────────────────────────────────────
func _compute_raw_buckets(ctx: BattleContext) -> void:
	for i in 3:
		if ctx.board[i] == null: continue
		ctx.buckets[i]["impact"]    = ctx.board[i].base_impact
		ctx.buckets[i]["bandwidth"] = ctx.board[i].base_bandwidth
		ctx.buckets[i]["morale"]    = ctx.board[i].base_morale

func _compute_buffed_buckets(ctx: BattleContext) -> void:
	_compute_raw_buckets(ctx) # Fill with base stats first
	
	var active_effects: Array = []
	for i in 3:
		if ctx.board[i] != null and ctx.board[i].effect != null:
			active_effects.append({"index": i, "effect": ctx.board[i].effect})
			
	# Sort by priority, then by index descending (Right-to-Left execution)
	active_effects.sort_custom(func(a, b):
		if a.effect.priority == b.effect.priority:
			return a.index > b.index
		return a.effect.priority < b.effect.priority
	)
	
	# Execute scripts
	for item in active_effects:
		item.effect.apply_effect(item.index, ctx)
	

# ── Label Generation ──────────────────────────────────────────────────────────
func describe_symbol(sym: SymbolData) -> String:
	match sym.effect_type:
		SymbolData.EffectType.DAMAGE: return "[b][color=#ff6060]" + str(sym.base_impact) + "[/color][/b][color=#cc4040] IMPACT[/color]"
		SymbolData.EffectType.SHIELD: return "[b][color=#60ccff]" + str(sym.base_bandwidth) + "[/color][/b][color=#4099bb] BW[/color]"
		SymbolData.EffectType.HEAL: return "[b][color=#60ee80]+" + str(sym.base_morale) + "[/color][/b][color=#40aa60] MORALE[/color]"
		SymbolData.EffectType.MULTIPLIER:
			if sym.effect: return sym.effect.get_description()
			return "[color=#ffd060]MOD[/color]"
		_: return "[color=#888888]???[/color]"

func get_label_for_position(ctx: BattleContext, index: int) -> String:
	var sym: SymbolData = ctx.board[index]
	if sym == null: return ""

	if sym.effect_type == SymbolData.EffectType.MULTIPLIER:
		_compute_buffed_buckets(ctx) # Calculate context so multiplier powers are ready
		if sym.effect: return sym.effect.get_contextual_label(index, ctx)
		return "[color=#ffd060]MOD[/color]"

	_compute_buffed_buckets(ctx)
	var b: Dictionary = ctx.buckets[index]

	var parts: Array[String] = []
	if b["impact"] > 0: parts.append("[b][color=#ff6060]" + str(b["impact"]) + "[/color][/b][color=#cc4040] IMPACT[/color]")
	if b["bandwidth"] > 0: parts.append("[b][color=#60ccff]" + str(b["bandwidth"]) + "[/color][/b][color=#4099bb] BW[/color]")
	if b["morale"] > 0: parts.append("[b][color=#60ee80]+" + str(b["morale"]) + "[/color][/b][color=#40aa60] MORALE[/color]")

	return " + ".join(parts) if not parts.is_empty() else "[color=#444455]—[/color]"
