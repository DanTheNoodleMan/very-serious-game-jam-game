extends Button

signal chosen(type: String, data: Variant)

@onready var title_label: RichTextLabel = %Title
@onready var icon_rect: TextureRect = %Icon
@onready var desc_label: RichTextLabel = %Description
@onready var panel_container: PanelContainer = $MarginContainer/VBoxContainer/PanelContainer

var _type: String
var _data: Variant

func setup(opt: Dictionary) -> void:
	_type = opt["type"]
	_data = opt["data"]
	title_label.text = opt["title"]
	pressed.connect(func(): chosen.emit(_type, _data))
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.scroll_active = false

	match _type:
		"add":
			var sym := _data as SymbolData
			icon_rect.texture = sym.icon
			icon_rect.visible = true
			desc_label.text = _build_symbol_desc(sym)
		"remove":
			var sym := _data as SymbolData
			icon_rect.texture = sym.icon
			icon_rect.visible = true
			desc_label.text = _build_remove_desc(sym)
		"upgrade_normal":
			var sym := _data as SymbolData
			icon_rect.texture = sym.icon
			icon_rect.visible = true
			desc_label.text = _build_upgrade_desc(sym, 4)
		"upgrade_multiplier":
			var sym := _data as SymbolData
			icon_rect.texture = sym.icon
			icon_rect.visible = true
			desc_label.text = _build_upgrade_desc(sym, 2)
		"reroll":
			icon_rect.visible = true
			panel_container.modulate = Color(0, 0, 0, 0.0)
			desc_label.text = "[color=#fff]Gain [color=#aaccff][b]+1 REROLL[/b][/color] per turn[/color]"

func _build_symbol_desc(sym: SymbolData) -> String:
	var name_color := _get_name_color(sym)
	var effect := ComboDictionary.describe_symbol(sym)
	return "[color=#fff]ADD [/color][wave amp=2 freq=6.0][b][color=" + name_color + "]" \
		+ sym.symbol_name.to_upper() + "[/color][/b][/wave]\n(" + effect + ")"

func _build_remove_desc(sym: SymbolData) -> String:
	var name_color := _get_name_color(sym)
	var effect := ComboDictionary.describe_symbol(sym)
	return "[color=#cc5555]REMOVE [/color][wave amp=2 freq=6.0][b][color=" + name_color + "]" \
		+ sym.symbol_name.to_upper() + "[/color][/b][/wave]\n(" + effect + ")"

func _build_upgrade_desc(sym: SymbolData, increase: int) -> String:
	var name_color := _get_name_color(sym)

	# Show before/after for the relevant stat
	var stat_label := ""
	match sym.effect_type:
		SymbolData.EffectType.DAMAGE:
			var old_val = sym.base_impact
			var new_val = old_val + increase
			stat_label = "[color=#cc4040]IMPACT[/color]  " \
				+ "[color=#888888]" + str(old_val) + "[/color]" \
				+ "[color=#ffd060] → [b]" + str(new_val) + "[/b][/color]"
		SymbolData.EffectType.SHIELD:
			var old_val = sym.base_bandwidth
			var new_val = old_val + increase
			stat_label = "[color=#4099bb]BANDWIDTH[/color]  " \
				+ "[color=#888888]" + str(old_val) + "[/color]" \
				+ "[color=#ffd060] → [b]" + str(new_val) + "[/b][/color]"
		SymbolData.EffectType.HEAL:
			var old_val = sym.base_morale
			var new_val = old_val + increase
			stat_label = "[color=#40aa60]MORALE[/color]  " \
				+ "[color=#888888]" + str(old_val) + "[/color]" \
				+ "[color=#ffd060] → [b]" + str(new_val) + "[/b][/color]"
		SymbolData.EffectType.MULTIPLIER:
			if sym.effect is MultiplyLeftEffect:
				var old_val = sym.effect.base_multiplier
				var new_val = old_val + increase
				stat_label = "[color=#ffd060]MULTIPLIER[/color]  " \
					+ "[color=#888888]×" + str(old_val) + "[/color]" \
					+ "[color=#ffd060] → [b]×" + str(new_val) + "[/b][/color]"
			elif sym.effect is BuffAllEffect:
				var old_val = sym.effect.buff_amount
				var new_val = old_val + increase
				stat_label = "[color=#ffd060]BONUS[/color]  " \
					+ "[color=#888888]+" + str(old_val) + "[/color]" \
					+ "[color=#ffd060] → [b]+" + str(new_val) + "[/b][/color]"
			else:
				stat_label = "[color=#ffd060]+" + str(increase) + " to effect[/color]"

	return "[color=#fff]UPGRADE [/color][wave amp=2 freq=6.0][b][color=" + name_color + "]" \
		+ sym.symbol_name.to_upper() + "[/color][/b][/wave]\n(" + stat_label + ")"


func _get_name_color(sym: SymbolData) -> String:
	match sym.effect_type:
		SymbolData.EffectType.DAMAGE:     return "#ff6060"
		SymbolData.EffectType.SHIELD:     return "#60ccff"
		SymbolData.EffectType.HEAL:       return "#60ee80"
		SymbolData.EffectType.MULTIPLIER: return "#ffd060"
		_:                                return "#ffffff"

func _on_mouse_entered() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", -3.0, 0.15).as_relative()

func _on_mouse_exited() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", 3.0, 0.15).as_relative()
