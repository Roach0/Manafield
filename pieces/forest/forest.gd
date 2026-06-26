extends PieceData
class_name Forest

func get_click_cost() -> Dictionary:
	return {"resource": "energy", "amount": 1}

func _click() -> Dictionary:
	return {"loot": true}
	health -= damage_received
	# here I want it so that the forest sends some loot to the inventory from it's loot pool
	# I also want a few parameters added to this functionality in the PieceData class
	# how many items from the pool, how many per item(stack)
	return {}

func get_destroy_replacements() -> Array[PieceData]:
	return destroy_replacements

func _tick() -> void:
	pass
func _destroy() -> void:
	pass
func _complete() -> void:
	pass
