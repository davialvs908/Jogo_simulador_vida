extends CanvasLayer
## HUD da partida: placar, relógio, avisos, stamina, barra de força, radar, replay, resultado.

const C := preload("res://scripts/match_consts.gd")
const RadarScript := preload("res://scripts/match_radar.gd")

var score_lbl: Label
var clock_lbl: Label
var home_lbl: Label
var away_lbl: Label
var banner_lbl: Label
var toast_lbl: Label
var info_lbl: Label
var hint_lbl: Label
var stamina_bar: ProgressBar
var power_bar: ProgressBar
var radar: Control
var replay_box: Control
var banner_t := 0.0
var toast_t := 0.0
var _rd := 0.0

func _style(bg: Color, radius := 8, margin := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb

func _label(text: String, size: int, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func build(m) -> void:
	layer = 5
	# placar no estilo transmissão
	var scorebar := HBoxContainer.new()
	scorebar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	scorebar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	scorebar.offset_top = 14
	scorebar.alignment = BoxContainer.ALIGNMENT_CENTER
	scorebar.add_theme_constant_override("separation", 0)
	add_child(scorebar)
	var home_box := PanelContainer.new()
	home_box.custom_minimum_size = Vector2(210, 54)
	home_box.add_theme_stylebox_override("panel", _style(Color(0.07, 0.24, 0.58, 0.94), 0, 8))
	scorebar.add_child(home_box)
	home_lbl = _label(GameState.club_name, 18, Color(0.92, 0.95, 1.0))
	home_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	home_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	home_lbl.clip_text = true
	home_lbl.custom_minimum_size = Vector2(190, 36)
	home_box.add_child(home_lbl)
	var mid := PanelContainer.new()
	mid.custom_minimum_size = Vector2(128, 54)
	mid.add_theme_stylebox_override("panel", _style(Color(0.02, 0.02, 0.03, 0.94), 0, 6))
	scorebar.add_child(mid)
	var mv := VBoxContainer.new()
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_child(mv)
	score_lbl = _label("0 – 0", 28)
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(score_lbl)
	clock_lbl = _label("0' · 1º TEMPO", 13, Color(0.78, 0.84, 0.9))
	clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(clock_lbl)
	var away_box := PanelContainer.new()
	away_box.custom_minimum_size = Vector2(210, 54)
	away_box.add_theme_stylebox_override("panel", _style(Color(0.58, 0.1, 0.12, 0.94), 0, 8))
	scorebar.add_child(away_box)
	away_lbl = _label(GameState.opponent_name(), 18, Color(1.0, 0.93, 0.93))
	away_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	away_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	away_lbl.clip_text = true
	away_lbl.custom_minimum_size = Vector2(190, 36)
	away_box.add_child(away_lbl)
	# faixas do replay
	replay_box = Control.new()
	replay_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	replay_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	replay_box.visible = false
	add_child(replay_box)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.8)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if top:
			bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
			bar.offset_bottom = 54
		else:
			bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			bar.offset_top = -54
		replay_box.add_child(bar)
	var rl := _label("● REPLAY", 30, Color(1.0, 0.25, 0.2))
	rl.position = Vector2(24, 8)
	replay_box.add_child(rl)
	var skip := _label("J / K / Enter para pular", 14, Color(0.85, 0.85, 0.85))
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left = -240
	skip.offset_top = -38
	replay_box.add_child(skip)
	# banner central
	banner_lbl = _label("", 76, Color(1, 0.95, 0.5))
	banner_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_lbl.offset_top = -110
	banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_lbl.add_theme_constant_override("outline_size", 12)
	banner_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	banner_lbl.visible = false
	add_child(banner_lbl)
	# toast
	toast_lbl = _label("", 22, Color(1, 1, 1))
	toast_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_lbl.offset_top = 96
	toast_lbl.add_theme_constant_override("outline_size", 6)
	toast_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(toast_lbl)
	# info do jogador controlado
	info_lbl = _label("", 16, Color(1.0, 0.9, 0.3))
	info_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	info_lbl.offset_left = -230
	info_lbl.offset_top = 14
	info_lbl.add_theme_constant_override("outline_size", 4)
	info_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(info_lbl)
	# stamina
	var sbox := VBoxContainer.new()
	sbox.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	sbox.offset_left = 16
	sbox.offset_top = -78
	sbox.offset_bottom = -34
	add_child(sbox)
	sbox.add_child(_label("Fôlego", 14, Color(0.85, 0.95, 0.85)))
	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(210, 14)
	stamina_bar.max_value = 1.0
	stamina_bar.step = 0.001
	stamina_bar.show_percentage = false
	sbox.add_child(stamina_bar)
	# força do chute
	power_bar = ProgressBar.new()
	power_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	power_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	power_bar.custom_minimum_size = Vector2(280, 18)
	power_bar.offset_top = -86
	power_bar.max_value = 1.0
	power_bar.step = 0.001
	power_bar.show_percentage = false
	power_bar.visible = false
	add_child(power_bar)
	# dica
	hint_lbl = _label("WASD mover · Shift correr · J passe (segure = lançamento) · K chute (segure = força) · sem bola: K carrinho, J desarme · Q/Tab trocar · Esc sair", 13, Color(0.9, 0.92, 0.95))
	hint_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint_lbl.offset_top = -26
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.add_theme_constant_override("outline_size", 4)
	hint_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(hint_lbl)
	# radar
	radar = RadarScript.new()
	radar.match_ref = m
	radar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	radar.offset_left = -194
	radar.offset_top = -152
	radar.offset_right = -16
	radar.offset_bottom = -32
	add_child(radar)

func banner(text: String, col := Color(1, 0.95, 0.5), secs := 2.0, size := 76) -> void:
	banner_lbl.text = text
	banner_lbl.add_theme_color_override("font_color", col)
	banner_lbl.add_theme_font_size_override("font_size", size)
	banner_lbl.visible = true
	banner_lbl.modulate.a = 1.0
	banner_t = secs

func toast(text: String, secs := 2.5, col := Color.WHITE) -> void:
	toast_lbl.text = text
	toast_lbl.add_theme_color_override("font_color", col)
	toast_t = secs

func set_replay(on: bool) -> void:
	replay_box.visible = on

func update(m, dt: float) -> void:
	score_lbl.text = "%d – %d" % [m.home_score, m.away_score]
	var mins := int(m.clock_min)
	var half_txt := "1º TEMPO" if m.half == 1 else "2º TEMPO"
	if m.state == C.State.HALFTIME:
		half_txt = "INTERVALO"
	elif m.state == C.State.FULLTIME:
		half_txt = "FIM DE JOGO"
	clock_lbl.text = "%d' · %s" % [mins, half_txt]
	if banner_t > 0.0:
		banner_t -= dt
		banner_lbl.modulate.a = clampf(banner_t / 0.5, 0.0, 1.0)
		if banner_t <= 0.0:
			banner_lbl.visible = false
	if toast_t > 0.0:
		toast_t -= dt
		if toast_t <= 0.0:
			toast_lbl.text = ""
	var u = m.controlled
	if u != null:
		stamina_bar.value = u.stamina
		info_lbl.text = "Você: #%d %s" % [u.shirt_number, u.role_text()]
	if m.charge_active():
		power_bar.visible = true
		power_bar.value = m.charge_value()
	else:
		power_bar.visible = false
	_rd -= dt
	if _rd <= 0.0:
		_rd = 0.05
		radar.queue_redraw()

func show_result(title: String, sub: String, stats: String, on_continue: Callable) -> void:
	var layer_r := CanvasLayer.new()
	layer_r.layer = 10
	add_child(layer_r)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.07, 0.11, 0.95), 12, 22))
	layer_r.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := _label(title, 32, Color(1, 0.95, 0.5))
	t.name = "Title"
	v.add_child(t)
	var s := _label(sub, 18)
	s.name = "Sub"
	v.add_child(s)
	var st := _label(stats, 15, Color(0.75, 0.82, 0.9))
	st.name = "Stats"
	v.add_child(st)
	var btn := Button.new()
	btn.name = "ContinueButton"
	btn.text = "Ir para a cidade"
	btn.pressed.connect(on_continue)
	v.add_child(btn)
	btn.grab_focus()
