class_name RewardCard extends PanelContainer
## A reward option drawn as a card: kicker, framed icon, name, tag, the full "what it does" text, footer.
## Built entirely in code, so there is no card scene to maintain. All text comes from RewardOption.get_card().
## Sizes assume your 640x360 base resolution; tweak MIN_SIZE and the font sizes below.

signal chosen(option: RewardOption)

const FONT := preload("uid://csmid407kor44")
const BG := Color("#171124")
const BG_HOVER := Color("#211a35")
const BORDER := Color("#3f3354")
const MIN_SIZE := Vector2(112, 150)

var _option: RewardOption
var _normal: StyleBoxFlat
var _hover: StyleBoxFlat
var _scale_tween: Tween


func setup(option: RewardOption, run: RunState) -> void:
	_option = option
	var d := option.get_card(run)
	var accent: Color = d.get("accent", BORDER)

	custom_minimum_size = MIN_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_normal = _box(BG, accent.darkened(0.5), 6)
	_hover = _box(BG_HOVER, accent, 6)
	add_theme_stylebox_override("panel", _normal)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	# Kicker: what kind of reward this is
	col.add_child(_rtl("[center][b][color=%s]%s[/color][/b][/center]" % [d["kicker_color"], d["kicker"]], 8))
	col.add_child(_line(accent.darkened(0.4)))

	# Framed icon
	if d["icon"] != null:
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", _box(Color("#0b0714"), accent.darkened(0.3), 2))
		frame.custom_minimum_size = Vector2(44, 44)
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = d["icon"]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(icon)
		col.add_child(frame)

	# Name + tag (department / level)
	col.add_child(_rtl("[center][wave amp=2 freq=6.0][b][color=%s]%s[/color][/b][/wave][/center]" % [d["name_color"], d["name"]], 10))
	if d["tag"] != "":
		col.add_child(_rtl("[center][color=#6b7593]%s[/color][/center]" % d["tag"], 8))
	col.add_child(_line(BORDER))

	# Body: the full description, unfolded (stat line + effect text), no hovering needed
	var body := _rtl("[center]%s[/center]" % d["body"], 9)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)

	if d["footer"] != "":
		col.add_child(_rtl("[center]%s[/center]" % d["footer"], 8))

	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		chosen.emit(_option)


func _on_enter() -> void:
	add_theme_stylebox_override("panel", _hover)
	pivot_offset = size / 2.0
	_animate_scale(Vector2(1.04, 1.04))


func _on_exit() -> void:
	add_theme_stylebox_override("panel", _normal)
	_animate_scale(Vector2.ONE)


func _animate_scale(target: Vector2) -> void:
	if is_instance_valid(_scale_tween):
		_scale_tween.kill()
	_scale_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", target, 0.12)


# ---- Small builders --------------------------------------------------------------
func _rtl(bbcode: String, font_size: int) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("normal_font", FONT)
	l.add_theme_font_override("bold_font", FONT)
	l.add_theme_font_size_override("normal_font_size", font_size)
	l.add_theme_font_size_override("bold_font_size", font_size)
	l.text = bbcode
	return l


func _line(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _box(bg: Color, border: Color, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.set_content_margin_all(margin)
	return s
