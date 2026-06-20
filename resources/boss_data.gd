class_name BossData extends Resource

@export var boss_name: String = "The Intern"
@export var max_hp: int= 50
# An array of damages the boss will do, cycling sequentially. 
# E.g., [5, 5, 10] means turn 1: 5dmg, turn 2: 5dmg, turn 3: 10dmg, loop.
@export var attack_pattern: Array[int] = [5]

@export var animations: SpriteFrames
