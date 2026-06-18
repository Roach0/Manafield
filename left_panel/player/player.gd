extends Panel
class_name Player

@export var max_health: int = 100:
	set(value):
		max_health = value
		_update_max(health_bar, max_health)
		_update_value_label(health_value_label, health, max_health)
		health = health # re-clamp current value against new max

@export var max_energy: int = 100:
	set(value):
		max_energy = value
		_update_max(energy_bar, max_energy)
		_update_value_label(energy_value_label, energy, max_energy)
		energy = energy

@export var max_hunger: int = 100:
	set(value):
		max_hunger = value
		_update_max(hunger_bar, max_hunger)
		_update_value_label(hunger_value_label, hunger, max_hunger)
		hunger = hunger

@export var max_nerve: int = 100:
	set(value):
		max_nerve = value
		_update_max(nerve_bar, max_nerve)
		_update_value_label(nerve_value_label, nerve, max_nerve)
		nerve = nerve

@export var health: int = 100:
	set(value):
		health = clamp(value, 0, max_health)
		_update_bar(health_bar, health)
		_update_value_label(health_value_label, health, max_health)

@export var energy: int = 100:
	set(value):
		energy = clamp(value, 0, max_energy)
		_update_bar(energy_bar, energy)
		_update_value_label(energy_value_label, energy, max_energy)

@export var hunger: int = 100:
	set(value):
		hunger = clamp(value, 0, max_hunger)
		_update_bar(hunger_bar, hunger)
		_update_value_label(hunger_value_label, hunger, max_hunger)

@export var nerve: int = 100:
	set(value):
		nerve = clamp(value, 0, max_nerve)
		_update_bar(nerve_bar, nerve)
		_update_value_label(nerve_value_label, nerve, max_nerve)

@onready var health_bar := %Health
@onready var health_label: RichTextLabel = %HealthLabel       # name tag, static
@onready var health_value_label: RichTextLabel = %HealthLabel2 # 0/100 display

@onready var energy_bar := %Energy
@onready var energy_label: RichTextLabel = %EnergyLabel
@onready var energy_value_label: RichTextLabel = %EnergyLabel2

@onready var hunger_bar := %Hunger
@onready var hunger_label: RichTextLabel = %HungerLabel
@onready var hunger_value_label: RichTextLabel = %HungerLabel2

@onready var nerve_bar := %Nerve
@onready var nerve_label: RichTextLabel = %NerveLabel
@onready var nerve_value_label: RichTextLabel = %NerveLabel2

func _ready() -> void:
	# Set the static name labels once.
	health_label.text = "Health"
	energy_label.text = "Energy"
	hunger_label.text = "Hunger"
	nerve_label.text = "Nerve"

	# Force a full sync now that nodes exist, in case exported values
	# were applied before @onready vars resolved.
	_update_max(health_bar, max_health)
	_update_max(energy_bar, max_energy)
	_update_max(hunger_bar, max_hunger)
	_update_max(nerve_bar, max_nerve)
	_update_bar(health_bar, health)
	_update_bar(energy_bar, energy)
	_update_bar(hunger_bar, hunger)
	_update_bar(nerve_bar, nerve)
	_update_value_label(health_value_label, health, max_health)
	_update_value_label(energy_value_label, energy, max_energy)
	_update_value_label(hunger_value_label, hunger, max_hunger)
	_update_value_label(nerve_value_label, nerve, max_nerve)

func _update_bar(bar: ProgressBar, value: int) -> void:
	if bar == null:
		return
	bar.target_value = value

func _update_max(bar: ProgressBar, value: int) -> void:
	if bar == null:
		return
	bar.max_value = value

func _update_value_label(label: RichTextLabel, current: int, max_value: int) -> void:
	if label == null:
		return
	label.text = "%d/%d" % [current, max_value]
