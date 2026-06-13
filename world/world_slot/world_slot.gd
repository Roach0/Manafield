extends MarginContainer
class_name WorldSlot


@onready var icon: TextureRect = %TextureRect
var piece: PieceData
var tween: Tween
var health: int


func set_piece(data: PieceData) -> void:
	piece = data
	piece.pick_icon()
	icon.texture = piece.selected_icon

func _on_button_mouse_entered() -> void:
	_kill_tween()
	tween = create_tween().set_loops(2)
	tween.tween_property(icon, "position:x", 3.0, 0.02)
	tween.tween_property(icon, "position:x", -3.0, 0.02)
	tween.tween_property(icon, "position:x", 0.0, 0.02)

func _on_button_pressed() -> void:
	_kill_tween()
	tween = create_tween()
	tween.tween_property(icon, "position:y", -8.0, 0.03)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "position:y", 0.0, 0.31)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_ELASTIC)

func _remove() -> void:
	piece = null # make a default spawn bank later :p
	icon.texture = null
	_kill_tween()
	tween = create_tween()
	tween.tween_property(icon, "position:y", -8.0, 0.1)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "position:y", 20.0, 0.2)\
		.set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _kill_tween() -> void:
	if tween and tween.is_valid():
		tween.kill()
	icon.position = Vector2.ZERO
