extends HBoxContainer
class_name EffectsManager

@onready var world: World = %World
@onready var right_panel: RightPanel = %RightPanel
@onready var left_panel: LeftPanel = %LeftPanel
@export var prefix_pool_1: Array[Prefix]
@export var prefix_pool_2: Array[Prefix]
@export var prefix_pool_3: Array[Prefix]
var _loot_overlay: CanvasLayer

var _hovered_piece: PieceData   # SFX: tracks current hover for the tick sound
var _last_inv_item: ItemData    # SFX: last hovered inventory item, for its exit sound

func _ready() -> void:
	world.update_display.connect(_on_update_display)
	world.piece_click_requested.connect(_on_piece_click_requested)
	left_panel.inventory.yield_flight_requested.connect(_on_yield_flight_requested)
	left_panel.inventory.sort_flight_requested.connect(_on_sort_flight_requested)
	left_panel.inventory.item_hovered.connect(_on_inventory_item_hovered)




# core

func _apply_stat_effect(effect_name: String, amount: int) -> void:
	match effect_name:
		# player stats
		"update_health": left_panel.player.health += amount
		"update_energy": left_panel.player.energy += amount
		"update_hunger": left_panel.player.hunger += amount
		"update_nerve": left_panel.player.nerve += amount
		_: push_warning("Unhandled piece effect: %s" % effect_name)



# Queries

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




# Prefix assignment

func roll_prefixes(piece: PieceData) -> void:
	piece.mods.clear()
	var pool := _pool_for(piece.prefix_pool)
	if pool.is_empty() or piece.prefix_count <= 0:
		return
	piece.loot1 = pool.pick_random()
	piece.mods.append(piece.loot1)
	if piece.prefix_count >= 2:
		piece.loot2 = pool.pick_random()
		if pool.size() > 1:
			while piece.loot2 == piece.loot1:
				piece.loot2 = pool.pick_random()
		piece.mods.append(piece.loot2)

func _pool_for(i: int) -> Array[Prefix]:
	match i:
		1: return prefix_pool_1
		2: return prefix_pool_2
		3: return prefix_pool_3
		_: return []

func fill_prefix_pools():
	#welcome back
	pass


# Handlers

func _on_update_display(piece: PieceData) -> void:
	right_panel.update_display(piece)
	Sfx.play_cycle(piece.hover_sounds, piece.type_id + ":hover")   # SFX: hover (cycles)
	_hovered_piece = piece                                         # SFX: remember for tick

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
	Sfx.play_cycle(piece.click_sounds, piece.type_id + ":click")   # SFX: click (cycles, after affordability)
	slot.health = piece.health
	right_panel.update_display(piece)
	if not result.is_empty():
		_apply_stat_effect(result.get("effect", ""), result.get("amount", 0))
		if result.get("loot", false):
			_grant_loot(piece, slot)
	if piece.health_max > 0 and piece.health <= 0:
		Sfx.play(piece.destroy_sound)   # SFX: destroy (single, before swap)
		piece._destroy()
		world.replace_with(slot, piece)

func _on_yield_flight_requested(item: ItemData, from_slot: InventorySlot, to_slot: InventorySlot) -> void:
	_fly_item(item, from_slot.icon, to_slot)

func _on_click_denied(resource_name: String, amount: int) -> void:
	push_warning("Not enough %s to interact (need %d)" % [resource_name, amount])
	# hook for feedback later — flash the slot, play a sound, shake the UI, etc.
	# SFX: a "denied" buzz would go here, e.g. Sfx.play(denied_sound)

func _on_inventory_item_hovered(item: ItemData) -> void:
	if item != null:
		right_panel.update_item_display(item)
		if item != _last_inv_item:
			Sfx.play(item.hover_sound)            # SFX: item hover enter
		_last_inv_item = item
	else:
		right_panel.clear_display()
		if _last_inv_item != null:
			Sfx.play(_last_inv_item.sort_sound)   # SFX: item hover exit (shares the sort sound)
		_last_inv_item = null

# SFX: call this from wherever a turn advances (e.g. GameManager when
# remaining_turns decrements). Plays only the hovered tile's tick, not all ~168.
func _on_game_ticked() -> void:
	if _hovered_piece:
		Sfx.play_cycle(_hovered_piece.tick_sounds, _hovered_piece.type_id + ":tick")   # SFX: tick (cycles)

func _grant_loot(piece: PieceData, world_slot: WorldSlot) -> void:
	var item := piece.pick_loot()
	if item == null:
		return
	if item.prefix_region > 0:
		item = item.duplicate()
		item.prefix = piece.get_prefix_for_region(item.prefix_region)
	print("[loot] %s | region=%d | prefix=%s | from=%s" % [
		item.name,
		item.prefix_region,
		item.prefix.prefix_name if item.prefix != null else "<none>",
		piece.name,
	])
	var target := left_panel.claim_loot_slot(item)
	if target == null:
		# claim_slot_for returns null both when the inventory is full AND while a
		# sort is rebuilding the grid. Distinguish the two: defer during a sort
		# (it'll be added the instant the sort ends), only warn on a real full.
		if left_panel.inventory.is_sorting():
			left_panel.inventory.defer_add(item)
		else:
			push_warning("Inventory full — loot lost")
		return
	_fly_loot(item, world_slot, target)

func _fly_loot(item: ItemData, from_slot: WorldSlot, to_slot: InventorySlot) -> void:
	_fly_item(item, from_slot.icon, to_slot)

# Slot-agnostic arc: flies `item` from any source icon into an inventory slot.
func _fly_item(item: ItemData, from_icon: TextureRect, to_slot: InventorySlot, on_land: Callable = Callable()) -> void:
	var tex: Texture2D = item.icons[0] if not item.icons.is_empty() else from_icon.texture
	var src_size: Vector2 = from_icon.size
	if src_size == Vector2.ZERO and tex:
		src_size = tex.get_size()

	var dest_icon: TextureRect = to_slot.icon
	var dest_size: Vector2 = dest_icon.size
	if dest_size == Vector2.ZERO:
		dest_size = src_size

	var flier := TextureRect.new()
	flier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flier.texture = tex
	flier.stretch_mode = TextureRect.STRETCH_SCALE
	flier.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flier.size = src_size
	flier.pivot_offset = src_size * 0.5
	flier.modulate = item.prefix.color if item.prefix else Color.WHITE
	_ensure_overlay().add_child(flier)

	var start := from_icon.global_position + src_size * 0.5
	var end := to_slot.global_position + to_slot.size * 0.5

	var end_scale := (dest_size / src_size) if src_size != Vector2.ZERO else Vector2.ONE

	var vary := -1.0 if randf() < 0.5 else 1.0
	var dir_to_end := (end - start).normalized()
	var ctrl := start + Vector2(0.0, 70.0 * vary) + dir_to_end * 22.0

	var set_center := func(t: float) -> void:
		var c := _qbezier(start, ctrl, end, t)
		flier.global_position = c - flier.size * 0.5
	set_center.call(0.0)

	var land := func() -> void:
		if on_land.is_valid():
			on_land.call()
		else:
			left_panel.commit_loot(to_slot, item)
		flier.queue_free()

	var tw := create_tween()
	tw.tween_method(set_center, 0.0, 1.0, 0.40)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(flier, "scale", end_scale, 0.40)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(land)

func _qbezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)

func _ensure_overlay() -> CanvasLayer:
	if is_instance_valid(_loot_overlay):
		return _loot_overlay
	_loot_overlay = CanvasLayer.new()
	_loot_overlay.layer = 100
	get_tree().root.add_child(_loot_overlay)
	return _loot_overlay

func _on_sort_flight_requested(item: ItemData, count: int, from_slot: InventorySlot, to_slot: InventorySlot) -> void:
	var inv := left_panel.inventory
	var land := func() -> void:
		inv.place_sorted(to_slot, item, count)
		Sfx.play(item.sort_sound, randf_range(0.94, 1.06))   # SFX: sort — random pitch so the cluster shuffles
	# from_slot may equal to_slot for an unmoved-but-resorted item; still flies.
	_fly_item(item, from_slot.icon, to_slot, land)
