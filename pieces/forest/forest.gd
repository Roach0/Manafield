extends PieceData
class_name Forest

@export var destroy_replacements: Array[PieceData] # assign Field, Deer, etc. in the inspector

func get_click_cost() -> Dictionary:
	return {"resource": "energy", "amount": 1}

func _click() -> Dictionary:
	health -= 1
	return {}

func get_destroy_replacements() -> Array[PieceData]:
	return destroy_replacements

func _tick() -> void:
	pass
func _destroy() -> void:
	pass
func _complete() -> void:
	pass
