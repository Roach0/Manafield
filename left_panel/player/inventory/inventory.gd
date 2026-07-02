extends Panel
class_name Inventory

signal yield_flight_requested(item: ItemData, from_slot: InventorySlot, to_slot: InventorySlot)
signal sort_flight_requested(item: ItemData, count: int, from_slot: InventorySlot, to_slot: InventorySlot)
signal item_hovered(item: ItemData)
signal sacrifice_requested(item: ItemData, count: int, slot: InventorySlot)


const INVENTORY_SIZE: int = 28
@onready var inventory_grid: GridContainer = %InventoryGrid
@export var slot_scene: PackedScene          # your InventorySlot.tscn

# Reserved/forming slots with an item in flight toward them, keyed by the
# stack they're forming. A second same-kind drop targets the same forming
# slot instead of grabbing another empty one.
var _incoming: Dictionary = {}   # InventorySlot -> String (stack key)
var slots: Array[InventorySlot] = []

# Region hover tracking (drives auto-sort on exit).
var _mouse_inside: bool = false

# Sort state.
var _sorting: bool = false
var _pending_landings: int = 0
var _sort_queued: bool = false          # a sort was requested but blocked; run it once settled
var _in_flight: int = 0                  # count of ALL fliers in the air (yields + loot)
var _deferred: Array[ItemData] = []      # loot that arrived mid-sort, added the instant it ends

# Hover-display debounce (prevents the info panel flicker when gliding
# between adjacent slots).
var _hover_item: ItemData = null
var _hover_clear_pending: bool = false


func _ready() -> void:
	_build_slots()
	mouse_entered.connect(_on_region_entered)
	mouse_exited.connect(_on_region_exited)

func _build_slots() -> void:
	for i in INVENTORY_SIZE:
		var slot: InventorySlot = slot_scene.instantiate()
		inventory_grid.add_child(slot)   # add first so the slot's @onready vars are valid
		slot.use_requested.connect(_on_slot_use_requested)
		slot.hover_changed.connect(_on_region_hover_changed)
		slot.item_hovered.connect(_on_slot_item_hovered)
		slot.sacrifice_requested.connect(_on_slot_sacrifice_requested)
		slots.append(slot)


# --- Adding / stacking ---

# Immediate add (no fly animation). Stacks when possible.
func add_item(data: ItemData) -> bool:
	if data == null:
		return false
	var existing := _find_matching_slot(data)
	if existing != null:
		existing.add_to_stack()
		return true
	var slot := _find_empty_slot()
	if slot == null:
		return false                     # inventory full
	slot.setup(data.duplicate())         # hand it its own copy
	return true

# Pick the slot an in-flight item should fly toward:
#   1) an already-committed stack of the same kind
#   2) a stack of the same kind still forming (item mid-flight)
#   3) a freshly reserved empty slot
# Returns null while a sort is running (grid is mid-rebuild — caller should
# defer) or when the inventory is full.
func claim_slot_for(data: ItemData) -> InventorySlot:
	if data == null:
		return null
	# Grid is being torn down and rebuilt by sort fliers; any slot we hand out
	# now is unreliable. Tell the caller to defer (see EffectsManager._grant_loot).
	if _sorting:
		return null

	var result: InventorySlot = null
	var key := data.stack_key()
	if key != "":                                   # "" => non-stackable
		var existing := _find_matching_slot(data)
		if existing != null:
			result = existing
		else:
			for slot in _incoming:
				if _incoming[slot] == key:
					result = slot
					break
	if result == null:
		for slot in slots:
			if slot.is_empty() and not _incoming.has(slot):
				_incoming[slot] = key
				result = slot
				break

	# Count EVERY flier — including ones heading toward an existing stack, which
	# never touch _incoming. The sort guard relies on this being complete.
	if result != null:
		_in_flight += 1
	return result

# Called when a flier lands: seed a new stack or grow an existing one.
func commit_item(slot: InventorySlot, data: ItemData) -> void:
	_in_flight = max(_in_flight - 1, 0)
	_incoming.erase(slot)
	if slot == null or data == null:
		_try_queued_sort()
		return
	if slot.is_empty():
		slot.setup(data.duplicate())
	elif slot.matches(data):
		slot.add_to_stack()
	else:
		# Slot was taken by something else mid-flight. Don't fold this into the
		# wrong stack — re-home it to a free slot.
		var fallback := _find_empty_slot()
		if fallback != null:
			fallback.setup(data.duplicate())
		else:
			push_warning("Inventory full — landed item lost: %s" % data.name)
	_try_queued_sort()


func _on_slot_use_requested(slot: InventorySlot) -> void:
	if _sorting:
		return   # grid is being rebuilt by sort fliers; ignore the click
	var data := slot.item_data
	if data == null or not data.is_usable():
		return
	if slot.count < data.consume_count:
		return
	Sfx.play(data.click_sound)
	# Pay first, so a same-type yield can re-target the slot we just emptied.
	slot.remove_from_stack(data.consume_count)
	for yield_item in data.roll_yields():
		if yield_item == null:
			continue
		var produced := _resolve_yield(yield_item, data)
		var target := claim_slot_for(produced)
		if target == null:
			push_warning("Inventory full — yield lost: %s" % produced.name)
			continue
		yield_flight_requested.emit(produced, slot, target)

func _on_slot_sacrifice_requested(slot: InventorySlot) -> void:
	if _sorting:
		return
	var data := slot.item_data
	if data == null:
		return
	var count := slot.count
	Sfx.play(data.sacrifice_sound)
	# Hand the bundle off; EffectsManager applies it. Then the stack is gone.
	sacrifice_requested.emit(data, count, slot)
	slot._clear()


# A yield authored to inherit (prefix_region > 0) takes the source item's
# prefix. Duplicate so the authored .tres stays untouched.
func _resolve_yield(yield_item: ItemData, source: ItemData) -> ItemData:
	if yield_item.prefix_region > 0 and source.prefix != null:
		var copy := yield_item.duplicate()
		copy.prefix = source.prefix
		return copy
	return yield_item


# --- Lookups ---

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

func _slot_holding(data: ItemData, count: int) -> InventorySlot:
	for slot in slots:
		if not slot.is_empty() and slot.item_data == data and slot.count == count:
			return slot
	return null

# Find the slot whose stack is this exact ItemData instance (survives sorts,
# which carry the instance along). Returns null if it's gone (consumed/lost).
func slot_for_item(data: ItemData) -> InventorySlot:
	for slot in slots:
		if not slot.is_empty() and slot.item_data == data:
			return slot
	return null

# --- Region hover tracking (auto-sort on exit) ---

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


# --- Item hover -> info display (debounced to avoid flicker) ---

func _on_slot_item_hovered(item: ItemData) -> void:
	if item != null:
		_hover_clear_pending = false
		if item != _hover_item:
			_hover_item = item
			item_hovered.emit(item)
	else:
		# Don't hide immediately — a hop to the next slot lands next frame and
		# should cancel this. Only a real exit (nothing entered) clears.
		_hover_clear_pending = true
		_deferred_clear_hover()

func _deferred_clear_hover() -> void:
	await get_tree().process_frame
	if _hover_clear_pending:
		_hover_clear_pending = false
		_hover_item = null
		item_hovered.emit(null)


# --- Alphabetical sort on mouse exit ---

func sort_alphabetical() -> void:
	# Never sort while anything is moving (yields, loot). Clearing the grid out
	# from under an in-flight item is what swallows stacks and creates dupes.
	# Re-run once everything has settled (see _try_queued_sort).
	if _sorting or _in_flight > 0:
		_sort_queued = true
		return
	_sort_queued = false

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

	# Blank every source visually, then clear all slot data so destinations are
	# free to receive. Data is rebuilt as fliers land.
	for slot in slots:
		slot.hide_icon()
	var snapshot := moves.duplicate(true)
	for slot in slots:
		slot._clear()

	_pending_landings = snapshot.size()
	for m in moves:
		sort_flight_requested.emit(m.item, m.count, m.from, m.to)

# Landing callback target for sort fliers: place the stack, don't stack onto it.
func place_sorted(slot: InventorySlot, item: ItemData, count: int) -> void:
	if slot != null and item != null:
		slot.place(item.duplicate(), count)
	_pending_landings -= 1
	if _pending_landings <= 0:
		_sorting = false
		_flush_deferred()
		_try_queued_sort()


# --- Settle helpers ---

# Run a sort that was requested while something was in flight, but only once the
# grid is fully settled and the mouse is still outside.
func _try_queued_sort() -> void:
	if _sort_queued and not _sorting and _in_flight == 0 and not _mouse_inside:
		sort_alphabetical()

# Loot that couldn't claim a slot because a sort was running. Add it instantly
# (correct stacking/prefix via setup) the moment the sort finishes.
func _flush_deferred() -> void:
	if _deferred.is_empty():
		return
	var pending := _deferred.duplicate()
	_deferred.clear()
	for d in pending:
		add_item(d)

# EffectsManager calls this when claim_slot_for returned null during a sort.
func defer_add(data: ItemData) -> void:
	_deferred.append(data)

func is_sorting() -> bool:
	return _sorting
