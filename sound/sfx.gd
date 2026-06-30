extends Node
# Autoload as "Sfx". Fire-and-forget one-shots via a round-robin pool.

@export var pool_size := 12
@export var bus: StringName = &"Master"

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cycle: Dictionary = {}   # key -> next index, for play_cycle

func _ready() -> void:
	for i in pool_size:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_players.append(p)

func play(sfx: SoundEffect, pitch := 1.0) -> void:
	if sfx == null or sfx.stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = sfx.stream
	p.volume_db = sfx.volume_db
	p.pitch_scale = pitch
	p.play()

# Cycles through `sounds` round-robin, keyed by `key` (index can't live on the
# piece — it's duplicated per tile). Each element is a SoundEffect, so they can
# carry different volumes.
func play_cycle(sounds: Array, key: String, pitch := 1.0) -> void:
	if sounds.is_empty():
		return
	var i: int = _cycle.get(key, 0) % sounds.size()
	_cycle[key] = i + 1
	play(sounds[i], pitch)
