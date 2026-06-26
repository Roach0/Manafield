extends Resource
class_name ItemData

# --- Prefix / coloring ---
# Authored per-item: which colored region of the source piece this item
# inherits. 0 = none, 1 = color_1 region, 2 = color_2 region.
@export_enum("None:0", "Region 1 (color_1):1", "Region 2 (color_2):2") var prefix_region: int = 0

# Filled in at loot time from the source piece. Exported so it survives
# Resource.duplicate() when the item is copied into an inventory slot.
@export var prefix: Prefix

@export var name: String
@export var type_id: String # do not change like ever
@export var icons: Array[Texture2D]
@export var description: String

func _click():
	pass

func _tick():
	pass

func stack_key() -> String:
	if type_id.is_empty():
		return ""
	var pfx := prefix.prefix_name if prefix != null else ""
	return "%s|%s" % [type_id, pfx]

func can_stack_with(other: ItemData) -> bool:
	if other == null:
		return false
	var k := stack_key()
	return k != "" and k == other.stack_key()
