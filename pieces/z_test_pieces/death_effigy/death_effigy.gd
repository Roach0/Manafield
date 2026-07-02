extends PieceData
class_name DeathEffigy


@export var poison_status: StatusData

@export var poison_stacks: int = 2

@export var click_self_damage: int = 1

func _init() -> void:
	ticks = true   # ensure it registers as a ticker even if forgotten in the inspector

func _tick() -> Dictionary:
	if poison_status == null:
		push_warning("%s has no poison_status assigned" % type_id)
		return {}
	return {"effects": [
		{
			"status": poison_status,
			"stacks": poison_stacks,
			"target": {"target": "pieces", "match": "adjacent"},
		},
	]}

func _click() -> Dictionary:
	# Direct self-mutation; EffectsManager's post-click check sees health <= 0
	# and routes through kill_piece (the single death path).
	health -= click_self_damage
	return {}
