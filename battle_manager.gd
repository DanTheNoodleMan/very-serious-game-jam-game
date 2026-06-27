extends Node

signal boss_turn
signal player_turn

const STAMP_OFFSETS := [Vector2(-64, -60), Vector2(-64, 10), Vector2(-64, -60)]

enum GameState {PLAYER_TURN, SPINNING, RESOLVING, ENEMY_TURN, UPGRADE, GAME_OVER, VICTORY}
var current_state: GameState = GameState.PLAYER_TURN

@export var button_down_sfx: AudioStream
@export var button_up_sfx: AudioStream
@export var slide: AudioStream
@export var whoosh: AudioStream
@export var hit: AudioStream
@export var shield_impact: AudioStream
@export var shield_break: AudioStream
@export var win_fight: AudioStream
@export var game_over: AudioStream
@export var victory: AudioStream
@export var victory_music: AudioStream
@export var boss_roster: Array[BossData] = []

@export var boss_music: AudioStream

var current_boss_index: int = 0
var current_boss: BossData
var player_hp: int = 100
var player_max_hp: int = 100
var player_shield: int = 0   # resets each enemy turn after absorbing
var boss_hp: int = 100
var turn_number: int = 0
var rerolls_left: int = 1
var base_rerolls_left: int = 2

var _combat_ui_rest_x: float
var _combo_label_rest_y: float
var _combat_ui_tween: Tween
var _upgrade_display_rest_x: float
var _enemy_display_rest_y: float
var _slot_machine_rest_y: float

var _has_learned_hold: bool = false

@onready var enemy_display: EnemyDisplay = $EnemyArea
@onready var player_display: PlayerDisplay = $PlayerArea
@onready var combat_ui: Control = $CombatUI  # the whole button panel

@onready var upgrade_display: Control = $UpgradeDisplay 
@onready var enemy_area: Control = $EnemyArea

@onready var slot_machine: SlotMachine = $SlotMachine
@onready var action_button: TextureButton = $CombatUI/ActionButton
@onready var action_button_label: Label = $CombatUI/ActionButton/ActionButtonLabel
@onready var lock_in_button: TextureButton = $CombatUI/LockInButton
@onready var lock_in_button_label: Label = $CombatUI/LockInButton/LockInButtonLabel
@onready var combo_label: RichTextLabel = $ComboLabel 
@onready var pool_roster: Control = %PoolRoster
@onready var camera: Camera2D = %Camera2D
@onready var hold_tutorial: RichTextLabel = $HoldTutorialLabel

@onready var game_over_screen: TextureRect = $GameOverScreen
@onready var btn_restart: Button = %Restart
@onready var btn_easy: Button = %RestartEasy

@onready var victory_screen: TextureRect = $VictoryScreen
@onready var btn_victory_restart: Button = %VictoryRestart

var custom_font = load("uid://csmid407kor44")

func _ready() -> void:
	player_max_hp += GlobalSettings.easy_mode_hp_buff
	player_hp = player_max_hp

	game_over_screen.visible = false
	victory_screen.visible = false
	
	_play_scene_reveal()
	
	if boss_roster.size() > 0:
		current_boss = boss_roster[0]
		boss_hp = current_boss.max_hp
	enemy_display.setup(current_boss)
	enemy_display.show_name_immediate()
	
	player_display.setup(player_hp)
	
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_easy.pressed.connect(_on_easy_pressed)
	btn_victory_restart.pressed.connect(_on_restart_pressed)
	
	action_button.pressed.connect(_on_action_button_pressed)
	action_button.button_down.connect(_on_action_button_down)
	action_button.button_up.connect(_on_action_button_up)
	
	lock_in_button.pressed.connect(_on_lock_in_button_pressed)
	lock_in_button.button_down.connect(_on_lock_in_button_down)
	lock_in_button.button_up.connect(_on_lock_in_button_up)
	
	slot_machine.spin_finished.connect(_on_spin_finished)
	slot_machine.spin_start.connect(_on_spin_start)
	slot_machine.player_learned_hold.connect(_on_player_learned_hold)
	
	upgrade_display.upgrade_chosen.connect(_on_upgrade_chosen)
	upgrade_display.visible = false
	
	await get_tree().process_frame
	_combat_ui_rest_x = combat_ui.position.x
	_combo_label_rest_y = combo_label.position.y
	_upgrade_display_rest_x = upgrade_display.position.x
	_enemy_display_rest_y = enemy_display.position.y
	_slot_machine_rest_y = slot_machine.position.y
	combat_ui.visible = false  # Start hidden, first show comes from start_player_turn
	upgrade_display.visible = false
	
	pool_roster.refresh(slot_machine.logic.shared_pool)
	
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
	slot_machine.trigger_spin(player_hp)

func _on_spin_finished(results: Array[SymbolData]) -> void:
	# Update combo preview
	var combo = ComboDictionary.calculate(results)
	_update_combo_label(results, combo)

	if rerolls_left > 0:
		current_state = GameState.PLAYER_TURN
		slot_machine.interactible = true  # Player can click reels
		action_button.disabled = false
		action_button_label.text = "REROLL (" + str(rerolls_left) + ")"
		action_button_label.position.y -= 1
		lock_in_button.disabled = false
		lock_in_button_label.position.y -= 1
		
		if not _has_learned_hold:
			hold_tutorial.modulate.a = 0.0
			hold_tutorial.visible = true
			create_tween().tween_property(hold_tutorial, "modulate:a", 1.0, 0.4)
	else:
		# Auto-resolve
		slot_machine.interactible = false # Lock reels so they can't click during wait
		await get_tree().create_timer(1.25).timeout
		
		# Only resolve if the player hasn't somehow already resolved it
		if current_state != GameState.RESOLVING and current_state != GameState.UPGRADE:
			resolve_player_attack()


func resolve_player_attack() -> void:
	# --- Race condition lock ---
	if current_state == GameState.RESOLVING or current_state == GameState.UPGRADE or current_state == GameState.GAME_OVER:
		return 
	current_state = GameState.RESOLVING
	# ----------------------------
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
		# Check if this is the final boss in the array
		if current_boss_index >= boss_roster.size() - 1:
			current_state = GameState.VICTORY
			await _transition_to_victory()
		else:
			current_state = GameState.UPGRADE
			await _transition_to_upgrade()
			start_upgrade_phase()
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
		current_state = GameState.GAME_OVER
		game_over_screen.modulate.a = 0.0
		game_over_screen.visible = true
		create_tween().tween_property(game_over_screen, "modulate:a", 1.0, 1.5)
		SFXManager.play(game_over, 0.0, 0.0, -15.0, 1.0, 0.0)
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

# Inside battle_manager.gd

func _update_combo_label(results: Array[SymbolData], combo: Dictionary) -> void:
	var new_text := ""

	if combo["is_combo"]:
		SFXManager.play(preload("uid://b4nmr0ovmbky3"), 0.0, 0.05, -5.0, 1.0)
		camera.screen_shake(6, 0.1)
		new_text = "[wave color=#ffffff amp=2 freq=10.0][b][color=#ffe135]★ " + combo["name"].to_upper() + " ★[/color][/b][/wave]   "

	var parts: Array[String] = []

	# Build IMPACT string
	if combo["impact"] > 0:
		if combo["impact"] > combo["base_impact"]:
			# FORMAT: 16 IMPACT (Base 5)
			parts.append("[wave amp=2 freq=5.0][color=#ffd060][b]" + str(combo["impact"]) + "[/b][/color] [color=#ff7777]IMPACT[/color] [color=#ffd060](Base [color=#ff7777]" + str(combo["base_impact"]) + "[/color])[/color][/wave]")
		else:
			parts.append("[wave amp=2 freq=5.0][color=#ff7777][b]" + str(combo["impact"]) + "[/b][/color] [color=#ff7777]IMPACT[/color][/wave]")

	# Build BANDWIDTH string
	if combo["bandwidth"] > 0:
		if combo["bandwidth"] > combo["base_bandwidth"]:
			# FORMAT: 8 BW (Base 4)
			parts.append("[wave amp=2 freq=5.0][color=#ffd060][b]" + str(combo["bandwidth"]) + "[/b][/color] [color=#77aaff]BW[/color] [color=#ffd060](Base [color=#77aaff]" + str(combo["base_bandwidth"]) + "[/color])[/color][/wave]")
		else:
			parts.append("[wave amp=2 freq=5.0][color=#77aaff][b]" + str(combo["bandwidth"]) + "[/b][/color] [color=#77aaff]BW[/color][/wave]")

	# Build MORALE string
	if combo["morale"] > 0:
		if combo["morale"] > combo["base_morale"]:
			# FORMAT: 20 MORALE (Base 8)
			parts.append("[wave amp=2 freq=5.0][color=#ffd060][b]" + str(combo["morale"]) + "[/b][/color] [color=#77ee99]MORALE[/color] [color=#ffd060](Base [color=#77ee99]" + str(combo["base_morale"]) + "[/color])[/color][/wave]")
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
	SFXManager.play(preload("uid://b4nmr0ovmbky3"), 0.0, 0.05, -2.0, 1.0)
	camera.screen_shake(6, 0.1)
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
	

func _transition_to_upgrade() -> void:
	# "Call ended" on the nameplate first, brief pause for drama
	enemy_display.play_disconnected()
	await get_tree().create_timer(0.8).timeout
	
	SFXManager.play(win_fight, 0.0, 0.0, -10.0 , 1.0, 0.0)

	_hide_combat_ui()
	combo_label.text = ""
	

	# Slide enemy UP and slot machine DOWN simultaneously
	var t := create_tween()
	t.tween_property(enemy_display, "position:y",
		enemy_display.position.y - 420, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(slot_machine, "position:y",
		slot_machine.position.y + 320, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(combo_label, "position:y",
		combo_label.position.y + 320, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await t.finished

# --- UPGRADE SCREEN ------------------------------------

func start_upgrade_phase() -> void:
	current_state = GameState.UPGRADE
	upgrade_display.show_upgrades(slot_machine.logic.shared_pool, base_rerolls_left)

	# Start offscreen to the right, then slide in
	upgrade_display.position.x = get_viewport().get_visible_rect().size.x + 200
	upgrade_display.visible = true
	var t := create_tween()
	t.tween_property(upgrade_display, "position:x",
		_upgrade_display_rest_x, 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await t.finished


func _on_upgrade_chosen(type: String, data: Variant) -> void:
	match type:
		"add":
			slot_machine.logic.shared_pool.append(data as SymbolData)
		"remove":
			slot_machine.logic.shared_pool.erase(data as SymbolData)
		"reroll":
			base_rerolls_left += 1
		"upgrade_normal":
			var sym := data as SymbolData
			sym.base_value += 2  # Modifies the resource directly, persists for the run
			ComboDictionary.dictionary_updated.emit() 
		"upgrade_multiplier":
			var sym := data as SymbolData
			sym.base_value += 1
			ComboDictionary.dictionary_updated.emit()
	
	pool_roster.refresh(slot_machine.logic.shared_pool)
	
	upgrade_display.visible = false
	_advance_to_next_boss()

func _advance_to_next_boss() -> void:
	
	current_boss_index += 1
	if current_boss_index >= boss_roster.size():
		combo_label.text = "[center][wave]YOU ARE THE CEO NOW.[/wave][/center]"
		current_state = GameState.GAME_OVER
		return

	# Slide upgrade panel back out to the right
	var out := create_tween()
	out.tween_property(upgrade_display, "position:x",
		get_viewport().get_visible_rect().size.x + 200, 0.3) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await out.finished
	upgrade_display.visible = false

	# Load new boss data
	current_boss = boss_roster[current_boss_index]
	if current_boss.boss_id == "ceo":
		print("Ceo")
		SFXManager.play_music(boss_music, -15.0)
	boss_hp = current_boss.max_hp
	turn_number = 0
	enemy_display.setup(current_boss)

	# Slide enemy and slot machine back in with a slight stagger
	var t := create_tween()
	t.tween_property(enemy_display, "position:y", _enemy_display_rest_y, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(slot_machine, "position:y",
		_slot_machine_rest_y, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.set_delay(0.08)
	t.parallel().tween_property(combo_label, "position:y",
		_combo_label_rest_y, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	
	# Play connecting animation
	await enemy_display.play_reconnected()

	start_player_turn()


func _play_scene_reveal() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.08, 0.15)
	overlay.z_index = 200
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://transition.gdshader")
	mat.set_shader_parameter("transition_type", 3)
	mat.set_shader_parameter("sectors", 1)
	mat.set_shader_parameter("position", Vector2(0.5, 0.5))
	mat.set_shader_parameter("invert", false)
	mat.set_shader_parameter("clock_feather", 0.5)
	mat.set_shader_parameter("use_sprite_alpha", false)
	mat.set_shader_parameter("use_transition_texture", false)
	mat.set_shader_parameter("progress", 1.0)  # start fully covering
	overlay.material = mat
	add_child(overlay)

	# Wipe away to reveal the combat scene
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(
		func(v: float): mat.set_shader_parameter("progress", v),
		1.0, 0.0, 0.55
	)
	t.tween_callback(overlay.queue_free)


func _transition_to_victory() -> void:
	# "Call ended" on the CEO
	enemy_display.play_disconnected()
	
	await get_tree().create_timer(1.2).timeout
	SFXManager.stop_music()
	SFXManager.play_music(victory_music, -15.0)
	SFXManager.play(victory, 0.0, 0.0, -10.0, 0.0, 0.0)
	_hide_combat_ui()
	combo_label.text = ""

	# Slide everything off screen cleanly
	var t := create_tween()
	t.tween_property(enemy_display, "position:y", enemy_display.position.y - 420, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(slot_machine, "position:y", slot_machine.position.y + 320, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(player_display, "position:x", player_display.position.x - 300, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(pool_roster, "modulate:a", 0.0, 0.3)
	await t.finished

	# Slowly fade in the Victory Screen
	victory_screen.modulate.a = 0.0
	victory_screen.visible = true
	
	var vic_tween = create_tween()
	vic_tween.tween_property(victory_screen, "modulate:a", 1.0, 1.5)
	
	# Optional: Make the player portrait pulse with success
	var portrait = %VictoryPortrait
	portrait.play("idle")

	
# --- Signal receivers -----------------------------------
func _on_spin_start() -> void:
	if combo_label:
		_hide_combo_label()

func _on_action_button_pressed() -> void:
	if current_state != GameState.PLAYER_TURN: return
	rerolls_left -= 1
	_set_buttons_spinning()
	current_state = GameState.SPINNING
	slot_machine.trigger_spin(player_hp)

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

func _on_player_learned_hold() -> void:
	if not _has_learned_hold:
		_has_learned_hold = true
		
		var t := create_tween()
		t.tween_property(hold_tutorial, "modulate:a", 0.0, 0.3)
		t.tween_callback(func(): hold_tutorial.visible = false)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_easy_pressed() -> void:
	GlobalSettings.easy_mode_hp_buff += 25
	get_tree().reload_current_scene()
