extends PieceData
class_name Camp

@export var destroy_replacements: Array[PieceData] # assign Field, Deer, etc. in the inspector

func get_click_cost() -> Dictionary:
	return {}

func _click() -> Dictionary:
	return {"effect": "update_energy", "amount": 1}

func get_destroy_replacements() -> Array[PieceData]:
	return destroy_replacements

func _tick() -> void:
	pass
func _destroy() -> void:
	pass
func _complete() -> void:
	pass
