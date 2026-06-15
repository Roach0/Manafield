extends Panel
class_name RightPanel

@onready var info_display: InfoDisplay = %InfoDisplay
@onready var upgrades: Upgrades = %Upgrades


func _ready() -> void:
	pass


func update_display(piece):
	info_display.update(piece) # "if" piece in just a sec to make this force between updating and clearing if null.
