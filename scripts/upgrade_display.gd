extends Control
## Replaces upgrade_display.gd. Shows a queue of RewardOffers one page at a time, as RewardCards.
## Knows nothing about what an option does; RewardOption applies itself to the RunState.
## Replacing a symbol (roster full) opens a LayoffModal on top.
##
## Scene requirements: %CardContainer (an HBoxContainer is fine now), %HeaderLabel, %SkipButton.
## There is no card scene any more: RewardCard builds itself in code.

signal finished

@onready var card_container: Container = %CardContainer
@onready var header_label: RichTextLabel = %HeaderLabel
@onready var skip_button: Button = %SkipButton

var _run: RunState
var _queue: Array[RewardOffer] = []
var _offer: RewardOffer
var _modal: LayoffModal


func _ready() -> void:
	skip_button.pressed.connect(_on_skip_pressed)


func show_rewards(run: RunState, offers: Array[RewardOffer]) -> void:
	_run = run
	_queue.assign(offers)
	_next_offer()


func _next_offer() -> void:
	if _queue.is_empty():
		finished.emit()
		return
	_offer = _queue.pop_front()
	_show_offer(_offer)


func _show_offer(offer: RewardOffer) -> void:
	header_label.text = offer.title
	skip_button.text = "SKIP (+$%d)" % offer.skip_cash if offer.skip_cash > 0 else "SKIP"
	skip_button.visible = offer.can_skip
	_clear_cards()
	for opt in offer.options:
		var card := RewardCard.new()
		card_container.add_child(card)
		card.setup(opt, _run)
		card.chosen.connect(_on_option_chosen)


func _on_option_chosen(option: RewardOption) -> void:
	if is_instance_valid(_modal):
		return                                   # modal already open
	if option.needs_layoff(_run):
		_open_layoff(option)
		return
	option.apply(_run)
	_next_offer()


# Roster is full: pick who the new hire replaces. Closing the modal just returns to the candidates.
func _open_layoff(new_hire: RewardOption) -> void:
	_modal = LayoffModal.open(self, _run, new_hire)
	_modal.picked.connect(func(sym: SymbolData) -> void:
		new_hire.apply(_run, sym)
		_next_offer())


func _on_skip_pressed() -> void:
	if is_instance_valid(_modal):
		return
	_run.add_cash(_offer.skip_cash)
	_next_offer()


func _clear_cards() -> void:
	for c in card_container.get_children():
		card_container.remove_child(c)
		c.queue_free()
