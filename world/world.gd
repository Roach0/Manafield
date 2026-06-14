extends MarginContainer
class_name World

@export var slot_scene: PackedScene
@export var piece_data_list: Array[PieceData]  # your forest .tres for now

@onready var grid: GridContainer = %WorldSlots

signal update_display(piece)

func _ready() -> void:
	pass

func generate_world() -> void:
	for i in 169:
		var piece_data = piece_data_list[randi() % piece_data_list.size()]
		var data := piece_data.duplicate() as PieceData
		var slot := slot_scene.instantiate() as WorldSlot
		grid.add_child(slot)
		slot.set_piece(data)
		slot.update_display.connect(func(piece): update_display.emit(piece))
