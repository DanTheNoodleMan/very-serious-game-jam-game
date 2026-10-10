class_name StatusContainer extends RefCounted

signal changed
signal status_applied(status: ActiveStatus)
signal status_removed(status: ActiveStatus)

enum Side { PLAYER, ENEMY, MACHINE }

var side: Side
var _list: Array[ActiveStatus] = []

func _init(_side) -> void:
	side = _side

func all() -> Array[ActiveStatus]:   # treat as read-only (for UI)
	return _list

func find(id: String, reel_index: int = -1) -> ActiveStatus:
	for s in _list:
		if s.effect.id == id and s.reel_index == reel_index:
			return s
	return null

func apply(effect: StatusEffect, stacks: int = 1, duration: int = 0, reel_index: int = -1) -> ActiveStatus:
	var turns := effect.default_duration if duration == 0 else duration
	var existing := find(effect.id, reel_index)
	if existing != null:
		match effect.stacking:
			StatusEffect.Stacking.INTENSITY:
				existing.stacks = mini(existing.stacks + stacks, effect.max_stacks)
				existing.turns_left = turns
			StatusEffect.Stacking.DURATION:
				if existing.turns_left != -1 and turns != -1:
					existing.turns_left += turns
			StatusEffect.Stacking.REPLACE:
				existing.stacks = stacks
				existing.turns_left = turns
		changed.emit()
		return existing
	var s := ActiveStatus.new(effect, side, stacks, turns, reel_index)
	_list.append(s)
	status_applied.emit(s)
	changed.emit()
	return s

func remove(s: ActiveStatus) -> void:
	if _list.has(s):
		_list.erase(s)
		status_removed.emit(s)
		changed.emit()

func remove_by_id(id: String) -> void:
	for s: ActiveStatus in _list.duplicate():
		if s.effect.id == id: remove(s)

func tick_turn_start(combat: CombatContext) -> void:
	for s: ActiveStatus in _list.duplicate():
		s.effect.on_turn_start(s, combat)

func tick_turn_end(combat: CombatContext) -> void:
	for s: ActiveStatus in _list.duplicate():
		s.effect.on_turn_end(s, combat)   # effect fires first, then duration drops,
		if s.turns_left > 0:              # so a 1-turn status still gets its end-of-turn tick
			s.turns_left -= 1
			if s.turns_left == 0:
				remove(s)
	changed.emit()

# ---- Aggregators ----
func modify_battle(ctx: BattleContext) -> void:
	for s in _list: s.effect.modify_battle(s, ctx)

func modify_damage_taken(amount: int) -> int:
	for s in _list: amount = s.effect.modify_damage_taken(s, amount)
	return amount

func modify_damage_dealt(amount: int) -> int:
	for s in _list: amount = s.effect.modify_damage_dealt(s, amount)
	return amount

func modify_reel_rules(reel_index: int, rules: ReelRules) -> void:
	for s in _list: s.effect.modify_reel_rules(s, reel_index, rules)
