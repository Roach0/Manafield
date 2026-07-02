extends PieceData
class_name Harvester
## Rolls its own loot table into the inventory whenever a matching piece is
## clicked anywhere on the board. What it "harvests" = its loot_common/
## uncommon/rare arrays — author those on the resource.
##
## Prefix handling: absorbed prefixes from the piece it was built on live in
## `stored_prefixes`, NOT in mods/loot1/loot2 — so the harvester itself is never
## colored, never matches prefix-targeted effects, and adopts no prefix behavior.
## get_prefix_for_region is overridden so yielded items pull from the stored
## pool instead.

## type_id that triggers a harvest (e.g. "field"). Empty = react to EVERY click.
@export var harvest_trigger_type: String = ""

## Prefixes absorbed at build time. Runtime state, not authored.
var stored_prefixes: Array = []

func _init() -> void:
	reacts_to_clicks = true

func _react_click(clicked: PieceData) -> Dictionary:
	if harvest_trigger_type != "" and clicked.type_id != harvest_trigger_type:
		return {}
	return {"loot": true}

# Loot inheritance reads through this (grant_loot calls it per item with
# prefix_region > 0). Redirect region lookups to the stored pool.
func get_prefix_for_region(region: int) -> Prefix:
	var idx := region - 1
	if idx < 0 or idx >= stored_prefixes.size():
		return null
	return stored_prefixes[idx] as Prefix
