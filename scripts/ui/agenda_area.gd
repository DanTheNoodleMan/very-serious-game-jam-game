# agenda.gd — attached to AgendaPanel
extends Control

@export var combo_entry_scene: PackedScene
#@export var symbol_row_scene: PackedScene
@onready var list: VBoxContainer = %ComboList

func _ready() -> void:
	_build_combos()
	#_build_symbol_list()

func _build_combos() -> void:
	for combo in ComboDictionary.get_all_combos():
		var entry = combo_entry_scene.instantiate()
		list.add_child(entry)
		entry.setup(combo)

#func _build_symbol_list() -> void:
	#for sym: SymbolData in ComboDictionary.all_symbols:
		#var row = symbol_row_scene.instantiate()
		#list.add_child(row)
		#row.setup(sym)
