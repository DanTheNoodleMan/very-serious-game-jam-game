class_name RunState extends RefCounted
## Everything that survives between fights.
## Mutate through the methods so signals fire and UI stays in sync.

signal hp_changed(hp: int, max_hp: int)
signal cash_changed(amount: int)
signal pool_changed
signal relics_changed

@export var max_hp: int = 100
@export var hp: int = 100
@export var petty_cash: int = 0
@export var base_rerolls: int = 2
@export var symbol_pool: Array[SymbolData] = []
@export var relics: Array[RelicData] = []
## Per-relic data that must outlive one combat: { relic_id: { key: value } }
@export var relic_state: Dictionary = {}
#@export var map: MapData                  #TODO(map)
#@export var current_node_id: int = -1

static func create(starter_pool: Array[SymbolData], hp_bonus: int = 0) -> RunState:
	var r := RunState.new()
	r.max_hp += hp_bonus
	r.hp = r.max_hp
	for s in starter_pool:
		r.symbol_pool.append(s.duplicate(true)) # deep copy so upgrades never leak between runs
	return r

func add_cash(amount: int) -> void:
	petty_cash += amount
	cash_changed.emit(petty_cash)

func spend_cash(amount: int) -> bool:
	if petty_cash < amount: return false
	petty_cash -= amount
	cash_changed.emit(petty_cash)
	return true

func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	hp_changed.emit(hp, max_hp)

func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	hp_changed.emit(hp, max_hp)

func add_symbol(s: SymbolData) -> void:
	symbol_pool.append(s.duplicate(true))
	pool_changed.emit()

func remove_symbol(s: SymbolData) -> void:
	symbol_pool.erase(s)
	pool_changed.emit()

func add_relic(r: RelicData) -> void:
	if r.id == "":
		push_warning("Relic '%s' has no id, it would collide with others" % r.resource_path)
		return
	if has_relic(r.id): return
	relics.append(r)
	r.on_acquired(self)
	relics_changed.emit()

func has_relic(id: String) -> bool:
	for r in relics:
		if r.id == id: return true
	return false

func set_relic_value(id: String, key: String, value: Variant) -> void:
	if not relic_state.has(id):
		relic_state[id] = {}
	relic_state[id][key] = value

# ---- Run-level relic pipelines (the reward and shop screens call these) ----
func apply_reward_modifiers(choices: Array) -> Array:
	for r in relics: choices = r.modify_reward_choices(self, choices)
	return choices

func get_shop_price(base_price: int, kind: String) -> int:
	var p := base_price
	for r in relics: p = r.modify_shop_price(self, p, kind)
	return maxi(p, 0)
