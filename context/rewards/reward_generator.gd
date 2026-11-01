class_name RewardGenerator extends RefCounted
## Pure logic: given the run + a node type, decides what gets offered. No nodes so it's testable
## All the tuning numbers live at the top of this file.

enum Source { NORMAL, ELITE, BOSS, REST }

const RARITY_WEIGHT := {
	SymbolData.Rarity.COMMON: 6.0,
	SymbolData.Rarity.UNCOMMON: 3.0,
	SymbolData.Rarity.RARE: 1.0,
}
const ELITE_RARE_MULT := 3.0            # elites push rare candidates up
const DEPARTMENT_BIAS := 3.0            # symbols from the node's department are x3 as likely
const FULL_ROSTER_PROMOTION_CHANCE := 0.25   # roster full: sometimes offer a promotion instead of a hire
const REST_HEAL_FRACTION := 0.3
const CANDIDATES := 3
const SKIP_CASH := 8                    # Petty Cash for declining an offer

var run: RunState
var symbols: Array[SymbolData]          # library of everything that can be offered
var relics: Array[RelicData]
var rng := RandomNumberGenerator.new()


func _init(_run: RunState, _symbols: Array[SymbolData], _relics: Array[RelicData] = []) -> void:
	run = _run
	for s in _symbols:
		if s != null:
			symbols.append(s)
	for r in _relics:
		if r != null:
			relics.append(r)
	if symbols.size() != _symbols.size():
		push_warning("RewardGenerator: %d empty slot(s) in the symbol library (ComboDictionary.all_symbols)" % (_symbols.size() - symbols.size()))
	if relics.size() != _relics.size():
		push_warning("RewardGenerator: %d empty slot(s) in relic_pool" % (_relics.size() - relics.size()))
	rng.randomize()


func build(source: Source, act: int = 1, dept: SymbolData.Department = SymbolData.Department.NONE) -> Array[RewardOffer]:
	var out: Array[RewardOffer] = []
	match source:
		Source.NORMAL:
			if run.is_full() and rng.randf() < FULL_ROSTER_PROMOTION_CHANCE:
				_append(out, _promotion_offer(CANDIDATES))
			else:
				_append(out, _hire_offer(act, dept, false))
		Source.ELITE:
			print("elite found")
			_append(out, _relic_offer(1, false))
			_append(out, _hire_offer(act, dept, true))
		Source.BOSS:
			_append(out, _relic_offer(3, true))
		Source.REST:
			_append(out, _rest_offer())
	# Relics get the last word on what is offered (for any relics that affect rewards or shops...)
	for offer in out:
		offer.options.assign(run.apply_reward_modifiers(offer.options))
	return out


func _append(out: Array[RewardOffer], offer: RewardOffer) -> void:
	if offer != null and not offer.options.is_empty():
		out.append(offer)


# ---- Offers -------------------------------------------------------------------
func _hire_offer(act: int, dept: SymbolData.Department, rare_bias: bool) -> RewardOffer:
	var offer := RewardOffer.new("HIRE CANDIDATE  (%d/%d)" % [run.headcount(), run.max_headcount], true)
	offer.skip_cash = SKIP_CASH
	for s in _pick_symbols(CANDIDATES, act, dept, rare_bias):
		offer.options.append(RewardOption.hire(s))
	return offer


func _promotion_offer(n: int) -> RewardOffer:
	var offer := RewardOffer.new("PERFORMANCE REVIEW", true)
	for s in _upgradable(n):
		offer.options.append(RewardOption.promote(s))
	return offer


func _rest_offer() -> RewardOffer:
	# One pick: heal OR promote one of two symbols. (Trimming is deliberately shop-only.)
	var offer := RewardOffer.new("BREAK ROOM", false)
	offer.options.append(RewardOption.personal_day(ceili(run.max_hp * REST_HEAL_FRACTION)))
	for s in _upgradable(2):
		offer.options.append(RewardOption.promote(s))
	return offer


func _relic_offer(n: int, can_skip: bool) -> RewardOffer:
	var owned := {}
	for r in run.relics:
		owned[r.id] = true
	var bag: Array[RelicData] = []
	for r in relics:
		if not owned.has(r.id):
			bag.append(r)
	bag.shuffle()
	var offer := RewardOffer.new("COMPANY POLICY", can_skip)
	offer.skip_cash = SKIP_CASH if can_skip else 0
	for i in mini(n, bag.size()):
		offer.options.append(RewardOption.policy(bag[i]))
	return offer


# ---- Picking ---------------------------------------------------------------------
func _pick_symbols(count: int, act: int, dept: SymbolData.Department, rare_bias: bool) -> Array[SymbolData]:
	var bag: Array[SymbolData] = []
	for s in symbols:
		if s.min_act <= act:
			bag.append(s)
	var picked: Array[SymbolData] = []
	while picked.size() < count and not bag.is_empty():
		var s := _weighted_pick(bag, dept, rare_bias)
		picked.append(s)
		bag.assign(bag.filter(func(x: SymbolData): return x.id != s.id))   # no repeats within one offer
	return picked


func _weighted_pick(bag: Array[SymbolData], dept: SymbolData.Department, rare_bias: bool) -> SymbolData:
	var weights: Array[float] = []
	var total := 0.0
	for s in bag:
		var w: float = RARITY_WEIGHT.get(s.rarity, 1.0)
		if rare_bias and s.rarity == SymbolData.Rarity.RARE:
			w *= ELITE_RARE_MULT
		if dept != SymbolData.Department.NONE and s.department == dept:
			w *= DEPARTMENT_BIAS
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in bag.size():
		roll -= weights[i]
		if roll <= 0.0:
			return bag[i]
	return bag[bag.size() - 1]


## Distinct upgradable symbols from the run's own pool (instances, so upgrades land on real copies).
func _upgradable(n: int) -> Array[SymbolData]:
	var cands: Array[SymbolData] = []
	for s in run.symbol_pool:
		if s.can_upgrade():
			cands.append(s)
	cands.shuffle()
	var out: Array[SymbolData] = []
	var seen := {}
	for s in cands:
		if seen.has(s.id):
			continue
		seen[s.id] = true
		out.append(s)
		if out.size() >= n:
			break
	return out
