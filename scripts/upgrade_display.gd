# upgrade_display.gd
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

	# Option 1: Add a random symbol not already dominant in pool
	var all := ComboDictionary.all_symbols.duplicate()
	all.shuffle()
	# Pick one that isn't already 3+ copies in pool
	for sym in all:
		var count = pool.filter(func(s): return s.id == sym.id).size()
		if count < 3:
			opts.append({ "type": "add", "data": sym,
				"title": "HIRE CONSULTANT",
				"desc": "Add [" + sym.symbol_name.to_upper() + "] to your roster" })
			break

	# Option 2: Remove a symbol (only if pool has more than 3)
	if pool.size() > 3:
		var to_remove: SymbolData = pool.pick_random()
		opts.append({ "type": "remove", "data": to_remove,
			"title": "RESTRUCTURE",
			"desc": "Remove [" + to_remove.symbol_name.to_upper() + "] from your roster" })
	else:
		# Fallback if pool is tiny
		opts.append({ "type": "reroll", "data": null,
			"title": "SCHEDULE ALIGNMENT",
			"desc": "Gain +1 REROLL per turn" })

	# Option 3: Extra reroll (unless they already have a lot)
	if rerolls < 4:
		opts.append({ "type": "reroll", "data": null,
			"title": "EXTEND THE MEETING",
			"desc": "Gain +1 REROLL per turn (currently " + str(rerolls) + ")" })
	else:
		# Fallback
		var sym2 = ComboDictionary.all_symbols.pick_random()
		opts.append({ "type": "add", "data": sym2,
			"title": "OUTSOURCE",
			"desc": "Add [" + sym2.symbol_name.to_upper() + "] to your roster" })

	return opts

func _on_card_chosen(type: String, data: Variant) -> void:
	upgrade_chosen.emit(type, data)
