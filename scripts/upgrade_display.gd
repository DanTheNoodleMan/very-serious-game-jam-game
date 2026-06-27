extends Control

signal upgrade_chosen(type: String, data: Variant)

@export var card_scenes: Array[PackedScene] = []  # 3 UpgradeCard scenes
@onready var card_container: HBoxContainer = %CardContainer
@onready var header_label: RichTextLabel = %HeaderLabel

var _current_pool: Array[SymbolData] = []

func show_upgrades(pool: Array[SymbolData], current_rerolls: int) -> void:
	_current_pool = pool
	header_label.text = "PERFORMANCE REVIEW"

	# Clear old cards
	for child in card_container.get_children():
		child.queue_free()

	var options := _generate_options(pool, current_rerolls)
	for opt in options:
		var card = preload("uid://c0grhwl3tyrdh").instantiate()
		card_container.add_child(card)
		card.setup(opt)
		card.chosen.connect(_on_card_chosen)

func _generate_options(pool: Array[SymbolData], rerolls: int) -> Array[Dictionary]:
	var opts: Array[Dictionary] = []

	 # which unlockable symbols haven't entered the pool yet, hardcoded for now since i don't have many
	var unlockable_ids := ["disruptor", "ai", "leverage", "annual_bonus"]
	var pool_ids := pool.map(func(s): return s.id)
	var available_unlocks: Array[SymbolData] = []
	for sym in ComboDictionary.all_symbols:
		if sym.id in unlockable_ids and sym.id not in pool_ids:
			available_unlocks.append(sym)
	available_unlocks.shuffle()
	
	# Option 1: Add a new unlockable symbol (if any remain)
	if available_unlocks.size() > 0:
		var sym := available_unlocks[0]
		opts.append({
			"type": "add", "data": sym,
			"title": "BRING IN A CONSULTANT",
			"desc": "Add [" + sym.symbol_name.to_upper() + "] to your roster"
		})
	else:
		# Fallback: add a duplicate of a random existing symbol
		var sym: SymbolData = pool.pick_random()
		opts.append({
			"type": "add", "data": sym,
			"title": "EXPAND THE TEAM",
			"desc": "Add another [" + sym.symbol_name.to_upper() + "] — increases its roll chance"
		})

	# Option 2: Upgrade a symbol's base_value
	if pool.size() > 0:
		var sym: SymbolData = pool.pick_random()
		if sym.effect_type != SymbolData.EffectType.MULTIPLIER:
			opts.append({
				"type": "upgrade_normal", "data": sym,
				"title": "AREA OF IMPROVEMENT",
				"desc": "Upgrade [" + sym.symbol_name.to_upper() + "] — increases its value by 4"
			})
		else:
			opts.append({
				"type": "upgrade_multiplier", "data": sym,
				"title": "CAREER COACHING",
				"desc": "Upgrade [" + sym.symbol_name.to_upper() + "] — increases its value by 2"
			})

	# Option 3: Option C: Extra reroll OR remove a symbol
	if pool.size() > 5 and rerolls >= 3:
		var weakest: SymbolData = pool.pick_random()
		opts.append({
			"type": "remove", "data": weakest,
			"title": "RESTRUCTURE",
			"desc": "Remove [" + weakest.symbol_name.to_upper() + "] from your roster"
		})
	else:
		opts.append({
			"type": "reroll", "data": null,
			"title": "EXTEND THE MEETING",
			"desc": "Gain +1 REROLL per turn (currently " + str(rerolls) + ")"
		})

	return opts

func _on_card_chosen(type: String, data: Variant) -> void:
	upgrade_chosen.emit(type, data)
