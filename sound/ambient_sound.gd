extends Resource
class_name AmbientSound

## A shared ambient bed (water, wind, birds…). Put the SAME resource on every
## piece that should emit it. Proximity to the *nearest* emitting tile drives
## volume + stereo pan. One looping player is spawned per resource, not per tile.
@export var stream: AudioStream
## Distance in tiles at which the bed is full volume (this close or closer).
@export var near_tiles: float = 0.5
## Distance in tiles at which it fades to silence; beyond this the player pauses.
@export var far_tiles: float = 6.0
## Volume (dB) at full proximity.
@export var volume_db: float = 0.0
## Fade shape: 1 = linear, >1 = stays loud then drops off, <1 = drops fast.
@export var falloff: float = 1.6
## Cap so a source never sits 100% in one ear. 0 = mono, 1 = full pan.
@export_range(0.0, 1.0) var max_pan: float = 0.85
## Bus the auto-created panner routes into.
@export var bus: StringName = &"Master"
