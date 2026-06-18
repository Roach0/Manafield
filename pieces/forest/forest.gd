extends PieceData
class_name Forest

func _click() -> Dictionary:
	health -= 1
	return {"effect": "update_energy", "amount": -1}

func _tick() -> void:
	pass
func _destroy() -> void:
	pass
func _complete() -> void:
	pass
