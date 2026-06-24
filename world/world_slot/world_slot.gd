extends MarginContainer
class_name WorldSlot

const RECOLOR_SHADER := preload("res://shaders/recolor.gdshader")
const SHINE_SHADER := preload("res://shaders/water_shine.gdshader")

# Named back-variants, keyed by the base name of the front icon.
# river1.png -> river1back.png, etc.
const RIVER_BACKS := {
	"river1": preload("res://pieces/river/icons/river1back.png"),
	"river2": preload("res://pieces/river/icons/river2back.png"),
	"river3": preload("res://pieces/river/icons/river3back.png"),
}

# How many frames icon2 trails behind icon1. 1 = literal one step (basically
# invisible at 60fps); 6-10 reads as a nice drag.
const TRAIL_DELAY := 8

@onready var icon: TextureRect = %TextureRect
@onready var icon2: TextureRect = %TextureRect2

var piece: PieceData
var tween: Tween
var health: int

var grid_pos: Vector2i
var floating := false
var float_time := 0.0
var float_phase := randf() * 1.5
var float_offset := Vector2.ZERO
var interaction_offset := Vector2.ZERO

var _is_river := false
var _icon2_base := Vector2.ZERO      # icon2's resting position from the scene
var _trail: Array[Vector2] = []      # recent offsets of icon1
var _shimmer_seed := randf() * 100.0 # per-tile noise offset so rivers don't sync

signal update_display(piece)
signal clicked

func _ready() -> void:
	_icon2_base = icon2.position
	# Defensive: ensure no shine material leaks from the scene onto a fresh tile.
	icon2.material = null
	icon2.visible = false

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

	var offset := float_offset + interaction_offset
	icon.position = offset

	# icon2 replays icon1's offset, TRAIL_DELAY frames late.
	if _is_river:
		_trail.push_back(offset)
		if _trail.size() > TRAIL_DELAY:
			icon2.position = _icon2_base + _trail.pop_front()

func set_piece(data: PieceData) -> void:
	piece = data
	piece.pick_icon()
	icon.texture = piece.selected_icon
	_apply_icon_colors()
	_refresh_river_back()
	floating = piece.should_float()
	if floating:
		float_phase = randf() * TAU
		float_time = randf() * TAU
	else:
		float_phase = 0.0
		float_time = 0.0
		float_offset = Vector2.ZERO

func _refresh_river_back() -> void:
	_trail.clear()
	var key := ""
	if piece and piece.selected_icon:
		key = piece.selected_icon.resource_path.get_file().get_basename()

	if RIVER_BACKS.has(key):
		_is_river = true
		icon2.texture = RIVER_BACKS[key]
		icon2.position = _icon2_base
		icon2.visible = true
		_apply_shine()
	else:
		# Non-river: strip texture, material, and hide. Clearing the material
		# here is what prevents the shine from leaking onto every tile.
		_is_river = false
		icon2.texture = null
		icon2.material = null
		icon2.visible = false

func _apply_shine() -> void:
	var mat := icon2.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = SHINE_SHADER
		icon2.material = mat
	mat.set_shader_parameter("seed", _shimmer_seed)

func _apply_icon_colors() -> void:
	if piece == null:
		return
	var has_two := piece.loot2 != null
	if not has_two:
		# zero or one prefix: cheap modulate, no shader
		icon.material = null
		icon.modulate = piece.loot1.color if piece.loot1 else Color.WHITE
		return
	# two prefixes: shader handles the two regions
	icon.modulate = Color.WHITE
	var mat := icon.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = RECOLOR_SHADER
		icon.material = mat
	mat.set_shader_parameter("color_1", piece.loot1.color if piece.loot1 else Color.WHITE)
	mat.set_shader_parameter("color_2", piece.loot2.color)

func phase_offset() -> float:
	return grid_pos.x * 0.7 + grid_pos.y * 0.4

func _on_button_mouse_entered() -> void:
	if piece == null:
		return
	update_display.emit(piece)
	_kill_tween()
	tween = create_tween().set_loops(2)
	tween.tween_property(self, "interaction_offset:x", 3.0, 0.02)
	tween.tween_property(self, "interaction_offset:x", -3.0, 0.02)
	tween.tween_property(self, "interaction_offset:x", 0.0, 0.02)

func _on_button_pressed() -> void:
	_kill_tween()
	tween = create_tween()
	tween.tween_property(self, "interaction_offset:y", -8.0, 0.03).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "interaction_offset:y", 0.0, 0.31)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_ELASTIC)
	clicked.emit()

func _remove() -> void:
	piece = null
	icon.texture = null
	_is_river = false
	icon2.texture = null
	icon2.material = null
	icon2.visible = false
	_trail.clear()
	floating = false
	_kill_tween()
	tween = create_tween()
	tween.tween_property(self, "interaction_offset:y", -8.0, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "interaction_offset:y", 20.0, 0.2).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _kill_tween() -> void:
	if tween and tween.is_valid():
		tween.kill()
	interaction_offset = Vector2.ZERO

func _swap_piece(new_data: PieceData) -> void:
	_kill_tween()
	set_piece(new_data)                          # new piece appears instantly
	interaction_offset.y = -8.0
	tween = create_tween()
	tween.tween_property(self, "interaction_offset:y", 0.0, 0.12)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)
