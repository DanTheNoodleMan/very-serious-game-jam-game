class_name CombatUI extends Control

signal reroll_pressed
signal lock_in_pressed

@export var button_down_sfx: AudioStream
@export var button_up_sfx: AudioStream
@export var slide: AudioStream

@onready var reroll_button: TextureButton = $RerollButton
@onready var reroll_button_label: Label = $RerollButton/RerollButtonLabel
@onready var lock_in_button: TextureButton = $LockInButton
@onready var lock_in_button_label: Label = $LockInButton/LockInButtonLabel

var _rest_x: float
var _ui_tween: Tween


func _ready() -> void:
	reroll_button.pressed.connect(reroll_pressed.emit)
	reroll_button.button_down.connect(_on_reroll_down)
	reroll_button.button_up.connect(_on_reroll_up)
	
	lock_in_button.pressed.connect(lock_in_pressed.emit)
	lock_in_button.button_down.connect(_on_lock_in_down)
	lock_in_button.button_up.connect(_on_lock_in_up)

	await get_tree().process_frame
	_rest_x = position.x
	visible = false  # Start hidden, first show comes from start_player_turn


# --- Public API for BattleManager ---

func show_ui(rerolls_left: int) -> void:
	set_buttons_active(rerolls_left)
	if is_instance_valid(_ui_tween): _ui_tween.kill()
	
	position.x = _rest_x + size.x + 16.0
	visible = true
	var overshoot := 6.0
	SFXManager.play(slide, 0.0, 0.0, -10.0, 0.75, 0.0) 

	_ui_tween = create_tween()
	# Step 1: slide in and slightly past the rest position
	_ui_tween.tween_property(self, "position:x", _rest_x - overshoot, 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Step 2: spring back to the true rest position
	_ui_tween.chain().tween_property(self, "position:x", _rest_x, 0.12) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func hide_ui() -> void:
	if not visible: return
	if is_instance_valid(_ui_tween): _ui_tween.kill()
	
	SFXManager.play(slide, 0.0, 0.0, -10.0, 1.5, 0.0) 
	_ui_tween = create_tween()
	_ui_tween.tween_property(self, "position:x", _rest_x + size.x + 16.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_ui_tween.tween_callback(func(): visible = false)

func set_buttons_active(rerolls_left: int) -> void:
	reroll_button.disabled = false
	reroll_button_label.text = "REROLL (" + str(rerolls_left) + ")"
	lock_in_button.disabled = false

func set_buttons_spinning() -> void:
	reroll_button.disabled = true
	lock_in_button.disabled = true
	reroll_button_label.text = "SPINNING..."

# --- Private Button SFX ---

func _on_reroll_down(): reroll_button_label.position.y += 2; SFXManager.play(button_down_sfx, 0.1, 0.05, -15.0, 1.0)
func _on_reroll_up(): reroll_button_label.position.y -= 2; SFXManager.play(button_up_sfx, 0.1, 0.05, -15.0, 1.0)
func _on_lock_in_down(): lock_in_button_label.position.y += 2; SFXManager.play(button_down_sfx, 0.1, 0.05, -15.0, 1.0)
func _on_lock_in_up(): lock_in_button_label.position.y -= 2; SFXManager.play(button_up_sfx, 0.1, 0.05, -15.0, 1.0)
