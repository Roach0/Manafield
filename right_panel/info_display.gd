extends MarginContainer
class_name InfoDisplay


@onready var condition: ProgressBar = %Condition
@onready var tile_name: RichTextLabel = %Name
@onready var descrition: RichTextLabel = %Description

func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
