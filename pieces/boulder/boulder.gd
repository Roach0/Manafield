extends PieceData
class_name Boulder


func get_click_cost() -> Array:
	return []

func _click() -> Dictionary:
	health -= damage_received
	return {"loot":true}

func get_destroy_replacements() -> Array[PieceData]:
	return destroy_replacements

func _tick() -> Dictionary:
	return {}

func _destroy() -> void:
	pass
func _complete() -> void:
	pass
