extends PieceData
class_name Forest

func get_click_cost() -> Array:
	return [{"resource": "energy", "amount": 1}]

func _click() -> Dictionary:
	return {"loot": true}


func get_destroy_replacements() -> Array[PieceData]:
	return destroy_replacements

func _tick() -> Dictionary:
	return {}

func _destroy() -> Dictionary:
	return {}

func _complete() -> Dictionary:
	return {}
