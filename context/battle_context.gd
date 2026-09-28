class_name BattleContext extends RefCounted

var board: Array[SymbolData]
var buckets: Array[Dictionary] = []
var stat_logs: Array[Dictionary] = []  # per index: {"impact": [], "bandwidth": [], "morale": []}

# --- Useful Game State Data ---
var player_max_hp: int = 0
var player_hp: int = 0
var player_shield: int = 0
var boss_max_hp: int = 0
var boss_hp: int = 0
var turn_number: int = 0
var rerolls_left: int = 0

func _init(_board: Array[SymbolData]):
	board = _board
	# Automatically setup the buckets when created
	for i in 3:
		buckets.append({
			"impact": 0, 
			"bandwidth": 0, 
			"morale": 0, 
			"multiplier_bonus": 0, # Flat additions (Leverage)
			"multiplier_scale": 1,  # Multiplicative chaining (A.I. into A.I.)
			"impact_add": 0, "impact_mult": 1,
			"bandwidth_add": 0, "bandwidth_mult": 1,
			"morale_add": 0, "morale_mult": 1,
		})
		stat_logs.append({"impact": [], "bandwidth": [], "morale": []})

func log_step(index: int, stat: String, text: String) -> void:
	stat_logs[index][stat].append(text)

func add_stat(index: int, stat: String, amount: int, source: String) -> void:
	if amount == 0: return
	buckets[index][stat] += amount
	buckets[index][stat + "_add"] += amount
	var sign_str := "+" if amount > 0 else ""
	log_step(index, stat, "%s%d (%s)" % [sign_str, amount, source])

func mult_stat(index: int, stat: String, factor: int, source: String) -> void:
	if factor == 1: return
	buckets[index][stat] *= factor
	buckets[index][stat + "_mult"] *= factor
	log_step(index, stat, "×%d (%s)" % [factor, source])
