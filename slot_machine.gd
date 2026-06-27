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

	logic.trigger_spin(player_hp) # Tells logic to pick 3 symbols
	

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
		# 1. Update the text immediately to RAW base stats
		label.text = ComboDictionary.describe_symbol(symbol)
		label.pivot_offset = label.size * 0.5
		
		# 2. The "Thump" Animation
		label.scale = Vector2(0.5, 0.5)
		label.modulate.a = 0.0
		
		var t := create_tween()
		t.tween_property(label, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(label, "modulate:a", 1.0, 0.08)
		t.chain().tween_property(label, "scale", Vector2(1.0, 1.0), 0.06).set_trans(Tween.TRANS_SINE)
		
		var base_pitch := 0.9 + 0.1 * (_stopped_count - 1)
		base_pitch += randf_range(-0.03, 0.03)
		SFXManager.play(reel_thump, 0.0, 0.05, -2.0, base_pitch)

	# If this was the last reel, trigger the Synergy Phase!
	if _stopped_count == 3:
		is_spinning = false
		await _update_contextual_labels() # WAIT for animations to finish!
		spin_finished.emit(_last_results)


	# If this was the last reel, finish the spin
	if _stopped_count == 3:
		is_spinning = false
		_update_contextual_labels()
		spin_finished.emit(_last_results)

func _update_contextual_labels() -> void:
	for i in 3:
		if _last_results[i] == null:
			continue
		var new_text := ComboDictionary.get_label_for_position(_last_results, i)
		var label := info_labels[i]
		if new_text == label.text:
			continue  # No change, skip animation
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
