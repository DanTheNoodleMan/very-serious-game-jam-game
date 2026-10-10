class_name CombatVFX extends Node

@export var whoosh_sfx: AudioStream
@onready var combo_label: RichTextLabel = $ComboLabel 

@onready var camera_2d: Camera2D = %Camera2D

var combo_label_rest_y: float

var custom_font = preload("uid://csmid407kor44")
const STAMP_OFFSETS := [Vector2(-64, -60), Vector2(-64, 10), Vector2(-64, -60)]

# ------------------------
# --- Combo Announcement ---
#-------------------------

func _update_combo_label(results: Array[SymbolData], combo: Dictionary) -> void:
	var new_text := ""

	if combo["is_combo"]:
		SFXManager.play(preload("uid://b4nmr0ovmbky3"), 0.0, 0.05, -5.0, 1.0)
		camera_2d.screen_shake(6, 0.1)
		new_text = "[wave color=#ffffff amp=2 freq=10.0][b][color=#ffe135]* " + combo["name"].to_upper() + " *[/color][/b][/wave]   "

	var parts: Array[String] = []

	# Build IMPACT string
	if combo["impact"] > 0:
		if combo["impact"] > combo["base_impact"]:
			# FORMAT: 16 IMPACT (Base 5)
			parts.append("[wave amp=2 freq=5.0][color=#ffd060][b]" + str(combo["impact"]) + "[/b][/color] [color=#ff7777]IMPACT[/color][/wave]")
		else:
			parts.append("[wave amp=2 freq=5.0][color=#ff7777][b]" + str(combo["impact"]) + "[/b][/color] [color=#ff7777]IMPACT[/color][/wave]")

	# Build BANDWIDTH string
	if combo["bandwidth"] > 0:
		if combo["bandwidth"] > combo["base_bandwidth"]:
			# FORMAT: 8 BW (Base 4)
			parts.append("[wave amp=2 freq=5.0][color=#ffd060][b]" + str(combo["bandwidth"]) + "[/b][/color] [color=#77aaff]BW[/color][/wave]")
		else:
			parts.append("[wave amp=2 freq=5.0][color=#77aaff][b]" + str(combo["bandwidth"]) + "[/b][/color] [color=#77aaff]BW[/color][/wave]")

	# Build MORALE string
	if combo["morale"] > 0:
		if combo["morale"] > combo["base_morale"]:
			# FORMAT: 20 MORALE (Base 8)
			parts.append("[wave amp=2 freq=5.0][color=#ffd060][b]" + str(combo["morale"]) + "[/b][/color] [color=#77ee99]MORALE[/color] [/wave]")
		else:
			parts.append("[wave amp=2 freq=5.0][color=#77ee99][b]" + str(combo["morale"]) + "[/b][/color] [color=#77ee99]MORALE[/color][/wave]")

	if parts.is_empty():
		new_text += "[color=#44445a]no effect[/color]"
	else:
		new_text += " + ".join(parts)

	combo_label.text = new_text
	combo_label.scale = Vector2(0.75, 0.75)
	combo_label.rotation = deg_to_rad(randf_range(-2, 2))

	if combo_label.has_meta("active_tween"):
		var old_t = combo_label.get_meta("active_tween") as Tween
		if old_t and old_t.is_valid():
			old_t.kill()

	var t := combo_label.create_tween()
	combo_label.set_meta("active_tween", t)
	
	t.tween_property(combo_label, "scale", Vector2(1.08, 1.08), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.08)
	t.parallel().tween_property(combo_label, "rotation", 0.0, 0.1)

func _hide_combo_label() -> void:
	if combo_label.text.is_empty():
		return

	if combo_label.has_meta("active_tween"):
		var old_t = combo_label.get_meta("active_tween") as Tween
		if old_t and old_t.is_valid():
			old_t.kill()

	combo_label.modulate = Color.WHITE

	var t := combo_label.create_tween()
	combo_label.set_meta("active_tween", t)

	# Mirror of the pop-in, reversed
	t.tween_property(combo_label, "scale", Vector2(1.08, 1.08), 0.08)
	t.chain().tween_property(combo_label, "scale", Vector2(0.75, 0.75), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(combo_label, "rotation", deg_to_rad(randf_range(-2, 2)), 0.10)

	t.tween_callback(func():
		combo_label.text = ""
		combo_label.scale = Vector2.ONE
		combo_label.rotation = 0.0
		combo_label.modulate = Color.WHITE
	)
	
# ------------------------
# --- THROWING SYMBOLS ---
#-------------------------
func throw_symbols(symbols: Array[SymbolData], origins: Array[Vector2], target: Vector2) -> void:
	for i in 3:
		if symbols[i] == null: continue
		SFXManager.play(whoosh_sfx, 0.0, 0.0, -20.0, 1.0, 0.0) 
		await get_tree().create_timer(0.09).timeout 
		_launch_word_projectile(symbols[i], origins[i], target, STAMP_OFFSETS[i])
	await get_tree().create_timer(0.09 * 3).timeout 

func _launch_word_projectile(sym: SymbolData, from: Vector2, to: Vector2, stamp_offset: Vector2) -> void:
	var flight_time := 0.26
	var icon := TextureRect.new()
	icon.texture = sym.icon
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.z_index = 100
	icon.pivot_offset = Vector2(20, 20)
	get_tree().root.add_child(icon)
	icon.global_position = from - Vector2(20, 20)
	
	var icon_t := icon.create_tween()
	icon_t.tween_property(icon, "global_position", to - Vector2(20, 20), flight_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	icon_t.parallel().tween_property(icon, "scale", Vector2(0.1, 0.1), flight_time)
	icon_t.parallel().tween_property(icon, "rotation", randf_range(-0.5, 0.5), flight_time)
	icon_t.tween_callback(icon.queue_free)
	
	var stamp_pos := from + stamp_offset
	var delay_t := create_tween()
	delay_t.tween_interval(flight_time)
	delay_t.tween_callback(func(): _spawn_word_stamp(sym.symbol_name.to_upper(), stamp_pos))

func _spawn_word_stamp(word: String, pos: Vector2) -> void:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.autowrap_mode = TextServer.AUTOWRAP_OFF 
	rtl.scroll_active = false
	rtl.text = "[b][shake rate=10 level=5][color=#cbf9ff]" + word + "[/color][/shake][/b]"
	rtl.z_index = 110
	rtl.scale = Vector2(2.8, 2.8)
	rtl.modulate.a = 0.0
	rtl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rtl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rtl.add_theme_font_override("normal_font", custom_font)
	rtl.add_theme_font_override("bold_font", custom_font)
	rtl.add_theme_font_size_override("normal_font_size", 16)
	rtl.add_theme_font_size_override("bold_font_size", 22)
	rtl.add_theme_constant_override("outline_size", 6)
	rtl.add_theme_color_override("font_outline_color", Color.BLACK)
	get_tree().root.add_child(rtl)
	
	await get_tree().process_frame 
	await get_tree().process_frame 
	rtl.pivot_offset = rtl.size * 0.5
	rtl.global_position = pos - rtl.size * 0.5
	
	var t := rtl.create_tween()
	t.tween_property(rtl, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(rtl, "modulate:a", 1.0, 0.06)
	t.tween_interval(0.7) 
	t.chain().tween_property(rtl, "modulate:a", 0.0, 0.2)
	t.tween_callback(rtl.queue_free)

func spawn_floating_text(bbcode: String, global_pos: Vector2) -> void:
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rtl.scroll_active = false
	rtl.text = bbcode
	rtl.z_index = 150
	rtl.scale = Vector2(0.1, 0.1)
	rtl.modulate.a = 0.0
	rtl.add_theme_font_override("normal_font", custom_font)
	rtl.add_theme_font_override("bold_font", custom_font)
	rtl.add_theme_font_size_override("normal_font_size", 16)
	rtl.add_theme_font_size_override("bold_font_size", 22)
	rtl.add_theme_constant_override("outline_size", 6)
	rtl.add_theme_color_override("font_outline_color", Color.BLACK)
	get_tree().root.add_child(rtl)

	await get_tree().process_frame
	await get_tree().process_frame
	rtl.pivot_offset = rtl.size * 0.5
	rtl.global_position = global_pos - rtl.size * 0.5

	var t := rtl.create_tween()
	t.tween_property(rtl, "scale", Vector2(1.45, 1.45), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(rtl, "modulate:a", 1.0, 0.06)
	t.chain().tween_property(rtl, "scale", Vector2(1.0, 1.0), 0.08)
	t.parallel().tween_property(rtl, "modulate:a", 0.0, 0.45).set_delay(0.8)
	t.parallel().tween_property(rtl, "scale", Vector2(0.5, 0.5), 0.45).set_delay(0.8)
	t.tween_callback(rtl.queue_free)
