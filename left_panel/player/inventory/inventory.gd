extends Panel
class_name Inventory

signal yield_flight_requested(item: ItemData, from_slot: InventorySlot, to_slot: InventorySlot)

const INVENTORY_SIZE: int = 28
@onready var inventory_grid: GridContainer = %InventoryGrid
@export var slot_scene: PackedScene          # your InventorySlot.tscn

var _incoming: Dictionary = {}   # InventorySlot -> String (stack key)
var slots: Array[InventorySlot] = []
var _mouse_inside: bool = false

signal sort_flight_requested(item: ItemData, count: int, from_slot: InventorySlot, to_slot: InventorySlot)

var _sorting: bool = false

func _ready() -> void:
	_build_slots()
	mouse_entered.connect(_on_region_entered)
	mouse_exited.connect(_on_region_exited)

func _build_slots() -> void:
	for i in INVENTORY_SIZE:
		var slot: InventorySlot = slot_scene.instantiate()
		inventory_grid.add_child(slot)
		slot.use_requested.connect(_on_slot_use_requested)
		slot.hover_changed.connect(_on_region_hover_changed)
		slots.append(slot)

func add_item(data: ItemData) -> bool:
	if data == null:
		return false
	var existing := _find_matching_slot(data)
	if existing != null:
		existing.add_to_stack()
		return true
	var slot := _find_empty_slot()
	if slot == null:
		return false
	slot.setup(data.duplicate())
	return true

func claim_slot_for(data: ItemData) -> InventorySlot:
	if data == null:
		return null
	var key := data.stack_key()
	if key != "":
		var existing := _find_matching_slot(data)
		if existing != null:
			return existing
		for slot in _incoming:
			if _incoming[slot] == key:
				return slot
	for slot in slots:
		if slot.is_empty() and not _incoming.has(slot):
			_incoming[slot] = key
			return slot
	return null

func commit_item(slot: InventorySlot, data: ItemData) -> void:
	_incoming.erase(slot)
	if slot == null or data == null:
		return
	if slot.is_empty():
		slot.setup(data.duplicate())
	else:
		slot.add_to_stack()

# A slot was clicked with a usable item: pay the cost, then fly each yield
# out of the clicked slot into its destination stack (same arc as world loot).
func _on_slot_use_requested(slot: InventorySlot) -> void:
	var data := slot.item_data
	if data == null or not data.is_usable():
		return
	if slot.count < data.consume_count:
		return
	# Pay first, so a same-type yield can re-target the slot we just emptied.
	slot.remove_from_stack(data.consume_count)
	for yield_item in data.click_yields:
		if yield_item == null:
			continue
		var produced := _resolve_yield(yield_item, data)
		var target := claim_slot_for(produced)
		if target == null:
			push_warning("Inventory full — yield lost: %s" % produced.name)
			continue
		yield_flight_requested.emit(produced, slot, target)

# A yield authored to inherit (prefix_region > 0) takes the source item's
# prefix. Duplicate so the authored .tres stays untouched — same pattern as
# _grant_loot does with piece prefixes.
func _resolve_yield(yield_item: ItemData, source: ItemData) -> ItemData:
	if yield_item.prefix_region > 0 and source.prefix != null:
		var copy := yield_item.duplicate()
		copy.prefix = source.prefix
		return copy
	return yield_item

func _find_matching_slot(data: ItemData) -> InventorySlot:
	for slot in slots:
		if not slot.is_empty() and slot.matches(data):
			return slot
	return null

func _find_empty_slot() -> InventorySlot:
	for slot in slots:
		if slot.is_empty():
			return slot
	return null

func _on_region_entered() -> void:
	_mouse_inside = true

func _on_region_hover_changed(is_inside: bool) -> void:
	if is_inside:
		_mouse_inside = true
	else:
		_recheck_region_exit()

func _on_region_exited() -> void:
	_recheck_region_exit()

func _recheck_region_exit() -> void:
	# Wait a frame so the destination control's `entered` has a chance to fire
	# before we decide nothing is hovered.
	await get_tree().process_frame
	if _pointer_over_inventory():
		return
	if _mouse_inside:
		_mouse_inside = false
		sort_alphabetical()

func _pointer_over_inventory() -> bool:
	var p := get_global_mouse_position()
	if get_global_rect().has_point(p):
		return true
	for slot in slots:
		if slot.get_global_rect().has_point(p):
			return true
	return false

# Called when the mouse leaves the inventory area.
func sort_alphabetical() -> void:
	if _sorting:
		return

	# Gather occupied slots as (data, count) units, sorted by item name.
	var units: Array = []
	for slot in slots:
		if not slot.is_empty():
			units.append({"data": slot.item_data, "count": slot.count})
	units.sort_custom(func(a, b): return a.data.name.naturalnocasecmp_to(b.data.name) < 0)

	# Map each unit to its destination slot (first N slots, in order).
	var moves: Array = []   # { item, count, from, to }
	for i in units.size():
		var unit = units[i]
		var dest := slots[i]
		# Find the slot this unit currently lives in (by identity match on data).
		var src: InventorySlot = _slot_holding(unit.data, unit.count)
		moves.append({"item": unit.data, "count": unit.count, "from": src, "to": dest})

	# If nothing actually changes position, skip the whole dance.
	var changed := false
	for m in moves:
		if m.from != m.to:
			changed = true
			break
	if not changed:
		return

	_sorting = true

	# Blank every source visually and clear all slot data so destinations are
	# free to receive. Data is rebuilt as fliers land.
	for slot in slots:
		slot.hide_icon()
	var snapshot := moves.duplicate(true)
	for slot in slots:
		slot._clear()

	# Fly each unit from its old position to its sorted home.
	_pending_landings = snapshot.size()
	for m in moves:
		sort_flight_requested.emit(m.item, m.count, m.from, m.to)

var _pending_landings: int = 0

# Landing callback target for sort fliers: place the stack, don't stack onto it.
func place_sorted(slot: InventorySlot, item: ItemData, count: int) -> void:
	if slot != null and item != null:
		slot.place(item.duplicate(), count)
	_pending_landings -= 1
	if _pending_landings <= 0:
		_sorting = false

func _slot_holding(data: ItemData, count: int) -> InventorySlot:
	for slot in slots:
		if not slot.is_empty() and slot.item_data == data and slot.count == count:
			return slot
	return null

func _on_mouse_exited() -> void:
	await get_tree().process_frame   # let the new hover settle
	if not get_global_rect().has_point(get_global_mouse_position()):
		sort_alphabetical()
