extends Resource
class_name PieceData
@export var name: String
@export var type_id: String # do not change like ever
@export var icons: Array[Texture2D]
@export var health: int
@export var health_max: int
@export var progress: int
@export var progress_max: int
@export var description: String
@export var can_build_on: Array[PieceData]

@export var loot_pool: Array[ItemData]

@export var damage_received:int = 1

@export var destroy_replacements: Array[PieceData] # assign Field, Deer, etc. in the inspector

# --- Prefix / coloring ---
@export var prefix_pool: int = 0   # 0 = none, 1/2/3 = which EffectsManager pool
@export var prefix_count: int = 0  # 0, 1, or 2 colored regions

var mods: Array
var selected_icon: Texture2D
var loot1: Prefix
var loot2: Prefix

func pick_icon() -> void:
	if icons.size() > 0:
		selected_icon = icons[randi() % icons.size()]

func _tick() -> void:
	# When a different piece is clicked.
	pass

func get_click_cost() -> Dictionary:
	return {}

func _click() -> Dictionary:
	return {}

func _complete() -> void:
	# When my progress is complete.
	pass

func _destroy() -> void:
	# When my health is emptied.
	pass


# looting
func pick_loot() -> ItemData:
	if loot_pool.is_empty():
		return null
	return loot_pool[randi() % loot_pool.size()]

func get_prefix_for_region(region: int) -> Prefix:
	var idx := region - 1
	if idx < 0 or idx >= mods.size():
		return null
	return mods[idx] as Prefix



# animation flags
func should_float() -> bool:
	return false

## Override in subclasses to offer a specific replacement pool.
## Empty array = "use the world's default field piece."
func get_destroy_replacements() -> Array[PieceData]:
	return []
