extends MarginContainer
class_name InfoDisplay


@onready var health: ProgressBar = %Health
@onready var progress: ProgressBar = %Progress
@onready var tile_name: RichTextLabel = %Name
@onready var description: RichTextLabel = %Description
@onready var modifiers: RichTextLabel = %Modifiers


func _ready() -> void:
	pass


func update(piece: PieceData):
	if piece == null:
		visible = false
		return
	visible = true
	print("InfoDisplay.update mods=", piece.mods, " size=", piece.mods.size())
	
	health.visible = piece.health_max > 0
	progress.visible = piece.progress_max > 0
	
	if health.visible:
		health.max_value = piece.health_max
		health.target_value = piece.health

	
	if progress.visible:
		progress.max_value = piece.progress_max
		progress.target_value = piece.progress

	
	tile_name.text = piece.name
	description.text = piece.description
	modifiers.text = ", ".join(piece.mods)
