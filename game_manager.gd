extends Node
class_name GameManager

@onready var effects: EffectsManager = %EffectsManager
@onready var left_panel: LeftPanel = %LeftPanel
@onready var right_panel: RightPanel = %RightPanel
@onready var world: World = %World

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass
