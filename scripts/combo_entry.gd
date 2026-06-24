extends PanelContainer

@onready var name_label: RichTextLabel = %ComboName
@onready var effect_label: RichTextLabel = %ComboEffectName
@onready var icon_1: TextureRect = %Symbol1
@onready var icon_2: TextureRect = %Symbol2
@onready var icon_3: TextureRect = %Symbol3

func setup(combo: Dictionary) -> void:
	name_label.text = "[wave amp=2 freq=2.0][color=#fff][b]" + combo["name"].to_upper() + "[/b][/color][/wave]"
	
	var ids: Array = combo["symbol_ids"]  # e.g. ["roi", "roi", "roi"]
	var icons := [icon_1, icon_2, icon_3]
	var simulated_spin: Array[SymbolData] = []
	
	# Look up the actual SymbolData resources to build a "fake spin"
	for i in 3:
		var sym = _find_symbol_data(ids[i])
		simulated_spin.append(sym)
		
		if sym:
			icons[i].expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icons[i].size = Vector2(12, 12)
			icons[i].texture = sym.icon

	# Run the simulated spin through the dictionary to get the TRUE total math!
	var final_math = ComboDictionary.calculate(simulated_spin)

	# Build effect string from the calculated final values
	var parts: Array[String] = []
	if final_math["impact"] > 0: 
		parts.append("[wave amp=2 freq=2.0][color=#cc5555][b]" + str(final_math["impact"]) + "[/b] IM[/color][/wave]")
	if final_math["morale"] > 0: 
		parts.append("[wave amp=2 freq=2.0][color=#55aa77][b]" + str(final_math["morale"]) + "[/b] MO[/color][/wave]")
	if final_math["bandwidth"] > 0: 
		parts.append("[wave amp=2 freq=2.0][color=#5588cc][b]" + str(final_math["bandwidth"]) + "[/b] BW[/color][/wave]")
		
	effect_label.text = " | ".join(parts)


func _find_symbol_data(id: String) -> SymbolData:
	for sym in ComboDictionary.all_symbols:
		if sym.id == id:
			return sym
	return null
