extends HBoxContainer
class_name EffectsManager

@onready var world: World = %World
@onready var right_panel: RightPanel = %RightPanel
@onready var left_panel: LeftPanel = %LeftPanel


# gonna catch most things with signals here.
# And orchestrate out using methods via connected the connected variables.

func _ready() -> void:
	world.update_display.connect(_on_update_display)




func _on_update_display(piece: PieceData) -> void:
	right_panel.update_display(piece)
	pass
