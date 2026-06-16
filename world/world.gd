extends MarginContainer
class_name World

@export var slot_scene: PackedScene
@export var piece_data_list: Array[PieceData]
@export var river_piece_data: PieceData

@onready var grid: GridContainer = %WorldSlots

signal update_display(piece)
signal build_mode_started
signal piece_placed(piece_data)
signal build_mode_ended

var _build_queue: Array[PieceData] = []
var _in_build_mode := false

func _ready() -> void:
	pass

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
			slot.set_piece(river_data)
		else:
			var piece_data := piece_data_list[randi() % piece_data_list.size()]
			var data := piece_data.duplicate() as PieceData
			slot.set_piece(data)
		
		slot.update_display.connect(func(piece): update_display.emit(piece))
		slot.clicked.connect(_on_slot_clicked.bind(slot))

# --- Build Mode ---

func begin_build_mode(pieces: Array[PieceData]) -> void:
	if pieces.is_empty():
		return
	_build_queue = pieces.duplicate()
	_in_build_mode = true
	build_mode_started.emit()

func _on_slot_clicked(slot: WorldSlot) -> void:
	if not _in_build_mode:
		return
	
	var next_piece: PieceData = _build_queue.front()
	
	# placement validation hook — expand this as needed
	if not _can_place(next_piece, slot):
		return
	
	var data := next_piece.duplicate() as PieceData
	slot.set_piece(data)
	piece_placed.emit(data)
	
	_build_queue.pop_front()
	
	if _build_queue.is_empty():
		_in_build_mode = false
		build_mode_ended.emit()

func _can_place(incoming: PieceData, slot: WorldSlot) -> bool:
	# stub — add type checks here later, e.g.:
	# if slot.piece.type == "river": return false
	# if incoming.requires_flat and slot.piece.type != "flat": return false
	return true

# --- River Generation ---

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

func _in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < 13 and coord.y >= 0 and coord.y < 13
