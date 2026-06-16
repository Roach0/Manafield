extends MarginContainer
class_name World

@export var slot_scene: PackedScene
@export var piece_data_list: Array[PieceData]
@export var river_piece_data: PieceData


@onready var grid: GridContainer = %WorldSlots

signal update_display(piece)

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


# note: river path is generated, but returns an array of coordinates that form a path
# from one edge of the map to another, these are used as reference for tile laying during generation.
func generate_river_path() -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	
	# Pick two different edges (0=top, 1=bottom, 2=left, 3=right)
	var edge_a := randi() % 4
	var edge_b := randi() % 4
	while edge_b == edge_a or (edge_b == 1 - edge_a) == false and abs(edge_b - edge_a) != 1:
		# Ensure edges aren't the same; opposite edges also fine, adjacent is fine too
		# Actually let's just prevent same edge only:
		edge_b = randi() % 4
		if edge_b != edge_a:
			break
	
	var start := _random_edge_point(edge_a)
	var end   := _random_edge_point(edge_b)
	
	var current := start
	path.append(current)
	
	var max_steps := 169  # safety cap
	var steps := 0
	
	while current != end and steps < max_steps:
		steps += 1
		var dx: int = sign(end.x - current.x)
		var dy: int = sign(end.y - current.y)
		
		# Build weighted candidate list — bias toward goal, allow drift
		var candidates: Array[Vector2i] = []
		
		if dx != 0:
			candidates.append(Vector2i(current.x + dx, current.y))
			candidates.append(Vector2i(current.x + dx, current.y))  # double weight
		if dy != 0:
			candidates.append(Vector2i(current.x, current.y + dy))
			candidates.append(Vector2i(current.x, current.y + dy))  # double weight
		# Occasional lateral drift
		candidates.append(Vector2i(current.x + 1, current.y))
		candidates.append(Vector2i(current.x - 1, current.y))
		candidates.append(Vector2i(current.x, current.y + 1))
		candidates.append(Vector2i(current.x, current.y - 1))
		
		# Shuffle and pick first valid, unvisited, in-bounds candidate
		candidates.shuffle()
		var moved := false
		for candidate in candidates:
			if _in_bounds(candidate) and not path.has(candidate):
				current = candidate
				path.append(current)
				moved = true
				break
		
		if not moved:
			break  # Stuck — shouldn't happen often with 13x13
	
	# Make sure we actually reach the end cell
	if not path.has(end):
		path.append(end)
	
	return path

# also generated, this is used to select a random point along one of the maps edges.
func _random_edge_point(edge: int) -> Vector2i:
	# Leave corners free — start from column/row 1..11
	var pos := 1 + randi() % 11
	match edge:
		0: return Vector2i(pos, 0)       # top
		1: return Vector2i(pos, 12)      # bottom
		2: return Vector2i(0, pos)       # left
		3: return Vector2i(12, pos)      # right
	return Vector2i(0, 0)

# this is an easy check to maintain boundries in case a point exceeds the map dimension i intend.
func _in_bounds(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < 13 and coord.y >= 0 and coord.y < 13
