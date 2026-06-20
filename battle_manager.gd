extends Node

signal boss_turn
signal player_turn

enum GameState {PLAYER_TURN, SPINNING, RESOLVING, ENEMY_TURN, GAME_OVER}
var current_state: GameState = GameState.PLAYER_TURN

@export var current_boss: BossData
var player_hp: int = 100
var boss_hp: int = 100
var turn_number: int = 0
var rerolls_left: int = 2

@onready var enemy_display: EnemyDisplay = $EnemyArea
@onready var player_display: PlayerDisplay = $PlayerArea
@onready var combat_ui: Control = $CombatUI  # the whole button panel

@onready var slot_machine: SlotMachine = $SlotMachine
@onready var action_button: Button = $CombatUI/ActionButton
@onready var lock_in_button: Button = $CombatUI/LockInButton
@onready var intent_label: RichTextLabel = $EnemyArea/IntentBox/IntentLabel
@onready var combo_label: RichTextLabel = $CombatUI/ComboLabel  # ADD THIS NODE in editor

func _ready() -> void:
	boss_hp = current_boss.max_hp
	enemy_display.setup(current_boss)
	player_display.setup(player_hp)

	action_button.pressed.connect(_on_action_button_pressed)
	lock_in_button.pressed.connect(_on_lock_in_button_pressed)
	slot_machine.spin_finished.connect(_on_spin_finished)

	start_player_turn()

func start_player_turn() -> void:
	player_turn.emit()
	current_state = GameState.PLAYER_TURN
	rerolls_left = 2
	combat_ui.visible = true  # Show buttons again
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
	var preview = ComboDictionary.calculate(results)
	_update_combo_label(preview)

	if rerolls_left > 0:
		current_state = GameState.PLAYER_TURN
		action_button.disabled = false
		action_button.text = "REROLL (" + str(rerolls_left) + ")"
		lock_in_button.disabled = false
	else:
		# No rerolls left, auto-resolve after brief pause so player sees result
		await get_tree().create_timer(0.6).timeout
		resolve_player_attack()


func resolve_player_attack() -> void:
	current_state = GameState.RESOLVING
	slot_machine.interactible = false
	combat_ui.visible = false  # Hide buttons during resolution

	var final_symbols = slot_machine.logic.active_symbols
	var combo_result = ComboDictionary.calculate(final_symbols)
	
	boss_hp -= combo_result["damage"]
	enemy_display.update_hp(boss_hp)
	print("Player: ", combo_result["name"], " — ", combo_result["damage"], " DMG")
	await enemy_display.play_hit()  # Wait for hit anim to finish

	if boss_hp <= 0:
		print("YOU WIN!")
		current_state = GameState.GAME_OVER
		return

	await get_tree().create_timer(0.4).timeout
	start_enemy_turn()

func start_enemy_turn() -> void:
	boss_turn.emit() # for small things like changing ui stuff like mic from enemy_display
	current_state = GameState.ENEMY_TURN
	await get_tree().create_timer(0.6).timeout # for mic to change 

	var attack_dmg = current_boss.attack_pattern[turn_number % current_boss.attack_pattern.size()]
	await enemy_display.play_attack() 
	
	player_hp -= attack_dmg
	player_display.update_hp(player_hp)
	print("Boss attacks for: ", attack_dmg, " DMG")
	await player_display.play_hit()  # Then player reacts

	if player_hp <= 0:
		print("GAME OVER")
		current_state = GameState.GAME_OVER
		return

	await get_tree().create_timer(0.3).timeout
	turn_number += 1
	start_player_turn()

# --- Helpers -------------------------------------------

func _set_buttons_spinning() -> void:
	action_button.disabled = true
	lock_in_button.disabled = true
	action_button.text = "SPINNING..."

func _update_combo_label(combo: Dictionary) -> void:
	var effect_text = ""
	if combo["damage"] > 0:
		effect_text = str(combo["damage"]) + " DMG"
	elif combo.get("shield", 0) > 0:
		effect_text = str(combo["shield"]) + " SHIELD"
	combo_label.text = combo["name"] + "\n" + effect_text

# --- Signal receivers -----------------------------------
func _on_action_button_pressed() -> void:
	if current_state != GameState.PLAYER_TURN: return
	rerolls_left -= 1
	_set_buttons_spinning()
	current_state = GameState.SPINNING
	slot_machine.trigger_spin()

func _on_lock_in_button_pressed() -> void:
	if current_state != GameState.PLAYER_TURN: return
	resolve_player_attack()
