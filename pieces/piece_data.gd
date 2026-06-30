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
# --- Turn behavior ---
@export var ticks: bool = false    # true => _tick() runs every turn (registers as a ticker)
# --- Ambient audio ---
@export var ambient: AmbientSound          # optional; leave null for silent tiles
@export var river_ambience: RiverAmbience  # rivers only; if set, `ambient` is ignored
# --- One-shot SFX (all optional; leave null/empty for silence) ---
@export_group("Sounds")
@export var hover_sounds: Array[SoundEffect]
@export var click_sounds: Array[SoundEffect]
@export var destroy_sound: SoundEffect
@export var complete_sound: SoundEffect
@export var tick_sounds: Array[SoundEffect]
@export var build_sound: SoundEffect       # player places it in build mode
@export var spawn_sound: SoundEffect       # appears dynamically (replacement / spawned)
@export_group("")
var mods: Array
var selected_icon: Texture2D
var loot1: Prefix
var loot2: Prefix
func pick_icon() -> void:
	if icons.size() > 0:
		selected_icon = icons[randi() % icons.size()]
# Runs every turn IF `ticks` is true. Same return shape as _click():
#   {"effects": [{"stat","amount","target"}, ...], "loot": bool}
# Use this for global emitters (target groups) or per-turn self behavior.
func _tick() -> Dictionary:
	return {}
# Cost to click. List of {"stat","amount"}; player pays each. [] = free.
func get_click_cost() -> Array:
	return []
# What clicking does. Mutate SELF here to drive destruction; the return is the
# player-facing payout: {"effects":[{"stat","amount","target"}...], "loot":bool}
func _click() -> Dictionary:
	return {}
func _complete() -> Dictionary:
	# Fires when progress fills; progress then resets (carrying overflow), so this
	# is a repeatable cycle. "self" targets this piece (it stays after completing).
	return {}
func _destroy() -> Dictionary:
	# Effects to fire on death. Same bundle shape as _click/_tick.
	# "self" targets the DYING piece (resolved before replacement).
	return {}
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
# True if any of this piece's rolled prefixes is named `prefix_name`.
func has_prefix(prefix_name: String) -> bool:
	for m in mods:
		if m != null and m.prefix_name == prefix_name:
			return true
	return false
# animation flags
func should_float() -> bool:
	return false
## Override in subclasses to offer a specific replacement pool.
## Empty array = "use the world's default field piece."
func get_destroy_replacements() -> Array[PieceData]:
	return []
