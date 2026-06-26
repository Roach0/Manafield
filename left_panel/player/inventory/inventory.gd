extends Panel
class_name Inventory

const INVENTORY_SIZE: int = 28
@onready var inventory_grid: GridContainer = %InventoryGrid
@export var slot_scene: PackedScene

# Reserved/forming slots with an item in flight toward them, keyed by the
# stack they're forming. A second same-kind drop targets the same forming
# slot instead of grabbing another empty one.
var _incoming: Dictionary = {}   # InventorySlot -> String (stack key)
var slots: Array[InventorySlot] = []

func _ready() -> void:
	_build_slots()

func _build_slots() -> void:
	for i in INVENTORY_SIZE:
		var slot: InventorySlot = slot_scene.instantiate()
		inventory_grid.add_child(slot)
		slots.append(slot)

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
		return false
	slot.setup(data.duplicate())
	return true

# Pick the slot an in-flight item should fly toward:
#   1) an already-committed stack of the same kind
#   2) a stack of the same kind still forming (item mid-flight)
#   3) a freshly reserved empty slot
func claim_slot_for(data: ItemData) -> InventorySlot:
	if data == null:
		return null
	var key := data.stack_key()
	if key != "":                                   # "" => non-stackable
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

# Called when a flier lands: seed a new stack or grow an existing one.
func commit_item(slot: InventorySlot, data: ItemData) -> void:
	_incoming.erase(slot)
	if slot == null or data == null:
		return
	if slot.is_empty():
		slot.setup(data.duplicate())
	else:
		slot.add_to_stack()

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
