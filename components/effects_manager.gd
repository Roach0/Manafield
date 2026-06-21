extends HBoxContainer
class_name EffectsManager
@onready var world: World = %World
@onready var right_panel: RightPanel = %RightPanel
@onready var left_panel: LeftPanel = %LeftPanel
@export var prefix_pool_1: Array[Prefix]
@export var prefix_pool_2: Array[Prefix]
@export var prefix_pool_3: Array[Prefix]

func _ready() -> void:
	world.update_display.connect(_on_update_display)
	world.piece_click_requested.connect(_on_piece_click_requested)

func _on_update_display(piece: PieceData) -> void:
	right_panel.update_display(piece)

func _on_piece_click_requested(slot: WorldSlot) -> void:
	var piece := slot.piece
	if piece == null:
		return
	var cost: Dictionary = piece.get_click_cost()
	if not cost.is_empty():
		var resource_name: String = cost.get("resource", "")
		var amount: int = cost.get("amount", 0)
		if not _can_afford(resource_name, amount):
			_on_click_denied(resource_name, amount)
			return
		_pay_cost(resource_name, amount)
	var result: Dictionary = piece._click()
	print("click → ", piece.name, " h=", piece.health, " hm=", piece.health_max)
	slot.health = piece.health
	right_panel.update_display(piece)
	if not result.is_empty():
		_apply_effect(result.get("effect", ""), result.get("amount", 0))
	if piece.health_max > 0 and piece.health <= 0:
		piece._destroy()
		world.replace_with(slot, piece)

func _apply_effect(effect_name: String, amount: int) -> void:
	match effect_name:
		"update_health": left_panel.player.health += amount
		"update_energy": left_panel.player.energy += amount
		"update_hunger": left_panel.player.hunger += amount
		"update_nerve": left_panel.player.nerve += amount
		_: push_warning("Unhandled piece effect: %s" % effect_name)

func _pay_cost(resource_name: String, amount: int) -> void:
	match resource_name:
		"energy": left_panel.player.energy -= amount
		"health": left_panel.player.health -= amount
		"hunger": left_panel.player.hunger -= amount
		"nerve":  left_panel.player.nerve -= amount

func _can_afford(resource_name: String, amount: int) -> bool:
	match resource_name:
		"energy": return left_panel.player.energy >= amount
		"health": return left_panel.player.health >= amount
		"hunger": return left_panel.player.hunger >= amount
		"nerve":  return left_panel.player.nerve >= amount
		_: return true # unrecognized resource — don't block on something we don't understand

func _on_click_denied(resource_name: String, amount: int) -> void:
	push_warning("Not enough %s to interact (need %d)" % [resource_name, amount])
	# hook for feedback later — flash the slot, play a sound, shake the UI, etc.

# --- Prefix assignment ---

func roll_prefixes(piece: PieceData) -> void:
	piece.mods.clear()   # safe even on a fresh duplicate; avoids stale carryover

	var pool := _pool_for(piece.prefix_pool)
	if pool.is_empty() or piece.prefix_count <= 0:
		return

	piece.loot1 = pool.pick_random()
	piece.mods.append(piece.loot1.prefix_name)

	if piece.prefix_count >= 2:
		piece.loot2 = pool.pick_random()
		if pool.size() > 1:
			while piece.loot2 == piece.loot1:
				piece.loot2 = pool.pick_random()
		piece.mods.append(piece.loot2.prefix_name)

func _pool_for(i: int) -> Array[Prefix]:
	match i:
		1: return prefix_pool_1
		2: return prefix_pool_2
		3: return prefix_pool_3
		_: return []

func fill_prefix_pools():
	#welcome back
	pass
