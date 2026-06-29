extends Node
# Autoload as "Sfx". Fire-and-forget one-shots via a round-robin pool —
# no per-sound allocation, up to pool_size overlapping at once.

@export var pool_size := 12
@export var bus: StringName = &"Master"

var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	for i in pool_size:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_players.append(p)

func play(stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
