class_name SlotReel
extends Control

signal reel_stopped
signal reel_clicked
signal hover_changed(is_hovered: bool)

@export var sym_size := 64
@export var border_texture: Texture2D # NEW: Assign your border PNG here
@export var border_thickness := 2    # NEW: How far outside the reel the border sits
@export var nine_patch_margin := 10  # Adjust based on your PNG's border size
@export var lock_texture: Texture2D

var lock_sfx: AudioStream = load("uid://d0xou4xt62a8b")

var _pool: Array = []
var _flash_rect: ColorRect
var _spin_coroutine: RefCounted   
var _hold_tween: Tween 

var is_held: bool = false
var _is_hovered: bool = false

var _clip_box: Control # The internal box that clips the spin
var _border_rect: NinePatchRect # The border
var _symbol_rect: TextureRect
var _next_rect: TextureRect 
var _lock_icon: TextureRect

func _ready() -> void:
	# clip_contents is NOT on 'self' anymore so the border can render outside
	custom_minimum_size = Vector2(sym_size, sym_size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# ── The Clipping Box ──
	_clip_box = Control.new()
	_clip_box.size = Vector2(sym_size, sym_size)
	_clip_box.clip_contents = true
	_clip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip_box)

	# ── Main symbol display ──
	_symbol_rect = TextureRect.new()
	_symbol_rect.size = Vector2(sym_size, sym_size)
	_symbol_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_symbol_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_symbol_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip_box.add_child(_symbol_rect) # Added to _clip_box instead of self
	
	# ── Second symbol for the infinite scroll illusion ──
	_next_rect = TextureRect.new()
	_next_rect.size = Vector2(sym_size, sym_size)
	_next_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_next_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_next_rect.position.y = -sym_size
	_next_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_clip_box.add_child(_next_rect) # Added to _clip_box instead of self

	# ── Overlay rectangles ──
	# Modified _make_overlay to add them to _clip_box
	_flash_rect = _make_overlay(Color(1.0, 0.95, 0.55, 0.0))
		
	# ── The NinePatchRect Border ──
	_border_rect = NinePatchRect.new()
	if border_texture:
		_border_rect.texture = border_texture
		_border_rect.patch_margin_left = nine_patch_margin
		_border_rect.patch_margin_right = nine_patch_margin
		_border_rect.patch_margin_top = nine_patch_margin
		_border_rect.patch_margin_bottom = nine_patch_margin
		_border_rect.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		_border_rect.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	
	# ── The Lock Symbol Sprite ──
	_lock_icon = TextureRect.new()
	if lock_texture:
		_lock_icon.texture = lock_texture
		_lock_icon.size = lock_texture.get_size()   # 32x32
		_lock_icon.pivot_offset = _lock_icon.size * 0.5
		_lock_icon.position = (Vector2(sym_size, sym_size) - _lock_icon.size) / 2.0
		_lock_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lock_icon.visible = false
		_lock_icon.modulate.a = 0.0
		add_child(_lock_icon)      # add as last child = on top
	
	# Position it so it perfectly surrounds the 64x64 clip box
	_border_rect.position = Vector2(-1, -1) # -1 and -1 to take into account the shadow on the new border I made

	_border_rect.size = Vector2(sym_size + border_thickness * 2, sym_size + border_thickness * 2)

	add_child(_border_rect)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_refresh_visuals()

func initialise(pool: Array) -> void:
	_pool = pool
	if not _pool.is_empty():
		_symbol_rect.texture = (_pool.pick_random() as SymbolData).icon
		_next_rect.texture = (_pool.pick_random() as SymbolData).icon

# ── The Physics-Based Spin Cycle ────────────────────────────────────────────────────────

func _spin_cycle(result_symbol: SymbolData, fast_time: float, decel_time: float) -> void:
	var total_time := fast_time + decel_time
	var start_time := Time.get_ticks_msec() / 1000.0
	
	var max_speed := 1800.0 
	
	while true:
		var elapsed := (Time.get_ticks_msec() / 1000.0) - start_time
		if elapsed >= total_time:
			break
			
		var delta := get_process_delta_time()
		var current_speed := max_speed
		
		if elapsed > fast_time:
			var decel_ratio := 1.0 - ((elapsed - fast_time) / decel_time)
			current_speed = max_speed * decel_ratio
			current_speed = max(current_speed, 300.0)

		_symbol_rect.position.y += current_speed * delta
		_next_rect.position.y += current_speed * delta
		
		if _symbol_rect.position.y >= sym_size:
			_symbol_rect.position.y = _next_rect.position.y - sym_size
			if not _pool.is_empty():
				_symbol_rect.texture = (_pool.pick_random() as SymbolData).icon
			
		if _next_rect.position.y >= sym_size:
			_next_rect.position.y = _symbol_rect.position.y - sym_size
			if not _pool.is_empty():
				_next_rect.texture = (_pool.pick_random() as SymbolData).icon
			
		await get_tree().process_frame

	if result_symbol != null:
		_symbol_rect.texture = result_symbol.icon
	else:
		_symbol_rect.texture = null 
		
	_next_rect.position.y = -sym_size
	_symbol_rect.position.y = 12.0 
	
	var snap_tween := create_tween()
	snap_tween.tween_property(_symbol_rect, "position:y", 0.0, 0.15)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	
	_on_landed()

func _make_overlay(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.size = Vector2(sym_size , sym_size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	r.material = mat
	
	# ── NEW: Add overlays to the clip box so they don't cover the border ──
	_clip_box.add_child(r)
	return r

func spin_to(result_symbol: SymbolData, duration: float) -> void:
	_spin_coroutine = null

	if is_held:
		reel_stopped.emit()
		return

	var fast_time := duration * 0.7
	var decel_time := duration * 0.3

	_spin_coroutine = await _spin_cycle.bind(result_symbol, fast_time, decel_time).call()

func _on_landed() -> void:
	_squeeze_pop()
	_flash_lock_in()
	reel_stopped.emit()

func _squeeze_pop() -> void:
	var t := create_tween()
	# Tween the whole reel (including the border) for the mechanical feel
	t.tween_property(self, "scale", Vector2(0.82, 1.22), 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(self, "scale", Vector2(1.14, 0.88), 0.10) \
		.set_trans(Tween.TRANS_SINE)
	t.chain().tween_property(self, "scale", Vector2(1.0, 1.0),  0.22) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _flash_lock_in() -> void:
	var t := create_tween()
	t.tween_property(_flash_rect, "color:a", 0.85, 0.04)
	t.chain().tween_property(_flash_rect, "color:a", 0.0,  0.30)

func set_held(held: bool, clicked: bool) -> void:
	is_held = held
	
	if is_instance_valid(_hold_tween):
		_hold_tween.kill()
	_hold_tween = create_tween()
	_hold_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)

	if held:
		if clicked: SFXManager.play(lock_sfx, 0.2, 0.0, -30.0, 2.0, 0.0)
		
		# Bounce the symbol down a little
		_symbol_rect.position.y = 8.0
		_hold_tween.parallel().tween_property(_symbol_rect, "position:y", 0.0, 0.25)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			
		# Snappy lock pop
		_hold_tween.parallel().tween_property(_lock_icon, "modulate:a", 1.0, 0.1)
		_hold_tween.parallel().tween_property(_lock_icon, "scale", Vector2(1.2, 1.2), 0.08)\
			.from(Vector2(0.6, 0.6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_hold_tween.chain().tween_property(_lock_icon, "scale", Vector2(1.0, 1.0), 0.02)\
			.set_trans(Tween.TRANS_SINE)
	else:
		if clicked: SFXManager.play(lock_sfx, 0.2, 0.0, -30.0, 1.5, 0.0)
		
		# Fade out and shrink a tiny bit
		_hold_tween.tween_property(_lock_icon, "modulate:a", 0.0, 0.12)
		_hold_tween.parallel().tween_property(_lock_icon, "scale", Vector2(0.8, 0.8), 0.12)\
			.set_trans(Tween.TRANS_SINE)
		_symbol_rect.position.y = 0.0
		
	_refresh_visuals()

func flash_jackpot() -> void:
	var t := create_tween()
	t.tween_property(_flash_rect, "color:a", 1.0,  0.06)
	t.chain().tween_property(_flash_rect, "color:a", 0.0,  0.10)
	t.chain().tween_property(_flash_rect, "color:a", 0.90, 0.06)
	t.chain().tween_property(_flash_rect, "color:a", 0.0,  0.10)
	t.chain().tween_property(_flash_rect, "color:a", 0.70, 0.06)
	t.chain().tween_property(_flash_rect, "color:a", 0.0,  0.35)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			reel_clicked.emit()

func _on_mouse_entered() -> void:
	_is_hovered = true
	_refresh_visuals()

func _on_mouse_exited() -> void:
	_is_hovered = false
	_refresh_visuals()

func _refresh_visuals() -> void:
	if is_held:
		# Held state → lock on, symbol dimmed
		_lock_icon.visible = true
		_symbol_rect.modulate = Color(0.6, 0.6, 0.6, 1.0)   # dim to 50% grey
		# (lock alpha will be handled by the tween in set_held)
	elif _is_hovered:
		# Hovered but not held → lock faint, symbol slightly dimmed
		_lock_icon.visible = true
		_lock_icon.modulate.a = 0.3
		_symbol_rect.modulate = Color(0.8, 0.8, 0.8, 1.0)   # slightly grey
	else:
		# Normal state → no lock, symbol full colour
		_lock_icon.visible = false
		_lock_icon.modulate.a = 0.0
		_symbol_rect.modulate = Color.WHITE
