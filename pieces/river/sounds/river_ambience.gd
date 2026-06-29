extends Resource
class_name RiverAmbience

## River tiles split into two beds by how many river neighbors they have.
## Thin/isolated tiles use stream_sound; tiles deep in a body use shore_sound.
@export var stream_sound: AmbientSound   # babbling — few river neighbors
@export var shore_sound: AmbientSound    # waves on shore — many river neighbors
## A tile counts as "shore/body" at this many river neighbors (of 8 surrounding).
@export var shore_neighbor_threshold: int = 5
