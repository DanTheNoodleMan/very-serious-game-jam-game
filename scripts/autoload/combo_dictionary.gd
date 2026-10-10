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

const EFFECT_COLORS := {
	SymbolData.EffectType.DAMAGE:     Color(1.0, 0.376, 0.376),   # ff6060
	SymbolData.EffectType.SHIELD:     Color(0.376, 0.8, 1.0),     # 60ccff
	SymbolData.EffectType.HEAL:       Color(0.376, 0.933, 0.502), # 60ee80
	SymbolData.EffectType.MULTIPLIER: Color(1.0, 0.816, 0.376),   # ffd060
}
const EFFECT_COLORS_DIM := {
	SymbolData.EffectType.DAMAGE:     Color(0.8, 0.251, 0.251),   # cc4040
	SymbolData.EffectType.SHIELD:     Color(0.251, 0.6, 0.733),   # 4099bb
	SymbolData.EffectType.HEAL:       Color(0.251, 0.667, 0.376), # 40aa60
	SymbolData.EffectType.MULTIPLIER: Color(0.8, 0.663, 0.267),   # dim gold
}
const DEFAULT_COLOR := Color(0.4, 0.4, 0.5)
const MATH_ACCENT_COLOR := Color(1.0, 0.878, 0.4) # ffe066 for the math tooltip, not tied to any one effect type


# ── Public entry point ────────────────────────────────────────────────────────
func calculate(ctx: BattleContext) -> Dictionary:
	# 1. Have the effects modify the context's buckets
	_compute_buffed_buckets(ctx)
	for source in ctx.status_sources:
		source.modify_battle(ctx)
		
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
		ctx.buckets[i]["multiplier_bonus"] = 0
		ctx.buckets[i]["multiplier_scale"] = 1
		for stat in ["impact", "bandwidth", "morale"]:
			ctx.buckets[i][stat + "_add"] = 0
			ctx.buckets[i][stat + "_mult"] = 1
		if ctx.combat != null:
			for stat in ["impact", "bandwidth", "morale"]:
				var sources := ctx.combat.get_symbol_bonus_sources(ctx.board[i], stat)
				for source in sources:
					ctx.add_stat(i, stat, sources[source], source)

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
func describe_symbol(sym: SymbolData, short_labels: bool = true, combat: CombatContext = null) -> String:
	var stat := ""
	var base := 0
	var lbl := ""
	match sym.effect_type:
		SymbolData.EffectType.DAMAGE:
			stat = "impact"; base = sym.base_impact; lbl = "IM" if short_labels else "Impact"
		SymbolData.EffectType.SHIELD:
			stat = "bandwidth"; base = sym.base_bandwidth; lbl = "BW" if short_labels else "Bandwidth"
		SymbolData.EffectType.HEAL:
			stat = "morale"; base = sym.base_morale; lbl = "MO" if short_labels else "Morale"
		SymbolData.EffectType.MULTIPLIER:
			if sym.effect: return sym.effect.get_description()
			return "[color=%s]MOD[/color]" % get_effect_color_hex(sym.effect_type)
		_:
			return "[color=#888888]???[/color]"

	var bonus := combat.get_symbol_bonus(sym, stat) if combat != null else 0
	var val_color := "#ffe066" if bonus > 0 else get_effect_color_hex(sym.effect_type)
	return "[b][color=%s]%d[/color][/b][color=%s] %s[/color]" % [val_color, base + bonus, get_effect_color_dim_hex(sym.effect_type), lbl]

# ComboDictionary.gd
func build_card_description(sym: SymbolData) -> String:
	var lines: Array[String] = []

	if sym.effect_type == SymbolData.EffectType.MULTIPLIER:
		# Multiplier symbols have no base stat of their own — the effect description IS the identity
		if sym.effect != null:
			lines.append(sym.effect.get_description())
		else:
			lines.append("[color=%s]MOD[/color]" % get_effect_color_hex(sym.effect_type))
	else:
		# Every other symbol: colored base-stat line first (reusing describe_symbol,
		# so this looks identical to the reel label styling), then any extra behavior below it
		lines.append(describe_symbol(sym, false))
		if sym.effect != null:
			var extra := sym.effect.get_description()
			if extra != "":
				lines.append("[font_size=9][color=#99a3c2]%s[/color][/font_size]" % extra)
		elif sym.flavor_text != "":
			# the only way to give this symbol any hover text
			lines.append("[font_size=9][i][color=#6b7593]%s[/color][/i][/font_size]" % sym.flavor_text)

	return "\n".join(lines) if not lines.is_empty() else "[color=#888888]No effect[/color]"

func get_label_for_position(ctx: BattleContext, index: int) -> String:
	var sym: SymbolData = ctx.board[index]
	if sym == null: return ""

	if sym.effect_type == SymbolData.EffectType.MULTIPLIER:
		if sym.effect: return sym.effect.get_contextual_label(index, ctx)
		return "[color=%s]MOD[/color]" % get_effect_color_hex(SymbolData.EffectType.MULTIPLIER)

	var b: Dictionary = ctx.buckets[index]
	var parts: Array[String] = []

	if b["impact"] > 0:
		parts.append(_format_stat_line(b["impact"], sym.base_impact, get_stat_color_hex("impact"), get_stat_color_dim_hex("impact"), "IM"))
	if b["bandwidth"] > 0:
		parts.append(_format_stat_line(b["bandwidth"], sym.base_bandwidth, get_stat_color_hex("bandwidth"), get_stat_color_dim_hex("bandwidth"), "BW"))
	if b["morale"] > 0:
		parts.append(_format_stat_line(b["morale"], sym.base_morale, get_stat_color_hex("morale"), get_stat_color_dim_hex("morale"), "MO"))

	return " ".join(parts) if not parts.is_empty() else "[color=#444455]—[/color]"


func _format_stat_line(final_value: int, base_value: int, val_color: String, tag_color: String, short_label: String) -> String:
	var line := "[b][color=%s]%d[/color][/b][color=%s] %s[/color]" % [val_color, final_value, tag_color, short_label]
	if final_value != base_value:
		#line += " [font_size=11][color=#ffe066]*[/color][/font_size]"  # small dot = "this is modified", nothing more
		line = "[b][color=%s]%d[/color][/b][color=%s] %s[/color]" % ["#ffe066", final_value, tag_color, short_label]
	return line

func build_tooltip_for_position(ctx: BattleContext, index: int) -> String:
	var sym: SymbolData = ctx.board[index]
	if sym == null: return ""

	var blocks: Array[String] = []
	_append_stat_block(blocks, ctx, index, "impact", sym.base_impact, "Impact")
	_append_stat_block(blocks, ctx, index, "bandwidth", sym.base_bandwidth, "Bandwidth")
	_append_stat_block(blocks, ctx, index, "morale", sym.base_morale, "Morale")
	return "\n\n".join(blocks) if not blocks.is_empty() else "[color=#888888]No modifiers this spin.[/color]"

func _append_stat_block(blocks: Array[String], ctx: BattleContext, index: int, stat: String, base_value: int, label: String) -> void:
	var final_value: int = ctx.buckets[index][stat]
	var steps: Array = ctx.stat_logs[index][stat]
	if steps.is_empty(): return

	var color := get_stat_color_hex(stat)
	var lines: Array[String] = ["[b][color=%s]%s[/color][/b]  Base %d" % [color, label, base_value]]
	for step in steps:
		lines.append("  [color=#ffe066]%s[/color]" % step)
	lines.append("[b]= %d[/b]" % final_value)
	blocks.append("\n".join(lines))
	
	
# ── COLOR SECTION ──────────────────────────────────────────────────────────
func get_effect_color(effect_type) -> Color:
	return EFFECT_COLORS.get(effect_type, DEFAULT_COLOR)

func get_effect_color_dim(effect_type) -> Color:
	return EFFECT_COLORS_DIM.get(effect_type, DEFAULT_COLOR)

func get_effect_color_hex(effect_type) -> String:
	return "#" + get_effect_color(effect_type).to_html(false)

func get_effect_color_dim_hex(effect_type) -> String:
	return "#" + get_effect_color_dim(effect_type).to_html(false)

# Route stat coloring through the same table instead of maintaining a second mapping
func get_stat_color_hex(stat: String) -> String:
	match stat:
		"impact": return get_effect_color_hex(SymbolData.EffectType.DAMAGE)
		"bandwidth": return get_effect_color_hex(SymbolData.EffectType.SHIELD)
		"morale": return get_effect_color_hex(SymbolData.EffectType.HEAL)
		_: return "#888888"

func get_stat_color_dim_hex(stat: String) -> String:
	match stat:
		"impact": return get_effect_color_dim_hex(SymbolData.EffectType.DAMAGE)
		"bandwidth": return get_effect_color_dim_hex(SymbolData.EffectType.SHIELD)
		"morale": return get_effect_color_dim_hex(SymbolData.EffectType.HEAL)
		_: return "#888888"
