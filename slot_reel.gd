class_name SlotReel
extends Control

signal reel_stopped
signal reel_clicked

@export var sym_size := 64

var _pool: Array = []
var _flash_rect: ColorRect
var _held_rect: ColorRect
var _spin_coroutine: RefCounted   
var _hold_tween: Tween # stores the hold animation so we can loop/kill it!

var is_held: bool = false


var _symbol_rect: TextureRect
var _next_rect: TextureRect # the second texture for the scrolling illusion

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(sym_size, sym_size)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# ── Main symbol display ───────────────────────────────────
	_symbol_rect = TextureRect.new()
	_symbol_rect.size = Vector2(sym_size, sym_size)
	_symbol_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_symbol_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_symbol_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_symbol_rect)
	
	# ── Second symbol for the infinite scroll illusion ────────
	_next_rect = TextureRect.new()
	_next_rect.size = Vector2(sym_size, sym_size)
	_next_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_next_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_next_rect.position.y = -sym_size # Start it hidden above the box
	_next_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_next_rect)

	# ── Overlay rectangles ───────
	_flash_rect = _make_overlay(Color(1.0, 0.95, 0.55, 0.0))
	_held_rect  = _make_overlay(Color(0.98, 0.78, 0.0,  0.0))


func initialise(pool: Array) -> void:
	_pool = pool
	if not _pool.is_empty():
		_symbol_rect.texture = (_pool.pick_random() as SymbolData).icon
		_next_rect.texture = (_pool.pick_random() as SymbolData).icon


# ── The Physics-Based Spin Cycle ────────────────────────────────────────────────────────

func _spin_cycle(result_symbol: SymbolData, fast_time: float, decel_time: float) -> void:
	var total_time := fast_time + decel_time
	var start_time := Time.get_ticks_msec() / 1000.0
	
	var max_speed := 1800.0 # Pixels per second (Adjust for faster/slower blur!)
	
	while true:
		var elapsed := (Time.get_ticks_msec() / 1000.0) - start_time
		if elapsed >= total_time:
			break
			
		# Delta time for smooth movement regardless of framerate
		var delta := get_process_delta_time()
		var current_speed := max_speed
		
		# Decelerate smoothly during the last phase
		if elapsed > fast_time:
			var decel_ratio := 1.0 - ((elapsed - fast_time) / decel_time)
			current_speed = max_speed * decel_ratio
			current_speed = max(current_speed, 300.0) # Don't let it stop completely until the snap!

		# Move both textures DOWN
		_symbol_rect.position.y += current_speed * delta
		_next_rect.position.y += current_speed * delta
		
		# WRAP-AROUND LOGIC: If a texture falls below the bottom, snap it to the top!
		if _symbol_rect.position.y >= sym_size:
			_symbol_rect.position.y = _next_rect.position.y - sym_size
			if not _pool.is_empty():
				_symbol_rect.texture = (_pool.pick_random() as SymbolData).icon
			
		if _next_rect.position.y >= sym_size:
			_next_rect.position.y = _symbol_rect.position.y - sym_size
			if not _pool.is_empty():
				_next_rect.texture = (_pool.pick_random() as SymbolData).icon
			
		await get_tree().process_frame

	# --- THE FINAL SNAP ---
	# When time is up, lock the final result perfectly into the center!
	# --- THE MECHANICAL OVERSHOOT SNAP ---
	if result_symbol != null:
		_symbol_rect.texture = result_symbol.icon
	else:
		_symbol_rect.texture = null 
		
	_next_rect.position.y = -sym_size
	
	# Start it slightly too low!
	_symbol_rect.position.y = 12.0 
	
	# Spring it back into the center
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
	
	add_child(r)
	return r


# ── Public API ────────────────────────────────────────────────────────

func spin_to(result_symbol: SymbolData, duration: float) -> void:
	_spin_coroutine = null

	if is_held:
		var t := create_tween()
		t.tween_property(_held_rect, "color:a", 0.80, 0.05)
		t.chain().tween_property(_held_rect, "color:a", 0.28, 0.22)
		t.tween_callback(reel_stopped.emit)
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

# --- Hold Animation ---
func set_held(held: bool) -> void:
	is_held = held
	
	if is_instance_valid(_hold_tween):
		_hold_tween.kill()
		
	_hold_tween = create_tween()
	
	if held:
		# 1. Flash the gold overlay super bright instantly
		_held_rect.color.a = 0.8
		
		# 2. Physically "Slam" the symbol down like a mechanical lock catching it
		_symbol_rect.position.y = 8.0 
		_hold_tween.parallel().tween_property(_symbol_rect, "position:y", 0.0, 0.25)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
		# 3. Fade the overlay to a nice held tint
		_hold_tween.parallel().tween_property(_held_rect, "color:a", 0.35, 0.2)
		
		# 4. Throb the color gently to show it is "Locked and Loaded"
		_hold_tween.chain().tween_property(_held_rect, "color:a", 0.15, 0.6).set_ease(Tween.EASE_IN_OUT)
		_hold_tween.tween_property(_held_rect, "color:a", 0.35, 0.6).set_ease(Tween.EASE_IN_OUT)
		_hold_tween.set_loops() # Loop forever until released or spun!
		
	else:
		# Fast release
		_hold_tween.tween_property(_held_rect, "color:a", 0.0, 0.15)
		_symbol_rect.position.y = 0.0 # Ensure it snaps back


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
