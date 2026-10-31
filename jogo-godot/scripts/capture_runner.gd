extends Node

func _ready() -> void:
	# Kick autoload capture after tree is ready
	await get_tree().process_frame
	CaptureService.start_capture()
