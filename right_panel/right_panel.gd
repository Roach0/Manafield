extends Panel
class_name RightPanel

@onready var info_display: InfoDisplay = %InfoDisplay
@onready var interaction_display: InteractionDisplay = %InteractionDisplay

# info display, not interaction, update names later
func update_display(piece: PieceData):
	info_display.update(piece)

# interaction display stuff

func update_item_display(item: ItemData):
	info_display.update_item(item)

func clear_display():
	info_display.clear()

func update_build_display(piece: PieceData):
	interaction_display.update_display(piece, InteractionDisplay.Mode.BUILD)
