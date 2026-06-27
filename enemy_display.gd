class_name EnemyDisplay
extends Control

@onready var enemy_portrait: AnimatedSprite2D = $EnemyPortrait
@onready var hp_bar: TextureProgressBar = $EnemyHPBar
@onready var intent_label: RichTextLabel = $IntentBox/IntentLabel
@onready var enemy_name: RichTextLabel = $EnemyNameContainer/HBoxContainer/NameContainer/EnemyName
@onready var mic: TextureRect = $EnemyNameContainer/HBoxContainer/MicContainer/Mic
@onready var talking_border: TextureRect = $TalkingBorder
@onready var enemy_hp_label: RichTextLabel = $EnemyHPBar/EnemyHPLabel

const REACTIONS_MILD := {
	"default": [
		'"Let\'s circle back on that."',
		'"Let\'s touch base offline."',
		'"Identify the pain point."',
		'"Let\'s put a pin in it."'
	],
	"salaryman": [
		'"Per my last email..."',
		'"I\'ll run it up the flagpole."',
		'"Time to move the goal posts."',
		'"Let\'s do a deep dive here."',
		'"Just touching base!"'
	],
	"finance_bro": [
		'"That\'s a bearish move, bro."',
		'"Where\'s the ROI on this?"',
		'"Buy the dip. Sell the high."',
		'"Alpha mindset, always."',
		'"We need to hedge our bets."',
		'"Short it.'
	],
	"chief_empathy_officer": [
		'"I hear your frustration."',
		'"Let\'s assume positive intent."',
		'"Is this a safe space?"',
		'"Remember our core values."',
		'"I\'m making a note of this."'
	],
	"senior_partner": [
		'"Not how we did it in the 80s."',
		'"Cancel my 2 PM golf game."',
		'"Who authorized this?"',
		'"You\'ve got grit, kid."',
		'"This is billable time."'
	],
	"ceo": [
		'"We must pivot seamlessly."',
		'"Disrupt the paradigm."',
		'"I see the macro-vision."',
		'"Synergize or die."',
		'"A truly agile maneuver."',
		'"See you in the metaverse."',
		'"Tax, what\'s that?"'
	]
}

const REACTIONS_HEAVY := {
	"default": [
		'"I... that is not... aligned."',
		'"Can we revisit... next quarter..."',
	],
	"salaryman": [
		'"I\'m CC\'ing my manager!"',
		'"This is out of my scope!"',
		'"Can we take this offline forever?!"'
	],
	"finance_bro": [
		'"Margin call! MARGIN CALL!"',
		'"You\'re shorting my vibe!"',
		'"My crypto portfolio is crashing!"'
	],
	"chief_empathy_officer": [
		'"This is a gross violation of conduct."',
		'"I am opening a formal ticket!"',
		'"But we are a *family* here!"'
	],
	"senior_partner": [
		'"I\'ll bury you in litigation!"',
		'"You\'re jeopardizing the merger!"',
		'"Do you know who my father is?!"'
	],
	"ceo": [
		'"I AM THE MAJORITY SHAREHOLDER!"',
		'"You are tanking my stock options!"',
		'"Think about the poor billionaires!"',
		'"Tax me? TAX ME?'
	]
}

@onready var reaction_label: RichTextLabel = $ReactionLabel

const mic_on = preload("uid://brlf6outqe7y5")
const mic_off = preload("uid://cplpsa1rtn0di")
const border = preload("uid://csite2sa0gul7")

var _boss_name: String = ""
var _boss_id: String = ""
var _max_hp: int = 100
var camera: Camera2D

func _ready() -> void:
	var game_manager = owner

	if game_manager:
		if game_manager.has_signal("boss_turn"):
			game_manager.boss_turn.connect(_on_boss_turn)
		if game_manager.has_signal("player_turn"):
			game_manager.player_turn.connect(_on_player_turn)

	camera = get_tree().get_first_node_in_group("camera")


func setup(boss: BossData) -> void:
	talking_border.visible = false
	enemy_portrait.modulate = Color.WHITE
	_boss_id = boss.boss_id

	if _boss_id == "salaryman":
		_boss_name = boss.boss_name + " #" + str(randi_range(1000, 9999))
	else:
		_boss_name = boss.boss_name

	# ❗ Never show the final name here – only store it
	enemy_name.text = ""
	enemy_name.visible = false
	enemy_name.visible_characters = -1

	enemy_portrait.sprite_frames = boss.animations
	enemy_portrait.play("idle")

	_max_hp = boss.max_hp
	hp_bar.max_value = boss.max_hp
	hp_bar.value = boss.max_hp
	_set_hp_text(boss.max_hp)


func show_name_immediate() -> void:
	"""Call this ONLY for the very first boss after setup() – no animation, instant reveal."""
	enemy_name.visible = true
	enemy_name.text = _boss_name
	enemy_name.visible_characters = -1   # all at once


func _set_hp_text(current_val: int) -> void:
	enemy_hp_label.text = "[center][b]" + str(current_val) + "[/b] [color=#8899a6]/ " + str(_max_hp) + "[/color][/center]"


func update_hp(new_hp: int) -> void:
	print("NEW HP: ", new_hp)

	# Center pivot for scale animation
	enemy_hp_label.pivot_offset = enemy_hp_label.size / 2.0

	# Smooth bar drain
	create_tween().tween_property(hp_bar, "value", new_hp, 0.3).set_trans(Tween.TRANS_SINE)

	# Rolling number
	var num_tween := create_tween()
	var current_hp_int := int(hp_bar.value)
	num_tween.tween_method(_set_hp_text, current_hp_int, new_hp, 0.3).set_trans(Tween.TRANS_SINE)

	# Impact pop
	var pop_tween := create_tween()
	pop_tween.tween_property(enemy_hp_label, "modulate", Color(1.5, 0.4, 0.4), 0.05)
	pop_tween.parallel().tween_property(enemy_hp_label, "scale", Vector2(1.4, 1.4), 0.05)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	pop_tween.chain().tween_property(enemy_hp_label, "modulate", Color.WHITE, 0.2)
	pop_tween.parallel().tween_property(enemy_hp_label, "scale", Vector2(1.0, 1.0), 0.25)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func play_hit() -> void:
	camera.screen_shake(6, 0.1)

	if enemy_portrait.sprite_frames.has_animation("hit"):
		enemy_portrait.play("hit")
		await enemy_portrait.animation_finished
		enemy_portrait.play("idle")
	else:
		var origin := enemy_portrait.position
		var t := create_tween()
		t.tween_property(enemy_portrait, "modulate", Color(1.5, 0.3, 0.3), 0.04)
		t.parallel().tween_property(enemy_portrait, "position:x", origin.x + 10, 0.05)
		t.chain().tween_property(enemy_portrait, "position:x", origin.x - 10, 0.05)
		t.chain().tween_property(enemy_portrait, "position:x", origin.x, 0.07)
		t.chain().tween_property(enemy_portrait, "modulate", Color.WHITE, 0.15)
		await t.finished


func play_attack() -> void:
	if enemy_portrait.sprite_frames.has_animation("attack"):
		enemy_portrait.play("attack")
		await enemy_portrait.animation_finished
		enemy_portrait.play("idle")
	else:
		var origin := enemy_portrait.position
		var t := create_tween()
		t.tween_property(enemy_portrait, "position:x", origin.x + 18, 0.08).set_trans(Tween.TRANS_SINE)
		t.chain().tween_property(enemy_portrait, "position:x", origin.x, 0.18).set_trans(Tween.TRANS_BOUNCE)
		await t.finished


func set_intent(next_attack: int) -> void:
	var new_text := ""
	var parts: Array[String] = []

	if next_attack > 0:
		parts.append("[color=#cc5555][b]" + str(next_attack) + "[/b] IMPACT[/color]")

	new_text = " + ".join(parts) if not parts.is_empty() else "[color=#44445a]no effect[/color]"

	var full_text = "[shake rate=10.0 level=2][color=#ffffff][font_size=16]Intent: [/font_size][/color]" + new_text + "[/shake]"
	intent_label.text = full_text
	intent_label.scale = Vector2(0.75, 0.75)
	intent_label.rotation = deg_to_rad(randf_range(-2, 2))

	if intent_label.has_meta("active_tween"):
		var old_t = intent_label.get_meta("active_tween") as Tween
		if old_t and old_t.is_valid():
			old_t.kill()

	var t := intent_label.create_tween()
	intent_label.set_meta("active_tween", t)

	t.tween_property(intent_label, "scale", Vector2(1.08, 1.08), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(intent_label, "scale", Vector2(1.0, 1.0), 0.08)
	t.parallel().tween_property(intent_label, "rotation", 0.0, 0.1)

	var pulse := intent_label.create_tween().set_loops()
	pulse.tween_property(intent_label, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.8)
	pulse.tween_property(intent_label, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8)


func get_portrait_global_center() -> Vector2:
	return enemy_portrait.global_position


func show_reaction(damage: int) -> void:
	var is_heavy := damage >= 15

	var dict_to_use = REACTIONS_HEAVY if is_heavy else REACTIONS_MILD
	# Fallback to "default" if boss_id isn't found
	var pool: Array
	if dict_to_use.has(_boss_id):
		pool = dict_to_use[_boss_id]
	else:
		pool = dict_to_use["default"]
		
	var line = pool.pick_random()
	
	if is_heavy:
		reaction_label.text = "[shake rate=10.0 level=4][b][color=#dd8844]" + line + "[/color][/b][/shake]"
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


# --- UPGRADE SCREEN TRANSITION -----------------------------------

func play_disconnected() -> void:
	# Step 1: Portrait greys out and border fades, name flickers
	var t := create_tween()
	t.tween_property(enemy_portrait, "modulate", Color(0.3, 0.3, 0.4), 0.35)
	t.parallel().tween_property(talking_border, "modulate:a", 0.0, 0.25)

	# Flicker the name out mid-fade
	t.parallel().tween_property(enemy_name, "modulate:a", 0.0, 0.15)
	await t.finished

	# Step 2: Swap to "CONNECTION LOST" while invisible, then type it in
	enemy_name.text = "[ CONNECTION LOST ]"
	enemy_name.visible_characters = 0
	enemy_name.modulate.a = 1.0
	enemy_name.visible = true   # ensure it's visible

	var name_tween := create_tween()
	name_tween.tween_property(enemy_name, "visible_characters",
		enemy_name.get_total_character_count(), 0.4)
	await name_tween.finished


func play_reconnected() -> void:
	# Reset state but start invisible — we'll reveal theatrically
	enemy_portrait.modulate = Color(0.0, 0.0, 0.0, 0.0)
	talking_border.modulate.a = 0.0
	talking_border.visible = true
	enemy_name.text = "[ CONNECTING... ]"
	enemy_name.visible_characters = -1
	enemy_name.visible = true

	# Step 1: Flicker like a bad connection establishing
	var t := create_tween()
	for i in 4:
		t.tween_property(enemy_portrait, "modulate",
			Color(0.4, 0.45, 0.5, 0.6), 0.07)
		t.chain().tween_property(enemy_portrait, "modulate",
			Color(0.0, 0.0, 0.0, 0.0), 0.05)

	# Step 2: Snap to full colour
	t.chain().tween_property(enemy_portrait, "modulate",
		Color.WHITE, 0.12).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(talking_border, "modulate:a", 1.0, 0.15)

	await t.finished

	# Step 3: Name types in like a caption appearing
	enemy_name.text = _boss_name
	enemy_name.visible_characters = 0
	var name_tween := create_tween()
	name_tween.tween_property(enemy_name, "visible_characters",
		enemy_name.get_total_character_count(), 0.35)
	await name_tween.finished


func _on_boss_turn() -> void:
	mic.texture = mic_on
	talking_border.visible = true

func _on_player_turn() -> void:
	mic.texture = mic_off
	talking_border.visible = false
