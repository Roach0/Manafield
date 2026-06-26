extends Panel
class_name InventorySlot

@onready var button: Button = %Button
@onready var icon: TextureRect = %TextureRect

@export var item_data: ItemData = null

const HOVER_LIFT := 6.0      # how high it rests while hovered
const HOP_HEIGHT := 14.0     # peak of the initial hop (above the rest height)
const PULSE_SCALE := 1.50    # how big the blip pulse is.
var _base_y: float
var _tween: Tween
var _pulse_tween: Tween       # separate from _tween so they don't fight


func _ready() -> void:
	_refresh()
	button.mouse_entered.connect(_on_hover_start)
	button.mouse_exited.connect(_on_hover_end)
	button.pressed.connect(_on_pressed)
	await get_tree().process_frame
	icon.pivot_offset = icon.size / 2.0
	_base_y = icon.position.y

func setup(data: ItemData) -> void:
	item_data = data
	if is_node_ready():
		_refresh()

func _refresh() -> void:
	if item_data and not item_data.icons.is_empty():
		icon.texture = item_data.icons[0]
	else:
		icon.texture = null

func is_empty() -> bool:
	return item_data == null

func _on_hover_start() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	# quick hop up past the rest point...
	_tween.tween_property(icon, "position:y", _base_y - HOP_HEIGHT, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# ...then settle down to the elevated resting height
	_tween.tween_property(icon, "position:y", _base_y - HOVER_LIFT, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_hover_end() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(icon, "position:y", _base_y, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_pressed() -> void:
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	icon.scale = Vector2.ONE
	icon.rotation = 0.0
	_pulse_tween = create_tween()

	# --- scale: punch out, then damped bounces back to rest ---
	_pulse_tween.tween_property(icon, "scale", Vector2.ONE * 1.25, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(icon, "scale", Vector2.ONE * 0.92, 0.07)
	_pulse_tween.tween_property(icon, "scale", Vector2.ONE * 1.06, 0.06)
	_pulse_tween.tween_property(icon, "scale", Vector2.ONE, 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# --- rotation: wobble left/right, decaying, runs alongside the scale ---
	var wob := create_tween()
	wob.tween_property(icon, "rotation", deg_to_rad(8), 0.06)
	wob.tween_property(icon, "rotation", deg_to_rad(-6), 0.06)
	wob.tween_property(icon, "rotation", deg_to_rad(3), 0.05)
	wob.tween_property(icon, "rotation", 0.0, 0.06)
