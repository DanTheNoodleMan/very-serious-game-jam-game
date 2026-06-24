class_name PlayerDisplay
extends Control

@onready var player_portrait: AnimatedSprite2D = $PlayerPortrait
@onready var hp_bar: TextureProgressBar = $PlayerHPBar
@onready var shield_badge: TextureRect = $ShieldBadge
@onready var shield_label: RichTextLabel = $ShieldBadge/ShieldAmount

var current_shield: int = 0

func setup(max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = max_hp
	shield_badge.visible = false
	player_portrait.play("idle")

func update_hp(new_hp: int) -> void:
	create_tween().tween_property(hp_bar, "value", new_hp, 0.3).set_trans(Tween.TRANS_SINE)

func set_shield(amount: int) -> void:
	current_shield = amount
	if amount > 0:
		var t := shield_badge.create_tween()
		shield_badge.set_meta("active_tween", t)
		
		# The Pop-In
		t.tween_property(shield_badge, "scale", Vector2(1.08, 1.08), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.chain().tween_property(shield_badge, "scale", Vector2(1.0, 1.0), 0.08)
		t.parallel().tween_property(shield_badge, "rotation", 0.0, 0.1)
		shield_badge.visible = true
		shield_label.text = str(amount)
	else:
		shield_badge.visible = false

func clear_shield() -> void:
	set_shield(0)

# Returns actual HP damage taken after shield absorbs what it can
func absorb_damage(incoming: int) -> int:
	var absorbed := mini(current_shield, incoming)
	set_shield(current_shield - absorbed)
	var hp_damage := incoming - absorbed
	return hp_damage

func play_hit() -> void:
	var origin := player_portrait.position
	var t := create_tween()
	t.tween_property(player_portrait, "modulate", Color(1.5, 0.3, 0.3), 0.04)
	t.parallel().tween_property(player_portrait, "position:x", origin.x - 10, 0.05)
	t.chain().tween_property(player_portrait, "position:x", origin.x + 10, 0.05)
	t.chain().tween_property(player_portrait, "position:x", origin.x, 0.07)
	t.chain().tween_property(player_portrait, "modulate", Color.WHITE, 0.15)
	await t.finished

# When a hit is fully blocked
func play_blocked() -> void:
	var t := create_tween()
	t.tween_property(shield_badge, "scale", Vector2(1.3, 1.3), 0.06).set_trans(Tween.TRANS_SINE)
	t.chain().tween_property(shield_badge, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BOUNCE)
	# Brief blue flash on the HP bar area
	t.parallel().tween_property(hp_bar, "modulate", Color(0.4, 0.8, 1.5), 0.06)
	t.chain().tween_property(hp_bar, "modulate", Color.WHITE, 0.2)
	await t.finished


func play_shield_break(absorbed_amount: int, exact: bool) -> void:
	shield_badge.visible = true
	shield_label.text = str(absorbed_amount)
	shield_badge.modulate = Color.WHITE
	shield_badge.scale = Vector2.ONE
	# Scale from center, not top-left corner — this is why it was drifting
	shield_badge.pivot_offset = shield_badge.size / 2.0
	
	var t := shield_badge.create_tween()
	
	if exact:
		# Clean precise drain — white flash, then implodes neatly
		t.tween_property(shield_badge, "modulate", Color(1.8, 2.0, 2.5), 0.06)
		t.parallel().tween_property(shield_badge, "scale", Vector2(1.15, 1.15), 0.06)
		t.chain().tween_property(shield_badge, "scale", Vector2(0.0, 0.0), 0.14) \
			.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(shield_badge, "modulate:a", 0.0, 0.12)
	else:
		# Overkill — micro-shake first, then red implosion
		var ox := shield_badge.position.x
		t.tween_property(shield_badge, "position:x", ox + 5, 0.03)
		t.chain().tween_property(shield_badge, "position:x", ox - 5, 0.03)
		t.chain().tween_property(shield_badge, "position:x", ox + 3, 0.025)
		t.chain().tween_property(shield_badge, "position:x", ox, 0.025)
		t.chain().tween_property(shield_badge, "modulate", Color(2.0, 0.4, 0.4), 0.05)
		t.parallel().tween_property(shield_badge, "scale", Vector2(1.1, 1.1), 0.05)
		t.chain().tween_property(shield_badge, "scale", Vector2(0.0, 0.0), 0.12) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(shield_badge, "modulate:a", 0.0, 0.10)
		
	t.tween_callback(func():
		shield_badge.visible = false
		shield_badge.modulate = Color.WHITE
		shield_badge.scale = Vector2.ONE
		shield_badge.pivot_offset = Vector2.ZERO
	)
	await t.finished


func get_global_center() -> Vector2:
	return global_position + size * 0.5
