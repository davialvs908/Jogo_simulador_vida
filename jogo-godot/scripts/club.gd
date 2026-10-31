extends Control
## Início de carreira: nome, posição, aparência, liga e clube.

const CareerSquad = preload("res://scripts/career_squad.gd")

var name_edit: LineEdit
var league_opt: OptionButton
var club_opt: OptionButton
var pos_opt: OptionButton
var skin_opt: OptionButton
var hair_opt: OptionButton
var hair_color_opt: OptionButton
var skin_swatch: ColorRect
var hair_swatch: ColorRect
var info: Label
var player_info: Label

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(1280, 0)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(root)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_theme_constant_override("separation", 10)
	root.add_child(box)

	var title := Label.new()
	title.text = "Crie seu jogador"
	title.add_theme_font_size_override("font_size", 36)
	box.add_child(title)

	box.add_child(_label("Nome"))
	name_edit = LineEdit.new()
	name_edit.text = GameState.player_name
	name_edit.max_length = 24
	name_edit.text_changed.connect(func (_t): _update_player())
	box.add_child(name_edit)

	box.add_child(_label("Posição"))
	pos_opt = OptionButton.new()
	for i in CareerSquad.POSITIONS.size():
		var p: String = CareerSquad.POSITIONS[i]
		pos_opt.add_item("%s — %s" % [p, CareerSquad.POS_NAMES[p]], i)
	pos_opt.select(maxi(0, CareerSquad.POSITIONS.find(GameState.player_pos)))
	pos_opt.item_selected.connect(func (_i): _update_player())
	box.add_child(pos_opt)

	var look := GridContainer.new()
	look.columns = 3
	look.add_theme_constant_override("h_separation", 10)
	box.add_child(look)
	look.add_child(_label("Pele"))
	look.add_child(_label("Cabelo"))
	look.add_child(_label("Cor do cabelo"))
	var r1 := HBoxContainer.new()
	skin_opt = OptionButton.new()
	for i in GameState.LOOK_SKIN_NAMES.size():
		skin_opt.add_item(GameState.LOOK_SKIN_NAMES[i], i)
	skin_opt.select(clampi(GameState.look_skin, 0, GameState.LOOK_SKIN_NAMES.size() - 1))
	skin_swatch = ColorRect.new()
	skin_swatch.custom_minimum_size = Vector2(24, 24)
	r1.add_child(skin_opt)
	r1.add_child(skin_swatch)
	look.add_child(r1)
	hair_opt = OptionButton.new()
	for i in GameState.LOOK_HAIR_NAMES.size():
		hair_opt.add_item(GameState.LOOK_HAIR_NAMES[i], i)
	hair_opt.select(clampi(GameState.look_hair, 0, GameState.LOOK_HAIR_NAMES.size() - 1))
	look.add_child(hair_opt)
	var r3 := HBoxContainer.new()
	hair_color_opt = OptionButton.new()
	for i in GameState.LOOK_HAIR_COLOR_NAMES.size():
		hair_color_opt.add_item(GameState.LOOK_HAIR_COLOR_NAMES[i], i)
	hair_color_opt.select(clampi(GameState.look_hair_color, 0, GameState.LOOK_HAIR_COLOR_NAMES.size() - 1))
	hair_swatch = ColorRect.new()
	hair_swatch.custom_minimum_size = Vector2(24, 24)
	r3.add_child(hair_color_opt)
	r3.add_child(hair_swatch)
	look.add_child(r3)
	skin_opt.item_selected.connect(func (_i): _update_player())
	hair_opt.item_selected.connect(func (_i): _update_player())
	hair_color_opt.item_selected.connect(func (_i): _update_player())

	player_info = Label.new()
	player_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(player_info)

	box.add_child(_label("Liga (12 disponíveis)"))
	league_opt = OptionButton.new()
	for i in Leagues.count():
		var d: Dictionary = Leagues.DATA[i]
		league_opt.add_item("%s — %s" % [d.name, d.region], i)
	league_opt.item_selected.connect(_on_league)
	box.add_child(league_opt)

	box.add_child(_label("Clube"))
	club_opt = OptionButton.new()
	club_opt.item_selected.connect(func (_i): _update_info())
	box.add_child(club_opt)

	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)

	var coach := Label.new()
	coach.text = "WASD move · Shift sprint · J passe · K chute. Treine, jogue bem, renove ou mude de clube, e construa sua vida na cidade."
	coach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(coach)

	var row := HBoxContainer.new()
	box.add_child(row)
	var go := Button.new()
	go.text = "Começar carreira"
	go.pressed.connect(_start)
	row.add_child(go)
	var back := Button.new()
	back.text = "Voltar"
	back.pressed.connect(func (): get_tree().change_scene_to_file("res://scenes/boot.tscn"))
	row.add_child(back)

	league_opt.select(GameState.league_id)
	_on_league(GameState.league_id)
	_update_player()

func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l

func _pos() -> String:
	return CareerSquad.POSITIONS[maxi(0, pos_opt.selected)]

func _pname() -> String:
	var n := name_edit.text.strip_edges()
	return n if n != "" else "Jogador"

func _update_player() -> void:
	skin_swatch.color = GameState.LOOK_SKINS[skin_opt.selected]
	hair_swatch.color = GameState.LOOK_HAIR_COLORS[hair_color_opt.selected]
	var pv: Dictionary = GameState.preview_player(_pos(), _pname())
	var parts: Array = []
	for k in CareerSquad.ATTR_KEYS:
		parts.append("%s %d" % [CareerSquad.ATTR_NAMES[k], int(pv.attrs[k])])
	player_info.text = "Aos 18 anos: Overall %d · Potencial %d\n%s" % [int(pv.ovr), int(pv.potential), " · ".join(PackedStringArray(parts))]
	if info != null:
		_update_info()

func _on_league(i: int) -> void:
	club_opt.clear()
	for c in 8:
		club_opt.add_item(Leagues.club_name(i, c), c)
	club_opt.select(0)
	_update_info()

func _update_info() -> void:
	var lg := league_opt.selected
	var d: Dictionary = Leagues.DATA[lg]
	var st := Leagues.club_strength(lg, club_opt.selected)
	var sq: Array = CareerSquad.squad(lg, club_opt.selected, 1)
	info.text = "Nível da liga %d · salário x%.1f · força do clube %d · elenco de %d jogadores (média %.0f)\nSalário base: vitória $%d / empate $%d / derrota $%d\nContrato inicial de 3 temporadas, salário semanal conforme overall." % [
		int(d.power), float(d.pay), st, sq.size(), CareerSquad.average_top(sq),
		int(400 * float(d.pay) * 0.5), int(220 * float(d.pay) * 0.5), int(120 * float(d.pay) * 0.5)]

func _start() -> void:
	var look := {"skin": skin_opt.selected, "hair": hair_opt.selected, "hair_color": hair_color_opt.selected}
	GameState.start_career(league_opt.selected, club_opt.selected, _pos(), look, _pname())
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
