extends MarginContainer
class_name InfoDisplay


@onready var health: ProgressBar = %Health
@onready var progress: ProgressBar = %Progress
@onready var tile_name: RichTextLabel = %Name
@onready var description: RichTextLabel = %Description
@onready var modifiers: RichTextLabel = %Modifiers

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	pass

func update(piece: PieceData):
	health.value = piece.health
	progress.value = piece.progress
	tile_name.text = piece.name
	description.text = piece.description
	# still gotta handle the mods though, iterate through array of string?
	pass
