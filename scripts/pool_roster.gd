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
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = "#201533"
	style.border_color = ComboDictionary.get_effect_color(sym.effect_type)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP  # chip catches hover

	# Wire hover
	panel.mouse_entered.connect(func(): _show_tooltip(sym, panel))
	panel.mouse_exited.connect(func(): _hide_tooltip(panel))

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
	TooltipManager.show_tooltip(chip, sym.symbol_name, ComboDictionary.build_card_description(sym), ComboDictionary.get_effect_color(sym.effect_type))

func _hide_tooltip(chip: Control) -> void:
	TooltipManager.hide_tooltip(chip)
