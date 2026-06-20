extends Node

func calculate(results: Array[SymbolData]) -> Dictionary:
	var ids = results.map(func(s): return s.id)
	ids.sort()
	
	match ids:
		["roi", "roi", "roi"]:
			return { "name": "Quarterly Report", "damage": 15, "shield": 0 }
		["synergy", "synergy", "synergy"]:
			return { "name": "Team Building Exercise", "damage": 0, "shield": 20 }
		["ai", "blockchain", "pivot"]:
			return { "name": "Disruptive Innovation", "damage": 30, "shield": 0 }
		_:
			return { "name": "Confused Rambling", "damage": 2, "shield": 0 }
