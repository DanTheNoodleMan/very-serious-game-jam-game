extends Control

@onready var chip_row: HBoxContainer = $ChipRow
var custom_font = preload("uid://csmid407kor44")
var _scroll_tween: Tween

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
	# 1. Main Chip Base
	var chip := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#171124")
	style.border_color = ComboDictionary.get_effect_color(sym.effect_type)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(2)
	chip.add_theme_stylebox_override("panel", style)
	chip.custom_minimum_size = Vector2(26, 26)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP

	# Wire hover tooltips
	chip.mouse_entered.connect(func(): _show_tooltip(sym, chip))
	chip.mouse_exited.connect(func(): _hide_tooltip(chip))

	# 2. Layering Container (Icon + Overlay Badge)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(22, 22)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(canvas)

	# 3. Symbol Icon (Centered, full-bleed)
	var icon := TextureRect.new()
	icon.texture = sym.icon
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(icon)

	# 4. Corner Count Badge (Sleek pill pinned to bottom-right)
	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color("#0b0714")
	badge_style.border_color = Color("#3f3354") if count == 1 else ComboDictionary.get_effect_color(sym.effect_type)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(2)
	badge_style.content_margin_left = 2
	badge_style.content_margin_right = 2
	badge_style.content_margin_top = 0
	badge_style.content_margin_bottom = 0
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Position badge to overlap bottom-right corner
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge.position = Vector2(2, 2) # Slight overhang for high-end UI feel

	var lbl := Label.new()
	lbl.text = str(count)
	lbl.add_theme_font_override("font", custom_font)
	lbl.add_theme_font_size_override("font_size", 8)
	# Dim count of 1; brightly highlight multiple copies
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7) if count == 1 else Color(1.0, 1.0, 1.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lbl)

	canvas.add_child(badge)

	return chip

# ── Tooltip logic ─────────────────────────────────────────────────────────────

func _show_tooltip(sym: SymbolData, chip: Control) -> void:
	TooltipManager.show_tooltip(
		chip, 
		sym.symbol_name, 
		ComboDictionary.build_card_description(sym), 
		ComboDictionary.get_effect_color(sym.effect_type)
	)

func _hide_tooltip(chip: Control) -> void:
	TooltipManager.hide_tooltip(chip)
