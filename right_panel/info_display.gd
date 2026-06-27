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
	health.visible = piece.health_max > 0
	progress.visible = piece.progress_max > 0
	if health.visible:
		health.max_value = piece.health_max
		health.target_value = piece.health
	if progress.visible:
		progress.max_value = piece.progress_max
		progress.target_value = piece.progress
	_render_text(piece.name, piece.description, piece.mods)


# Item view: no bars, single prefix rendered with the same colored chip.
func update_item(item: ItemData):
	if item == null:
		clear()
		return
	visible = true
	health.visible = false
	progress.visible = false
	var mods: Array = [item.prefix] if item.prefix != null else []
	_render_text(item.name, item.description, mods)


# Blank the panel but keep it laid out — no collapse, no reflow.
func clear() -> void:
	visible = true
	health.visible = false
	progress.visible = false
	tile_name.text = ""
	description.text = ""
	modifiers.text = ""
	modifiers.visible = false


# Shared name/description/prefix rendering for both pieces and items.
func _render_text(display_name: String, desc: String, mods: Array) -> void:
	tile_name.text = display_name
	description.text = desc
	modifiers.visible = not mods.is_empty()
	modifiers.bbcode_enabled = true
	var parts := PackedStringArray()
	for m in mods:
		parts.append("[color=#%s]%s[/color]" % [m.color.to_html(false), m.prefix_name])
	modifiers.text = ", ".join(parts)
