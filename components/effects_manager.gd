extends HBoxContainer
class_name EffectsManager

@onready var world: World = %World
@onready var right_panel: RightPanel = %RightPanel
@onready var left_panel: LeftPanel = %LeftPanel

@export var prefix_pool_1: Array[Prefix]
@export var prefix_pool_2: Array[Prefix]
@export var prefix_pool_3: Array[Prefix]

func _ready() -> void:
	world.update_display.connect(_on_update_display)
	world.piece_effect_triggered.connect(_on_piece_effect_triggered)

func _on_update_display(piece: PieceData) -> void:
	right_panel.update_display(piece)

func _on_piece_effect_triggered(effect_name: String, amount: int) -> void:
	match effect_name:
		"update_energy":
			left_panel.player.energy += amount
		_:
			push_warning("Unhandled piece effect: %s" % effect_name)

func fill_prefix_pools():
	#welcome back
	pass
