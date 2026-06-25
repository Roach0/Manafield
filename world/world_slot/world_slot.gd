extends MarginContainer
class_name WorldSlot

const RECOLOR_SHADER := preload("res://shaders/recolor.gdshader")
const SHINE_SHADER := preload("res://shaders/water_shine.gdshader")

# Default frames a trailing layer lags behind icon1.
# 1 = literal one step (invisible at 60fps); 6-10 reads as a nice drag.
const TRAIL_DELAY := 10

# --- Effect texture sets -----------------------------------------------------
# Each set maps a front-icon base name to the variant that layer draws.
# river1.png -> river1back.png / river1front.png, etc.
const RIVER_BACKS := {
	"river1": preload("res://pieces/river/icons/river1back.png"),
	"river2": preload("res://pieces/river/icons/river2back.png"),
	"river3": preload("res://pieces/river/icons/river3back.png"),
}
const RIVER_FRONTS := {
	"river1": preload("res://pieces/river/icons/river1front.png"),
	"river2": preload("res://pieces/river/icons/river2front.png"),
	"river3": preload("res://pieces/river/icons/river3front.png"),
}

# A trailing layer: a TextureRect that replays icon1's motion `delay` frames
# late, draws whatever textures[key] resolves to, and optionally runs a
# per-show setup hook. Adding an effect = adding one of these in _ready().
class TrailLayer:
	var node: TextureRect
	var textures: Dictionary
	var on_show: Callable
	var delay: int
	var base_pos: Vector2

	func _init(layer_node: TextureRect, layer_textures: Dictionary,
			setup := Callable(), trail_delay := 0) -> void:
		node = layer_node
		textures = layer_textures
		on_show = setup
		delay = trail_delay

@onready var icon: TextureRect = %TextureRect
@onready var icon2: TextureRect = %TextureRect2
@onready var icon3: TextureRect = %TextureRect3

var piece: PieceData
var tween: Tween
var health: int

var grid_pos: Vector2i
var floating := false
var float_time := 0.0
var float_phase := randf() * 1.5
var float_offset := Vector2.ZERO
var interaction_offset := Vector2.ZERO

var _layers: Array[TrailLayer] = []
var _layers_active := false           # any trailing layer showing for this piece
var _max_delay := 0                   # longest layer delay; bounds trail history
var _trail: Array[Vector2] = []       # recent offsets of icon1
var _shimmer_seed := randf() * 100.0  # per-tile noise offset so rivers don't sync

signal update_display(piece)
signal clicked

func _ready() -> void:
	# Register trailing layers. Order here is intent only — actual draw order
	# is the TextureRects' stacking in the scene tree, so keep them matched.
	_layers = [
		TrailLayer.new(icon2, RIVER_BACKS, _setup_shine_layer, TRAIL_DELAY),
		TrailLayer.new(icon3, RIVER_FRONTS, _setup_front_layer, TRAIL_DELAY),
	]
	for layer in _layers:
		layer.base_pos = layer.node.position
		_max_delay = max(_max_delay, layer.delay)
		# Defensive: ensure no material/visibility leaks from the scene.
		layer.node.material = null
		layer.node.visible = false

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

	# Each visible layer replays icon1's offset, its own `delay` frames late.
	if _layers_active:
		_trail.push_back(offset)
		while _trail.size() > _max_delay + 1:
			_trail.pop_front()
		var newest := _trail.size() - 1
		for layer in _layers:
			if not layer.node.visible:
				continue
			var idx := newest - layer.delay
			if idx >= 0:
				layer.node.position = layer.base_pos + _trail[idx]

func set_piece(data: PieceData) -> void:
	piece = data
	piece.pick_icon()
	icon.texture = piece.selected_icon
	_apply_icon_colors()
	_refresh_layers()
	floating = piece.should_float()
	if floating:
		float_phase = randf() * TAU
		float_time = randf() * TAU
	else:
		float_phase = 0.0
		float_time = 0.0
		float_offset = Vector2.ZERO

func _refresh_layers() -> void:
	_trail.clear()
	var key := ""
	if piece and piece.selected_icon:
		key = piece.selected_icon.resource_path.get_file().get_basename()

	_layers_active = false
	for layer in _layers:
		if layer.textures.has(key):
			_layers_active = true
			layer.node.texture = layer.textures[key]
			layer.node.position = layer.base_pos
			layer.node.visible = true
			if layer.on_show.is_valid():
				layer.on_show.call(layer)
		else:
			# Strip texture + material and hide. Clearing the material is what
			# stops an effect (e.g. shine) leaking onto tiles without it.
			layer.node.texture = null
			layer.node.material = null
			layer.node.visible = false

func _setup_shine_layer(layer: TrailLayer) -> void:
	var mat := layer.node.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = SHINE_SHADER
		layer.node.material = mat
	mat.set_shader_parameter("seed", _shimmer_seed)

func _setup_front_layer(layer: TrailLayer) -> void:
	# Plain faded layer. modulate.a only, so RGB stays untinted.
	layer.node.modulate.a = 0.2

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
	_layers_active = false
	for layer in _layers:
		layer.node.texture = null
		layer.node.material = null
		layer.node.visible = false
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
