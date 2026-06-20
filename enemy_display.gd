class_name EnemyDisplay
extends Control

@onready var portrait: AnimatedSprite2D = $EnemyPortrait
@onready var hp_bar: TextureProgressBar = $EnemyHPBar
@onready var intent_label: RichTextLabel = $IntentBox/IntentLabel
@onready var enemy_name: RichTextLabel = $EnemyNameContainer/HBoxContainer/NameContainer/EnemyName
@onready var mic: TextureRect = $EnemyNameContainer/HBoxContainer/MicContainer/Mic
@onready var talking_border: TextureRect = $TalkingBorder

const mic_on = preload("uid://brlf6outqe7y5")
const mic_off = preload("uid://cplpsa1rtn0di")
const border = preload("uid://csite2sa0gul7")

func _ready() -> void:
	var game_manager = owner

	if game_manager:
		if game_manager.has_signal("boss_turn"):
			game_manager.boss_turn.connect(_on_boss_turn)
		if game_manager.has_signal("player_turn"):
			game_manager.player_turn.connect(_on_player_turn)


func setup(boss: BossData) -> void:
	talking_border.visible = false
	enemy_name.text = boss.boss_name
	portrait.sprite_frames = boss.animations
	portrait.play("idle")
	hp_bar.max_value = boss.max_hp
	hp_bar.value = boss.max_hp

func update_hp(new_hp: int) -> void:
	print("NEW HP: ", new_hp)
	create_tween().tween_property(hp_bar, "value", new_hp, 0.3).set_trans(Tween.TRANS_SINE)

func play_hit() -> void:
	if portrait.sprite_frames.has_animation("hit"):
		portrait.play("hit")
		await portrait.animation_finished
		portrait.play("idle")
	else:
		# Fallback if no hit animation drawn yet
		var origin := portrait.position
		var t := create_tween()
		t.tween_property(portrait, "modulate", Color(1.5, 0.3, 0.3), 0.04)
		t.parallel().tween_property(portrait, "position:x", origin.x + 10, 0.05)
		t.chain().tween_property(portrait, "position:x", origin.x - 10, 0.05)
		t.chain().tween_property(portrait, "position:x", origin.x, 0.07)
		t.chain().tween_property(portrait, "modulate", Color.WHITE, 0.15)
		await t.finished

func play_attack() -> void:
	if portrait.sprite_frames.has_animation("attack"):
		portrait.play("attack")
		await portrait.animation_finished
		portrait.play("idle")
	else:
		var origin := portrait.position
		var t := create_tween()
		t.tween_property(portrait, "position:x", origin.x + 18, 0.08).set_trans(Tween.TRANS_SINE)
		t.chain().tween_property(portrait, "position:x", origin.x, 0.18).set_trans(Tween.TRANS_BOUNCE)
		await t.finished

func set_intent(next_attack: int) -> void:
		intent_label.text = "⚔ " + str(next_attack) + " DMG"
		
		
func _on_boss_turn() -> void:
	mic.texture = mic_on
	talking_border.visible = true

func _on_player_turn() -> void:
	mic.texture = mic_off
	talking_border.visible = false
