extends CanvasLayer

var _tooltip: PanelContainer
var _style: StyleBoxFlat
var _title_lbl: Label
var _dept_lbl: Label
var _body_lbl: RichTextLabel
var _target: Control = null
var custom_font = preload("uid://csmid407kor44")

const TOOLTIP_WIDTH := 240.0
const CONTENT_PADDING := 14.0

func _ready() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.z_index = 200
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.05, 0.09, 0.18)
	_style.border_color = Color(0.25, 0.45, 0.75)  # default, overwritten per-call in show_tooltip
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(0)
	_style.set_content_margin_all(7)
	_tooltip.add_theme_stylebox_override("panel", _style)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(vbox)

	# ── Title row: name (left, stretches) + department (right, stays put) ──
	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size = Vector2(TOOLTIP_WIDTH - CONTENT_PADDING, 0)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_row)

	_title_lbl = Label.new()
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # takes all leftover space
	_title_lbl.add_theme_font_override("font", custom_font)
	_title_lbl.add_theme_font_size_override("font_size", 12)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_title_lbl)

	_dept_lbl = Label.new()
	_dept_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dept_lbl.add_theme_font_override("font", custom_font)
	_dept_lbl.add_theme_font_size_override("font_size", 9)
	_dept_lbl.add_theme_color_override("font_color", Color(0.53, 0.6, 0.73))
	_dept_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_dept_lbl)

	# ── Divider ──
	var divider := ColorRect.new()
	divider.color = Color(0.2, 0.25, 0.37)
	divider.custom_minimum_size = Vector2(0, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(divider)

	_body_lbl = RichTextLabel.new()
	_body_lbl.bbcode_enabled = true
	_body_lbl.fit_content = true
	_body_lbl.scroll_active = false
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_body_lbl.custom_minimum_size = Vector2(TOOLTIP_WIDTH - CONTENT_PADDING, 0)
	_body_lbl.add_theme_font_override("normal_font", custom_font)
	_body_lbl.add_theme_font_override("bold_font", custom_font)
	_body_lbl.add_theme_font_size_override("normal_font_size", 10)
	_body_lbl.add_theme_font_size_override("bold_font_size", 10)
	_body_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_body_lbl)

	add_child(_tooltip)

func show_tooltip(anchor: Control, title: String, body_bbcode: String, accent: Color = Color(0.25, 0.45, 0.75), department: String = "") -> void:
	_target = anchor
	_title_lbl.text = title.to_upper()
	_title_lbl.add_theme_color_override("font_color", accent)
	_dept_lbl.text = department.to_upper()
	_dept_lbl.visible = department != ""
	_body_lbl.text = body_bbcode

	_style.border_color = accent  # the actual fix — border now matches whichever symbol/effect this is

	_tooltip.reset_size()
	_tooltip.global_position = Vector2(-4000, -4000)
	_tooltip.visible = true
	_reposition(anchor)

func _reposition(anchor: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _target != anchor: return

	var anchor_global := anchor.global_position
	var tsize := _tooltip.size
	var vsize := get_viewport().get_visible_rect().size

	var x := anchor_global.x + anchor.size.x * 0.5 - tsize.x * 0.5
	var y := anchor_global.y - tsize.y - 6
	x = clamp(x, 4.0, vsize.x - tsize.x - 4.0)
	y = clamp(y, 4.0, vsize.y - tsize.y - 4.0)
	_tooltip.global_position = Vector2(x, y)

func hide_tooltip(anchor: Control) -> void:
	if _target == anchor:
		_target = null
		_tooltip.visible = false
