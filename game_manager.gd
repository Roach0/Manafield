extends Node
class_name GameManager

@export var start_pieces: Array[PieceData]
@onready var effects: EffectsManager = %EffectsManager
@onready var left_panel: LeftPanel = %LeftPanel
@onready var right_panel: RightPanel = %RightPanel
@onready var world: World = %World

func _ready() -> void:
	world.generate_world()
	world.update_display.connect(right_panel.update_display)
	world.build_queue_advanced.connect(right_panel.update_build_display)
	world.piece_placed.connect(_on_piece_placed)
	world.build_mode_ended.connect(_on_build_mode_ended)
	world.begin_build_mode(start_pieces)

func _on_piece_placed(piece_data: PieceData, next_piece: PieceData) -> void:
	print("placed: ", piece_data.name)
	if next_piece:
		right_panel.update_build_display(next_piece)

func _on_build_mode_ended() -> void:
	right_panel.interaction_display.set_visibility(InteractionDisplay.Mode.IDLE)
