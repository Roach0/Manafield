extends MarginContainer
class_name WorldSlot

@onready var icon: TextureRect = %TextureRect

var piece: PieceData
var tween: Tween
var health: int

var phase := (
	grid_pos.x * 0.3 +
	grid_pos.y * 0.2 +
	float_phase
)

var grid_pos: Vector2i

var floating := false
var float_time := 0.0
var float_phase := randf() * 1.5

var float_offset := Vector2.ZERO
var interaction_offset := Vector2.ZERO

signal update_display(piece)
signal clicked


func _process(delta: float) -> void:
	if floating:
		float_time += delta

		float_offset.x = (
			sin(float_time * 0.7 + float_phase) * 1.5
		)

		float_offset.y = (
			sin(float_time * 1.1 + float_phase) * 2.5 +
			sin(float_time * 0.35 + float_phase * 1.7) * 1.0
		)
	else:
		float_offset = Vector2.ZERO

	icon.position = float_offset + interaction_offset


func set_piece(data: PieceData) -> void:
	piece = data
	piece.pick_icon()
	icon.texture = piece.selected_icon

	floating = piece.should_float()

	if floating:
		float_phase = randf() * TAU
		float_time = randf() * TAU
	else:
		float_phase = 0.0
		float_time = 0.0
		float_offset = Vector2.ZERO


func phase_offset() -> float:
	return grid_pos.x * 0.7 + grid_pos.y * 0.4


func _on_button_mouse_entered() -> void:
	update_display.emit(piece)

	_kill_tween()

	tween = create_tween().set_loops(2)

	tween.tween_property(
		self,
		"interaction_offset:x",
		3.0,
		0.02
	)

	tween.tween_property(
		self,
		"interaction_offset:x",
		-3.0,
		0.02
	)

	tween.tween_property(
		self,
		"interaction_offset:x",
		0.0,
		0.02
	)


func _on_button_pressed() -> void:
	clicked.emit()

	_kill_tween()

	tween = create_tween()

	tween.tween_property(
		self,
		"interaction_offset:y",
		-8.0,
		0.03
	).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"interaction_offset:y",
		0.0,
		0.31
	).set_ease(Tween.EASE_OUT)\
	 .set_trans(Tween.TRANS_ELASTIC)


func _remove() -> void:
	piece = null
	icon.texture = null
	floating = false

	_kill_tween()

	tween = create_tween()

	tween.tween_property(
		self,
		"interaction_offset:y",
		-8.0,
		0.1
	).set_ease(Tween.EASE_OUT)

	tween.tween_property(
		self,
		"interaction_offset:y",
		20.0,
		0.2
	).set_ease(Tween.EASE_IN)

	tween.tween_callback(queue_free)


func _kill_tween() -> void:
	if tween and tween.is_valid():
		tween.kill()

	interaction_offset = Vector2.ZERO
