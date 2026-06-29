extends Node
class_name AmbientAudio

## Proximity-driven ambient beds for the world grid. Reads each slot's
## piece.ambient; for every distinct bed it finds the nearest emitting tile to
## the mouse and sets that bed's volume + pan. One looping player per bed,
## however many tiles carry it. Decoupled from WorldSlot — it only *reads*.

@export var world: World                 # drag your %World node here in the inspector
@export var rescan_interval := 0.25      # how often to re-learn tile→bed mapping
@export var smoothing := 10.0            # higher = volume/pan chase faster

class _Bed:
	var sound: AmbientSound
	var player: AudioStreamPlayer
	var bus_idx: int
	var positions: PackedVector2Array     # global centres of emitting tiles
	var cur_db := -80.0
	var cur_pan := 0.0

var _beds: Dictionary = {}                # AmbientSound -> _Bed
var _tile_px := 0.0
var _rescan_timer := 0.0
var _bus_counter := 0

func _ready() -> void:
	if world == null:
		push_warning("AmbientAudio: assign 'world' (drag your World node).")
	call_deferred("rebuild")   # let the grid lay out first

func rebuild() -> void:
	if world == null or world.grid == null:
		return
	for bed: _Bed in _beds.values():
		bed.positions = PackedVector2Array()
	for child in world.grid.get_children():
		var slot := child as WorldSlot
		if slot == null or slot.piece == null:
			continue
		var snd: AmbientSound = slot.piece.ambient
		if snd == null:
			continue
		if _tile_px <= 0.0 and slot.size.x > 0.0:
			_tile_px = slot.size.x
		var centre := slot.global_position + slot.size * 0.5
		var bed: _Bed = _beds.get(snd)
		if bed == null:
			bed = _make_bed(snd)
			_beds[snd] = bed
		bed.positions.push_back(centre)

func _make_bed(snd: AmbientSound) -> _Bed:
	var bed := _Bed.new()
	bed.sound = snd
	bed.bus_idx = _make_panner_bus(snd.bus)
	var p := AudioStreamPlayer.new()
	p.stream = snd.stream
	p.bus = AudioServer.get_bus_name(bed.bus_idx)
	p.volume_db = -80.0
	_force_loop(p.stream)
	add_child(p)
	p.play()
	p.stream_paused = true    # silent until the mouse comes near
	bed.player = p
	return bed

func _make_panner_bus(send_to: StringName) -> int:
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Amb_%d" % _bus_counter)
	_bus_counter += 1
	var target := send_to if AudioServer.get_bus_index(send_to) != -1 else &"Master"
	AudioServer.set_bus_send(idx, target)
	AudioServer.add_bus_effect(idx, AudioEffectPanner.new())
	return idx

func _force_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true

func _process(delta: float) -> void:
	if world == null:
		return
	_rescan_timer -= delta
	if _rescan_timer <= 0.0:
		_rescan_timer = rescan_interval
		rebuild()
	if _beds.is_empty() or _tile_px <= 0.0:
		return

	var mouse := world.get_global_mouse_position()
	var t := 1.0 - exp(-smoothing * delta)   # fps-independent smoothing

	for bed: _Bed in _beds.values():
		var target_db := -80.0
		var target_pan := 0.0
		if bed.positions.size() > 0:
			var nearest: Vector2 = bed.positions[0]
			var best := mouse.distance_squared_to(nearest)
			for i in range(1, bed.positions.size()):
				var d := mouse.distance_squared_to(bed.positions[i])
				if d < best:
					best = d
					nearest = bed.positions[i]
			var dist_tiles := sqrt(best) / _tile_px
			var gain := _gain_for(bed.sound, dist_tiles)
			if gain > 0.0:
				target_db = bed.sound.volume_db + linear_to_db(gain)
				var far_px := bed.sound.far_tiles * _tile_px
				var dx := (nearest.x - mouse.x) / far_px
				target_pan = clampf(dx, -1.0, 1.0) * bed.sound.max_pan

		bed.cur_db = lerpf(bed.cur_db, target_db, t)
		bed.cur_pan = lerpf(bed.cur_pan, target_pan, t)
		bed.player.volume_db = bed.cur_db
		(AudioServer.get_bus_effect(bed.bus_idx, 0) as AudioEffectPanner).pan = bed.cur_pan

		# pause when effectively silent; resume when it climbs back
		var audible := bed.cur_db > -60.0
		if bed.player.stream_paused and audible:
			bed.player.stream_paused = false
		elif not bed.player.stream_paused and not audible and target_db <= -80.0:
			bed.player.stream_paused = true

func _gain_for(snd: AmbientSound, dist_tiles: float) -> float:
	if dist_tiles <= snd.near_tiles:
		return 1.0
	if dist_tiles >= snd.far_tiles:
		return 0.0
	var n := (dist_tiles - snd.near_tiles) / (snd.far_tiles - snd.near_tiles)
	return pow(1.0 - n, snd.falloff)
