extends PieceData
class_name River


func _ready() -> void:
	pass

func _click() -> Dictionary:
	return {"loot":true}

func _tick() -> Dictionary:
	return {}

func _destroy() -> Dictionary:
	return {}

func _complete() -> Dictionary:
	return {}

func should_float() -> bool:
	return true
