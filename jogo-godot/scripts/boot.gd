extends Control
## Tela inicial: Continuar carreira / Nova carreira.

var confirm_btn: Button
var fresh_btn: Button

func _ready() -> void:
	GameState.load_game()
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(root)
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(620, 0)
	center.add_theme_constant_override("separation", 12)
	root.add_child(center)

	var title := Label.new()
	title.text = "JOGO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	center.add_child(title)

	var sub := Label.new()
	sub.text = "Carreira de futebol e vida real.\nTreine, jogue, renove o contrato, mude de liga, cuide da Maya e da sua fortuna.\nFutebol original. Sem clubes licenciados."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)

	var has_save := GameState.has_save()
	if has_save:
		var stats := Label.new()
		stats.text = GameState.career_summary_text()
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		center.add_child(stats)
		var cont := Button.new()
		cont.text = "Continuar carreira"
		cont.pressed.connect(_on_continue)
		center.add_child(cont)
		fresh_btn = Button.new()
		fresh_btn.text = "Nova carreira (apaga o save)"
		fresh_btn.pressed.connect(_on_fresh_ask)
		center.add_child(fresh_btn)
	else:
		var begin := Button.new()
		begin.text = "Nova carreira"
		begin.pressed.connect(_on_new)
		center.add_child(begin)

func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")

func _on_new() -> void:
	get_tree().change_scene_to_file("res://scenes/club.tscn")

func _on_fresh_ask() -> void:
	# confirmação em dois passos para não apagar o save sem querer
	fresh_btn.text = "Confirmar: apagar tudo e recomeçar"
	fresh_btn.pressed.disconnect(_on_fresh_ask)
	fresh_btn.pressed.connect(_on_fresh)

func _on_fresh() -> void:
	GameState.clear_save()
	get_tree().change_scene_to_file("res://scenes/club.tscn")
