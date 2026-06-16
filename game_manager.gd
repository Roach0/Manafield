extends Node
class_name GameManager


@onready var effects: EffectsManager = %EffectsManager
@onready var left_panel: LeftPanel = %LeftPanel
@onready var right_panel: RightPanel = %RightPanel
@onready var world: World = %World

func _ready() -> void:
	world.generate_world()
	world.camp_placed.connect(_on_camp_placed)
	world.begin_camp_placement()

func _on_camp_placed() -> void:
	# generation phase is done, begin normal gameplay
	pass
