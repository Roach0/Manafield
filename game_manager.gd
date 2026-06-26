extends Node
class_name GameManager

@export var start_pieces: Array[PieceData]
@onready var effects: EffectsManager = %EffectsManager
@onready var left_panel: LeftPanel = %LeftPanel
@onready var right_panel: RightPanel = %RightPanel
@onready var world: World = %World
@onready var crt_filter: ColorRect = %CRTFilter

@export var remaining_turns: int
@export var crt_enabled: bool = true

func _ready() -> void:
	set_crt_enabled(crt_enabled)
	new_game()

func new_game() -> void:
	world.effects = effects          # give World access to the prefix pools
	world.generate_world()
	world.build_queue_advanced.connect(right_panel.update_build_display)
	world.piece_placed.connect(_on_piece_placed)
	world.build_mode_ended.connect(_on_build_mode_ended)
	world.begin_build_mode(start_pieces)
	left_panel.set_new_player()

func _on_piece_placed(piece_data: PieceData, next_piece: PieceData) -> void:
	print("placed: ", piece_data.name)
	if next_piece:
		right_panel.update_build_display(next_piece)

func _on_build_mode_ended() -> void:
	right_panel.interaction_display.set_visibility(InteractionDisplay.Mode.IDLE)

# --- CRT filter control ---

func set_crt_enabled(value: bool) -> void:
	crt_enabled = value
	if crt_filter and crt_filter.material:
		crt_filter.material.set_shader_parameter("enabled", value)

func toggle_crt() -> void:
	set_crt_enabled(not crt_enabled)

func set_crt_parameter(param: String, value: Variant) -> void:
	if crt_filter and crt_filter.material:
		crt_filter.material.set_shader_parameter(param, value)
