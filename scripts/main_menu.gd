extends Control

@onready var button_panel: VBoxContainer = $ButtonPanel
@onready var title_label: RichTextLabel = $Title
@onready var start_button: Button = $ButtonPanel/Start
@onready var settings_button: Button = $ButtonPanel/Settings
@onready var quit_button: Button = $ButtonPanel/Quit

@onready var audio_panel: PanelContainer = $AudioPanel
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var close_button: Button = $AudioPanel/VBoxContainer/CloseButton

@onready var transition_rect: ColorRect = $TransitionLayer

@export var background_music: AudioStream

var custom_font = load("uid://csmid407kor44")
var _transitioning := false

func _ready() -> void:
	SFXManager.play_music(background_music, -20.0)

	_setup_transition_shader()
	_setup_title()
	_setup_audio_sliders()

	audio_panel.visible = false

	start_button.pressed.connect(_on_start_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	close_button.pressed.connect(_on_close_settings)

	for btn: Button in [start_button, settings_button, quit_button]:
		btn.mouse_entered.connect(_on_btn_hover.bind(btn, true))
		btn.mouse_exited.connect(_on_btn_hover.bind(btn, false))

	# Reveal the menu on load
	_set_progress(1.0)
	await get_tree().process_frame
	_tween_progress(1.0, 0.0, 0.6)

func _setup_transition_shader() -> void:
	var mat := transition_rect.material as ShaderMaterial
	# Clock wipe — sweeps around from the left, covers entire screen at progress=1
	mat.set_shader_parameter("transition_type", 3)
	mat.set_shader_parameter("sectors", 1)
	mat.set_shader_parameter("position", Vector2(0.5, 0.5))
	mat.set_shader_parameter("invert", false)
	mat.set_shader_parameter("clock_feather", 0.5)
	mat.set_shader_parameter("use_sprite_alpha", false)
	mat.set_shader_parameter("use_transition_texture", false)
	# progress=0 → transparent, progress=1 → fully covering
	_set_progress(0.0)

func _set_progress(value: float) -> void:
	(transition_rect.material as ShaderMaterial).set_shader_parameter("progress", value)

func _tween_progress(from: float, to: float, duration: float, on_done: Callable = Callable()) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(_set_progress, from, to, duration)
	if on_done.is_valid():
		t.tween_callback(on_done)

# ── Title ─────────────────────────────────────────────────────────────────────
func _setup_title() -> void:
	

	# Subtitle line
	var sub := title_label.get_node_or_null("Subtitle") as RichTextLabel
	if sub:
		sub.text = "[center][wave amp=4 freq=2.0]a very serious corporate battle simulator[/wave][/center]"

# ── Audio ─────────────────────────────────────────────────────────────────────
func _setup_audio_sliders() -> void:
	var buses := ["Master", "Music", "SFX"]
	var sliders := [master_slider, music_slider, sfx_slider]
	for i in 3:
		var idx := AudioServer.get_bus_index(buses[i])
		var db := AudioServer.get_bus_volume_db(idx)
		sliders[i].value = _db_to_linear(db)
		sliders[i].value_changed.connect(_on_slider_changed.bind(buses[i]))

func _db_to_linear(db: float) -> float:
	if db <= -60.0: return 0.0
	return db_to_linear(db)

func _on_slider_changed(value: float, bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if value <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(value))

# ── Buttons ───────────────────────────────────────────────────────────────────
func _on_btn_hover(btn: Button, hovered: bool) -> void:
	if _transitioning: return
	btn.pivot_offset = btn.size / 2.0
		
	var target_scale := Vector2(1.1, 1.1) if hovered else Vector2.ONE
	
	if btn.has_meta("scale_tween"):
		var old_tween = btn.get_meta("scale_tween") as Tween
		if old_tween and old_tween.is_valid():
			old_tween.kill()
	
	var t := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	btn.set_meta("scale_tween", t)
	
	t.tween_property(btn, "scale", target_scale, 0.14)

# ── Scene flow ────────────────────────────────────────────────────────────────

func _on_start_pressed() -> void:
	if _transitioning: return
	_transitioning = true
	for btn: Button in [start_button, settings_button, quit_button]:
		btn.disabled = true
	# Cover the screen FIRST, then switch
	_tween_progress(0.0, 1.0, 0.45, func():
		get_tree().change_scene_to_file("res://main.tscn")
	)

func _on_quit_pressed() -> void:
	if _transitioning: return
	_transitioning = true
	_tween_progress(0.0, 1.0, 0.35, func(): get_tree().quit())

func _tween_transition(from: float, to: float, duration: float, callback: Callable = Callable()) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_method(
		func(v: float): transition_rect.material.set_shader_parameter("animation_progress", v),
		from, to, duration
	)
	if callback.is_valid():
		t.tween_callback(callback)

# ── Audio panel ───────────────────────────────────────────────────────────────

func _on_settings_pressed() -> void:
	await get_tree().process_frame
	audio_panel.position = (get_viewport_rect().size - audio_panel.size) * 0.5
	audio_panel.pivot_offset = audio_panel.size * 0.5
	audio_panel.modulate.a = 0.0
	audio_panel.scale = Vector2(0.88, 0.88)
	audio_panel.visible = true

	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(audio_panel, "scale", Vector2.ONE, 0.2)
	t.parallel().tween_property(audio_panel, "modulate:a", 1.0, 0.15)
	create_tween().tween_property(button_panel, "modulate:a", 0.3, 0.2)

func _on_close_settings() -> void:
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(audio_panel, "scale", Vector2(0.88, 0.88), 0.15)
	t.parallel().tween_property(audio_panel, "modulate:a", 0.0, 0.15)
	t.tween_callback(func(): audio_panel.visible = false)
	create_tween().tween_property(button_panel, "modulate:a", 1.0, 0.2)
