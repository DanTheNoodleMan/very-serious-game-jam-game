class_name ReelRules extends RefCounted

var can_spin := true           # false = jammed, keeps its current symbol
var enabled := true            # false = blacked out, contributes nothing
var department_bonus := true   # false = "Under Review"
var notes: Array[String] = []
