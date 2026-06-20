extends MarginContainer
class_name World

@export var slot_scene: PackedScene
@export var piece_data_list: Array[PieceData]
@export var river_piece_data: PieceData
@export var field_piece_data: PieceData # default replace for removed pieces
@export var required_pieces: Array[PieceData]

@onready var grid: GridContainer = %WorldSlots

signal update_display(piece)
signal build_mode_started
signal build_queue_advanced(piece: PieceData)
signal piece_placed(piece_data)
signal build_mode_ended
signal piece_click_requested(slot: WorldSlot)

var _build_queue: Array[PieceData] = []
var _in_build_mode := false
var effects: EffectsManager   # set by GameManager before generate_world()

func _ready() -> void:
	pass


func _on_slot_clicked(slot: WorldSlot) -> void:
	if not _in_build_mode:
		piece_click_requested.emit(slot)
		return

	var next_piece: PieceData = _build_queue.front()
	if not _can_place(next_piece, slot):
		return

	var data := next_piece.duplicate() as PieceData
	if effects:
		effects.roll_prefixes(data)
	slot.set_piece(data)
	piece_placed.emit(data, null)

	_build_queue.pop_front()
	if _build_queue.is_empty():
		_in_build_mode = false
		build_mode_ended.emit()
	else:
		build_queue_advanced.emit(_build_queue.front())

# interaction level
func replace_with(slot: WorldSlot, destroyed_piece: PieceData) -> void:
	var pool := destroyed_piece.get_destroy_replacements()
	var source: PieceData = field_piece_data
	if not pool.is_empty():
		source = pool[randi() % pool.size()]
	var data := source.duplicate() as PieceData
	if effects:
		effects.roll_prefixes(data)
	slot._swap_piece(data)

func _in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < 13 and coord.y >= 0 and coord.y < 13

func _get_slot_at(coord: Vector2i) -> WorldSlot:
	var index := coord.y * 13 + coord.x
	return grid.get_child(index) as WorldSlot

# --- Building ---

func begin_build_mode(pieces: Array[PieceData]) -> void:
	if pieces.is_empty():
		return
	_build_queue = pieces.duplicate()
	_in_build_mode = true
	build_mode_started.emit()
	build_queue_advanced.emit(_build_queue.front())

func _can_place(incoming: PieceData, slot: WorldSlot) -> bool:
	return incoming.can_build_on.any(func(p): return p.type_id == slot.piece.type_id)
	# gonna expand to do adjacency and presence checks later.

# --- World Gen ---

func generate_world() -> void:
	var river_path := generate_river_path()
	
	for i in 169:
		var col := i % 13
		var row := i / 13
		var coord := Vector2i(col, row)
		
		var slot := slot_scene.instantiate() as WorldSlot
		grid.add_child(slot)
		
		if river_path.has(coord):
			var river_data := river_piece_data.duplicate() as PieceData
			if effects:
				effects.roll_prefixes(river_data)
			slot.set_piece(river_data)
		else:
			var piece_data := piece_data_list[randi() % piece_data_list.size()]
			var data := piece_data.duplicate() as PieceData
			if effects:
				effects.roll_prefixes(data)
			slot.set_piece(data)
		
		slot.update_display.connect(func(piece): update_display.emit(piece))
		slot.clicked.connect(_on_slot_clicked.bind(slot))
	
	# Place each required piece into a unique non-river slot
	var available_slots: Array[WorldSlot] = []
	for child in grid.get_children():
		var slot := child as WorldSlot
		if slot and slot.piece.type_id != river_piece_data.type_id:
			available_slots.append(slot)
	available_slots.shuffle()
	
	for i in required_pieces.size():
		if i >= available_slots.size():
			push_warning("Not enough non-river slots for all required_pieces!")
			break
		var data := required_pieces[i].duplicate() as PieceData
		if effects:
			effects.roll_prefixes(data)
		available_slots[i].set_piece(data)

func generate_river_path() -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	
	var edge_a := randi() % 4
	var edge_b := randi() % 4
	while edge_b == edge_a or (edge_b == 1 - edge_a) == false and abs(edge_b - edge_a) != 1:
		edge_b = randi() % 4
		if edge_b != edge_a:
			break
	
	var start := _random_edge_point(edge_a)
	var end   := _random_edge_point(edge_b)
	
	var current := start
	path.append(current)
	
	var max_steps := 169
	var steps := 0
	
	while current != end and steps < max_steps:
		steps += 1
		var dx: int = sign(end.x - current.x)
		var dy: int = sign(end.y - current.y)
		
		var candidates: Array[Vector2i] = []
		
		if dx != 0:
			candidates.append(Vector2i(current.x + dx, current.y))
			candidates.append(Vector2i(current.x + dx, current.y))
		if dy != 0:
			candidates.append(Vector2i(current.x, current.y + dy))
			candidates.append(Vector2i(current.x, current.y + dy))
		candidates.append(Vector2i(current.x + 1, current.y))
		candidates.append(Vector2i(current.x - 1, current.y))
		candidates.append(Vector2i(current.x, current.y + 1))
		candidates.append(Vector2i(current.x, current.y - 1))
		
		candidates.shuffle()
		var moved := false
		for candidate in candidates:
			if _in_bounds(candidate) and not path.has(candidate):
				current = candidate
				path.append(current)
				moved = true
				break
		
		if not moved:
			break
	
	if not path.has(end):
		path.append(end)
	
	return path

func _random_edge_point(edge: int) -> Vector2i:
	var pos := 1 + randi() % 11
	match edge:
		0: return Vector2i(pos, 0)
		1: return Vector2i(pos, 12)
		2: return Vector2i(0, pos)
		3: return Vector2i(12, pos)
	return Vector2i(0, 0)
