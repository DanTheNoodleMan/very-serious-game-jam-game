class_name EnemyDisplay
extends Control

@onready var portrait: AnimatedSprite2D = $EnemyPortrait
@onready var hp_bar: TextureProgressBar = $EnemyHPBar
@onready var intent_label: RichTextLabel = $IntentBox/IntentLabel
@onready var enemy_name: RichTextLabel = $EnemyNameContainer/HBoxContainer/NameContainer/EnemyName
@onready var mic: TextureRect = $EnemyNameContainer/HBoxContainer/MicContainer/Mic
@onready var talking_border: TextureRect = $TalkingBorder

# enemy_display.gd
const REACTIONS_MILD := [
	'"Let\'s circle back on that."',
	'"Let\'s touch base."',
	'"Let\'s take this offline."',
	'"Identify the pain point.',
	'"Let\'s put a pin in it."',
	'"We need to do a deep dive here."',
	'"Let\'s touch base tomorrow morning."',
	'"This will be a game changer."',
	'"Time to move the goal posts."',
	'"I\'ll un it up the flagpole."',
	'"We must trim the fat"',
]
const REACTIONS_HEAVY := [
	'"I... that is not... aligned."',
	'"Can we revisit... next quarter..."',
	'"I\'m going to need to... escalate."',
]

@onready var reaction_label: RichTextLabel = $ReactionLabel  # Add this node in editor, default hidden


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
	var new_text := ""
	var parts: Array[String] = []
	#if combo["impact"] > 0:    parts.append("[color=#cc5555][b]" + str(combo["impact"]) + "[/b] IMPACT[/color]")
	#if combo["bandwidth"] > 0: parts.append("[color=#5588cc][b]" + str(combo["bandwidth"]) + "[/b] BW[/color]")
	#if combo["morale"] > 0:    parts.append("[color=#55aa77][b]" + str(combo["morale"]) + "[/b] MORALE[/color]")
	
	if next_attack > 0:
		parts.append("[color=#cc5555][b]" + str(next_attack) + "[/b] IMPACT[/color]")

	new_text = " + ".join(parts) if not parts.is_empty() else "[color=#44445a]no effect[/color]"
	
	var full_text = "[color=#ffffff][font_size=16]Intent: [/font_size][/color]" + new_text
	intent_label.text = full_text
	intent_label.scale = Vector2(0.75, 0.75)
	intent_label.rotation = deg_to_rad(randf_range(-2, 2)) # Slight tilt every update

	# Stop previous tween if the player is spamming Reroll
	if intent_label.has_meta("active_tween"):
		var old_t = intent_label.get_meta("active_tween") as Tween
		if old_t and old_t.is_valid():
			old_t.kill()

	var t := intent_label.create_tween()
	intent_label.set_meta("active_tween", t)
	
	# The Pop-In
	t.tween_property(intent_label, "scale", Vector2(1.08, 1.08), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(intent_label, "scale", Vector2(1.0, 1.0), 0.08)
	t.parallel().tween_property(intent_label, "rotation", 0.0, 0.1)
	
	var pulse := intent_label.create_tween().set_loops()

	pulse.tween_property(intent_label, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.8)
	pulse.tween_property( intent_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8)


func get_portrait_global_center() -> Vector2:
	return portrait.global_position

func show_reaction(damage: int) -> void:
	var is_heavy := damage >= 15
	var pool := REACTIONS_HEAVY if is_heavy else REACTIONS_MILD
	var line = pool.pick_random()

	if is_heavy:
		reaction_label.text = "[b][color=#dd8844]" + line + "[/color][/b]"
	else:
		reaction_label.text = "[i][color=#8899bb]" + line + "[/color][/i]"

	reaction_label.visible_characters = 0
	reaction_label.modulate.a = 1.0
	reaction_label.visible = true

	var total := reaction_label.get_total_character_count()
	var t := create_tween()

	if is_heavy:
		reaction_label.scale = Vector2(0.4, 0.4)
		t.tween_property(reaction_label, "scale", Vector2(1.12, 1.12), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.chain().tween_property(reaction_label, "scale", Vector2(1.0, 1.0), 0.07)
		t.parallel().tween_property(reaction_label, "visible_characters", total, 0.22)
		t.tween_interval(1.1)
	else:
		reaction_label.scale = Vector2(1.0, 1.0)
		t.tween_property(reaction_label, "visible_characters", total, 0.55)
		t.tween_interval(1.3)

	t.chain().tween_property(reaction_label, "modulate:a", 0.0, 0.28)
	t.tween_callback(func():
		reaction_label.visible = false
		reaction_label.visible_characters = -1
	)

func _on_boss_turn() -> void:
	mic.texture = mic_on
	talking_border.visible = true

func _on_player_turn() -> void:
	mic.texture = mic_off
	talking_border.visible = false
