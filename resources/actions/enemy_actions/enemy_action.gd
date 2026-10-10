class_name EnemyAction extends Resource

@export var action_name: String = "Attack"
@export var damage: int = 0
@export var shield: int = 0
@export var heal: int = 0
@export var effects: Array[ActionEffect] = []

func get_intent_bbcode(combat: CombatContext = null) -> String:
	var parts: Array[String] = []
	var dmg := damage
	if combat != null: dmg = combat.enemy_statuses.modify_damage_dealt(damage)  # intent shows the real number
	if dmg > 0:    parts.append("[color=#cc5555][b]%d[/b] IMPACT[/color]" % dmg)
	if shield > 0: parts.append("[color=#55aaff][b]%d[/b] BW[/color]" % shield)
	if heal > 0:   parts.append("[color=#55ee77][b]%d[/b] MORALE[/color]" % heal)
	for e in effects: parts.append(e.describe())
	return " + ".join(parts) if not parts.is_empty() else "[color=#44445a]no effect[/color]"
