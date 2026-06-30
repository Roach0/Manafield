extends Resource
class_name ItemData

@export_enum("None:0", "Region 1 (color_1):1", "Region 2 (color_2):2") var prefix_region: int = 0

@export var prefix: Prefix
@export var name: String
@export var type_id: String
@export var icons: Array[Texture2D]
@export var description: String

# How many leave the stack each click. 0 = clicking does nothing (inert).
@export var consume_count: int = 1
# What a click produces. Drop item .tres files straight in.
# Want 3 of something? Add it to the list 3 times.
@export var click_yields: Array[ItemData]
# --- Sounds (all optional; leave null for silence) ---
@export_group("Sounds")
@export var hover_sound: SoundEffect
@export var click_sound: SoundEffect
@export var sort_sound: SoundEffect
@export_group("")
func _click():
	pass
func _tick():
	pass
# An item only responds to clicks if it consumes something AND yields something.
func is_usable() -> bool:
	return consume_count > 0 and not click_yields.is_empty()

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
