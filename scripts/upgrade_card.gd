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
			desc_label.text = _build_symbol_desc(sym, false)
		"remove":
			var sym := _data as SymbolData
			icon_rect.texture = sym.icon
			icon_rect.visible = true
			desc_label.text = _build_symbol_desc(sym, true)
		"reroll":
			icon_rect.visible = true
			panel_container.modulate = Color(0, 0, 0, 0.0)
			desc_label.text = "[color=#fff]Gain [color=#aaccff][b]+1 REROLL[/b][/color] per turn[/color]"

func _build_symbol_desc(sym: SymbolData, is_remove: bool) -> String:
	var verb := "[color=#fff]REMOVE [/color]" if is_remove \
		else "[color=#fff]ADD [/color]"

	# Effect description in the matching color
	var effect := ComboDictionary.describe_symbol(sym)

	# Verb + name in effect color + effect in parens
	var name_color := _get_name_color(sym)
	return verb + "[wave amp=2 freq=6.0][b][color=" + name_color + "]" + sym.symbol_name.to_upper() \
	+  "[/color][/b][/wave]\n" \
		+ "(" + effect + ")"

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
