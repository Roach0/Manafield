extends HBoxContainer
class_name EffectsManager

@onready var world: World = %World
@onready var right_panel: RightPanel = %RightPanel
@onready var left_panel: LeftPanel = %LeftPanel
@export var prefix_pool_1: Array[Prefix]
@export var prefix_pool_2: Array[Prefix]
@export var prefix_pool_3: Array[Prefix]
var _loot_overlay: CanvasLayer

var turn_system: TurnSystem     # set by GameManager (mutual link)
var _hovered_piece: PieceData
var _last_inv_item: ItemData

# Match kinds that need the firing slot's coordinate to resolve. Everything else
# is a per-piece predicate that doesn't care where the source is.
const SPATIAL_MATCHES := ["adjacent", "within", "row", "column", "nearest", "random"]

func _ready() -> void:
	world.update_display.connect(_on_update_display)
	world.piece_click_requested.connect(_on_piece_click_requested)
	left_panel.inventory.yield_flight_requested.connect(_on_yield_flight_requested)
	left_panel.inventory.sort_flight_requested.connect(_on_sort_flight_requested)
	left_panel.inventory.item_hovered.connect(_on_inventory_item_hovered)
	left_panel.inventory.sacrifice_requested.connect(_on_sacrifice_requested)


# === Effect application ======================================================
# An effect entry is either a stat change or a status application; both carry an
# optional `target` (default = player). `self_slot` resolves target "self" and
# anchors any spatial match.
func apply_effects(effects_list: Array, self_slot: WorldSlot = null) -> void:
	for e in effects_list:
		var recipients := resolve_targets(e.get("target", "player"), self_slot)
		if e.has("status"):
			for r in recipients:
				_apply_status_to(r, e.get("status"), int(e.get("stacks", 1)))
		elif e.has("stat"):
			var stat: String = e.get("stat", "")
			var amount: int = int(e.get("amount", 0))
			for r in recipients:
				_apply_stat_to(r, stat, amount)

# Resolve a target spec into recipients: {"kind":"player"/"piece"/"item","obj":...}.
# Specs: "player" | "self"
#      | {"target":"pieces", ...}  (see _resolve_piece_targets — incl. spatial)
#      | {"target":"items",  "match":"all"/"type_id"/"prefix","value":X}
#      | {"target":"player"}
func resolve_targets(spec, self_slot: WorldSlot) -> Array:
	if spec == null or spec is String:
		if spec == "self":
			return [] if self_slot == null else [{"kind": "piece", "obj": self_slot}]
		return [{"kind": "player", "obj": null}]
	var domain: String = spec.get("target", "pieces")
	if domain == "pieces":
		return _resolve_piece_targets(spec, self_slot)
	elif domain == "items":
		var match_kind: String = spec.get("match", "all")
		var value = spec.get("value", null)
		var out: Array = []
		for slot in left_panel.inventory.slots:
			if slot.is_empty():
				continue
			if _item_matches(slot.item_data, match_kind, value):
				out.append({"kind": "item", "obj": slot})
		return out
	elif domain == "player":
		return [{"kind": "player", "obj": null}]
	return []

# All occupied board slots, in grid child order.
func _occupied_piece_slots() -> Array[WorldSlot]:
	var out: Array[WorldSlot] = []
	for child in world.grid.get_children():
		var slot := child as WorldSlot
		if slot != null and slot.piece != null:
			out.append(slot)
	return out

# Resolve a {"target":"pieces", ...} spec.
#
# Non-spatial (unchanged): "all" / "type_id" / "prefix" — a per-piece predicate.
#
# Spatial (NEW): anchored on `self_slot.grid_pos`, so valid only where a source
# slot exists (_click/_tick/_complete/_destroy). With no source (e.g. an item
# sacrifice) a spatial match warns and resolves to nothing rather than guessing.
#   "adjacent"  [+ "diagonals":true]        4 (or 8) neighbors
#   "within"    "value":N [+ "metric":"manhattan"]   box (or diamond) radius N
#   "row" / "column"                        source's row / column
#   "nearest"                               closest other tile(s); all ties
#   "random"    [+ "value":K]               1 (or up to K) random other tiles
# Modifiers on any spatial match:
#   "include_self":true   row/column/within may also hit the source
#   "type_id":<id> / "prefix":<name>   narrow the pool first (e.g. adjacent TREES)
func _resolve_piece_targets(spec: Dictionary, self_slot: WorldSlot) -> Array:
	var match_kind: String = spec.get("match", "all")
	var candidates := _occupied_piece_slots()

	if not SPATIAL_MATCHES.has(match_kind):
		var value = spec.get("value", null)
		var out: Array = []
		for slot in candidates:
			if _piece_matches(slot.piece, match_kind, value):
				out.append({"kind": "piece", "obj": slot})
		return out

	if self_slot == null:
		push_warning("Spatial match '%s' has no source slot; no effect." % match_kind)
		return []

	# Narrow by optional type_id/prefix BEFORE geometry, so "nearest tree" picks
	# among trees rather than picking the nearest tile then discarding it.
	var pool: Array[WorldSlot] = []
	for slot in candidates:
		if _piece_passes_filter(slot.piece, spec):
			pool.append(slot)

	var origin: Vector2i = self_slot.grid_pos
	var include_self: bool = bool(spec.get("include_self", false))
	var hits: Array[WorldSlot] = []

	match match_kind:
		"adjacent":
			var diag := bool(spec.get("diagonals", false))
			for slot in pool:
				if slot == self_slot:
					continue
				var d := slot.grid_pos - origin
				var ok := (maxi(absi(d.x), absi(d.y)) == 1) if diag else (absi(d.x) + absi(d.y) == 1)
				if ok:
					hits.append(slot)
		"within":
			var n := int(spec.get("value", 1))
			var manhattan := String(spec.get("metric", "chebyshev")) == "manhattan"
			for slot in pool:
				if slot == self_slot and not include_self:
					continue
				var d := slot.grid_pos - origin
				var dist := (absi(d.x) + absi(d.y)) if manhattan else maxi(absi(d.x), absi(d.y))
				if dist <= n:
					hits.append(slot)
		"row":
			for slot in pool:
				if slot == self_slot and not include_self:
					continue
				if slot.grid_pos.y == origin.y:
					hits.append(slot)
		"column":
			for slot in pool:
				if slot == self_slot and not include_self:
					continue
				if slot.grid_pos.x == origin.x:
					hits.append(slot)
		"nearest":
			hits = _nearest_in(pool, self_slot)
		"random":
			hits = _random_in(pool, self_slot, int(spec.get("value", 1)), include_self)

	var out: Array = []
	for slot in hits:
		out.append({"kind": "piece", "obj": slot})
	return out

# Optional secondary filter on a spatial query. Absent keys = no constraint, so a
# bare spatial spec still matches every occupied tile in range.
func _piece_passes_filter(p: PieceData, spec: Dictionary) -> bool:
	if spec.has("type_id") and p.type_id != spec.get("type_id"):
		return false
	if spec.has("prefix") and not p.has_prefix(spec.get("prefix")):
		return false
	return true

# Closest tile(s) to the source by Chebyshev distance. ALL ties are returned, so
# a "nearest" query carries no hidden RNG. Source is excluded.
func _nearest_in(pool: Array[WorldSlot], self_slot: WorldSlot) -> Array[WorldSlot]:
	var origin: Vector2i = self_slot.grid_pos
	var best := -1
	var winners: Array[WorldSlot] = []
	for slot in pool:
		if slot == self_slot:
			continue
		var d := slot.grid_pos - origin
		var dist := maxi(absi(d.x), absi(d.y))
		if best == -1 or dist < best:
			best = dist
			winners = [slot]
		elif dist == best:
			winners.append(slot)
	return winners

# Up to `count` distinct random tiles. Source excluded unless include_self. The
# one spatial mode with intentional randomness.
func _random_in(pool: Array[WorldSlot], self_slot: WorldSlot, count: int, include_self: bool) -> Array[WorldSlot]:
	var bag: Array[WorldSlot] = []
	for slot in pool:
		if slot == self_slot and not include_self:
			continue
		bag.append(slot)
	bag.shuffle()
	var k := clampi(count, 0, bag.size())
	var out: Array[WorldSlot] = []
	for i in k:
		out.append(bag[i])
	return out

func _piece_matches(p: PieceData, kind: String, value) -> bool:
	match kind:
		"all":     return true
		"type_id": return p.type_id == value
		"prefix":  return p.has_prefix(value)
		_:         return false

func _item_matches(it: ItemData, kind: String, value) -> bool:
	match kind:
		"all":     return true
		"type_id": return it.type_id == value
		"prefix":  return it.prefix != null and it.prefix.prefix_name == value
		_:         return false

func _apply_stat_to(recipient: Dictionary, stat: String, amount: int) -> void:
	match recipient.kind:
		"player": _apply_player_stat(stat, amount)
		"piece":  _apply_piece_stat(recipient.obj, stat, amount)
		"item":   _apply_item_stat(recipient.obj, stat, amount)

func _apply_player_stat(stat: String, amount: int) -> void:
	match stat:
		"health": left_panel.player.health += amount
		"energy": left_panel.player.energy += amount
		"hunger": left_panel.player.hunger += amount
		"nerve":  left_panel.player.nerve += amount
		_: push_warning("Unhandled player stat: %s" % stat)

func _apply_piece_stat(slot: WorldSlot, stat: String, amount: int) -> void:
	var p := slot.piece
	if p == null:
		return
	match stat:
		"health":   p.health += amount
		"progress": p.progress += amount
		_:
			push_warning("Unhandled piece stat: %s" % stat)
			return
	slot.health = p.health
	if p.progress_max > 0:                          # <-- the guard block
		var safety := 0
		while p.progress >= p.progress_max and slot.piece == p and safety < 100:
			p.progress -= p.progress_max
			complete_piece(slot, p)
			safety += 1
	if p.health_max > 0 and p.health <= 0:
		kill_piece(slot, p)

func _apply_item_stat(slot: InventorySlot, stat: String, amount: int) -> void:
	match stat:
		"count":
			if amount >= 0:
				slot.add_to_stack(amount)
			else:
				slot.remove_from_stack(-amount)
		"value":
			if slot.item_data != null:
				slot.item_data.value += amount
		_: push_warning("Unhandled item stat: %s" % stat)

# Apply a stat to ONE specific item slot. Item statuses are per-instance, and the
# all/type_id/prefix target vocabulary can't address a single stack, so the item
# status tick path calls this directly instead of routing through resolve_targets.
# Reuses the same applier — no parallel logic.
func apply_item_stat_to(slot: InventorySlot, stat: String, amount: int) -> void:
	if slot == null or slot.is_empty():
		return
	_apply_item_stat(slot, stat, amount)

func _apply_status_to(recipient: Dictionary, status: StatusData, stacks: int) -> void:
	match recipient.kind:
		"piece": turn_system.apply_status(recipient.obj, status, stacks)
		"item":  turn_system.apply_item_status(recipient.obj.item_data, status, stacks)
		_: push_warning("Statuses can't apply to %s" % recipient.kind)


# === Costs ===================================================================
func _pay_cost(stat: String, amount: int) -> void:
	match stat:
		"energy": left_panel.player.energy -= amount
		"health": left_panel.player.health -= amount
		"hunger": left_panel.player.hunger -= amount
		"nerve":  left_panel.player.nerve -= amount

func _can_afford(stat: String, amount: int) -> bool:
	match stat:
		"energy": return left_panel.player.energy >= amount
		"health": return left_panel.player.health >= amount
		"hunger": return left_panel.player.hunger >= amount
		"nerve":  return left_panel.player.nerve >= amount
		_: return true

func _can_afford_all(costs: Array) -> bool:
	var totals := {}
	for c in costs:
		var stat: String = c.get("stat", "")
		totals[stat] = int(totals.get(stat, 0)) + int(c.get("amount", 0))
	for stat in totals:
		if not _can_afford(stat, totals[stat]):
			return false
	return true

func _pay_all(costs: Array) -> void:
	for c in costs:
		_pay_cost(c.get("stat", ""), int(c.get("amount", 0)))


# === Prefix assignment =======================================================
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
	pass


# === Handlers ================================================================
func _on_update_display(piece: PieceData) -> void:
	right_panel.update_display(piece)
	Sfx.play_cycle(piece.hover_sounds, piece.type_id + ":hover")
	_hovered_piece = piece

func _on_piece_click_requested(slot: WorldSlot) -> void:
	var piece := slot.piece
	if piece == null:
		return
	var costs: Array = piece.get_click_cost()
	if not _can_afford_all(costs):
		_on_click_denied(costs)
		return
	_pay_all(costs)
	var result: Dictionary = piece._click()
	Sfx.play_cycle(piece.click_sounds, piece.type_id + ":click")
	slot.health = piece.health
	right_panel.update_display(piece)
	if not result.is_empty():
		apply_effects(result.get("effects", []), slot)
		if result.get("loot", false):
			grant_loot(piece, slot)
	if slot.piece == piece and piece.health_max > 0 and piece.health <= 0:
		kill_piece(slot, piece)
	_broadcast_click(slot, piece)          # reactions resolve before the world ticks
	turn_system.advance_turn()

func _on_yield_flight_requested(item: ItemData, from_slot: InventorySlot, to_slot: InventorySlot) -> void:
	_fly_item(item, from_slot.icon, to_slot)

func _on_click_denied(costs: Array) -> void:
	push_warning("Click denied — can't afford: %s" % str(costs))
	# SFX: a "denied" buzz would go here.

func _on_inventory_item_hovered(item: ItemData) -> void:
	if item != null:
		right_panel.update_item_display(item)
		_last_inv_item = item
	else:
		right_panel.clear_display()
		_last_inv_item = null

# Plays the hovered tile's tick sound. GameManager calls this on turn_advanced.
func play_hovered_tick() -> void:
	if _hovered_piece:
		Sfx.play_cycle(_hovered_piece.tick_sounds, _hovered_piece.type_id + ":tick")

func grant_loot(piece: PieceData, world_slot: WorldSlot) -> void:
	# One drop event now rolls a tiered table: guaranteed common (if non-empty)
	# plus independent uncommon/rare chance rolls — so 0–3 items can land. Each
	# is claimed and flown separately; same-kind items fold into one stack.
	for template in piece.roll_loot():
		if template == null:
			continue
		var item := template
		if item.prefix_region > 0:
			item = item.duplicate()
			item.prefix = piece.get_prefix_for_region(item.prefix_region)
		var target := left_panel.claim_loot_slot(item)
		if target == null:
			if left_panel.inventory.is_sorting():
				left_panel.inventory.defer_add(item)
			else:
				push_warning("Inventory full — loot lost")
			continue
		_fly_loot(item, world_slot, target)

func _fly_loot(item: ItemData, from_slot: WorldSlot, to_slot: InventorySlot) -> void:
	_fly_item(item, from_slot.icon, to_slot)

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
		Sfx.play(item.sort_sound, randf_range(0.94, 1.06))
	_fly_item(item, from_slot.icon, to_slot, land)

func _on_sacrifice_requested(item: ItemData, count: int, slot: InventorySlot) -> void:
	var bundle: Dictionary = item._sacrifice(count)
	if not bundle.is_empty():
		apply_effects(bundle.get("effects", []), null)

# The single death path — both the click-damage and effect-damage sites call this.
func kill_piece(slot: WorldSlot, piece: PieceData) -> void:
	if slot.piece != piece:
		return                          # stale reference; this slot already moved on
	if slot.get_meta("dying", false):
		return                          # already mid-death; don't re-enter
	slot.set_meta("dying", true)
	Sfx.play(piece.destroy_sound)
	var bundle: Dictionary = piece._destroy()
	if not bundle.is_empty():
		apply_effects(bundle.get("effects", []), slot)
		if bundle.get("loot", false):
			grant_loot(piece, slot)
	world.replace_with(slot, piece)
	slot.set_meta("dying", false)

# The single completion path. Progress has already been decremented by one bar
# before this is called, so completion effects resolve against a piece that's no
# longer "full" — meaning a self-progress effect here won't infinitely re-trigger.
func complete_piece(slot: WorldSlot, piece: PieceData) -> void:
	Sfx.play(piece.complete_sound)
	var bundle: Dictionary = piece._complete()
	if not bundle.is_empty():
		apply_effects(bundle.get("effects", []), slot)
		if bundle.get("loot", false):
			grant_loot(piece, slot)

# Let every reactor respond to this click. Snapshot first: a reaction can kill
# or replace pieces mid-broadcast, and newly-spawned pieces shouldn't react to
# the click that created them. The clicked slot is excluded — a piece reacting
# to its own click is just _click().
func _broadcast_click(clicked_slot: WorldSlot, clicked_piece: PieceData) -> void:
	for slot in _occupied_piece_slots():
		if slot == clicked_slot:
			continue
		var reactor := slot.piece
		if reactor == null or not reactor.reacts_to_clicks:
			continue
		var bundle: Dictionary = reactor._react_click(clicked_piece)
		if bundle.is_empty():
			continue
		if slot.piece != reactor:
			continue   # an earlier reaction replaced this piece mid-broadcast
		apply_effects(bundle.get("effects", []), slot)
		if bundle.get("loot", false):
			grant_loot(reactor, slot)
