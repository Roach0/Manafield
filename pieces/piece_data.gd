extends Resource
class_name PieceData

@export var name: String
@export var icons: Array[Texture2D]
@export var health_max: int
@export var progress_max: int

var health: int
var progress: int
var selected_icon: Texture2D

func pick_icon() -> void:
	if icons.size() > 0:
		selected_icon = icons[randi() % icons.size()]

func _tick() -> void:
	# When a different piece is clicked.
	pass

func _click() -> void:
	# When I am the clciked piece.
	pass

func _complete() -> void:
	# When my progress is complete.
	pass

func _destroy() -> void:
	# When my health is emptied.
	pass
