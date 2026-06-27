class_name SlotMachineLogic extends Node

signal spin_calculated(results: Array[SymbolData])

var active_symbols: Array[SymbolData] = [null, null, null]
var held_slots: Array[bool] = [false, false, false] 

# Single pool of symbols (put tres files here in the editor)
@export var shared_pool: Array[SymbolData] = []

func trigger_spin(player_hp: int = 100) -> void:
	var result: Array[SymbolData] = [null, null, null]
	var needs_pity = player_hp <= 30
	var held_count = 0
	
	# Step 1: Lock in held symbols
	for i in 3:
		if held_slots[i] and active_symbols[i] != null:
			# Keep the held symbol
			result[i] = active_symbols[i]
			held_count += 1
			
	# Step 2: Rig the game if they are dying AND they locked 2 symbols
	var pity_triggered = false
	if needs_pity and held_count == 2:
		pity_triggered = _try_pity_roll(result)
		
	# Step 3: Fill any remaining empty slots normally
	for i in 3:
		if result[i] == null:
			result[i] = shared_pool.pick_random()
	
	active_symbols = result
	spin_calculated.emit(result)

# Secretly forces the missing piece of a combo
func _try_pity_roll(result: Array[SymbolData]) -> bool:
	var held_ids: Array[String] = []
	var empty_index = -1
	
	for i in 3:
		if result[i] != null:
			held_ids.append(result[i].id)
		else:
			empty_index = i
			
	# Look through all possible combos
	for combo in ComboDictionary.COMBOS:
		var required_ids: Array = combo["symbol_ids"].duplicate()
		var match_count = 0
		
		# Check if our 2 held symbols match 2 of the required symbols
		for held_id in held_ids:
			if held_id in required_ids:
				required_ids.erase(held_id) # Remove it so we don't double count
				match_count += 1
				
		if match_count == 2:
			# We found a combo they are 1 away from! What is the missing piece?
			var missing_id = required_ids[0]
			
			# Search the player's deck. Do they even own this missing piece?
			for sym in shared_pool:
				if sym.id == missing_id:
					# Yes! Give it to them guaranteed.
					result[empty_index] = sym
					print("PITY TRIGGERED! Forced: ", missing_id)
					return true
					
	return false
	
func toggle_hold(index: int) -> bool:
	held_slots[index] = !held_slots[index]
	return held_slots[index]

func reset_holds() -> void:
	held_slots = [false, false, false]
