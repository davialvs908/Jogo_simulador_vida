extends Node
## Autoload CaptureService — screenshots without being freed by scene changes.

const OUT := "/cursor/stores/bc-50e278ed-60c1-4fe4-9d73-543366c2b3af/media"
var active := false

func start_capture() -> void:
	if active:
		return
	active = true
	DirAccess.make_dir_recursive_absolute(OUT)
	GameState.clear_save()
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/boot.tscn")
	await get_tree().create_timer(1.0).timeout
	await _shot("01-boot-title.png")
	_click_button("Begin")
	await get_tree().create_timer(0.8).timeout
	await _shot("02-club-intro.png")
	_click_button("Enter pitch")
	await get_tree().create_timer(2.5).timeout
	Input.action_press("move_up")
	await get_tree().create_timer(0.7).timeout
	Input.action_release("move_up")
	Input.action_press("pass_ball")
	await get_tree().process_frame
	Input.action_release("pass_ball")
	await get_tree().create_timer(0.9).timeout
	await _shot("03-match-pitch.png")
	Input.action_press("ui_cancel")
	await get_tree().process_frame
	Input.action_release("ui_cancel")
	await get_tree().create_timer(1.0).timeout
	await _shot("04-match-result.png")
	_click_button("Go to the city")
	await get_tree().create_timer(2.0).timeout
	await _shot("05-city-hub.png")
	Input.action_press("move_right")
	Input.action_press("move_down")
	await get_tree().create_timer(2.6).timeout
	Input.action_release("move_right")
	Input.action_release("move_down")
	Input.action_press("interact")
	await get_tree().process_frame
	Input.action_release("interact")
	await get_tree().create_timer(0.8).timeout
	await _shot("06-hub-interact.png")
	print("CAPTURE_DONE")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	var path := "%s/%s" % [OUT, name]
	img.save_png(path)
	print("wrote ", path)

func _click_button(text: String) -> void:
	for b in _find_buttons(get_tree().root):
		if b is Button and (b as Button).text == text:
			(b as Button).pressed.emit()
			return
	push_warning("Button not found: " + text)

func _find_buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_buttons(c))
	return out
