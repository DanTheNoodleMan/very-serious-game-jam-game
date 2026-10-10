class_name ApplyStatusAction extends ActionEffect

enum Target { PLAYER, SELF, MACHINE }

@export var status: StatusEffect
@export var target: Target = Target.PLAYER
@export var stacks: int = 1
@export var duration: int = 0       # 0 = status default, -1 = rest of combat
@export var reel_index: int = -1    # MACHINE only: 0, 1, 2

func apply(combat: CombatContext) -> void:
	var container: StatusContainer
	match target:
		Target.SELF: container = combat.enemy_statuses
		Target.MACHINE: container = combat.machine_statuses
		_: container = combat.player_statuses
	container.apply(status, stacks, duration, reel_index)

func describe() -> String:
	return status.describe_application(stacks, reel_index)
