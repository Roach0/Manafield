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
	print("click → ", piece.name, " h=", piece.health, " hm=", piece.health_max)   # ← add this
	slot.health = piece.health
	right_panel.update_display(piece)
	if not result.is_empty():
		_apply_effect(result.get("effect", ""), result.get("amount", 0))
	if piece.health_max > 0 and piece.health <= 0:
		piece._destroy()
		world.replace_with(slot, piece)

func _can_afford(resource_name: String, amount: int) -> bool:
	match resource_name:
		"energy": return left_panel.player.energy >= amount
		"health": return left_panel.player.health >= amount
		"hunger": return left_panel.player.hunger >= amount
		"nerve":  return left_panel.player.nerve >= amount
		_: return true # unrecognized resource — don't block on something we don't understand

func _pay_cost(resource_name: String, amount: int) -> void:
	match resource_name:
		"energy": left_panel.player.energy -= amount
		"health": left_panel.player.health -= amount
		"hunger": left_panel.player.hunger -= amount
		"nerve":  left_panel.player.nerve -= amount

func _apply_effect(effect_name: String, amount: int) -> void:
	match effect_name:
		"damage_health": left_panel.player.health -= amount
		"update_energy": left_panel.player.energy += amount
		_: push_warning("Unhandled piece effect: %s" % effect_name)

func _on_click_denied(resource_name: String, amount: int) -> void:
	push_warning("Not enough %s to interact (need %d)" % [resource_name, amount])
	# hook for feedback later — flash the slot, play a sound, shake the UI, etc.

func fill_prefix_pools():
	#welcome back
	pass
