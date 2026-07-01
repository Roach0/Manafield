extends Node
class_name TurnSystem

## The turn heartbeat. Each world-slot click advances one turn; on each turn,
## every registered piece runs _tick() plus its statuses, and every status-bearing
## item ticks too. Effects route through EffectsManager. Piece registration is
## driven by each slot's `piece_changed` signal; item statuses are keyed by the
## ItemData instance so they survive inventory sorts.

@export var world: World
var effects: EffectsManager        # set by GameManager
var inventory: Inventory           # set by GameManager (for item-status ticking)

signal turn_advanced(turn: int)

var turn := 0

var _tickers: Dictionary = {}      # WorldSlot -> true (piece.ticks OR has a status)
var _statuses: Dictionary = {}     # WorldSlot -> Array of {"data": StatusData, "stacks": int}
var _item_statuses: Dictionary = {}# ItemData -> Array of {"data": StatusData, "stacks": int}

func bind() -> void:
	if world == null or world.grid == null:
		push_warning("TurnSystem: world not set")
		return
	for child in world.grid.get_children():
		var slot := child as WorldSlot
		if slot == null:
			continue
		if not slot.piece_changed.is_connected(_on_slot_piece_changed):
			slot.piece_changed.connect(_on_slot_piece_changed)
		_evaluate_slot(slot)

# --- Turn loop ---

func advance_turn() -> void:
	turn += 1
	for slot in _tickers.keys():
		if not is_instance_valid(slot) or slot.piece == null:
			_tickers.erase(slot)
			continue
		_tick_slot(slot)
	_tick_item_statuses()
	turn_advanced.emit(turn)

func _tick_slot(slot: WorldSlot) -> void:
	if slot.piece.ticks:
		var bundle: Dictionary = slot.piece._tick()
		if not bundle.is_empty():
			effects.apply_effects(bundle.get("effects", []), slot)
			if bundle.get("loot", false):
				effects.grant_loot(slot.piece, slot)
	_tick_piece_statuses(slot)

# --- Piece statuses ---

func apply_status(slot: WorldSlot, data: StatusData, stacks: int = 1) -> void:
	if slot == null or data == null or slot.piece == null:
		return
	var list: Array = _statuses.get(slot, [])
	var entry = _find_status(list, data.id)
	if entry == null:
		list.append({"data": data, "stacks": min(stacks, data.max_stacks)})
	else:
		entry.stacks = min(entry.stacks + stacks, data.max_stacks)
	_statuses[slot] = list
	Sfx.play(data.apply_sound)
	_register(slot)

func _tick_piece_statuses(slot: WorldSlot) -> void:
	var list: Array = _statuses.get(slot, [])
	if list.is_empty():
		return
	var host := slot.piece
	for entry in list.duplicate():
		var data: StatusData = entry.data
		Sfx.play(data.tick_sound)
		var scaled: Array = []
		for e in data.per_stack_effects:
			scaled.append({
				"stat": e.get("stat", ""),
				"amount": int(e.get("amount", 0)) * entry.stacks,
				"target": "self",
			})
		effects.apply_effects(scaled, slot)
		if not is_instance_valid(slot) or slot.piece != host:
			return   # host replaced/destroyed mid-tick; _on_slot_piece_changed cleared statuses
		if data.decays_per_tick:
			entry.stacks -= 1
	_prune_piece_statuses(slot)

func _prune_piece_statuses(slot: WorldSlot) -> void:
	var survivors: Array = []
	for entry in _statuses.get(slot, []):
		if entry.stacks > 0:
			survivors.append(entry)
	if survivors.is_empty():
		_statuses.erase(slot)
	else:
		_statuses[slot] = survivors
	_evaluate_slot(slot)

# --- Item statuses (keyed by ItemData instance, so sorts don't strand them) ---

func apply_item_status(item: ItemData, data: StatusData, stacks: int = 1) -> void:
	if item == null or data == null:
		return
	var list: Array = _item_statuses.get(item, [])
	var entry = _find_status(list, data.id)
	if entry == null:
		list.append({"data": data, "stacks": min(stacks, data.max_stacks)})
	else:
		entry.stacks = min(entry.stacks + stacks, data.max_stacks)
	_item_statuses[item] = list
	Sfx.play(data.apply_sound)

func _tick_item_statuses() -> void:
	if _item_statuses.is_empty() or inventory == null:
		return
	# Snapshot keys: applying count changes can empty a slot and drop the item.
	for item in _item_statuses.keys():
		var slot := inventory.slot_for_item(item)
		if slot == null:
			_item_statuses.erase(item)   # stack gone (consumed/lost) — sweep it
			continue
		var list: Array = _item_statuses.get(item, [])
		for entry in list.duplicate():
			var data: StatusData = entry.data
			Sfx.play(data.tick_sound)
			# Per-stack stat effects on THIS specific stack (e.g. drain `value`).
			# Applied straight to the host slot — item statuses are per-instance,
			# which the all/type_id/prefix target vocabulary can't express.
			for e in data.per_stack_effects:
				effects.apply_item_stat_to(slot, e.get("stat", ""), int(e.get("amount", 0)) * entry.stacks)
				if slot.is_empty():
					break
			if slot.is_empty():
				break
			if data.affects_item_count:
				var drain = data.item_count_per_tick * entry.stacks
				slot.remove_from_stack(drain)
			if data.decays_per_tick:
				entry.stacks -= 1
			if slot.is_empty():
				break   # whole stack drained away; nothing left to afflict
		if slot.is_empty():
			_item_statuses.erase(item)
		else:
			_prune_item_statuses(item)

func _prune_item_statuses(item: ItemData) -> void:
	var survivors: Array = []
	for entry in _item_statuses.get(item, []):
		if entry.stacks > 0:
			survivors.append(entry)
	if survivors.is_empty():
		_item_statuses.erase(item)
	else:
		_item_statuses[item] = survivors

# --- Shared ---

func _find_status(list: Array, id: String):
	for entry in list:
		if entry.data.id == id:
			return entry
	return null

func has_status(slot: WorldSlot, id: String) -> bool:
	return _find_status(_statuses.get(slot, []), id) != null

func has_item_status(item: ItemData, id: String) -> bool:
	return _find_status(_item_statuses.get(item, []), id) != null

# --- Registry (pieces only; items aren't slot-registered) ---

func _on_slot_piece_changed(slot: WorldSlot) -> void:
	_statuses.erase(slot)
	_evaluate_slot(slot)

func _evaluate_slot(slot: WorldSlot) -> void:
	var ticks := slot.piece != null and slot.piece.ticks
	var has_stat = not _statuses.get(slot, []).is_empty()
	if ticks or has_stat:
		_register(slot)
	else:
		_unregister(slot)

func _register(slot: WorldSlot) -> void:
	_tickers[slot] = true

func _unregister(slot: WorldSlot) -> void:
	_tickers.erase(slot)
