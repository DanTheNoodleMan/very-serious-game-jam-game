extends PanelContainer

@onready var name_label: RichTextLabel = %ComboName
@onready var effect_label: RichTextLabel = %ComboEffectName
@onready var icon_1: TextureRect = %Symbol1
@onready var icon_2: TextureRect = %Symbol2
@onready var icon_3: TextureRect = %Symbol3

var _combo_data: Dictionary
var _is_setup: bool = false

func _ready() -> void:
	ComboDictionary.dictionary_updated.connect(refresh)

func setup(combo: Dictionary) -> void:
	_combo_data = combo
	name_label.text = "[wave amp=2 freq=2.0][color=#fff][b]" + combo["name"].to_upper() + "[/b][/color][/wave]"
	
	var ids: Array = combo["symbol_ids"] 
	var icons := [icon_1, icon_2, icon_3]
	
	for i in 3:
		var sym = _find_symbol_data(ids[i])
		if sym:
			icons[i].expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icons[i].size = Vector2(12, 12)
			icons[i].texture = sym.icon
			
	# Run the math for the first time
	refresh()
	_is_setup = true

func refresh() -> void:
	if _combo_data.is_empty(): return
	
	var simulated_spin: Array[SymbolData] = []
	var ids: Array = _combo_data["symbol_ids"] 
	
	for id in ids:
		simulated_spin.append(_find_symbol_data(id))

	# --- Wrap it in a context --- # TODO: will remove this in favor of new left panel
	var dummy_ctx = BattleContext.new(simulated_spin)
	var final_math = ComboDictionary.calculate(dummy_ctx)
	# --------------------------------------

	# Build effect string from the calculated final values
	var parts: Array[String] = []
	if final_math["impact"] > 0: 
		parts.append("[wave amp=2 freq=2.0][color=#cc5555][b]" + str(final_math["impact"]) + "[/b] IM[/color][/wave]")
	if final_math["morale"] > 0: 
		parts.append("[wave amp=2 freq=2.0][color=#55aa77][b]" + str(final_math["morale"]) + "[/b] MO[/color][/wave]")
	if final_math["bandwidth"] > 0: 
		parts.append("[wave amp=2 freq=2.0][color=#5588cc][b]" + str(final_math["bandwidth"]) + "[/b] BW[/color][/wave]")
		
	var new_text = " | ".join(parts)
	
	# Only play the animation if the game is already running AND the text actually changed
	if _is_setup and effect_label.text != new_text:
		effect_label.text = new_text
		_play_upgrade_anim()
	else:
		effect_label.text = new_text

func _play_upgrade_anim() -> void:
	# Center the pivot just in case the layout changed
	effect_label.pivot_offset = effect_label.size / 2.0
	
	if effect_label.has_meta("upgrade_tween"):
		var old_t = effect_label.get_meta("upgrade_tween") as Tween
		if old_t and old_t.is_valid():
			old_t.kill()
			
	var t := create_tween()
	effect_label.set_meta("upgrade_tween", t)
	
	# Pop out and turn Gold/Yellow
	t.tween_property(effect_label, "modulate", Color(1.5, 1.3, 0.4), 0.1)
	t.parallel().tween_property(effect_label, "scale", Vector2(1.2, 1.2), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Settle back to normal white
	t.chain().tween_property(effect_label, "modulate", Color.WHITE, 0.4)
	t.parallel().tween_property(effect_label, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _find_symbol_data(id: String) -> SymbolData:
	for sym in ComboDictionary.all_symbols:
		if sym.id == id:
			return sym
	return null
