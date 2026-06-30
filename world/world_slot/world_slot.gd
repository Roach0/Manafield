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

# --- Falling-leaf effect (forest tiles) --------------------------------------
# Forest icons are detected by name prefix; rename to match your art
# (e.g. "tree" if your sprites are tree1.png, tree2.png ...).
const FOREST_PREFIX := "forest"
# Sprite is 16x16 with ~50/50 trunk/canopy, so leaves only spawn in the top
# rows. Columns are inset a touch so they start under the canopy, not its edge.
const LEAF_COL_MIN := 2
const LEAF_COL_MAX := 13
const LEAF_ROW_MIN := 1
const LEAF_ROW_MAX := 6
# Spawn cadence per tile (seconds). Low + jittered = an occasional drift.
const LEAF_INTERVAL_MIN := 1.8
const LEAF_INTERVAL_MAX := 5.0
const SECOND_LEAF_CHANCE := 0.25
# Board-wide cap on how many trees may be mid-flurry at once. A tile can only
# *start* dropping if it claims one of these tokens; it releases when its last
# leaf lands. Already-dropping tiles are never interrupted.
const MAX_CONCURRENT_DROPPERS := 4
# All of these are in *sprite* pixels; they're multiplied by the tile's display
# scale at spawn, so a leaf stays one art-pixel big and moves on the art grid
# no matter what zoom the board is drawn at.
const LEAF_FALL_MIN := 2.5   # downward speed, px/sec (kept slow on purpose)
const LEAF_FALL_MAX := 4.0
const LEAF_DIST_MIN := 6.0   # how far it drops before it's gone
const LEAF_DIST_MAX := 11.0
const LEAF_SWAY_MIN := 0.6   # horizontal rock amplitude
const LEAF_SWAY_MAX := 1.6
const LEAF_FREQ_MIN := 2.0   # rock speed, rad/sec
const LEAF_FREQ_MAX := 3.5
const LEAF_FADE_IN := 0.25
const LEAF_FADE_OUT := 0.6
# Once a leaf touches ground it rests, fully opaque, for this long (seconds)
# before the fade-out begins.
const LEAF_LINGER_MIN := 1.6
const LEAF_LINGER_MAX := 2.8
const LEAF_COLOR := Color(0.42, 0.62, 0.28)  # fallback tint when no prefix

# --- Glimmer effect (boulder tiles) ------------------------------------------
# Boulder icons detected by name prefix; rename to match your art.
const BOULDER_PREFIX := "boulder"
# Boulder is centred in the sprite, so glimmers stay in an inset box around the
# middle, away from the top/bottom edges.
const GLIMMER_COL_MIN := 4
const GLIMMER_COL_MAX := 11
const GLIMMER_ROW_MIN := 5
const GLIMMER_ROW_MAX := 10
# Very occasional: long jittered gap between attempts, and not every attempt
# actually fires.
const GLIMMER_INTERVAL_MIN := 6.0
const GLIMMER_INTERVAL_MAX := 14.0
const GLIMMER_CHANCE := 0.6
# Sparkle shape/timing. Arm length in *sprite* pixels (x tile scale at spawn).
const GLIMMER_ARM_MIN := 1.5   # peak half-length of each arm of the cross
const GLIMMER_ARM_MAX := 2.5
const GLIMMER_LIFE_MIN := 0.65
const GLIMMER_LIFE_MAX := 0.95
const GLIMMER_COLOR := Color(1.0, 1.0, 1.0)

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

# One falling pixel. Stores screen-space motion (sprite px x tile scale baked in
# at spawn) and rocks side to side on a sine while it descends, like a leaf.
class Leaf:
	var node: ColorRect
	var base_x: float
	var start_y: float
	var fall_speed: float
	var fall_time: float   # seconds of descent before it lands and rests
	var sway_amp: float
	var sway_freq: float
	var sway_phase: float
	var life: float
	var fade_in: float
	var fade_out: float
	var age := 0.0

	func is_falling() -> bool:
		return age < fall_time

	func advance(delta: float) -> bool:
		age += delta
		if age >= life:
			return false
		# Freeze descent and sway at the landing point, then it just sits there
		# (lingering, then fading) for the rest of its life.
		var t := minf(age, fall_time)
		var x := base_x + sin(t * sway_freq + sway_phase) * sway_amp
		var y := start_y + fall_speed * t
		var a := 1.0
		if age < fade_in:
			a = age / fade_in
		elif age > life - fade_out:
			a = (life - age) / fade_out
		node.position = Vector2(round(x), round(y))
		node.modulate.a = clampf(a, 0.0, 1.0)
		return true

# A gem-style sparkle: two thin crossing bars that grow from a point, peak, and
# retract on a sin envelope, so arm-length and brightness rise and fall as one.
# Brief and self-contained — spawned, then frees its nodes when its life ends.
class Glimmer:
	var vbar: ColorRect   # vertical arm
	var hbar: ColorRect   # horizontal arm
	var center: Vector2   # fixed screen-space centre
	var px: float         # one sprite pixel in screen px (bar thickness)
	var arm: float        # peak half-length of each arm, screen px
	var life: float
	var age := 0.0

	func advance(delta: float) -> bool:
		age += delta
		if age >= life:
			return false
		var e := sin(PI * age / life)          # 0 -> 1 -> 0
		var half := roundf(e * arm)
		var thick := maxf(1.0, round(px))
		var span := maxf(thick, half * 2.0 + thick)
		var a := clampf(e, 0.0, 1.0)
		vbar.size = Vector2(thick, span)
		vbar.position = (center - Vector2(thick, span) * 0.5).round()
		vbar.modulate.a = a
		hbar.size = Vector2(span, thick)
		hbar.position = (center - Vector2(span, thick) * 0.5).round()
		hbar.modulate.a = a
		return true

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

static var _active_droppers := 0      # shared across every WorldSlot
var _leaves: Array[Leaf] = []
var _leaves_active := false           # this piece is a forest tile, drop leaves
var _holding_token := false           # this tile currently owns a dropper token
var _leaf_timer := 0.0
var _leaf_host: Control               # plain Control so leaf churn never re-sorts

var _glimmers: Array[Glimmer] = []
var _glimmers_active := false         # this piece is a boulder tile, sparkle it
var _glimmer_timer := 0.0

signal update_display(piece)
signal clicked
signal piece_changed(slot)   # NEW: TurnSystem listens to (de)register tickers + reset statuses

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

	# Host for falling-leaf pixels. A plain Control (not a container) so adding
	# and removing leaf nodes never triggers a layout re-sort on the slot, and
	# nothing repositions them behind our back. Added last => drawn on top of
	# the icons, so leaves drift in front of the tree.
	_leaf_host = Control.new()
	_leaf_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_leaf_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.get_parent().add_child(_leaf_host)

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

	# Falling leaves (forest tiles). Independent of the tree's float, so a
	# dropped leaf drifts on its own rather than swaying with the trunk.
	if _leaves_active:
		_leaf_timer -= delta
		if _leaf_timer <= 0.0:
			# Already-dropping tiles keep their token; idle ones must claim one,
			# capping how many trees can leaf at the same moment board-wide.
			if _holding_token or _try_claim_token():
				_spawn_leaf()
				if randf() < SECOND_LEAF_CHANCE:
					_spawn_leaf()
			_leaf_timer = randf_range(LEAF_INTERVAL_MIN, LEAF_INTERVAL_MAX)
	var any_falling := false
	if not _leaves.is_empty():
		for i in range(_leaves.size() - 1, -1, -1):
			if not _leaves[i].advance(delta):
				if is_instance_valid(_leaves[i].node):
					_leaves[i].node.queue_free()
				_leaves.remove_at(i)
			elif _leaves[i].is_falling():
				any_falling = true
	# The cap limits trees that are *actively dropping*. Release the slot as
	# soon as this tile's leaves have all touched ground — they linger and fade
	# as harmless residue while another tree gets a turn.
	if _holding_token and not any_falling:
		_release_token()

	# Boulder glimmer. No cap or pooling — rare and cheap.
	if _glimmers_active:
		_glimmer_timer -= delta
		if _glimmer_timer <= 0.0:
			if randf() < GLIMMER_CHANCE:
				_spawn_glimmer()
			_glimmer_timer = randf_range(GLIMMER_INTERVAL_MIN, GLIMMER_INTERVAL_MAX)
	if not _glimmers.is_empty():
		for i in range(_glimmers.size() - 1, -1, -1):
			if not _glimmers[i].advance(delta):
				_free_glimmer(_glimmers[i])
				_glimmers.remove_at(i)

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
	piece_changed.emit(self)   # NEW — fires for gen, build, and swap/replace alike

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

	_refresh_leaves(key)
	_refresh_glimmers(key)

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

# --- Leaves ------------------------------------------------------------------

func _refresh_leaves(key: String) -> void:
	_clear_leaves()
	_leaves_active = _is_forest_key(key)
	# Jitter the first spawn so a screenful of forest doesn't pulse in unison.
	_leaf_timer = randf_range(0.0, LEAF_INTERVAL_MAX) if _leaves_active else 0.0

func _is_forest_key(key: String) -> bool:
	return key.begins_with(FOREST_PREFIX)

func _try_claim_token() -> bool:
	if _active_droppers >= MAX_CONCURRENT_DROPPERS:
		return false
	_active_droppers += 1
	_holding_token = true
	return true

func _release_token() -> void:
	if _holding_token:
		_holding_token = false
		_active_droppers -= 1

func _spawn_leaf() -> void:
	if _leaf_host == null:
		return
	var px := icon.size.x / 16.0   # screen pixels per sprite pixel
	if px <= 0.0:
		return                      # layout not settled yet; skip this beat

	var col := randi_range(LEAF_COL_MIN, LEAF_COL_MAX)
	var row := randi_range(LEAF_ROW_MIN, LEAF_ROW_MAX)

	var leaf := Leaf.new()
	leaf.base_x = col * px
	leaf.start_y = row * px
	leaf.fall_speed = randf_range(LEAF_FALL_MIN, LEAF_FALL_MAX) * px
	leaf.fall_time = (randf_range(LEAF_DIST_MIN, LEAF_DIST_MAX) * px) / leaf.fall_speed
	leaf.sway_amp = randf_range(LEAF_SWAY_MIN, LEAF_SWAY_MAX) * px
	leaf.sway_freq = randf_range(LEAF_FREQ_MIN, LEAF_FREQ_MAX)
	leaf.sway_phase = randf() * TAU
	leaf.fade_in = LEAF_FADE_IN
	leaf.fade_out = LEAF_FADE_OUT
	# fall -> linger on the ground -> fade out.
	leaf.life = leaf.fall_time + randf_range(LEAF_LINGER_MIN, LEAF_LINGER_MAX) + leaf.fade_out

	var s := maxf(1.0, round(px))   # one art-pixel block
	var rect := ColorRect.new()
	# Leaf takes the tile's first-prefix color (falls back to the leaf green).
	rect.color = piece.loot1.color if (piece and piece.loot1) else LEAF_COLOR
	rect.size = Vector2(s, s)
	rect.position = Vector2(round(leaf.base_x), round(leaf.start_y))
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0          # advance() fades it in on the first frame
	leaf.node = rect
	_leaf_host.add_child(rect)
	_leaves.append(leaf)

func _clear_leaves() -> void:
	for leaf in _leaves:
		if is_instance_valid(leaf.node):
			leaf.node.queue_free()
	_leaves.clear()
	_release_token()   # never strand a token when a tile is swapped/removed

# --- Glimmers ----------------------------------------------------------------

func _refresh_glimmers(key: String) -> void:
	_clear_glimmers()
	_glimmers_active = _is_boulder_key(key)
	# Start a full interval out so a boulder doesn't sparkle the instant it spawns.
	_glimmer_timer = randf_range(GLIMMER_INTERVAL_MIN, GLIMMER_INTERVAL_MAX) if _glimmers_active else 0.0

func _is_boulder_key(key: String) -> bool:
	return key.begins_with(BOULDER_PREFIX)

func _spawn_glimmer() -> void:
	if _leaf_host == null:
		return
	var px := icon.size.x / 16.0   # screen pixels per sprite pixel
	if px <= 0.0:
		return

	var col := randi_range(GLIMMER_COL_MIN, GLIMMER_COL_MAX)
	var row := randi_range(GLIMMER_ROW_MIN, GLIMMER_ROW_MAX)

	var g := Glimmer.new()
	g.px = px
	g.center = Vector2(col * px + px * 0.5, row * px + px * 0.5)  # centre of that pixel
	g.arm = randf_range(GLIMMER_ARM_MIN, GLIMMER_ARM_MAX) * px
	g.life = randf_range(GLIMMER_LIFE_MIN, GLIMMER_LIFE_MAX)
	g.vbar = _make_glimmer_bar()
	g.hbar = _make_glimmer_bar()
	_leaf_host.add_child(g.vbar)
	_leaf_host.add_child(g.hbar)
	_glimmers.append(g)

func _make_glimmer_bar() -> ColorRect:
	var r := ColorRect.new()
	r.color = GLIMMER_COLOR
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = 0.0   # advance() drives the twinkle in/out
	return r

func _free_glimmer(g: Glimmer) -> void:
	if is_instance_valid(g.vbar):
		g.vbar.queue_free()
	if is_instance_valid(g.hbar):
		g.hbar.queue_free()

func _clear_glimmers() -> void:
	for g in _glimmers:
		_free_glimmer(g)
	_glimmers.clear()

# --- Prefix / recolor --------------------------------------------------------

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
	_leaves_active = false
	_clear_leaves()
	_glimmers_active = false
	_clear_glimmers()
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
