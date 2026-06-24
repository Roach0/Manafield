extends PieceData
class_name GnomeVillage


func get_click_cost() -> Dictionary:
	return {}

func _click() -> Dictionary:
	return {}

func get_destroy_replacements() -> Array[PieceData]:
	return destroy_replacements

func _tick() -> void:
	pass
func _destroy() -> void:
	pass
func _complete() -> void:
	pass
