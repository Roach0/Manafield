extends Resource
class_name ItemData
# --- Prefix / coloring ---
@export_enum("None:0", "Region 1 (color_1):1", "Region 2 (color_2):2") var prefix_region: int = 0
@export var prefix: Prefix
@export var name: String
@export var type_id: String # do not change like ever
@export var icons: Array[Texture2D]
@export var description: String
# --- Value ---
# Authored worth of this item. Statuses can raise/lower it at runtime via the
# `value` stat; _sacrifice() can read it to decide its payout.
@export var value: int = 0
# --- Click / consumption ---
@export var consume_count: int = 1
@export var click_yields: Array[ItemData]
# --- Sounds ---
@export_group("Sounds")
@export var hover_sound: SoundEffect
@export var click_sound: SoundEffect
@export var sort_sound: SoundEffect
@export var sacrifice_sound: SoundEffect   # plays when the whole stack is sacrificed
@export_group("")
func _click():
	pass
func _tick():
	pass
# Whole stack sacrificed (held to fill the meter, released to confirm). Return
# the same bundle shape as PieceData: {"effects":[{"stat","amount","target"}...]}.
# `count` is how many were in the stack; read it if you want value × count.
func _sacrifice(count: int) -> Dictionary:
	return {}
func is_usable() -> bool:
	return consume_count > 0 and not click_yields.is_empty()
# --- Stacking identity ---
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
func has_prefix(prefix_name: String) -> bool:
	return prefix != null and prefix.prefix_name == prefix_name
