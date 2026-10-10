extends Node
## Combat scene controller.
## Rules live in CombatContext. This script only sequences beats (awaits) and drives the displays.
## Inject with setup(CombatContext) BEFORE add_child(). If nothing is injected (F6 on this scene),
## it builds its own throwaway run from the exports below so the scene still plays on its own.


signal boss_turn
signal player_turn
## Fired after a won fight AND its reward pick. Main listens to this to go back to the map.
signal combat_finished(victory: bool, cash_reward: int)

enum GameState {PLAYER_TURN, SPINNING, RESOLVING, ENEMY_TURN, UPGRADE, GAME_OVER, VICTORY}
var current_state: GameState = GameState.PLAYER_TURN

@export var hit: AudioStream
@export var shield_impact: AudioStream
@export var shield_break: AudioStream
@export var win_fight: AudioStream
@export var game_over: AudioStream
@export var victory: AudioStream
@export var victory_music: AudioStream
@export var background_music: AudioStream
@export var boss_music: AudioStream

@export_group("Standalone testing (F6)")
## Only used when no CombatContext was injected. Fights these in order.
@export var boss_roster: Array[BossData] = []
## Empty = use whatever is assigned on SlotMachineLogic.shared_pool in the editor.
@export var dev_starter_pool: Array[SymbolData] = []

var combat: CombatContext
var run: RunState:
	get:
		return combat.run

var _dev_boss_index: int = 0
var _upgrade_display_rest_x: float
var _enemy_display_rest_y: float
var _slot_machine_rest_y: float

var _has_learned_hold: bool = false

@onready var enemy_display: EnemyDisplay = $EnemyArea
@onready var player_display: PlayerDisplay = $PlayerArea
@onready var combat_ui: CombatUI = $CombatUI
@onready var combat_vfx: Node = $CombatVFX

@onready var upgrade_display: Control = $UpgradeDisplay 
@onready var enemy_area: Control = $EnemyArea

@onready var slot_machine: SlotMachine = $SlotMachine

@onready var pool_roster: Control = %PoolRoster
@onready var camera: Camera2D = %Camera2D
@onready var hold_tutorial: RichTextLabel = $HoldTutorialLabel

@onready var game_over_screen: TextureRect = $GameOverScreen
@onready var btn_restart: Button = %Restart
@onready var btn_easy: Button = %RestartEasy

@onready var victory_screen: TextureRect = $VictoryScreen
@onready var btn_victory_restart: Button = %VictoryRestart

var custom_font = load("uid://csmid407kor44")


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(c: CombatContext) -> void:
	combat = c

func _ready() -> void:
	if combat == null:
		_build_dev_combat()
	combat.passive_damage.connect(_on_passive_damage)
	run.pool_changed.connect(func(): pool_roster.refresh(run.symbol_pool))
	
	_play_combat_music()
	
	game_over_screen.visible = false
	victory_screen.visible = false
	
	enemy_display.setup(combat.enemy)
	enemy_display.show_name_immediate()
	player_display.setup(run.hp, run.max_hp)
	
	combat_ui.reroll_pressed.connect(_on_reroll_pressed)
	combat_ui.lock_in_pressed.connect(_on_lock_in_pressed)
	
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_easy.pressed.connect(_on_easy_pressed)
	btn_victory_restart.pressed.connect(_on_restart_pressed)
	
	slot_machine.spin_finished.connect(_on_spin_finished)
	slot_machine.spin_start.connect(_on_spin_start)
	slot_machine.player_learned_hold.connect(_on_player_learned_hold)
	slot_machine.setup(combat)
	
	upgrade_display.upgrade_chosen.connect(_on_upgrade_chosen)
	upgrade_display.visible = false
	
	await get_tree().process_frame
	combat_vfx.combo_label_rest_y = combat_vfx.combo_label.position.y
	_upgrade_display_rest_x = upgrade_display.position.x
	_enemy_display_rest_y = enemy_display.position.y
	_slot_machine_rest_y = slot_machine.position.y
	combat_ui.visible = false  # Start hidden, first show comes from start_player_turn
	upgrade_display.visible = false
	
	pool_roster.refresh(run.symbol_pool)
	start_player_turn()


func _play_combat_music() -> void:
	if combat.enemy.boss_id == "boss":
		SFXManager.play_music(boss_music, -15.0)
	else:
		SFXManager.play_music(background_music, -20.0)  # handles "already playing"


# ---------------------------------------------------------------------------
# Player turn
# ---------------------------------------------------------------------------

func start_player_turn() -> void:
	current_state = GameState.PLAYER_TURN   # must be set BEFORE _check_combat_over()
	
	combat.begin_player_turn()  # shield reset, rerolls, picks enemy action, start-of-turn ticks
	if _check_combat_over():
		return

	player_turn.emit()
	player_display.clear_shield()  
	combat_ui.show_ui(combat.rerolls_left)
	combat_ui.set_buttons_spinning()
	combat_vfx.combo_label.text = ""  # Clear preview from last turn
	slot_machine.reset_all_holds()
	slot_machine.apply_reel_rules(combat.get_reel_rules())
	enemy_display.set_intent(combat.next_action, combat)
	
	current_state = GameState.SPINNING
	await get_tree().create_timer(0.5).timeout
	slot_machine.trigger_spin(run.hp)


func resolve_player_attack() -> void:
	# --- Race condition lock ---
	if current_state == GameState.RESOLVING or current_state == GameState.UPGRADE or current_state == GameState.GAME_OVER:
		return 
	current_state = GameState.RESOLVING
	# ----------------------------
	slot_machine.interactible = false
	combat_ui.hide_ui()  # Hide buttons during resolution

	var final_symbols: Array[SymbolData] = slot_machine.logic.active_symbols
	var ctx := combat.make_battle_context(final_symbols)
	var combo_result = ComboDictionary.calculate(ctx)
	
	# --- COMMIT PHASE ---
	# Trigger all "on play" effects (like scaling) once
	for i in 3:
		if ctx.board[i] != null and ctx.board[i].effect != null:
			ctx.board[i].effect.on_commit(i, ctx)
	#combat.player_statuses.on_lock_in(ctx)
	await slot_machine.play_popups(ctx.drain_popups())
	# ------------------------
	
	# Beat 1: combo announcement (if earned)
	if combo_result["is_combo"]:
		await show_combo_announcement(combo_result["name"])
	
	# Beat 2: words fly across the screen (throw_symbols must skip null reels)
	await combat_vfx.throw_symbols(final_symbols, slot_machine.get_reel_global_centers(), enemy_display.get_portrait_global_center())
	
	# Beat 3: impact. Rules first (state), then show it
	var boss_center := enemy_display.get_portrait_global_center()
	var player_center := player_display.get_global_center()
	
	var enemy_hit := combat.damage_enemy(combo_result["impact"])
	combat.add_player_shield(combo_result["bandwidth"])
	combat.heal_player(combo_result["morale"])

	if enemy_hit.hp_damage > 0:
		combat_vfx.spawn_floating_text("[b][color=#cc5555]-" + str(enemy_hit.hp_damage) + " HP[/color][/b]",
		boss_center + Vector2(128, -32))
	if enemy_hit.absorbed > 0:
		combat_vfx.spawn_floating_text("[b][color=#55aaff]+" + str(enemy_hit.absorbed) + " BLOCKED[/color][/b]",
		player_center + Vector2(128, -8))
	if combo_result["bandwidth"] > 0:
		combat_vfx.spawn_floating_text("[b][color=#55aaff]+" + str(combo_result["bandwidth"]) + " BW[/color][/b]",
		player_center + Vector2(-24, 12))
	if combo_result["morale"] > 0:
		combat_vfx.spawn_floating_text("[b][color=#55ee77]+" + str(combo_result["morale"]) + " MORALE[/color][/b]",
		player_center + Vector2(0, -18))
		
	SFXManager.play(hit, 0.0, 0.0, -20.0, 1.5, 0.0)
	await enemy_display.play_hit()  # Wait for hit anim to finish
	
	enemy_display.update_hp(combat.enemy_hp)
	enemy_display.set_shield(combat.enemy_shield)
	player_display.set_shield(combat.player_shield)
	player_display.update_hp(run.hp)
	
	# Beat 4: boss mumbles defeated corporate speak
	enemy_display.show_reaction(combo_result["impact"])
	if _check_combat_over():
		return
	
	await get_tree().create_timer(1.0).timeout
	combat.end_player_turn()  # player/machine statuses tick + expire
	slot_machine.apply_reel_rules(combat.get_reel_rules())    # clear stamps that just expired
	if _check_combat_over():
		return
	start_enemy_turn()

# ---------------------------------------------------------------------------
# Enemy turn
# ---------------------------------------------------------------------------

func start_enemy_turn() -> void:
	combat.begin_enemy_turn()
	boss_turn.emit() # small UI things, e.g. mic on the enemy display
	current_state = GameState.ENEMY_TURN
	enemy_display.clear_shield()
	await get_tree().create_timer(0.5).timeout

	await enemy_display.play_attack() 
	await _execute_enemy_action(combat.next_action)
	if _check_combat_over():
			return
	
	combat.end_enemy_turn()  # enemy statuses tick here, turn_number increments
	if _check_combat_over():
			return
	await get_tree().create_timer(0.5).timeout
	start_player_turn()
	

func _execute_enemy_action(action: EnemyAction) -> void:
	var boss_center := enemy_display.get_portrait_global_center()
	
	if action.shield > 0:
		combat.add_enemy_shield(action.shield)
		enemy_display.set_shield(combat.enemy_shield)
		combat_vfx.spawn_floating_text("[b][color=#55aaff]+" + str(action.shield) + " BW[/color][/b]", boss_center + Vector2(128, -32))
	if action.heal > 0:
		combat.heal_enemy(action.heal)
		enemy_display.update_hp(combat.enemy_hp)
		combat_vfx.spawn_floating_text("[b][color=#55ee77]+" + str(action.heal) + " MORALE[/color][/b]", boss_center + Vector2(128, -32))
	if action.damage > 0:
		var dmg := combat.enemy_statuses.modify_damage_dealt(action.damage)
		await _play_player_damage(combat.damage_player(dmg))
	
	if not action.effects.is_empty():
		for effect in action.effects:
			effect.apply(combat)
		slot_machine.apply_reel_rules(combat.get_reel_rules())  # sabotage stamps slam in right now
		await get_tree().create_timer(0.4).timeout

# Read shield/HP block from the DamageResult instead of computing it
func _play_player_damage(r: DamageResult) -> void:
	player_display.set_shield(r.shield_after)  # what absorb_damage() used to do visually
	
	if r.shield_broke:
		await player_display.play_shield_break(r.shield_before, r.exact_break)
 
	if r.hp_damage <= 0:
		if not r.shield_broke:
			await player_display.play_blocked()
		SFXManager.play(shield_impact, 0.0, 0.0, -20.0, 1.0, 0.0)
	else:
		if r.shield_broke:
			SFXManager.play(shield_break, 0.0, 0.0, -20.0, 1.0, 0.0)
		player_display.update_hp(run.hp)
		combat_vfx.spawn_floating_text("[b][color=#cc5555]-" + str(r.hp_damage) + " HP[/color][/b]",
			player_display.get_global_center() + Vector2(-24, 12))
		SFXManager.play(hit, 0.0, 0.0, -20.0, 1.0, 0.0)
		await player_display.play_hit()

# Damage caused by statuses announced by CombatContext
func _on_passive_damage(side: int, r: DamageResult, source: String) -> void:
	if r.hp_damage <= 0:
		return
	var text := "[b][color=#cc5555]-%d HP[/color][/b] [color=#99a3c2](%s)[/color]" % [r.hp_damage, source]
	if side == StatusContainer.Side.PLAYER:
		player_display.update_hp(run.hp)
		combat_vfx.spawn_floating_text(text, player_display.get_global_center() + Vector2(-24, 12))
	else:
		enemy_display.update_hp(combat.enemy_hp)
		combat_vfx.spawn_floating_text(text, enemy_display.get_portrait_global_center() + Vector2(128, -32))


# ---------------------------------------------------------------------------
# End-of-combat checks
# ---------------------------------------------------------------------------
## True if the fight is over (and the right flow has been started).
func _check_combat_over() -> bool:
	if current_state == GameState.GAME_OVER or current_state == GameState.VICTORY or current_state == GameState.UPGRADE:
		return true
	if combat.is_player_dead():
		_trigger_game_over()
		return true
	if combat.is_enemy_dead():
		_on_enemy_defeated()
		return true
	return false

func _trigger_game_over() -> void:
	current_state = GameState.GAME_OVER
	game_over_screen.modulate.a = 0.0
	game_over_screen.visible = true
	create_tween().tween_property(game_over_screen, "modulate:a", 1.0, 1.5)
	SFXManager.play(game_over, 0.0, 0.0, -15.0, 1.0, 0.0)
 
func _on_enemy_defeated() -> void:
	if combat.is_final_boss:
		current_state = GameState.VICTORY
		await _transition_to_victory()
	else:
		current_state = GameState.UPGRADE
		await _transition_to_upgrade()
		start_upgrade_phase()

# --- Helpers ---------------------------------------------------------------

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
	rtl.clip_contents = false

	rtl.text = "[center][wave amp=20 freq=5][b][color=#ffe135]* " + combo_name.to_upper() + " *[/color][/b][/wave][/center]"
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
	

# -------------------------------------------------------
# --- UPGRADE SCREEN (will move to its own reward scene) 
# -------------------------------------------------------

func _transition_to_upgrade() -> void:
	# "Call ended" on the nameplate first, brief pause for drama
	enemy_display.play_disconnected()
	await get_tree().create_timer(0.8).timeout
	
	SFXManager.play(win_fight, 0.0, 0.0, -10.0 , 1.0, 0.0)

	combat_ui.hide_ui()
	combat_vfx.combo_label.text = ""
	
	# Slide enemy UP and slot machine DOWN simultaneously
	var t := create_tween()
	t.tween_property(enemy_display, "position:y",
		enemy_display.position.y - 420, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(slot_machine, "position:y",
		slot_machine.position.y + 320, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(combat_vfx.combo_label, "position:y",
		combat_vfx.combo_label.position.y + 320, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await t.finished


func start_upgrade_phase() -> void:
	current_state = GameState.UPGRADE
	upgrade_display.show_upgrades(run.symbol_pool, run.base_rerolls)

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
			run.add_symbol(data as SymbolData)
		"remove":
			run.remove_symbol(data as SymbolData)
		"reroll":
			run.base_rerolls += 1
		"upgrade_normal":
			var sym := data as SymbolData
			# Buff the correct specific stat
			match sym.effect_type:
				SymbolData.EffectType.DAMAGE: sym.base_impact += 4
				SymbolData.EffectType.SHIELD: sym.base_bandwidth += 4
				SymbolData.EffectType.HEAL: sym.base_morale += 4
			ComboDictionary.dictionary_updated.emit() 
		"upgrade_multiplier":
			var sym := data as SymbolData
			# TODO: make it not hard coded
			if sym.effect is MultiplyLeftEffect:
				sym.effect.base_multiplier += 2
			elif sym.effect is BuffAllEffect:
				sym.effect.buff_amount += 2
			ComboDictionary.dictionary_updated.emit()
	
	pool_roster.refresh(run.symbol_pool)
	upgrade_display.visible = false
	# Whoever owns the run loop (Main, or the dev harness below) takes it from here.
	combat_finished.emit(true, combat.enemy.cash_reward)


func _transition_to_victory() -> void:
	# "Call ended" on the CEO
	enemy_display.play_disconnected()
	
	await get_tree().create_timer(1.2).timeout
	SFXManager.stop_music()
	SFXManager.play_music(victory_music, -15.0)
	combat_ui.hide_ui()
	combat_vfx.combo_label.text = ""

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


# --------------------------------------------------------
# --- Signal receivers -----------------------------------
# --------------------------------------------------------

func _on_spin_start() -> void:
	if combat_vfx.combo_label:
		combat_vfx._hide_combo_label()

func _on_spin_finished(results: Array[SymbolData]) -> void:
	# Update combo preview
	var ctx = combat.make_battle_context(results)
	var combo = ComboDictionary.calculate(ctx)
	combat_vfx._update_combo_label(results, combo)

	if combat.rerolls_left > 0:
		current_state = GameState.PLAYER_TURN
		slot_machine.interactible = true  # Player can click reels
		combat_ui.set_buttons_active(combat.rerolls_left)
		
		if not _has_learned_hold:
			hold_tutorial.modulate.a = 0.0
			hold_tutorial.visible = true
			create_tween().tween_property(hold_tutorial, "modulate:a", 1.0, 0.4)
	else:
		# Auto-resolve
		slot_machine.interactible = false # Lock reels so they can't click during wait
		await get_tree().create_timer(1.0).timeout
		
		# Only resolve if the player hasn't somehow already resolved it
		if current_state != GameState.RESOLVING and current_state != GameState.UPGRADE:
			resolve_player_attack()

func _on_reroll_pressed() -> void:
	if current_state != GameState.PLAYER_TURN: return
	combat.rerolls_left -= 1
	combat_ui.set_buttons_spinning()
	current_state = GameState.SPINNING
	slot_machine.trigger_spin(run.hp)

func _on_lock_in_pressed() -> void:
	if current_state != GameState.PLAYER_TURN: return
	resolve_player_attack()

func _on_player_learned_hold() -> void:
	if not _has_learned_hold:
		_has_learned_hold = true
		
		var t := create_tween()
		t.tween_property(hold_tutorial, "modulate:a", 0.0, 0.3)
		t.tween_callback(func(): hold_tutorial.visible = false)

# Reloading the current scene reloads Main once it exists, which = a fresh run. Same call works in both modes.
func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_easy_pressed() -> void:
	GlobalSettings.easy_mode_hp_buff += 25
	get_tree().reload_current_scene()

# --------------------------------------------------------
# --- DEV HARNESS (delete once Main owns the run loop) ----
# --------------------------------------------------------
# Lets this scene run on its own: builds a RunState, and after each reward pick
# starts the next boss in boss_roster, same loop as the jam build.
 
func _build_dev_combat() -> void:
	assert(not boss_roster.is_empty(), "Standalone mode needs boss_roster filled in on the combat scene")
	var pool: Array[SymbolData] = dev_starter_pool
	if pool.is_empty():
		pool = slot_machine.logic.shared_pool
	var new_run := RunState.create(pool, GlobalSettings.easy_mode_hp_buff)
	combat = _dev_make_combat(new_run)
	combat_finished.connect(_dev_on_combat_finished)
 
func _dev_make_combat(r: RunState) -> CombatContext:
	var c := CombatContext.new(r, boss_roster[_dev_boss_index])
	c.is_final_boss = _dev_boss_index >= boss_roster.size() - 1
	return c
 
func _dev_on_combat_finished(won: bool, cash: int) -> void:
	if not won:
		return
	var r := run
	r.add_cash(cash)
	_dev_boss_index += 1
	combat = _dev_make_combat(r)
	combat.passive_damage.connect(_on_passive_damage)
	slot_machine.setup(combat)
 
	_play_combat_music()
	enemy_display.setup(combat.enemy)
 
	# Slide enemy and slot machine back in with a slight stagger
	var t := create_tween()
	t.tween_property(enemy_display, "position:y", _enemy_display_rest_y, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(slot_machine, "position:y",
		_slot_machine_rest_y, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.set_delay(0.08)
	t.parallel().tween_property(combat_vfx.combo_label, "position:y",
		combat_vfx.combo_label_rest_y, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
 
	await enemy_display.play_reconnected()
	start_player_turn()
 
