extends Control

@onready var chip_row: HBoxContainer = $ChipRow
var custom_font = preload("uid://csmid407kor44")
var _scroll_tween: Tween

# Tooltip state
var _tooltip: PanelContainer
var _tooltip_name_lbl: Label
var _tooltip_effect_lbl: RichTextLabel
var _tooltip_target: Control = null  # which chip is currently hovered

func _ready() -> void:
	_build_tooltip()

func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.z_index = 200
	_tooltip.visible = false
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE  # tooltip itself never blocks hover

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.18)
	style.border_color = Color(0.25, 0.45, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(7)
	_tooltip.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(vbox)

	_tooltip_name_lbl = Label.new()
	_tooltip_name_lbl.add_theme_font_override("font", custom_font)
	_tooltip_name_lbl.add_theme_font_size_override("font_size", 12)
	_tooltip_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tooltip_name_lbl)

	_tooltip_effect_lbl = RichTextLabel.new()
	_tooltip_effect_lbl.bbcode_enabled = true
	_tooltip_effect_lbl.fit_content = true
	_tooltip_effect_lbl.scroll_active = false
	_tooltip_effect_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tooltip_effect_lbl.add_theme_font_override("normal_font", custom_font)
	_tooltip_effect_lbl.add_theme_font_override("bold_font", custom_font)
	_tooltip_effect_lbl.add_theme_font_size_override("normal_font_size", 10)
	_tooltip_effect_lbl.add_theme_font_size_override("bold_font_size", 10)
	_tooltip_effect_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tooltip_effect_lbl)

	# Add to scene root so it's never clipped by any container
	get_tree().current_scene.add_child.call_deferred(_tooltip)

# ── Existing functions, unchanged except _make_chip ──────────────────────────

func refresh(pool: Array[SymbolData]) -> void:
	for child in chip_row.get_children():
		child.queue_free()

	var counts: Dictionary = {}
	var order: Array[SymbolData] = []

	for sym: SymbolData in pool:
		if not counts.has(sym.id):
			counts[sym.id] = 0
			order.append(sym)
		counts[sym.id] += 1

	for sym: SymbolData in order:
		var chip := _make_chip(sym, counts[sym.id])
		chip_row.add_child(chip)

	await get_tree().process_frame
	await get_tree().process_frame
	_check_overflow()

func _check_overflow() -> void:
	if is_instance_valid(_scroll_tween):
		_scroll_tween.kill()
	chip_row.position.x = 0

	var true_content_width = chip_row.get_minimum_size().x
	var available_width = size.x
	var overflow_amount = true_content_width - available_width

	if overflow_amount > 4:
		var duration = overflow_amount / 60.0
		_scroll_tween = create_tween().set_loops()
		_scroll_tween.tween_interval(2.0)
		_scroll_tween.tween_property(chip_row, "position:x", -overflow_amount, duration).set_trans(Tween.TRANS_LINEAR)
		_scroll_tween.tween_interval(2.0)
		_scroll_tween.tween_property(chip_row, "position:x", 0.0, duration).set_trans(Tween.TRANS_LINEAR)

func _make_chip(sym: SymbolData, count: int) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = "#201533"
	style.border_color = _get_border_color(sym)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # chip catches hover

	# Wire hover
	panel.mouse_entered.connect(func(): _show_tooltip(sym, panel))
	panel.mouse_exited.connect(func(): _hide_tooltip())

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS  # pass through to panel
	panel.add_child(vbox)

	var icon := TextureRect.new()
	icon.texture = sym.icon
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_PASS  # pass through to panel
	vbox.add_child(icon)

	var lbl := Label.new()
	lbl.text = "×" + str(count)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_font_size_override("bold_font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	lbl.add_theme_font_override("font", custom_font)
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS  # pass through to panel
	vbox.add_child(lbl)

	return panel

# ── Tooltip logic ─────────────────────────────────────────────────────────────

func _show_tooltip(sym: SymbolData, chip: Control) -> void:
	_tooltip_target = chip
	_tooltip_name_lbl.text = sym.symbol_name.to_upper()
	_tooltip_name_lbl.add_theme_color_override("font_color", _get_border_color(sym))
	_tooltip_effect_lbl.text = ComboDictionary.describe_symbol(sym)

	# Park offscreen while layout settles, then reposition
	_tooltip.global_position = Vector2(-2000, -2000)
	_tooltip.visible = true
	_reposition_tooltip(chip)

func _reposition_tooltip(chip: Control) -> void:
	# Two frames for RichTextLabel fit_content to finalise its size
	await get_tree().process_frame
	await get_tree().process_frame

	if _tooltip_target != chip:
		return  # mouse left before frames elapsed, abort

	var chip_global := chip.global_position
	var tooltip_size := _tooltip.size
	var viewport_size := get_viewport().get_visible_rect().size

	# Default: centered above the chip
	var x := chip_global.x + chip.size.x * 0.5 - tooltip_size.x * 0.5
	var y := chip_global.y - tooltip_size.y - 6

	# Clamp so it never goes off any edge
	x = clamp(x, 4.0, viewport_size.x - tooltip_size.x - 4.0)
	y = clamp(y, 4.0, viewport_size.y - tooltip_size.y - 4.0)

	_tooltip.global_position = Vector2(x, y)

func _hide_tooltip() -> void:
	_tooltip_target = null
	_tooltip.visible = false

func _get_border_color(sym: SymbolData) -> Color:
	match sym.effect_type:
		SymbolData.EffectType.DAMAGE:     return Color(0.8, 0.3, 0.3)
		SymbolData.EffectType.SHIELD:     return Color(0.3, 0.6, 1.0)
		SymbolData.EffectType.HEAL:       return Color(0.3, 0.8, 0.5)
		SymbolData.EffectType.MULTIPLIER: return Color(1.0, 0.8, 0.2)
		_:                                return Color(0.4, 0.4, 0.5)
