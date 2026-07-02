extends PieceData
class_name DeathEffigy
## Standing hazard. Every turn it poisons its 4 neighbors (2 stacks each).
## Clicking it chips its own health so the player can dig it out; death routes
## through the normal kill_piece path (destroy_replacements, _destroy bundle).

## Drag poison.tres in here.
@export var poison_status: StatusData

## Stacks applied to each adjacent piece per tick.
@export var poison_stacks: int = 2

## Damage the pit takes per click.
@export var click_self_damage: int = 1

func _init() -> void:
	ticks = true   # ensure it registers as a ticker even if forgotten in the inspector

func _tick() -> Dictionary:
	if poison_status == null:
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
