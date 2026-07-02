extends Node
class_name TurnSystem

## The turn heartbeat. Order per turn: player statuses -> each registered slot
## (statuses BEFORE the piece's _tick) -> item statuses -> dead-source sweep.
## Live entries are {"data": StatusData, "stacks": int, "source": Object|null}.
## MODIFIER entries remember their source; when that source disappears the
## modifier's stat delta is inverted and the entry removed.

@export var world: World
var effects: EffectsManager        # set by GameManager
var inventory: Inventory           # set by GameManager

signal turn_advanced(turn: int)

var turn := 0

var _tickers: Dictionary = {}        # WorldSlot -> true
var _statuses: Dictionary = {}       # WorldSlot -> Array[entry]
var _item_statuses: Dictionary = {}  # ItemData  -> Array[entry]
var _player_statuses: Array = []     # Array[entry]
var _mod_index: Dictionary = {}      # source Object -> Array of {"host_kind","host","entry"}
var _known_piece: Dictionary = {}    # WorldSlot -> PieceData (to know WHO left on piece_changed)

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
		_known_piece[slot] = slot.piece
		_evaluate_slot(slot)

# --- Turn loop ---

func advance_turn() -> void:
	turn += 1
	_tick_player_statuses()
	for slot in _tickers.keys():
		if not is_instance_valid(slot) or slot.piece == null:
			_tickers.erase(slot)
			continue
		_tick_slot(slot)
	_tick_item_statuses()
	_sweep_item_sources()
	turn_advanced.emit(turn)

func _tick_slot(slot: WorldSlot) -> void:
	var piece := slot.piece
	_tick_piece_statuses(slot)                 # statuses fire BEFORE the piece's tick
	if not is_instance_valid(slot) or slot.piece != piece:
		return                                 # a status killed/replaced the host
	if slot.piece.ticks:
		var bundle: Dictionary = slot.piece._tick()
		if not bundle.is_empty():
			effects.apply_effects(bundle.get("effects", []), slot)
			if bundle.get("loot", false):
				effects.grant_loot(slot.piece, slot)

# --- Entry plumbing (shared by all three hosts) ---

# Insert or grow an entry. Returns {"entry": Dictionary, "added": int}.
# STATUS/STATE merge by id alone (source is irrelevant to them). MODIFIER merges
# by (id, source): stackable grows stacks, non-stackable is a same-source no-op,
# and a different source always gets its own side-by-side entry.
func _upsert(list: Array, data: StatusData, stacks: int, source) -> Dictionary:
	var match_source := data.kind == StatusData.Kind.MODIFIER
	for e in list:
		if e.data.id != data.id:
			continue
		if match_source and e.source != source:
			continue
		if data.kind == StatusData.Kind.MODIFIER and not data.stackable:
			return {"entry": e, "added": 0}
		var before: int = e.stacks
		e.stacks = mini(before + stacks, data.max_stacks)
		return {"entry": e, "added": e.stacks - before}
	var added := mini(stacks, data.max_stacks)
	var entry := {"data": data, "stacks": added, "source": source}
	list.append(entry)
	return {"entry": entry, "added": added}

# Fire a MODIFIER's per_stack_effects, scaled by a signed stack delta
# (+added on gain, -stacks on revoke).
func _apply_modifier_delta(data: StatusData, stack_delta: int, host_kind: String, host) -> void:
	if stack_delta == 0:
		return
	for e in data.per_stack_effects:
		var stat: String = e.get("stat", "")
		var amt: int = int(e.get("amount", 0)) * stack_delta
		match host_kind:
			"piece":
				if is_instance_valid(host) and host.piece != null:
					effects.apply_effects([{"stat": stat, "amount": amt, "target": "self"}], host)
			"item":
				var slot = inventory.slot_for_item(host) if inventory != null else null
				if slot != null:
					effects.apply_item_stat_to(slot, stat, amt)
			"player":
				effects.apply_effects([{"stat": stat, "amount": amt, "target": "player"}], null)

func _index_modifier(source, host_kind: String, host, entry) -> void:
	if source == null:
		return   # unowned modifier — permanent until removed by id
	var recs: Array = _mod_index.get(source, [])
	for r in recs:
		if r.entry == entry:
			return
	recs.append({"host_kind": host_kind, "host": host, "entry": entry})
	_mod_index[source] = recs

# Revert + remove every modifier this source granted. Called when the source
# piece leaves its slot or the source item stack vanishes.
func revoke_source(source: Object) -> void:
	if source == null or not _mod_index.has(source):
		return
	var recs: Array = _mod_index[source]
	_mod_index.erase(source)
	for r in recs:
		_remove_entry(r.host_kind, r.host, r.entry)

func _remove_entry(host_kind: String, host, entry) -> void:
	var list = _host_list(host_kind, host)
	if list == null or not list.has(entry):
		return   # host already gone / entry already removed — nothing to revert
	if entry.data.kind == StatusData.Kind.MODIFIER:
		_apply_modifier_delta(entry.data, -entry.stacks, host_kind, host)
	list.erase(entry)
	_store_host_list(host_kind, host, list)

func _host_list(host_kind: String, host):
	match host_kind:
		"piece":
			if not is_instance_valid(host):
				return null
			return _statuses.get(host, null)
		"item":  return _item_statuses.get(host, null)
		"player": return _player_statuses
	return null

func _store_host_list(host_kind: String, host, list: Array) -> void:
	match host_kind:
		"piece":
			if list.is_empty():
				_statuses.erase(host)
			else:
				_statuses[host] = list
			if is_instance_valid(host):
				_evaluate_slot(host)
		"item":
			if list.is_empty():
				_item_statuses.erase(host)
			else:
				_item_statuses[host] = list
		"player":
			_player_statuses = list

# --- Piece hosts ---

func apply_status(slot: WorldSlot, data: StatusData, stacks: int = 1, source: Object = null) -> void:
	if slot == null or data == null or slot.piece == null:
		return
	var list: Array = _statuses.get(slot, [])
	var res := _upsert(list, data, stacks, source)
	_statuses[slot] = list
	_register(slot)
	if res.added == 0:
		return
	Sfx.play(data.apply_sound)
	if data.kind == StatusData.Kind.MODIFIER:
		_index_modifier(source, "piece", slot, res.entry)
		_apply_modifier_delta(data, res.added, "piece", slot)

func remove_status(slot: WorldSlot, id: String) -> void:
	for entry in _statuses.get(slot, []).duplicate():
		if entry.data.id == id:
			_remove_entry("piece", slot, entry)

func _tick_piece_statuses(slot: WorldSlot) -> void:
	var list: Array = _statuses.get(slot, [])
	if list.is_empty():
		return
	var host := slot.piece
	for entry in list.duplicate():
		var data: StatusData = entry.data
		if data.kind != StatusData.Kind.STATUS:
			continue                       # modifiers/states just sit there
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
			return   # host replaced/destroyed mid-tick; piece_changed cleaned up
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

# --- Player host ---

func apply_player_status(data: StatusData, stacks: int = 1, source: Object = null) -> void:
	if data == null:
		return
	var res := _upsert(_player_statuses, data, stacks, source)
	if res.added == 0:
		return
	Sfx.play(data.apply_sound)
	if data.kind == StatusData.Kind.MODIFIER:
		_index_modifier(source, "player", null, res.entry)
		_apply_modifier_delta(data, res.added, "player", null)

func remove_player_status(id: String) -> void:
	for entry in _player_statuses.duplicate():
		if entry.data.id == id:
			_remove_entry("player", null, entry)

func _tick_player_statuses() -> void:
	if _player_statuses.is_empty():
		return
	for entry in _player_statuses.duplicate():
		var data: StatusData = entry.data
		if data.kind != StatusData.Kind.STATUS:
			continue
		Sfx.play(data.tick_sound)
		var scaled: Array = []
		for e in data.per_stack_effects:
			scaled.append({
				"stat": e.get("stat", ""),
				"amount": int(e.get("amount", 0)) * entry.stacks,
				"target": "player",
			})
		effects.apply_effects(scaled, null)
		if data.decays_per_tick:
			entry.stacks -= 1
	var survivors: Array = []
	for entry in _player_statuses:
		if entry.stacks > 0:
			survivors.append(entry)
	_player_statuses = survivors

# --- Item hosts (keyed by ItemData instance, so sorts don't strand them) ---

func apply_item_status(item: ItemData, data: StatusData, stacks: int = 1, source: Object = null) -> void:
	if item == null or data == null:
		return
	var list: Array = _item_statuses.get(item, [])
	var res := _upsert(list, data, stacks, source)
	_item_statuses[item] = list
	if res.added == 0:
		return
	Sfx.play(data.apply_sound)
	if data.kind == StatusData.Kind.MODIFIER:
		_index_modifier(source, "item", item, res.entry)
		_apply_modifier_delta(data, res.added, "item", item)

func remove_item_status(item: ItemData, id: String) -> void:
	for entry in _item_statuses.get(item, []).duplicate():
		if entry.data.id == id:
			_remove_entry("item", item, entry)

func _tick_item_statuses() -> void:
	if _item_statuses.is_empty() or inventory == null:
		return
	for item in _item_statuses.keys():
		var slot := inventory.slot_for_item(item)
		if slot == null:
			_item_statuses.erase(item)   # stack gone (consumed/lost) — sweep it
			continue
		var list: Array = _item_statuses.get(item, [])
		for entry in list.duplicate():
			var data: StatusData = entry.data
			if data.kind != StatusData.Kind.STATUS:
				continue
			Sfx.play(data.tick_sound)
			for e in data.per_stack_effects:
				effects.apply_item_stat_to(slot, e.get("stat", ""), int(e.get("amount", 0)) * entry.stacks)
				if slot.is_empty():
					break
			if slot.is_empty():
				break
			if data.affects_item_count:
				slot.remove_from_stack(data.item_count_per_tick * entry.stacks)
			if data.decays_per_tick:
				entry.stacks -= 1
			if slot.is_empty():
				break
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

# Item stacks can vanish without a signal (consumed, sacrificed). Once per turn,
# revoke any modifiers whose SOURCE item no longer exists in inventory.
func _sweep_item_sources() -> void:
	if inventory == null:
		return
	for source in _mod_index.keys().duplicate():
		if source is ItemData and inventory.slot_for_item(source) == null:
			revoke_source(source)

# --- Queries ---

func _find_status(list: Array, id: String):
	for entry in list:
		if entry.data.id == id:
			return entry
	return null

func has_status(slot: WorldSlot, id: String) -> bool:
	return _find_status(_statuses.get(slot, []), id) != null

func has_item_status(item: ItemData, id: String) -> bool:
	return _find_status(_item_statuses.get(item, []), id) != null

func has_player_status(id: String) -> bool:
	return _find_status(_player_statuses, id) != null

# STATE checks — the "is this flag present" gates other systems test.
func has_state(slot: WorldSlot, id: String) -> bool:
	var e = _find_status(_statuses.get(slot, []), id)
	return e != null and e.data.kind == StatusData.Kind.STATE

func item_has_state(item: ItemData, id: String) -> bool:
	var e = _find_status(_item_statuses.get(item, []), id)
	return e != null and e.data.kind == StatusData.Kind.STATE

func player_has_state(id: String) -> bool:
	var e = _find_status(_player_statuses, id)
	return e != null and e.data.kind == StatusData.Kind.STATE

# Total stacks of an id on a piece (sums side-by-side non-stackable copies).
func stacks_of(slot: WorldSlot, id: String) -> int:
	var total := 0
	for entry in _statuses.get(slot, []):
		if entry.data.id == id:
			total += entry.stacks
	return total

# --- Registry ---

func _on_slot_piece_changed(slot: WorldSlot) -> void:
	var old: PieceData = _known_piece.get(slot, null)
	if old != null and old != slot.piece:
		revoke_source(old)          # modifiers this piece granted elsewhere die with it
	_known_piece[slot] = slot.piece
	_statuses.erase(slot)           # everything ON the departed piece dies with it
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
