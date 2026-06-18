extends HBoxContainer
class_name EffectsManager

@onready var world: World = %World
@onready var right_panel: RightPanel = %RightPanel
@onready var left_panel: LeftPanel = %LeftPanel

@export var prefix_pool_1: Array[Prefix]

@export var prefix_pool_2: Array[Prefix]

@export var prefix_pool_3: Array[Prefix]

# signals should only be passed up to send an effect towards something other
# than the slot from which it originates.

func _ready() -> void:
	world.update_display.connect(_on_update_display)



func _on_update_display(piece: PieceData) -> void:
	right_panel.update_display(piece)
	pass

func fill_prefix_pools():
	#welcome back
	pass
