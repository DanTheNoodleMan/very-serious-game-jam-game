class_name StatusEffect extends Resource

enum Stacking { INTENSITY, DURATION, REPLACE }

@export var id: String = ""
@export var status_name: String = ""
@export var icon: Texture2D
@export var is_debuff: bool = true
@export var stacking: Stacking = Stacking.INTENSITY
@export var max_stacks: int = 99
## -1 = lasts until combat ends
@export var default_duration: int = 1

# ---- Hooks: override what you need ----
func on_turn_start(status: ActiveStatus, combat: CombatContext) -> void: pass
func on_turn_end(status: ActiveStatus, combat: CombatContext) -> void: pass

## Spin math. Called on every preview, so it must only touch ctx.
func modify_battle(status: ActiveStatus, ctx: BattleContext) -> void: pass

func modify_damage_taken(status: ActiveStatus, amount: int) -> int: return amount
func modify_damage_dealt(status: ActiveStatus, amount: int) -> int: return amount

## Machine sabotage: edit the rules for one reel. Preview-safe, like modify_battle.
func modify_reel_rules(status: ActiveStatus, reel_index: int, rules: ReelRules) -> void: pass

func describe_application(stacks: int, reel_index: int) -> String:
	var txt := status_name if stacks <= 1 else "%s x%d" % [status_name, stacks]
	return "[color=%s]%s[/color]" % ["#cc77dd" if is_debuff else "#77ddaa", txt]
