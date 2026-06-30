extends Resource
class_name StatusData

## Authored template for a status (poison, regen, …). Live per-host stacks live
## in TurnSystem, not here — this is shared across every host.
@export var id: String                  # "poison" — identity for stacking/removal
@export var display_name: String
## Applied to the HOST each tick, multiplied by current stacks. Same
## {"stat","amount"} shape as everything else; target is implicitly the host.
@export var per_stack_effects: Array = []
@export var max_stacks: int = 99
## Lose one stack after each tick (poison counting down). False = persists.
@export var decays_per_tick: bool = true
## On an item host, does this status reduce the stack count over time, or is it
## inert (a pure tag, e.g. "blessed")? Pieces ignore this — they use stat effects.
@export var affects_item_count: bool = true
## How much to drain from an item stack per tick, per status-stack, when
## affects_item_count is true. Pieces ignore this.
@export var item_count_per_tick: int = 1
@export var apply_sound: SoundEffect
@export var tick_sound: SoundEffect
