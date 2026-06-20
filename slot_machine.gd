# slot_machine.gd
class_name SlotMachine
extends Control

signal spin_finished(results: Array[SymbolData])

@onready var logic: SlotMachineLogic = $SlotMachineLogic
@onready var reels_box: HBoxContainer = $MarginContainer/Reels

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
		reels_box.add_child(reel)
		reel.initialise(logic.shared_pool)
		reel.reel_stopped.connect(_on_reel_stopped)
		reel.reel_clicked.connect(_on_reel_clicked.bind(i))
		_reels.append(reel)


# Called by BattleManager to start the process
func trigger_spin() -> void:
	if is_spinning: return
	is_spinning = true
	interactible = false # locked during spin
	_stopped_count = 0
	logic.trigger_spin() # Tells logic to pick 3 symbols

# Triggered when logic finishes picking symbols
func _on_spin_calculated(results: Array[SymbolData]) -> void:
	_last_results = results
	# Tell the visual reels to start spinning to the chosen symbols
	for i in 3:
		_reels[i].spin_to(results[i], SPIN_DURATIONS[i])

func _on_reel_stopped() -> void:
	_stopped_count += 1
	if _stopped_count == 3:
		is_spinning = false
		# interactable stays false. BattleManager sets it to true in _on_spin_finished
		spin_finished.emit(_last_results) # Tell BattleManager we are done

func _on_reel_clicked(index: int) -> void:
	print("clicked : ", index)
	if not interactible or is_spinning: return
	print("reel inde: ", index)
	var is_now_held = logic.toggle_hold(index)
	_reels[index].set_held(is_now_held)

# --- HOLD LOGIC ---
func _input(event: InputEvent) -> void:
	if is_spinning: return # Can't hold while spinning
	
	var pressed := -1
	if event.is_action_pressed("hold_1"): pressed = 0
	elif event.is_action_pressed("hold_2"): pressed = 1
	elif event.is_action_pressed("hold_3"): pressed = 2
	
	if pressed != -1:
		# Toggle in logic, get the result, and apply to visual reel
		var is_now_held = logic.toggle_hold(pressed)
		_reels[pressed].set_held(is_now_held)

# Called by BattleManager at the start of a new turn
func reset_all_holds() -> void:
	logic.reset_holds()
	for reel in _reels:
		reel.set_held(false)
