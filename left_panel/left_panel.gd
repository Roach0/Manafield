extends Panel
class_name LeftPanel

@onready var player := %Player
@onready  var inventory := %Inventory

func _ready() -> void:
	pass

func set_new_player():
	player.max_health = 10
	player.health = 10
	player.max_energy = 10
	player.energy = 10
	player.max_hunger = 10
	player.hunger = 10
	player.max_nerve = 10
	player.nerve = 10

func add_item(item: ItemData) -> bool:
	return inventory.add_item(item)

func claim_loot_slot(item: ItemData) -> InventorySlot:
	return inventory.claim_slot_for(item)

func commit_loot(slot: InventorySlot, item: ItemData) -> void:
	inventory.commit_item(slot, item)
