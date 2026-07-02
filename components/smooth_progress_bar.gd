extends ProgressBar
class_name SmoothProgressBar

@export var fill_time := 0.25
@export var trans := Tween.TRANS_CUBIC
@export var ease_type := Tween.EASE_OUT

var _tween: Tween

## Set this instead of `value` to get an animated fill.
var target_value: float:
	set(v):
		v = clampf(v, min_value, max_value)
		if _tween and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "value", v, fill_time)\
			.set_trans(trans)\
			.set_ease(ease_type)
	get:
		return value

## Jump instantly with no animation (e.g. on first setup / new piece).
func set_instant(v: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	value = clampf(v, min_value, max_value)
