extends Panel
class_name Player

@export var max_health: int = 100:
	set(value):
		max_health = value
		_update_max(health_bar, max_health)
		health = health # re-clamp current value against new max

@export var max_energy: int = 100:
	set(value):
		max_energy = value
		_update_max(energy_bar, max_energy)
		energy = energy

@export var max_hunger: int = 100:
	set(value):
		max_hunger = value
		_update_max(hunger_bar, max_hunger)
		hunger = hunger

@export var max_nerve: int = 100:
	set(value):
		max_nerve = value
		_update_max(nerve_bar, max_nerve)
		nerve = nerve

@export var health: int = 100:
	set(value):
		health = clamp(value, 0, max_health)
		_update_bar(health_bar, health_label, health)

@export var energy: int = 100:
	set(value):
		energy = clamp(value, 0, max_energy)
		_update_bar(energy_bar, energy_label, energy)

@export var hunger: int = 100:
	set(value):
		hunger = clamp(value, 0, max_hunger)
		_update_bar(hunger_bar, hunger_label, hunger)

@export var nerve: int = 100:
	set(value):
		nerve = clamp(value, 0, max_nerve)
		_update_bar(nerve_bar, nerve_label, nerve)

@onready var health_bar := %Health
@onready var health_label: RichTextLabel = %HealthLabel
@onready var hunger_bar := %Hunger
@onready var hunger_label: RichTextLabel = %HungerLabel
@onready var energy_bar := %Energy
@onready var energy_label: RichTextLabel = %EnergyLabel
@onready var nerve_bar := %Nerve
@onready var nerve_label: RichTextLabel = %NerveLabel

func _ready() -> void:
	# Force a sync now that nodes exist, in case exported values
	# were applied before @onready vars resolved.
	_update_max(health_bar, max_health)
	_update_max(energy_bar, max_energy)
	_update_max(hunger_bar, max_hunger)
	_update_max(nerve_bar, max_nerve)
	_update_bar(health_bar, health_label, health)
	_update_bar(energy_bar, energy_label, energy)
	_update_bar(hunger_bar, hunger_label, hunger)
	_update_bar(nerve_bar, nerve_label, nerve)

func _update_bar(bar: ProgressBar, label: RichTextLabel, value: int) -> void:
	if bar == null:
		return
	bar.value = value
	if label:
		label.text = str(value)

func _update_max(bar: ProgressBar, value: int) -> void:
	if bar == null:
		return
	bar.max_value = value
