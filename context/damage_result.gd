class_name DamageResult extends RefCounted
var attempted := 0     # raw attack damage BEFORE modifiers
var incoming := 0      # damage AFTER modifiers
var absorbed := 0      # damage shield blocked
var hp_damage := 0     # damage HP actually took
var shield_before := 0
var shield_after := 0
var shield_broke := false
var exact_break := false
var source := ""   # "" = a normal hit, otherwise the status/relic that caused it. so relics can ignore status-caused damage and avoid retaliation loops.
