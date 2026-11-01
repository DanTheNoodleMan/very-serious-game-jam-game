class_name LayoffModal extends CanvasLayer
## "Who gets laid off?" popup, shown when a hire would overflow the roster.
## Lives on its own CanvasLayer, so it covers the whole screen no matter where the reward panel sits.
## Identical copies are grouped into one tile (x2), diverged copies get their own, so you always
## pick a specific copy. Hover a tile to read what it does next to what's joining.
##
## Usage:  var m := LayoffModal.open(self, run, option)
##         m.picked.connect(func(sym): ...)     # `cancelled` fires on Never Mind / Esc

signal picked(sym: SymbolData)
signal cancelled

const FONT := preload("uid://csmid407kor44")
const BG := Color("#171124")
const BORDER := Color("#3f3354")
const TILE_BG := Color("#0b0714")
const DANGER := Color("#cc5555")
const BODY_WIDTH := 400

var _run: RunState
var _incoming: RewardOption
var _detail: RichTextLabel


static func open(host: Node, run: RunState, incoming: RewardOption) -> LayoffModal:
	var m := LayoffModal.new()
	m._run = run
	m._incoming = incoming
	host.add_child(m)
	return m


func _ready() -> void:
	layer = 20

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# Dim + click blocker: nothing behind the modal can be clicked
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(BG, DANGER, 2, 8))
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	col.add_child(_rtl("[center][b][color=#ff6060]WHO GETS LAID OFF?[/color][/b][/center]", 14, BODY_WIDTH))
	col.add_child(_rtl("[center][color=#99a3c2]Pick someone to make room for[/color] %s[/center]" % _name_tag(_incoming.symbol), 9, BODY_WIDTH))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	col.add_child(body)
	body.add_child(_build_grid())
	body.add_child(_build_detail())

	var cancel := Button.new()
	cancel.text = "NEVER MIND"
	cancel.add_theme_font_override("font", FONT)
	cancel.add_theme_font_size_override("font_size", 10)
	cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel.pressed.connect(_cancel)
	col.add_child(cancel)

	# Pop in
	root.modulate.a = 0.0
	await get_tree().process_frame
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.9, 0.9)
	var t := create_tween().set_parallel()
	t.tween_property(root, "modulate:a", 1.0, 0.12)
	t.tween_property(panel, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel()


func _cancel() -> void:
	cancelled.emit()
	queue_free()


# ---- Grid of owned symbols -----------------------------------------------------------
func _build_grid() -> Control:
	var groups := {}                 # signature -> Array[SymbolData]
	var order: Array[String] = []
	for sym in _run.symbol_pool:
		var key: String = sym.get_signature()
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append(sym)

	var grid := GridContainer.new()
	grid.columns = 4 if order.size() <= 12 else 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for key in order:
		var copies: Array = groups[key]
		grid.add_child(_make_tile(copies[0], copies.size()))
	return grid


func _make_tile(sym: SymbolData, count: int) -> Control:
	var accent := ComboDictionary.get_effect_color(sym.effect_type)
	var normal := _box(TILE_BG, BORDER, 1, 3)
	var hover := _box(Color("#2a1018"), DANGER, 1, 3)

	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(62, 62)
	tile.add_theme_stylebox_override("panel", normal)
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.mouse_filter = Control.MOUSE_FILTER_STOP

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(v)

	var icon := TextureRect.new()
	icon.texture = sym.icon
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)

	v.add_child(_tile_label(sym.symbol_name, accent))

	var badges: Array[String] = []
	if count > 1:
		badges.append("x%d" % count)
	if sym.upgrade_level > 0:
		badges.append("+%d" % sym.upgrade_level)
	if not badges.is_empty():
		v.add_child(_tile_label(" ".join(badges), Color("#ffd060")))

	tile.mouse_entered.connect(func() -> void:
		tile.add_theme_stylebox_override("panel", hover)
		_detail.text = _card_text(sym))
	tile.mouse_exited.connect(func() -> void:
		tile.add_theme_stylebox_override("panel", normal))
	tile.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(sym)
			queue_free())
	return tile


# ---- Side pane: who's leaving vs who's joining ---------------------------------------
func _build_detail() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 0)
	panel.add_theme_stylebox_override("panel", _box(TILE_BG, BORDER, 1, 5))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	panel.add_child(v)

	v.add_child(_rtl("[b][color=#cc5555]LEAVING[/color][/b]", 9, 140))
	_detail = _rtl("[color=#6b7593]Hover a symbol to see what it does.[/color]", 9, 140)
	_detail.custom_minimum_size.y = 70
	v.add_child(_detail)

	var sep := ColorRect.new()
	sep.color = BORDER
	sep.custom_minimum_size = Vector2(0, 1)
	v.add_child(sep)

	v.add_child(_rtl("[b][color=#60ee80]JOINING[/color][/b]", 9, 140))
	v.add_child(_rtl(_card_text(_incoming.symbol), 9, 140))
	return panel


func _card_text(sym: SymbolData) -> String:
	var extra := ""
	if sym.department != SymbolData.Department.NONE:
		extra += "\n[color=#6b7593]%s[/color]" % sym.get_department_name()
	if sym.upgrade_level > 0:
		extra += "  [color=#ffd060]Promoted x%d[/color]" % sym.upgrade_level
	return "%s%s\n%s" % [_name_tag(sym), extra, ComboDictionary.build_card_description(sym)]


func _name_tag(sym: SymbolData) -> String:
	return "[b][color=%s]%s[/color][/b]" % [ComboDictionary.get_effect_color_hex(sym.effect_type), sym.symbol_name.to_upper()]


# ---- Small builders --------------------------------------------------------------
func _rtl(bbcode: String, font_size: int, min_width: int = 0) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.custom_minimum_size.x = min_width
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("normal_font", FONT)
	l.add_theme_font_override("bold_font", FONT)
	l.add_theme_font_size_override("normal_font_size", font_size)
	l.add_theme_font_size_override("bold_font_size", font_size)
	l.text = bbcode
	return l


func _tile_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = 56
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	return l


func _box(bg: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(margin)
	return s
