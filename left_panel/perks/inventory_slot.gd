extends Panel
class_name PlayerSlot

@onready var button: Button = %Button
@onready var icon: TextureRect = %TextureRect

@export var slot_type: player_slot_type

enum player_slot_type {
	ITEM = 0,
	PERK = 1
}

func _ready() -> void:
	pass
