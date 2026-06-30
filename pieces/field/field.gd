extends PieceData
class_name Field


func _ready() -> void:
	pass

func get_click_cost() -> Array:
	return [{"stat": "nerve", "amount": 1}]

func _click() -> Dictionary:
	return{"loot":true}

func _tick() -> Dictionary:
	return {}

func _destroy() -> void:
	pass

func _complete() -> void:
	pass
