class_name RewardOffer extends RefCounted
## One "page" of the reward screen: pick exactly one of `options`, or skip if allowed.
## A single-option offer is just a card you take (e.g. a guaranteed elite relic).

var title := ""
var options: Array[RewardOption] = []
var can_skip := true
## Petty Cash for declining. Makes "no thanks" (a thin pool) a real strategy, not a trap.
var skip_cash := 0


func _init(_title: String = "", _can_skip: bool = true) -> void:
	title = _title
	can_skip = _can_skip
