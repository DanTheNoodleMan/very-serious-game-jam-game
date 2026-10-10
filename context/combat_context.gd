class_name CombatContext extends RefCounted
## One encounter. Owns combat-only state and the combat RULES (damage, shields, statuses, turn ticks).
## Borrows RunState for anything that persists between fights (HP, deck, cash).
## No nodes in here, so it can be built and tested without a scene tree.
 
## Damage caused by a status/relic (not by a beat the manager is sequencing).
signal passive_damage(side: int, result: DamageResult, source: String)

var run: RunState
var enemy: BossData
var is_final_boss: bool = false

var enemy_hp: int
var enemy_max_hp: int
var enemy_shield := 0
var player_shield := 0
var turn_number: int = 0
var rerolls_left: int = 0
var next_action: EnemyAction

var player_statuses := StatusContainer.new(StatusContainer.Side.PLAYER)
var enemy_statuses := StatusContainer.new(StatusContainer.Side.ENEMY)
var machine_statuses := StatusContainer.new(StatusContainer.Side.MACHINE)

## SymbolData -> { stat: { source: amount } }
var _symbol_bonuses: Dictionary = {}

func _init(_run: RunState, _enemy: BossData) -> void:
	run = _run
	enemy = _enemy
	enemy_max_hp = _enemy.boss_max_hp
	enemy_hp = enemy_max_hp
 
# ---- Queries ---------------------------------------------------------------
func is_player_dead() -> bool: return run.hp <= 0
func is_enemy_dead() -> bool: return enemy_hp <= 0

# ---- Turn flow (rules only, no visuals) ------------------------------------
func begin_player_turn() -> void:
	player_shield = 0
	rerolls_left = run.base_rerolls
	next_action = enemy.pick_action(self)   # picked once, so the intent shown == what actually happens
	player_statuses.tick_turn_start(self)
	machine_statuses.tick_turn_start(self)
 
func end_player_turn() -> void:
	player_statuses.tick_turn_end(self)
	machine_statuses.tick_turn_end(self)    # machine sabotage lives and dies on the player's turn
 
func begin_enemy_turn() -> void:
	enemy_shield = 0
	enemy_statuses.tick_turn_start(self)
 
func end_enemy_turn() -> void:
	enemy_statuses.tick_turn_end(self)
	turn_number += 1


# ---- Damage / shield / heal ------------------------------------------------
func damage_player(amount: int, true_damage := false, source := "") -> DamageResult:
	if not true_damage:
		amount = player_statuses.modify_damage_taken(amount)
	var r := _resolve_damage(amount, player_shield, true_damage)
	player_shield = r.shield_after
	run.take_damage(r.hp_damage)
	if source != "":
		passive_damage.emit(StatusContainer.Side.PLAYER, r, source)
	return r
 
func damage_enemy(amount: int, true_damage := false, source := "") -> DamageResult:
	if not true_damage:
		amount = enemy_statuses.modify_damage_taken(amount)
	var r := _resolve_damage(amount, enemy_shield, true_damage)
	enemy_shield = r.shield_after
	enemy_hp = maxi(enemy_hp - r.hp_damage, 0)
	if source != "":
		passive_damage.emit(StatusContainer.Side.ENEMY, r, source)
	return r
 
func add_player_shield(n: int) -> void: player_shield += n
func add_enemy_shield(n: int) -> void: enemy_shield += n
func heal_player(n: int) -> void: run.heal(n)
func heal_enemy(n: int) -> void: enemy_hp = mini(enemy_hp + n, enemy_max_hp)
 
func _resolve_damage(amount: int, shield: int, true_damage: bool) -> DamageResult:
	var r := DamageResult.new()
	r.incoming = maxi(amount, 0)
	r.shield_before = shield
	if true_damage:
		r.hp_damage = r.incoming
		r.shield_after = shield
	else:
		r.absorbed = mini(shield, r.incoming)
		r.shield_after = shield - r.absorbed
		r.hp_damage = r.incoming - r.absorbed
	r.shield_broke = shield > 0 and r.shield_after == 0
	r.exact_break = r.shield_broke and r.incoming == shield
	return r
 
# Stat scaling and other context based effects
func add_symbol_bonus(sym: SymbolData, stat: String, amount: int, source: String) -> void:
	if not _symbol_bonuses.has(sym):
		_symbol_bonuses[sym] = {}
	var by_stat: Dictionary = _symbol_bonuses[sym]
	if not by_stat.has(stat):
		by_stat[stat] = {}
	by_stat[stat][source] = by_stat[stat].get(source, 0) + amount

func get_symbol_bonus(sym: SymbolData, stat: String) -> int:
	var total := 0
	var sources := get_symbol_bonus_sources(sym, stat)
	for source in sources:
		total += sources[source]
	return total

func get_symbol_bonus_sources(sym: SymbolData, stat: String) -> Dictionary:
	if _symbol_bonuses.has(sym) and _symbol_bonuses[sym].has(stat):
		return _symbol_bonuses[sym][stat]
	return {}

 
# ---- Machine ---------------------------------------------------------------
func get_reel_rules() -> Array[ReelRules]:
	var out: Array[ReelRules] = []
	for i in 3:
		var r := ReelRules.new()
		machine_statuses.modify_reel_rules(i, r)
		out.append(r)
	return out
 

# ---- Spin snapshot ---------------------------------------------------------
func make_battle_context(board: Array[SymbolData]) -> BattleContext:
	var b := BattleContext.new(board)
	b.player_max_hp = run.max_hp
	b.player_hp = run.hp
	b.player_shield = player_shield
	b.boss_max_hp = enemy_max_hp
	b.boss_hp = enemy_hp
	b.turn_number = turn_number
	b.rerolls_left = rerolls_left
	b.combat = self                         # only on_commit() may mutate through this
	b.reel_rules = get_reel_rules()
	b.status_sources.append(player_statuses)
	b.status_sources.append(machine_statuses)
	return b
