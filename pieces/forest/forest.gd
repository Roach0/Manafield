extends PieceData
class_name Forest

func _click() -> Dictionary:
	return {"effect": "damage_health", "amount": 1}

func _tick() -> void:
	pass
func _destroy() -> void:
	pass
func _complete() -> void:
	pass
