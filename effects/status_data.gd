extends Resource
class_name StatusData
## Authored template for a persistent effect. One class covers all three kinds;
## `kind` decides how TurnSystem treats the live entry. Live per-host entries
## (stacks, source) live in TurnSystem — this resource is shared across hosts.

enum Kind {
	MODIFIER,  ## stat delta applied once on gain, INVERTED when its source is removed
	STATUS,    ## re-applies per_stack_effects every turn (poison, regen, ...)
	STATE,     ## pure presence flag (invincible); no stat math, only queried
}

@export var kind: Kind = Kind.STATUS
@export var id: String                  # "poison" — identity for stacking/removal/queries
@export var display_name: String

## MODIFIER: applied once per stack when gained, inverted on removal.
## STATUS:   applied to the HOST each tick, multiplied by current stacks.
## STATE:    ignored entirely.
## Array of {"stat": String, "amount": int} dictionaries.
@export var per_stack_effects: Array = []
@export var max_stacks: int = 99

## MODIFIER only. true  = re-application from the SAME source grows this entry's
## stacks (up to max). false = fixed single instance per (id, source): same-source
## re-application is a no-op; copies from OTHER sources coexist as separate entries.
@export var stackable: bool = true

## STATUS only: lose one stack after each tick (poison counting down). False = persists.
@export var decays_per_tick: bool = true

## STATUS on an item host: does this drain the stack count over time?
## Pieces ignore this — they use stat effects. MODIFIER/STATE ignore it too.
@export var affects_item_count: bool = true
## Drain per tick, per status-stack, when affects_item_count is true.
@export var item_count_per_tick: int = 1

@export var apply_sound: SoundEffect
@export var tick_sound: SoundEffect

## The one place effect shape is resolved — TurnSystem reads through this, never
## the field directly, so the authoring format can change without touching it.
func get_per_stack_effects() -> Array:
	return per_stack_effects
