class_name ReelRuleStatus extends StatusEffect

@export var jam := false               # can't spin/reroll, keeps its symbol
@export var blackout := false          # reel disabled
@export var strip_department := false  # symbol counts, but no department bonus
@export var apply_text := "Reel %d"    # intent text, %d = reel number
@export_multiline var player_text := ""   # e.g. "Reel jammed: it can't spin or be held this turn."

func modify_reel_rules(status: ActiveStatus, reel_index: int, rules: ReelRules) -> void:
	if status.reel_index != reel_index: return
	if jam: rules.can_spin = false
	if blackout: rules.enabled = false
	if strip_department: rules.department_bonus = false
	if player_text != "": rules.notes.append(player_text)
		
func describe_application(stacks: int, reel_index: int) -> String:
	return "[color=#cc77dd]%s[/color]" % (apply_text % (reel_index + 1))
