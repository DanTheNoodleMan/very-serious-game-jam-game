class_name ReelPopup extends RefCounted

enum Style { BUFF, DEBUFF, INFO }

var reel_index: int
var text: String
var style: Style

func _init(_index: int, _text: String, _style: Style = Style.BUFF) -> void:
	reel_index = _index; text = _text; style = _style
