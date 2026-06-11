extends Resource
class_name PieceData

@export var name: String
@export var icons: Array[Texture2D]
var health: int
var selected_icon: Texture2D

func pick_icon() -> void:
	if icons.size() > 0:
		selected_icon = icons[randi() % icons.size()]
