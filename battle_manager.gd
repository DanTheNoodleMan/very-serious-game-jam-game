extends Node

signal boss_turn
signal player_turn

const STAMP_OFFSETS := [Vector2(-64, -60), Vector2(-64, 10), Vector2(-64, -60)]

enum GameState {PLAYER_TURN, SPINNING, RESOLVING, ENEMY_TURN, GAME_OVER}
var current_state: GameState = GameState.PLAYER_TURN

@export var button_down_sfx: AudioStream
@export var button_up_sfx: AudioStream
@export var slide: AudioStream
@export var whoosh: AudioStream
@export var hit: AudioStream
@export var shield_impact: AudioStream
@export var shield_break: AudioStream

@export var current_boss: BossData
var player_hp: int = 100
var player_max_hp: int = 100
var player_shield: int = 0   # resets each enemy turn after absorbing
var boss_hp: int = 100
var turn_number: int = 0
var rerolls_left: int = 1
var base_rerolls_left: int = 2

var _combat_ui_rest_x: float
var _combat_ui_tween: Tween

@onready var enemy_display: EnemyDisplay = $EnemyArea
@onready var player_display: PlayerDisplay = $PlayerArea
@onready var combat_ui: Control = $CombatUI  # the whole button panel

@onready var slot_machine: SlotMachine = $SlotMachine
@onready var action_button: TextureButton = $CombatUI/ActionButton
@onready var action_button_label: Label = $CombatUI/ActionButton/ActionButtonLabel
@onready var lock_in_button: TextureButton = $CombatUI/LockInButton
@onready var lock_in_button_label: Label = $CombatUI/LockInButton/LockInButtonLabel
@onready var combo_label: RichTextLabel = $ComboLabel 

var custom_font = load("uid://csmid407kor44")


func _ready() -> void:
	boss_hp = current_boss.max_hp
	enemy_display.setup(current_boss)
	player_display.setup(player_hp)

	action_button.pressed.connect(_on_action_button_pressed)
	action_button.button_down.connect(_on_action_button_down)
	action_button.button_up.connect(_on_action_button_up)
	
	lock_in_button.pressed.connect(_on_lock_in_button_pressed)
	lock_in_button.button_down.connect(_on_lock_in_button_down)
	lock_in_button.button_up.connect(_on_lock_in_button_up)
	
	slot_machine.spin_finished.connect(_on_spin_finished)
	slot_machine.spin_start.connect(_on_spin_start)
	
	await get_tree().process_frame
	_combat_ui_rest_x = combat_ui.position.x
	combat_ui.visible = false  # Start hidden, first show comes from start_player_turn
	
	start_player_turn()

func start_player_turn() -> void:
	player_turn.emit()
	player_display.clear_shield()  
	current_state = GameState.PLAYER_TURN
	rerolls_left = base_rerolls_left
	_show_combat_ui()
	combo_label.text = ""  # Clear preview from last turn
	slot_machine.reset_all_holds()

	var next_attack: int = current_boss.attack_pattern[turn_number % current_boss.attack_pattern.size()]
	enemy_display.set_intent(next_attack)
	
	_set_buttons_spinning()
	current_state = GameState.SPINNING
	await get_tree().create_timer(0.5).timeout
	slot_machine.trigger_spin()

func _on_spin_finished(results: Array[SymbolData]) -> void:
	slot_machine.interactible = true  # Player can now click reels

	# Update combo preview
	var combo = ComboDictionary.calculate(results)
	_update_combo_label(results, combo)

	if rerolls_left > 0:
		current_state = GameState.PLAYER_TURN
		action_button.disabled = false
		action_button_label.text = "REROLL (" + str(rerolls_left) + ")"
		action_button_label.position.y -= 2
		lock_in_button.disabled = false
		lock_in_button_label.position.y -= 2
	else:
		# No rerolls left, auto-resolve after brief pause so player sees result
		await get_tree().create_timer(0.6).timeout
		resolve_player_attack()


func resolve_player_attack() -> void:
	current_state = GameState.RESOLVING
	slot_machine.interactible = false
	_hide_combat_ui()  # Hide buttons during resolution

	var final_symbols = slot_machine.logic.active_symbols
	var combo_result = ComboDictionary.calculate(final_symbols)
	
	# Beat 1: Combo announcement (if earned)
	if combo_result["is_combo"]:
		await show_combo_announcement(combo_result["name"])
	
	# Beat 2: Words fly across the screen
	await throw_symbols_at_boss(final_symbols)
	
	# Beat 3: Impact — hit animation + numbers pop simultaneously
	var boss_center := enemy_display.get_portrait_global_center()
	var player_center := player_display.get_global_center()
	
	if combo_result["impact"] > 0:
		spawn_floating_text("[b][color=#cc5555]-" + str(combo_result["impact"]) + " HP[/color][/b]",
		boss_center + Vector2(128, -32))
	if combo_result["bandwidth"] > 0:
		spawn_floating_text("[b][color=#55aaff]+" + str(combo_result["bandwidth"]) + " BW[/color][/b]",
		player_center + Vector2(-24, 12))
	if combo_result["morale"] > 0:
		spawn_floating_text("[b][color=#55ee77]+" + str(combo_result["morale"]) + " MORALE[/color][/b]",
		player_center + Vector2(0, -18))
		
	SFXManager.play(hit, 0.0, 0.0, -20.0, 1.5, 0.0)
	await enemy_display.play_hit()  # Wait for hit anim to finish

	boss_hp -= combo_result["impact"]
	enemy_display.update_hp(boss_hp)
	
	player_shield += combo_result["bandwidth"]
	player_display.set_shield(player_display.current_shield + combo_result["bandwidth"])
	
	player_hp = min(player_hp + combo_result["morale"], player_max_hp)  # Cap at max
	player_display.update_hp(player_hp)

	# Beat 4: Boss mumbles defeated corporate speak
	enemy_display.show_reaction(combo_result["impact"])
	if boss_hp <= 0:
		print("YOU WIN!")
		current_state = GameState.GAME_OVER
		return

	await get_tree().create_timer(1.0).timeout
	start_enemy_turn()

func start_enemy_turn() -> void:
	boss_turn.emit() # for small things like changing ui stuff like mic from enemy_display
	current_state = GameState.ENEMY_TURN
	await get_tree().create_timer(0.5).timeout # for mic to change 

	var attack_dmg = current_boss.attack_pattern[turn_number % current_boss.attack_pattern.size()]
	await enemy_display.play_attack() 
	
	# Shield absorbs first
	var prev_shield = player_display.current_shield
	var hp_damage = player_display.absorb_damage(attack_dmg)
	var shield_broke = (prev_shield > 0 && player_display.current_shield == 0)
	var exact_break = (shield_broke && attack_dmg == prev_shield)
	
	if hp_damage <= 0:
		# Fully blocked
		if shield_broke:
			# Shield was exactly depleted
			await player_display.play_shield_break(prev_shield, exact_break)
			SFXManager.play(shield_impact, 0.0, 0.0, -20.0, 1.0, 0.0) 
		else:
			# Shield still has points left
			await player_display.play_blocked()
			SFXManager.play(shield_impact, 0.0, 0.0, -20.0, 1.0, 0.0) 
	else:
		# HP damage taken (shield may have broken or not)
		if shield_broke:
			await player_display.play_shield_break(prev_shield, exact_break)
			SFXManager.play(shield_break, 0.0, 0.0, -20.0, 1.0, 0.0) 
		# Now apply HP damage and play hit animation
		player_hp -= hp_damage
		player_display.update_hp(player_hp)
		
		var player_center := player_display.get_global_center()
		spawn_floating_text("[b][color=#cc5555]-" + str(hp_damage) + " HP[/color][/b]",
			player_center + Vector2(-24, 12))   # change "BW" to "HP" for clarity
		SFXManager.play(hit, 0.0, 0.0, -20.0, 1.0, 0.0)
		await player_display.play_hit()

	if player_hp <= 0:
		print("GAME OVER")
		current_state = GameState.GAME_OVER
		return

	await get_tree().create_timer(0.5).timeout
	turn_number += 1
	start_player_turn()

# --- Helpers -------------------------------------------

func _set_buttons_spinning() -> void:
	action_button.disabled = true
	lock_in_button.disabled = true
	action_button_label.text = "SPINNING..."
	action_button_label.position.y = 8
	lock_in_button_label.position.y = 8

func _update_combo_label(results: Array[SymbolData], combo: Dictionary) -> void:
	var new_text := ""

	if combo["is_combo"]:
		new_text = "[wave color=#ffffff amp=2 freq=10.0][b][color=#ffd060]★  " + combo["name"].to_upper() + "[/color][/b][/wave]"
		var effects: Array[String] = []
		if combo["impact"] > 0:    
			effects.append("[wave color=#ffffff amp=2 freq=10.0][color=#ff7777][b]" + str(combo["impact"]) + "[/b] IMPACT[/color][/wave]")
		if combo["bandwidth"] > 0: 
			effects.append("[wave color=#ffffff amp=2 freq=10.0][color=#77aaff][b]" + str(combo["bandwidth"]) + "[/b] BW[/color][/wave]")
		if combo["morale"] > 0:    
			effects.append("[wave color=#ffffff amp=2 freq=10.0][color=#77ee99][b]" + str(combo["morale"]) + "[/b] MORALE[/color][/wave]")
		if not effects.is_empty():
			new_text += "   " + "   ".join(effects)
	else:
		var parts: Array[String] = []
		if combo["impact"] > 0:    parts.append("[wave amp=2 freq=5.0][color=#cc5555][b]" + str(combo["impact"]) + "[/b] IMPACT[/color][/wave]")
		if combo["bandwidth"] > 0: parts.append("[wave amp=2 freq=5.0][color=#5588cc][b]" + str(combo["bandwidth"]) + "[/b] BW[/color][/wave]")
		if combo["morale"] > 0:    parts.append("[wave amp=2 freq=5.0][color=#55aa77][b]" + str(combo["morale"]) + "[/b] MORALE[/color][/wave]")
		new_text = " + ".join(parts) if not parts.is_empty() else "[color=#44445a]no effect[/color]"

	combo_label.text = new_text
	combo_label.scale = Vector2(0.75, 0.75)
	combo_label.rotation = deg_to_rad(randf_range(-2, 2)) # Slight tilt every update

	# Stop previous tween if the player is spamming Reroll
	if combo_label.has_meta("active_tween"):
		var old_t = combo_label.get_meta("active_tween") as Tween
		if old_t and old_t.is_valid():
			old_t.kill()

	var t := combo_label.create_tween()
	combo_label.set_meta("active_tween", t)
	
	# The Pop-In
	t.tween_property(combo_label, "scale", Vector2(1.08, 1.08), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.08)
	t.parallel().tween_property(combo_label, "rotation", 0.0, 0.1)
	
	var pulse := combo_label.create_tween().set_loops()

	pulse.tween_property(combo_label, "modulate", Color(1.1, 1.1, 1.1, 1.0), 0.8)
	pulse.tween_property( combo_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8)


func throw_symbols_at_boss(symbols: Array[SymbolData]) -> void:
	var origins: Array[Vector2] = slot_machine.get_reel_global_centers()
	var target: Vector2 = enemy_display.get_portrait_global_center()
	
	for i in 3:
		SFXManager.play(whoosh, 0.0, 0.0, -20.0, 1.0, 0.0) 
		await get_tree().create_timer(0.09).timeout  # Stagger launches
		_launch_word_projectile(symbols[i], origins[i], target, STAMP_OFFSETS[i])
	
	await get_tree().create_timer(0.09 * 3).timeout  # Last one finishes

func _launch_word_projectile(sym: SymbolData, from: Vector2, to: Vector2, stamp_offset: Vector2) -> void:
	var flight_time := 0.26
	
	# --- Icon: flies fast and shrinks into the target ---
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
	
	# --- Word stamp: fires after icon arrives ---
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
	
	await get_tree().process_frame  # Let layout run so size is valid
	await get_tree().process_frame  # RTL sometimes needs two frames to finalize BBCode layout
	rtl.pivot_offset = rtl.size * 0.5
	rtl.global_position = pos - rtl.size * 0.5
	
	var t := rtl.create_tween()
	t.tween_property(rtl, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(rtl, "modulate:a", 1.0, 0.06)
	t.tween_interval(0.7)  # Shake for a moment while visible
	t.chain().tween_property(rtl, "modulate:a", 0.0, 0.2)
	t.tween_callback(rtl.queue_free)

func show_combo_announcement(combo_name: String) -> void:
	# SFXManager.play(preload("res://assets/sfx/heavy_slam.ogg"), 0.1, 0.0, 5.0)

	# Main Text
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	rtl.scroll_active = false
	rtl.visible = false # Prevent top-left flash

	rtl.text = "[center][wave amp=20 freq=5][b][color=#ffe135]★ " + combo_name.to_upper() + " ★[/color][/b][/wave][/center]"
	rtl.add_theme_font_override("normal_font", custom_font)
	rtl.add_theme_font_override("bold_font", custom_font)
	rtl.add_theme_font_size_override("normal_font_size", 26)
	rtl.add_theme_font_size_override("bold_font_size", 26)
	rtl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	rtl.add_theme_constant_override("shadow_offset_x", 4)
	rtl.add_theme_constant_override("shadow_offset_y", 4)
	rtl.add_theme_constant_override("outline_size", 6)
	rtl.add_theme_color_override("font_outline_color", "#201533")
	rtl.z_index = 200
	get_tree().root.add_child(rtl)

	# Ghost copy for shockwave
	var ghost := rtl.duplicate() as RichTextLabel
	ghost.visible = false # Prevent top-left flash
	ghost.z_index = 199
	get_tree().root.add_child(ghost)

	await get_tree().process_frame
	await get_tree().process_frame

	var center_pos := Vector2(320, 180)

	rtl.pivot_offset = rtl.size * 0.5
	rtl.global_position = center_pos - rtl.size * 0.5

	ghost.pivot_offset = ghost.size * 0.5
	ghost.global_position = center_pos - ghost.size * 0.5

	# Show only after positioning
	rtl.visible = true
	ghost.visible = true

	# Shockwave
	var gt := ghost.create_tween()
	gt.tween_property(ghost, "scale", Vector2(1.8, 1.3), 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	gt.parallel().tween_property(ghost, "modulate:a", 0.0, 0.3)
	gt.tween_callback(ghost.queue_free)

	# Main Text
	rtl.scale = Vector2(2.5, 2.5)

	var t := rtl.create_tween()

	# Slam
	t.tween_property(rtl, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	t.parallel().tween_property(rtl, "rotation", deg_to_rad(randf_range(-5, 5)), 0.15)

	# Hold
	t.chain().tween_property(rtl, "rotation", 0.0, 0.05)
	t.tween_interval(0.8)

	# Exit
	t.chain().tween_property(rtl, "scale", Vector2(0.0, 0.5), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	t.parallel().tween_property(rtl, "modulate:a", 0.0, 0.2)
	t.tween_callback(rtl.queue_free)

	await t.finished

func spawn_floating_text(bbcode: String, global_pos: Vector2, drift: Vector2 = Vector2.ZERO) -> void:
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
	

func _show_combat_ui() -> void:
	if is_instance_valid(_combat_ui_tween):
		_combat_ui_tween.kill()
	
	combat_ui.position.x = _combat_ui_rest_x + combat_ui.size.x + 16.0
	combat_ui.visible = true
	
	var overshoot := 6.0  # <-- tune this, was implicitly ~20-30px with TRANS_BACK
	
	SFXManager.play(slide, 0.0, 0.0, -10.0, 0.75, 0.0) 

	_combat_ui_tween = create_tween()
	# Step 1: slide in and slightly past the rest position
	_combat_ui_tween.tween_property(combat_ui, "position:x", _combat_ui_rest_x - overshoot, 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Step 2: spring back to the true rest position
	_combat_ui_tween.chain().tween_property(combat_ui, "position:x", _combat_ui_rest_x, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _hide_combat_ui() -> void:
	if not combat_ui.visible: return
	if is_instance_valid(_combat_ui_tween):
		_combat_ui_tween.kill()
	
	SFXManager.play(slide, 0.0, 0.0, -10.0, 1.5, 0.0) 
	_combat_ui_tween = create_tween()
	_combat_ui_tween.tween_property(
		combat_ui, "position:x",
		_combat_ui_rest_x + combat_ui.size.x + 16.0, 0.15
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_combat_ui_tween.tween_callback(func(): combat_ui.visible = false)

# --- Signal receivers -----------------------------------
func _on_spin_start() -> void:
	if combo_label:
		_hide_combo_label()

func _on_action_button_pressed() -> void:
	if current_state != GameState.PLAYER_TURN: return
	rerolls_left -= 1
	_set_buttons_spinning()
	current_state = GameState.SPINNING
	slot_machine.trigger_spin()

func _on_lock_in_button_pressed() -> void:
	if current_state != GameState.PLAYER_TURN: return
	resolve_player_attack()

func _on_action_button_down() -> void:
	action_button_label.position.y += 2 
	SFXManager.play(button_down_sfx, 0.1, 0.05, -15.0, 1.0)

func _on_action_button_up() -> void:
	action_button_label.position.y -= 2 
	SFXManager.play(button_up_sfx, 0.1, 0.05, -15.0, 1.0)

func _on_lock_in_button_down() -> void:
	lock_in_button_label.position.y += 2
	SFXManager.play(button_down_sfx, 0.1, 0.05, -15.0, 1.0)

func _on_lock_in_button_up() -> void:
	lock_in_button_label.position.y -= 2
	SFXManager.play(button_up_sfx, 0.1, 0.05, -15.0, 1.0)
