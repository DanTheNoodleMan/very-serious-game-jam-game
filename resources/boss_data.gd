class_name BossData extends Resource

@export var boss_id: String = ""
@export var boss_name: String = "The Intern"
@export var boss_max_hp: int= 50
@export var cash_reward: int = 10
@export var attack_pattern: Array[int] = [5]
@export var action_pattern: Array[EnemyAction] = []

@export var animations: SpriteFrames

func pick_action(combat: CombatContext) -> EnemyAction:
	if not action_pattern.is_empty():
		return action_pattern[combat.turn_number % action_pattern.size()]
	# attack pattern fallback
	var a := EnemyAction.new()
	a.damage = attack_pattern[combat.turn_number % attack_pattern.size()]
	return a
