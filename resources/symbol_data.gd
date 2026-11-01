class_name SymbolData extends Resource

enum Rarity { COMMON, UNCOMMON, RARE }
enum EffectType { DAMAGE, SHIELD, HEAL, MULTIPLIER, UTILITY }
enum Department { NONE, FINANCE, HR, IT, MANAGEMENT, SALES }

@export var id: String = "roi"
@export var symbol_name: String = "R.O.I."
@export var icon: Texture2D

@export_group("Categorization")
@export var effect_type: EffectType = EffectType.DAMAGE
@export var department: Department = Department.NONE

@export_group("Base Stats")
@export var base_impact: int = 0
@export var base_bandwidth: int = 0
@export var base_morale: int = 0

@export_group("Special Ability")
@export var effect: SymbolEffect

@export_group("Rewards")
@export var rarity: Rarity = Rarity.COMMON
## First act in which this can be offered as a hire
@export var min_act: int = 1

@export_group("Upgrades")
## What promoting THIS symbol does. Empty = default (flat bump to its primary stat)
@export var upgrade: SymbolUpgrade
@export var max_upgrade_level: int = 2
## Runtime, per copy
@export var upgrade_level: int = 0

@export_group("Flavor")
@export_multiline var flavor_text: String = ""

static var _default_stat_upgrade: SymbolUpgrade
static var _default_effect_upgrade: SymbolUpgrade

func get_upgrade() -> SymbolUpgrade:
	if upgrade != null:
		return upgrade
	match effect_type:
		EffectType.DAMAGE, EffectType.SHIELD, EffectType.HEAL:
			if _default_stat_upgrade == null:
				_default_stat_upgrade = SymbolUpgrade.new()
			return _default_stat_upgrade
		_:
			if _default_effect_upgrade == null:
				_default_effect_upgrade = EffectUpgrade.new()
			return _default_effect_upgrade

func can_upgrade() -> bool:
	return upgrade_level < max_upgrade_level and get_upgrade().can_apply(self)

## Copies with identical state share one chip in the roster; diverged copies get their own
func get_signature() -> String:
	return "%s|%d|%d|%d|%d" % [id, base_impact, base_bandwidth, base_morale, upgrade_level]

## Every copy that enters a run gets its own instance.
func clone_for_run() -> SymbolData:
	var c := duplicate(true) as SymbolData
	if effect != null:
		# Effects hold upgradable numbers. Copy explicitly so it also works
		# when an effect is saved as its own .tres file
		c.effect = effect.duplicate(true) as SymbolEffect
	return c
	

# Helper functions
func get_department_name() -> String:
	return Department.keys()[department]
