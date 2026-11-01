class_name RewardOption extends RefCounted
## One clickable choice on the reward screen. It knows how to describe and apply itself,
## so neither the screen nor BattleManager ever switches on a "type" string.

enum Kind { ADD_SYMBOL, UPGRADE_SYMBOL, REMOVE_SYMBOL, HEAL, GAIN_RELIC }

var kind: Kind
var title := ""
var icon: Texture2D
## ADD_SYMBOL: the LIBRARY symbol (copied on apply).
## UPGRADE_SYMBOL / REMOVE_SYMBOL: the run's own instance.
var symbol: SymbolData
var relic: RelicData
var amount := 0


# ---- Factories ---------------------------------------------------------------
static func hire(sym: SymbolData) -> RewardOption:
	var o := RewardOption.new()
	o.kind = Kind.ADD_SYMBOL
	o.title = "HIRE"
	o.symbol = sym
	o.icon = sym.icon
	return o

static func promote(sym: SymbolData) -> RewardOption:
	var o := RewardOption.new()
	o.kind = Kind.UPGRADE_SYMBOL
	o.title = "PROMOTE"
	o.symbol = sym
	o.icon = sym.icon
	return o

static func lay_off(sym: SymbolData) -> RewardOption:
	var o := RewardOption.new()
	o.kind = Kind.REMOVE_SYMBOL
	o.title = "LAY OFF"
	o.symbol = sym
	o.icon = sym.icon
	return o

static func personal_day(heal_amount: int) -> RewardOption:
	var o := RewardOption.new()
	o.kind = Kind.HEAL
	o.title = "PERSONAL DAY"
	o.amount = heal_amount
	return o

static func policy(r: RelicData) -> RewardOption:
	var o := RewardOption.new()
	o.kind = Kind.GAIN_RELIC
	o.title = "COMPANY POLICY"
	o.relic = r
	o.icon = r.icon
	return o


# ---- Rules ---------------------------------------------------------------------
## Hiring into a full roster means someone has to go: the screen asks "who gets laid off?"
func needs_layoff(run: RunState) -> bool:
	return kind == Kind.ADD_SYMBOL and run.is_full()


func apply(run: RunState, replace: SymbolData = null) -> void:
	match kind:
		Kind.ADD_SYMBOL:
			# Never hand out the library instance: upgrades/scaling would mutate the shared resource.
			var hired := symbol.clone_for_run()
			if replace != null:
				run.replace_symbol(replace, hired)
			else:
				run.add_symbol(hired)
		Kind.UPGRADE_SYMBOL:
			symbol.get_upgrade().apply(symbol)
			run.pool_changed.emit()                      # roster UI refresh
			ComboDictionary.dictionary_updated.emit()
		Kind.REMOVE_SYMBOL:
			run.remove_symbol(symbol)
		Kind.HEAL:
			run.heal(amount)
		Kind.GAIN_RELIC:
			run.add_relic(relic)


# ---- Presentation ----------------------------------------------------------------
func describe() -> String:
	match kind:
		Kind.ADD_SYMBOL:
			var dept_line := ""
			if symbol.department != SymbolData.Department.NONE:
				dept_line = "\n[font_size=9][color=#99a3c2]%s[/color][/font_size]" % symbol.get_department_name()
			return "%s%s\n%s" % [_name_tag(symbol), dept_line, ComboDictionary.build_card_description(symbol)]
		Kind.UPGRADE_SYMBOL:
			return "%s\n(%s)%s" % [_name_tag(symbol), symbol.get_upgrade().preview(symbol), _effect_line(symbol)]
		Kind.REMOVE_SYMBOL:
			return "%s\n%s" % [_name_tag(symbol), ComboDictionary.build_card_description(symbol)]
		Kind.HEAL:
			return "[color=#60ee80]Restore [b]%d[/b] Morale[/color]" % amount
		Kind.GAIN_RELIC:
			return "[b][color=#ffd060]%s[/color][/b]\n%s" % [relic.status_name, relic.description]
	return ""


## The symbol's special ability as small text under the card's main line ("" if it has none).
func _effect_line(sym: SymbolData) -> String:
	if sym.effect == null:
		return ""
	var text := sym.effect.get_description()
	if text == "":
		return ""
	return "\n[font_size=9][color=#99a3c2]%s[/color][/font_size]" % text


func _name_tag(sym: SymbolData) -> String:
	return "[wave amp=2 freq=6.0][b][color=%s]%s[/color][/b][/wave]" % [
		ComboDictionary.get_effect_color_hex(sym.effect_type), sym.symbol_name.to_upper()]


# ---- Card data (read by RewardCard) -------------------------------------------------
## Everything a card needs, as plain data. The card shows the FULL description of a symbol
## (stat line + effect text), so players can compare options without hovering.
func get_card(run: RunState) -> Dictionary:
	match kind:
		Kind.ADD_SYMBOL:
			var owned := 0
			for s in run.symbol_pool:
				if s.id == symbol.id:
					owned += 1
			var footer := ""
			if owned > 0:
				footer = "[color=#99a3c2]You own %d[/color]" % owned
			if run.is_full():
				footer += ("\n" if footer != "" else "") + "[color=#cc5555]Roster full: swap someone out[/color]"
			return _symbol_card("NEW HIRE", "#9fb3ff", symbol, ComboDictionary.build_card_description(symbol), footer)
		Kind.UPGRADE_SYMBOL:
			var body := "%s\n\n%s" % [symbol.get_upgrade().preview(symbol), ComboDictionary.build_card_description(symbol)]
			var footer := "[color=#99a3c2]Level %d to %d of %d[/color]" % [symbol.upgrade_level, symbol.upgrade_level + 1, symbol.max_upgrade_level]
			return _symbol_card("PROMOTION", "#ffd060", symbol, body, footer)
		Kind.REMOVE_SYMBOL:
			return _symbol_card("LAY OFF", "#cc5555", symbol, ComboDictionary.build_card_description(symbol), "")
		Kind.HEAL:
			return {
				"kicker": "PERSONAL DAY", "kicker_color": "#60ee80", "accent": Color("#60ee80"),
				"icon": null, "name": "REST", "name_color": "#60ee80", "tag": "",
				"body": "Restore [b]%d[/b] Morale" % amount, "footer": "",
			}
		Kind.GAIN_RELIC:
			return {
				"kicker": "COMPANY POLICY", "kicker_color": "#ffd060", "accent": Color("#ffd060"),
				"icon": relic.icon, "name": relic.status_name.to_upper(), "name_color": "#ffd060",
				"tag": RelicData.Rarity.keys()[relic.rarity], "body": relic.description, "footer": "",
			}
	return {}


func _symbol_card(kicker: String, kicker_color: String, sym: SymbolData, body: String, footer: String) -> Dictionary:
	var tag_parts: Array[String] = []
	if sym.department != SymbolData.Department.NONE:
		tag_parts.append(sym.get_department_name())
	if sym.upgrade_level > 0:
		tag_parts.append("LV %d" % sym.upgrade_level)
	return {
		"kicker": kicker, "kicker_color": kicker_color,
		"accent": ComboDictionary.get_effect_color(sym.effect_type),
		"icon": sym.icon,
		"name": sym.symbol_name.to_upper(),
		"name_color": ComboDictionary.get_effect_color_hex(sym.effect_type),
		"tag": " / ".join(tag_parts), "body": body, "footer": footer,
	}
