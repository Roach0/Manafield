extends Panel
class_name LeftPanel

@onready var player := %Player

func _ready() -> void:
	pass

func set_new_player():
	
	player.max_health = 10
	player.health = 10
	player.max_energy = 10
	player.energy = 10
	player.max_hunger = 10
	player.hunger = 10
	player.max_nerve = 10
	player.nerve = 10
