extends Resource
class_name PieceData


@export var name: String
@export var type_id: String # do not change like ever
@export var icons: Array[Texture2D]
@export var health: int
@export var health_max: int
@export var progress: int
@export var progress_max: int
@export var description: String
@export var can_build_on: Array[PieceData]


var mods: Array
var selected_icon: Texture2D

var loot1: Prefix
var loot2: Prefix

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

# animation flags
func should_float() -> bool:
	return false
