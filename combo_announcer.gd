class_name ComboAnnouncer extends Control

func announce(combo: Dictionary, symbols: Array[SymbolData]) -> void:
	if combo["is_combo"]:
		await _flash_word(combo["name"].to_upper(), 28, Color(1.0, 1.0, 1.0))
	else:
		# Fire each buzzword individually, staggered
		for sym in symbols:
			if sym.effect_type == SymbolData.EffectType.MULTIPLIER:
				continue  # Skip multipliers in the word salvo
			await _flash_word(sym.symbol_name.to_upper(), 16, Color(0.75, 0.88, 1.0))
			await get_tree().create_timer(0.12).timeout

func _flash_word(text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_deferred("size", size)  # Match parent size so centering works
	label.pivot_offset = size * 0.05
	add_child(label)

	label.modulate.a = 0.0
	label.scale = Vector2(0.6, 0.6)

	var t := create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.08)
	t.parallel().tween_property(label, "scale", Vector2(1.05, 1.05), 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(label, "scale", Vector2(1.0, 1.0), 0.06)
	# Hold — combo name holds longer than individual words
	t.chain().tween_interval(0.45 if font_size > 20 else 0.2)
	t.tween_property(label, "modulate:a", 0.0, 0.18)
	t.tween_callback(label.queue_free)

	await t.finished
