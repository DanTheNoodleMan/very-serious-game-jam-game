# slot_machine.gd
class_name SlotMachine
extends Control

signal spin_finished(results: Array[SymbolData])
signal spin_start
signal player_learned_hold

@onready var logic: SlotMachineLogic = $SlotMachineLogic
@onready var reels_box: HBoxContainer = $MarginContainer/Reels
@onready var info_labels: Array[RichTextLabel] = [
	$SymbolInfoRow/InfoLabel0,
	$SymbolInfoRow/InfoLabel1,
	$SymbolInfoRow/InfoLabel2,
]

@export var spin_sound: AudioStream
@export var reel_thump: AudioStream
@export var border_tex: Texture2D
@export var lock_tex: Texture2D

const SPIN_SFX_LENGTH := 1.4 # seconds — update if you swap the file

const SPIN_DURATIONS := [0.6, 1.0, 1.4]
var _reels: Array[SlotReel] = []
var _stopped_count: int = 0
var is_spinning: bool = false
var interactible: bool = false # BattleManager controls this
var _last_results: Array[SymbolData] = []

func _ready() -> void:
	# Listen for when the math is done
	logic.spin_calculated.connect(_on_spin_calculated)
	_build_reels()

func _build_reels() -> void:
	# Clear out any placeholder panels in the editor
	for child in reels_box.get_children():
		child.queue_free()

	# Create 3 reels dynamically
	for i in 3:
		var reel := SlotReel.new()
		reel.border_texture = border_tex
		reel.lock_texture = lock_tex
		reels_box.add_child(reel)
		reel.initialise(logic.shared_pool)
		reel.reel_stopped.connect(_on_reel_stopped.bind(i))
		reel.reel_clicked.connect(_on_reel_clicked.bind(i))
		_reels.append(reel)
		
		# Make sure labels pivot from their center for the pop animation
		info_labels[i].pivot_offset = info_labels[i].size * 0.5

# Called by BattleManager to start the process
func trigger_spin(player_hp: int = 100) -> void:
	if is_spinning: return
	spin_start.emit()
	is_spinning = true
	interactible = false # locked during spin
	_stopped_count = 0
	for label in info_labels:
		label.text = ""
	SFXManager.play(spin_sound, 0.0, 0.0, -10.0, 0.0, 0.0) 

	logic.trigger_spin(player_hp) # Tells logic to pick 3 symbols // player_hp for pity system
	

func get_reel_global_centers() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for reel in _reels:
		positions.append(reel.global_position + Vector2(reel.custom_minimum_size.x, reel.custom_minimum_size.y) * 0.5)
	return positions


# Triggered when logic finishes picking symbols
func _on_spin_calculated(results: Array[SymbolData]) -> void:
	_last_results = results
	# Tell the visual reels to start spinning to the chosen symbols
	for i in 3:
		_reels[i].spin_to(results[i], SPIN_DURATIONS[i])

func _on_reel_stopped(index: int) -> void:
	_stopped_count += 1
	
	var label = info_labels[index]
	var symbol = _last_results[index]
	
	if symbol != null:
		# --- PRE: TRIGGER LANDING EFFECTS EXACTLY ONCE ---
		var popup_text := ""
		if symbol.effect != null:
			var dummy_ctx = BattleContext.new(_last_results)
			var was_held: bool = logic.held_slots[index]
			popup_text = symbol.effect.on_landed(index, was_held, dummy_ctx)
		# -------------------------------------------------
		
		# 1. Update the text immediately to RAW base stats
		label.text = ComboDictionary.describe_symbol(symbol)
		label.pivot_offset = label.size * 0.5
		
		var base_pitch := 0.9 + 0.1 * (_stopped_count - 1)
		base_pitch += randf_range(-0.03, 0.03)
		var t := create_tween()
		
		if popup_text != "":
			# --- THE MASSIVE LEVEL-UP POP ---
			SFXManager.play(reel_thump, 0.0, 0.05, 5.0, base_pitch + 0.8) # Much louder, much higher!
			
			label.scale = Vector2(1.8, 1.8) # Start HUGE
			label.modulate = Color(1.5, 1.3, 0.4, 1.0) # Start fully OPAQUE Gold
			
			t.tween_property(label, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(label, "modulate", Color.WHITE, 0.4).set_delay(0.1) # Fade back to white slowly
			
			# --- SPAWN THE FLOATING "+1" TEXT ---
			_spawn_reel_floaty(popup_text, index)
			
		else:
			# --- THE NORMAL THUMP ---
			SFXManager.play(reel_thump, 0.0, 0.05, -2.0, base_pitch)
			label.scale = Vector2(0.5, 0.5)
			label.modulate = Color(1, 1, 1, 0)
			
			t.tween_property(label, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(label, "modulate:a", 1.0, 0.08)
			t.chain().tween_property(label, "scale", Vector2(1.0, 1.0), 0.06).set_trans(Tween.TRANS_SINE)
		
		

	# If this was the last reel, finish the spin and update labels
	if _stopped_count == 3:
		is_spinning = false
		await _update_contextual_labels() # wait for animations to finish
		spin_finished.emit(_last_results)
# A tiny helper function to handle the floating text!
func _spawn_reel_floaty(text: String, reel_index: int) -> void:
	var floaty := Label.new()
	floaty.text = text
	floaty.add_theme_font_override("font", load("uid://csmid407kor44")) # Your custom font
	floaty.add_theme_font_size_override("font_size", 24)
	floaty.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2)) # Bright Gold
	floaty.add_theme_color_override("font_outline_color", Color.BLACK)
	floaty.add_theme_constant_override("outline_size", 6)
	
	add_child(floaty)
	
	# Start it perfectly centered on the reel
	var reel = _reels[reel_index]
	floaty.global_position = reel.global_position + (reel.size / 2.0) - Vector2(10, 10)
	
	var ft := create_tween()
	# Float up and fade out!
	ft.tween_property(floaty, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	ft.parallel().tween_property(floaty, "modulate:a", 0.0, 0.6).set_delay(0.2)
	ft.tween_callback(floaty.queue_free)
	
func _update_contextual_labels() -> void:
	# Build a basic context just for UI display purposes
	var display_ctx = BattleContext.new(_last_results)
	
	# Fill display_ctx.buckets with all the final numbers
	ComboDictionary.calculate(display_ctx)

	for i in 3:
		if _last_results[i] == null:
			continue
		
		var new_text := ComboDictionary.get_label_for_position(display_ctx, i)
		var label := info_labels[i]
		
		if new_text == label.text:
			continue  # No change, skip animation
		
		await get_tree().create_timer(0.2).timeout
		if _last_results[i].effect_type == SymbolData.EffectType.MULTIPLIER:
			label.text = new_text
			label.pivot_offset = label.size * 0.5
			# Small pop to draw attention to any value that changed
			var t := label.create_tween()
			t.tween_property(label, "scale", Vector2(1.18, 1.18), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.chain().tween_property(label, "scale", Vector2(1.0, 1.0), 0.07).set_trans(Tween.TRANS_SINE)



func _on_reel_clicked(index: int) -> void:
	if not interactible or is_spinning: return
	player_learned_hold.emit()
	var is_now_held = logic.toggle_hold(index)
	_reels[index].set_held(is_now_held, true)
	

# --- HOLD LOGIC ---
func _input(event: InputEvent) -> void:
	if is_spinning: return # Can't hold while spinning
	
	var pressed := -1
	if event.is_action_pressed("hold_1"): pressed = 0
	elif event.is_action_pressed("hold_2"): pressed = 1
	elif event.is_action_pressed("hold_3"): pressed = 2
	
	if pressed != -1:
		# Toggle in logic, get the result, and apply to visual reel
		player_learned_hold.emit()
		var is_now_held = logic.toggle_hold(pressed)
		_reels[pressed].set_held(is_now_held, true)

# Called by BattleManager at the start of a new turn
func reset_all_holds() -> void:
	logic.reset_holds()
	for reel in _reels:
		reel.set_held(false, false)
