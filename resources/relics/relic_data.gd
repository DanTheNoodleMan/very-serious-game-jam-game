class_name RelicData extends StatusEffect

enum Rarity { COMMON, UNCOMMON, RARE, BOSS }

@export var rarity: Rarity = Rarity.COMMON
@export_multiline var description: String = ""
@export var shop_price: int = 50

func is_relic() -> bool: return true

# ---- Run-level hooks (no combat exists: map, rewards, shops) ----
func on_acquired(run: RunState) -> void: pass
## `choices` become RewardOption objects once the reward revamp lands.
func modify_reward_choices(run: RunState, choices: Array) -> Array: return choices
## kind: "symbol", "relic", "removal"...
func modify_shop_price(run: RunState, price: int, kind: String) -> int: return price

# ---- Run-persistent state (saved with the run) ----
func get_value(run: RunState, key: String, default: Variant = 0) -> Variant:
	return run.get_relic_value(id, key, default)

func set_value(run: RunState, key: String, value: Variant) -> void:
	run.set_relic_value(id, key, value)
