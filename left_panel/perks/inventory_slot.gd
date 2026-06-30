extends Panel
class_name InventorySlot

signal use_requested(slot: InventorySlot)
signal hover_changed(is_inside: bool)
signal item_hovered(item: ItemData)
signal sacrifice_requested(slot: InventorySlot)

@onready var button: Button = %Button
@onready var icon: TextureRect = %TextureRect
@export var item_data: ItemData = null

const HOVER_LIFT := 6.0      # how high it rests while hovered
const HOP_HEIGHT := 14.0     # peak of the initial hop (above the rest height)
const PULSE_SCALE := 1.50    # how big the blip pulse is.
const SACRIFICE_HOLD := 0.6        # seconds of holding to fill the meter
const SACRIFICE_DRAIN := 3.0       # how fast the meter empties on early release (× fill rate)


var count: int = 0           # 0 = empty, >=1 = occupied
var _base_y: float
var _base_x: float
var _tween: Tween
var _pulse_tween: Tween       # separate from _tween so they don't fight
var _count_label: Label
var _sac_fill := 0.0               # 0..1 meter
var _sac_holding := false
var _sac_fired := false            # latch so a full hold fires exactly once
var _sac_bar: ColorRect            # the fill overlay

func _ready() -> void:
	_build_count_label()
	_refresh()
	_refresh_count()
	button.mouse_entered.connect(_on_hover_start)
	button.mouse_exited.connect(_on_hover_end)
	button.pressed.connect(_on_pressed)
	button.button_down.connect(_on_button_down)
	button.button_up.connect(_on_button_up)
	_build_sacrifice_bar()
	set_process(true)
	await get_tree().process_frame
	icon.pivot_offset = icon.size / 2.0
	_base_y = icon.position.y
	_base_x = icon.position.x

func _build_count_label() -> void:
	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.add_theme_font_size_override("font_size", 28)
	_count_label.add_theme_constant_override("outline_size", 6)
	_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_count_label)            # added last -> drawn over the icon
	_count_label.offset_right = -3
	_count_label.offset_bottom = -2
	_count_label.visible = false

func setup(data: ItemData) -> void:
	item_data = data
	count = 1
	if data.prefix != null:
		icon.material = null            # ensure no leftover shader from a pooled node
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

func _build_sacrifice_bar() -> void:
	_sac_bar = ColorRect.new()
	_sac_bar.name = "SacrificeBar"
	_sac_bar.color = Color(0.9, 0.2, 0.2, 0.55)   # tune to taste
	_sac_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sac_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_sac_bar.custom_minimum_size.y = 0.0
	_sac_bar.size.y = 0.0
	add_child(_sac_bar)               # drawn over icon, under count label if it's added later
	_sac_bar.visible = false

func _on_button_down() -> void:
	# Only meaningful on an occupied slot.
	if is_empty():
		return
	_sac_holding = true
	_sac_fired = false

func _on_button_up() -> void:
	_sac_holding = false
	# If the meter never filled, this was a normal click — let _on_pressed handle
	# use. (pressed also fires on release; the fill being incomplete means we did
	# not consume the gesture as a sacrifice.)

func _process(delta: float) -> void:
	if _sac_holding and not is_empty():
		_sac_fill = min(_sac_fill + delta / SACRIFICE_HOLD, 1.0)
		if _sac_fill >= 1.0 and not _sac_fired:
			_sac_fired = true
			_sac_holding = false
			sacrifice_requested.emit(self)
	elif _sac_fill > 0.0:
		_sac_fill = max(_sac_fill - delta / SACRIFICE_HOLD * SACRIFICE_DRAIN, 0.0)
	_update_sacrifice_bar()

func _update_sacrifice_bar() -> void:
	if _sac_bar == null:
		return
	var visible := _sac_fill > 0.001
	_sac_bar.visible = visible
	if visible:
		_sac_bar.size.y = size.y * _sac_fill
		_sac_bar.position.y = size.y - _sac_bar.size.y
		_sac_bar.size.x = size.x

# Pay down the stack; clears the slot when it empties.
func remove_from_stack(amount: int = 1) -> void:
	count -= amount
	if count <= 0:
		_clear()
	else:
		_refresh_count()

func _clear() -> void:
	item_data = null
	count = 0
	icon.texture = null
	icon.modulate = Color.WHITE
	icon.material = null
	_refresh_count()   # count is 0 -> badge hides, is_empty() now true

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
	hover_changed.emit(true)
	item_hovered.emit(item_data)   # null if slot is empty -> display hides
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(icon, "position:y", _base_y - HOP_HEIGHT, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(icon, "position:y", _base_y - HOVER_LIFT, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_hover_end() -> void:
	hover_changed.emit(false)
	item_hovered.emit(null)
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(icon, "position:y", _base_y, 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_pressed() -> void:
	if _sac_fired:
		_sac_fired = false   # consume the gesture; this release was a sacrifice, not a use
		return
	if is_empty() or not item_data.is_usable():
		return
	if count < item_data.consume_count:
		_denied_feedback()
		return
	_click_feedback()
	use_requested.emit(self)




func _click_feedback() -> void:
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


func _denied_feedback() -> void:
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
	icon.position.x = _base_x
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(icon, "position:x", _base_x - 4.0, 0.04)
	_pulse_tween.tween_property(icon, "position:x", _base_x + 4.0, 0.04)
	_pulse_tween.tween_property(icon, "position:x", _base_x, 0.04)

# Place an item into this slot at a specific count (used by sort relocation,
# where a whole stack moves as one unit). Unlike setup(), preserves count.
func place(data: ItemData, amount: int) -> void:
	item_data = data
	count = max(amount, 1)
	if data.prefix != null:
		icon.material = null
		icon.modulate = data.prefix.color
	else:
		icon.modulate = Color.WHITE
	if is_node_ready():
		_refresh()
		_refresh_count()

# Hide the icon without clearing data — slot still counts as occupied logically
# during a sort, but shows nothing while its flier is in the air.
func hide_icon() -> void:
	icon.texture = null
	if _count_label:
		_count_label.visible = false
