class_name PlayerDisplay
extends Control

@onready var portrait: TextureRect = $PlayerPortrait
@onready var hp_bar: TextureProgressBar = $PlayerHPBar

func setup(max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = max_hp

func update_hp(new_hp: int) -> void:
	create_tween().tween_property(hp_bar, "value", new_hp, 0.3).set_trans(Tween.TRANS_SINE)

func play_hit() -> void:
	var origin := portrait.position
	var t := create_tween()
	t.tween_property(portrait, "modulate", Color(1.5, 0.3, 0.3), 0.04)
	t.parallel().tween_property(portrait, "position:x", origin.x - 10, 0.05)
	t.chain().tween_property(portrait, "position:x", origin.x + 10, 0.05)
	t.chain().tween_property(portrait, "position:x", origin.x, 0.07)
	t.chain().tween_property(portrait, "modulate", Color.WHITE, 0.15)
	await t.finished
