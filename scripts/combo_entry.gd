extends PanelContainer

@onready var name_label: RichTextLabel = %ComboName
@onready var effect_label: RichTextLabel = %ComboEffectName
@onready var icon_1: TextureRect = %Symbol1
@onready var icon_2: TextureRect = %Symbol2
@onready var icon_3: TextureRect = %Symbol3

func setup(combo: Dictionary) -> void:
	name_label.text = "[wave amp=2 freq=2.0][color=#fff][b]" + combo["name"].to_upper() + "[/b][/color][/wave]"
	
	# Build effect string from whichever values are non-zero
	var parts: Array[String] = []
	if combo["impact"] > 0: parts.append("[wave amp=2 freq=2.0][color=#cc5555][b]" + str(combo["impact"]) + "[/b] IM[/color][/wave]")
	if combo["morale"] > 0: parts.append("[wave amp=2 freq=2.0][color=#55aa77][b]" + str(combo["morale"]) + "[/b] MO[/color][/wave]")
	if combo["bandwidth"] > 0: parts.append("[wave amp=2 freq=2.0][color=#5588cc][b]" + str(combo["bandwidth"]) + "[/b] BW[/color][/wave]")
	effect_label.text = " | ".join(parts)
	
	
	
	# Look up icons by matching symbol_ids to ComboDictionary.all_symbols
	var icons := [icon_1, icon_2, icon_3]
	var ids: Array = combo["symbol_ids"]  # e.g. ["roi", "roi", "roi"]
	for i in 3:
		icons[i].expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icons[i].size = Vector2(12, 12)
		icons[i].texture = _find_symbol_icon(ids[i])

func _find_symbol_icon(id: String) -> Texture2D:
	for sym in ComboDictionary.all_symbols:
		if sym.id == id:
			return sym.icon
	return null  # Fallback — shows blank if id doesn't match any SymbolData
