extends RefCounted
class_name LootRoll

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
