extends PieceData
class_name River


func _ready() -> void:
	pass

func _click() -> Dictionary:
	return {"loot":true}

func _tick() -> void:
	pass

func _destroy() -> void:
	pass

func _complete() -> void:
	pass

func should_float() -> bool:
	return true
