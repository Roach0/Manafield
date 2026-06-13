extends MarginContainer
class_name World

@export var slot_scene: PackedScene
@export var piece_data: PieceData  # your forest .tres for now

@onready var grid: GridContainer = %WorldSlots

func _ready() -> void:
	pass

func generate_world() -> void:
	for i in 169:
		var data := piece_data.duplicate() as PieceData
		var slot := slot_scene.instantiate() as WorldSlot
		grid.add_child(slot)
		slot.set_piece(data)
