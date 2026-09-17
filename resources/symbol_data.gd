class_name SymbolData extends Resource

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
