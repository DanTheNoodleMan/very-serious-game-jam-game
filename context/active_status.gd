class_name ActiveStatus extends RefCounted

var effect: StatusEffect
var side: int            # StatusContainer.Side
var stacks: int
var turns_left: int      # -1 = permanent for this combat
var reel_index: int      # -1 unless it's a reel-scoped machine status

func _init(_effect: StatusEffect, _side: int, _stacks: int, _turns: int, _reel: int) -> void:
	effect = _effect; side = _side; stacks = _stacks; turns_left = _turns; reel_index = _reel
