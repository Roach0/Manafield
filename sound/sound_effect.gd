extends Resource
class_name SoundEffect

## A one-shot sound with its own volume. Wrap a clip so each SFX can be
## balanced independently — mirrors AmbientSound.volume_db for the ambient beds.
@export var stream: AudioStream
@export var volume_db: float = 0.0
