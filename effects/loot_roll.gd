extends RefCounted
class_name LootRoll
## Shared tiered-drop roller for piece loot (PieceData.roll_loot) and item yields
## (ItemData.roll_yields). One central place so both stay identical.
##
## Common always contributes one random pick WHEN NON-EMPTY. Uncommon and rare
## each roll their own percent chance (0–100); on success, each contributes one
## random pick from its OWN array. So a single event returns 0–3 item templates,
## depending on contents and rolls.
##
## An empty common array is the idiom for "percent chance to drop anything at
## all": with no guaranteed common, the event only produces something when an
## uncommon or rare roll succeeds.
##
## Returns raw templates (shared .tres references). Callers do their own
## per-item post-processing (prefix inheritance, duplicate-on-commit), exactly
## as before — this only decides WHICH templates drop, not how they're minted.

static func roll(
		common: Array[ItemData],
		uncommon: Array[ItemData], uncommon_chance: float,
		rare: Array[ItemData], rare_chance: float) -> Array[ItemData]:
	var out: Array[ItemData] = []
	if not common.is_empty():
		out.append(common[randi() % common.size()])
	if not uncommon.is_empty() and _hits(uncommon_chance):
		out.append(uncommon[randi() % uncommon.size()])
	if not rare.is_empty() and _hits(rare_chance):
		out.append(rare[randi() % rare.size()])
	return out

## True with `percent` (0–100) probability. Clamped: <= 0 never fires, >= 100
## always fires, so the exposed chance is safe at either extreme.
static func _hits(percent: float) -> bool:
	if percent <= 0.0:
		return false
	if percent >= 100.0:
		return true
	return randf() * 100.0 < percent
