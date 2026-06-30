extends PieceData
class_name Field


func _ready() -> void:
	pass

func get_click_cost() -> Array:
	return []

func _click() -> Dictionary:
	return{"loot":true}

func _tick() -> Dictionary:
	return {}

func _destroy() -> Dictionary:
	return {}

func _complete() -> Dictionary:
	return {}
