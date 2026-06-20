# slot_machine_logic.gd
class_name SlotMachineLogic extends Node

signal spin_calculated(results: Array[SymbolData])

var active_symbols: Array[SymbolData] = [null, null, null]
var held_slots: Array[bool] = [false, false, false] 

# Single pool of symbols (put tres files here in the editor)
@export var shared_pool: Array[SymbolData] = []

func trigger_spin() -> void:
	var result: Array[SymbolData] = [null, null, null]
	
	for i in 3:
		if held_slots[i] and active_symbols[i] != null:
			# Keep the held symbol
			result[i] = active_symbols[i]
		else:
			# Draw a random symbol from the shared pool
			result[i] = shared_pool.pick_random()
	
	active_symbols = result
	spin_calculated.emit(result)

func toggle_hold(index: int) -> bool:
	held_slots[index] = !held_slots[index]
	return held_slots[index]

func reset_holds() -> void:
	held_slots = [false, false, false]
