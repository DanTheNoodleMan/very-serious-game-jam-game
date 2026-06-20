class_name SymbolData extends Resource

# What kind of base effect does this symbol do?
enum EffectType { DAMAGE, SHIELD, HEAL, MULTIPLIER, UTILITY }

@export var id: String = "roi" # e.g., "roi", "synergy", "coffee", "ai"
@export var symbol_name: String = "R.O.I."
@export var icon: Texture2D

@export_group("Base Stats")
@export var base_value: int = 2
@export var effect_type: EffectType = EffectType.DAMAGE
