extends MarginContainer
class_name InfoDisplay


@onready var condition: ProgressBar = %Condition
@onready var tile_name: RichTextLabel = %Name
@onready var description: RichTextLabel = %Description
@onready var modifiers: RichTextLabel = %Modifiers

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass
