extends Node
## Automated capture for media/01-06. Run:
## godot --path /agent/jogo-godot --script res://scripts/screenshot_tour.gd
## Prefer launching scenes via a dedicated runner scene instead.

const OUT := "/cursor/stores/bc-50e278ed-60c1-4fe4-9d73-543366c2b3af/media"

func _ready() -> void:
	print("Use capture_runner.tscn for screenshots")
	get_tree().quit()
