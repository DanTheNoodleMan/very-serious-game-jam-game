# i.e.  ("Company Card")  -> modify_shop_price
class_name ShopDiscountRelic extends RelicData
@export var percent_off: int = 20
@export var kinds: PackedStringArray = []   # empty = everything
func modify_shop_price(run: RunState, price: int, kind: String) -> int:
	if not kinds.is_empty() and not kinds.has(kind): return price
	return price - price * percent_off / 100
