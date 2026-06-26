extends Panel
class_name InventorySlot

@onready var button: Button = %Button
@onready var icon: TextureRect = %TextureRect
@export var item_data: ItemData = null

const HOVER_LIFT := 6.0
const HOP_HEIGHT := 14.0
const PULSE_SCALE := 1.50

var count: int = 0           # 0 = empty, >=1 = occupied
var _base_y: float
var _tween: Tween
var _pulse_tween: Tween
var _count_label: Label

func _ready() -> void:
	_build_count_label()
	_refresh()
	_refresh_count()
	button.mouse_entered.connect(_on_hover_start)
	button.mouse_exited.connect(_on_hover_end)
	button.pressed.connect(_on_pressed)
	await get_tree().process_frame
	icon.pivot_offset = icon.size / 2.0
	_base_y = icon.position.y

func _build_count_label() -> void:
	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.add_theme_font_size_override("font_size", 28)   # <- size of the number
	_count_label.add_theme_constant_override("outline_size", 6)
	_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_count_label)
	_count_label.offset_right = -3
	_count_label.offset_bottom = -2
	_count_label.visible = false

func setup(data: ItemData) -> void:
	item_data = data
	count = 1
	if data.prefix != null:
		icon.material = null
		icon.modulate = data.prefix.color
	else:
		icon.modulate = Color.WHITE
	if is_node_ready():
		_refresh()
		_refresh_count()

# Grow an existing stack (used when a same-type/prefix item lands here).
func add_to_stack(amount: int = 1) -> void:
	count += amount
	_refresh_count()
	_blip()

# Does this occupied slot accept `data` into its stack?
func matches(data: ItemData) -> bool:
	return item_data != null and item_data.can_stack_with(data)

func _refresh() -> void:
	if item_data and not item_data.icons.is_empty():
		icon.texture = item_data.icons[0]
	else:
		icon.texture = null

func _refresh_count() -> void:
	if _count_label == null:
		return
	_count_label.text = str(count)
	_count_label.visible = count > 1

func is_empty() -> bool:
	return item_data == null

# Small punch when something stacks onto this slot.
func _blip() -> void:
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	icon.scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(icon, "scale", Vector2.ONE * PULSE_SCALE, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(icon, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_hover_start() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(icon, "position:y", _base_y - HOP_HEIGHT, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
	_pulse_tween.tween_property(icon, "scale", Vector2.ONE * 1.25, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(icon, "scale", Vector2.ONE * 0.92, 0.07)
	_pulse_tween.tween_property(icon, "scale", Vector2.ONE * 1.06, 0.06)
	_pulse_tween.tween_property(icon, "scale", Vector2.ONE, 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var wob := create_tween()
	wob.tween_property(icon, "rotation", deg_to_rad(8), 0.06)
	wob.tween_property(icon, "rotation", deg_to_rad(-6), 0.06)
	wob.tween_property(icon, "rotation", deg_to_rad(3), 0.05)
	wob.tween_property(icon, "rotation", 0.0, 0.06)
