extends MarginContainer
class_name InteractionDisplay

enum Mode {
	UPGRADE,
	BUILD,
	IDLE
}

@onready var upgrade_layout = %UpgradesLayout
@onready var upgrade_slot1 = %Upgrade1
@onready var upgrade_slot2 = %Upgrade2
@onready var upgrade_slot3 = %Upgrade3

@onready var build_layout = %BuildLayout
@onready var build_order = %Order
@onready var build_piece = %PieceName
@onready var build_allowed = %Allowed

var current_mode: Mode = Mode.IDLE

func _ready() -> void:
	set_visibility(current_mode)




func update_display(piece: PieceData, mode: Mode) -> void:
	current_mode = mode
	match current_mode:
		Mode.UPGRADE:
			set_visibility(mode)
			update_upgrade_display(piece)
		Mode.BUILD:
			set_visibility(mode)
			update_build_display(piece)
		Mode.IDLE:
			set_visibility(mode)

func set_visibility(mode: Mode) -> void:
	current_mode = mode
	upgrade_layout.visible = mode == Mode.UPGRADE
	build_layout.visible = mode == Mode.BUILD
	pass

func update_upgrade_display(piece: PieceData) -> void:
	# populate upgrade slots later
	pass

func update_build_display(piece: PieceData) -> void:
	var allowed_list : PackedStringArray = []
	for i in piece.can_build_on:
		allowed_list.append(str(i.type_id))
	build_piece.text = piece.name
	build_allowed.text = ", ".join(allowed_list)
