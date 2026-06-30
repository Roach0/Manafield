extends Node
class_name GameManager

@export var start_pieces: Array[PieceData]
@onready var effects: EffectsManager = %EffectsManager
@onready var left_panel: LeftPanel = %LeftPanel
@onready var right_panel: RightPanel = %RightPanel
@onready var world: World = %World
@onready var crt_filter: ColorRect = %CRTFilter

@onready var turn_system: TurnSystem = %TurnSystem

@export var remaining_turns: int
@export var crt_enabled: bool = true

func _ready() -> void:
	set_crt_enabled(crt_enabled)
	new_game()

func new_game() -> void:
	world.effects = effects
	effects.turn_system = turn_system     # mutual link, set before any turn
	turn_system.effects = effects
	world.generate_world()
	turn_system.bind()                    # connect slots + seed the ticker registry
	turn_system.turn_advanced.connect(_on_turn_advanced)
	world.build_queue_advanced.connect(right_panel.update_build_display)
	world.piece_placed.connect(_on_piece_placed)
	world.build_mode_ended.connect(_on_build_mode_ended)
	world.begin_build_mode(start_pieces)
	left_panel.set_new_player()

func _on_turn_advanced(turn: int) -> void:
	effects.play_hovered_tick()           # the cosmetic tick sound
	remaining_turns -= 1
	# game-over check on remaining_turns <= 0 goes here when you want it

func _on_piece_placed(piece_data: PieceData, next_piece: PieceData) -> void:
	print("placed: ", piece_data.name)
	Sfx.play(piece_data.build_sound)   # SFX: build placement
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
