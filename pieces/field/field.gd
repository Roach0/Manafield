extends PieceData
class_name Field


func _ready() -> void:
	pass

func get_click_cost() -> Dictionary:
	return {"resource": "nerve", "amount": 1}

func _click() -> Dictionary:
	return{"loot":true}

func _tick() -> void:
	pass

func _destroy() -> void:
	pass

func _complete() -> void:
	pass
