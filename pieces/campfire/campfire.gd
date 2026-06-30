extends PieceData
class_name Campfire


func _ready() -> void:
	pass

func _click() -> Dictionary:
	return {"effect": "update_nerve", "amount": 1}

func _tick() -> Dictionary:
	return{}

func _destroy() -> void:
	pass

func _complete() -> void:
	pass
 
