extends Button
## Renders any RewardOption. All the per-type description building now lives on the option itself.

signal chosen(type: String, data: Variant)

@onready var title_label: RichTextLabel = %Title
@onready var icon_rect: TextureRect = %Icon
@onready var desc_label: RichTextLabel = %Description
@onready var panel_container: PanelContainer = $MarginContainer/VBoxContainer/PanelContainer

var _option: RewardOption

func setup(option: RewardOption) -> void:
	_option = option
	title_label.text = option.title
	icon_rect.texture = option.icon
	icon_rect.visible = option.icon != null
	
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.text = option.describe()
	
	pressed.connect(func(): chosen.emit(_option))
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", -3.0, 0.15).as_relative()

func _on_mouse_exited() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", 3.0, 0.15).as_relative()
