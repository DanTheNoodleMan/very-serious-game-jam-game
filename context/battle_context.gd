class_name BattleContext extends RefCounted

var board: Array[SymbolData]
var buckets: Array[Dictionary] = []

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
