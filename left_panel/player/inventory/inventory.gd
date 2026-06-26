extends Panel
class_name Inventory

const INVENTORY_SIZE: int = 28

@onready var inventory_grid: GridContainer = %InventoryGrid
@export var slot_scene: PackedScene          # your InventorySlot.tscn

var slots: Array[InventorySlot] = []

func _ready() -> void:
	_build_slots()

func _build_slots() -> void:
	for i in INVENTORY_SIZE:
		var slot: InventorySlot = slot_scene.instantiate()
		inventory_grid.add_child(slot)   # add first so the slot's @onready vars are valid
		slots.append(slot)

func add_item(data: ItemData) -> bool:
	if data == null:
		return false
	var slot := _find_empty_slot()
	if slot == null:
		return false                     # inventory full
	slot.setup(data.duplicate())         # hand it its own copy
	return true

func _find_empty_slot() -> InventorySlot:
	for slot in slots:
		if slot.is_empty():
			return slot
	return null
