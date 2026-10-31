extends RefCounted
## Painéis dos novos locais (restaurante, cinema, clínica, banco, eletrônicos, posto, praia, central de missões),
## celular/GPS, mapa grande, menu de pausa e opções.

const Missions = preload("res://scripts/city_missions.gd")

const MOVIES := ["O Último Apito", "Noite no Porto", "Corrida Contra o Vento", "Amor em Dois Tempos", "A Torcida Invisível", "Maré Alta"]
const ITEMS := [
	{"id": "camera", "name": "Câmera Pro", "price": 500, "desc": "+30% de pagamento nas fotos para a imprensa."},
	{"id": "radar", "name": "Detector de Radar", "price": 250, "desc": "Avisa a Guarda por perto, mostra viaturas no mapa e reduz multas em 40%."},
	{"id": "fone", "name": "Fone Esportivo", "price": 180, "desc": "Corre 8% mais rápido e cansa menos pela cidade."},
	{"id": "console", "name": "Console de Jogos", "price": 700, "desc": "Libera videogame em casa (energia, e vínculo se a Maya mora com você)."},
]

var hub

func setup(h) -> void:
	hub = h

func _g() -> Node:
	return GameState

func is_open(id: String) -> bool:
	var sp: Dictionary = hub.SPOTS[id]
	if not sp.has("hours"):
		return true
	var hrs: Array = sp.hours
	var h: float = GameState.hour
	return h >= float(hrs[0]) and h < float(hrs[1])

func open(id: String) -> bool:
	match id:
		"restaurant", "cinema", "clinic", "bank", "electro", "gas", "beach", "board":
			pass
		_:
			return false
	if not is_open(id):
		var sp: Dictionary = hub.SPOTS[id]
		var hrs: Array = sp.hours
		var v: VBoxContainer = hub._panel(str(sp.label), "Fechado agora. Horário de funcionamento: %dh às %dh." % [int(hrs[0]), int(hrs[1]) % 24 if int(hrs[1]) != 24 else 24])
		hub._btn(v, "Esperar até abrir", func ():
			var wait: float = float(hrs[0]) - GameState.hour
			if wait < 0.0:
				wait += 24.0
			GameState.add_time(wait + 0.05)
			hub._say(id, "Você esperou até a abertura."))
		hub._back(v)
		return true
	match id:
		"restaurant": _restaurant()
		"cinema": _cinema()
		"clinic": _clinic()
		"bank": _bank()
		"electro": _electro()
		"gas": _gas()
		"beach": _beach()
		"board": _board()
	return true

# ---------------- restaurante ----------------
func _restaurant() -> void:
	var g := GameState
	var v: VBoxContainer = hub._panel("Restaurante Sabor do Porto",
		"Pratos do dia com ingredientes frescos.\nCaixa: $%d · Energia %d%%" % [g.money, int(g.energy)])
	hub._btn(v, "Almoço rápido — $35 (+20 energia, 1h)", func ():
		if g.spend(35):
			g.energy = minf(100.0, g.energy + 20.0)
			g.add_time(1.0)
			hub._say("restaurant", "Prato feito caprichado. Energia %d%%." % int(g.energy)), g.money < 35)
	hub._btn(v, "Jantar executivo — $120 (+40 energia, 2h)", func ():
		if g.spend(120):
			g.energy = minf(100.0, g.energy + 40.0)
			g.add_time(2.0)
			hub._say("restaurant", "Banquete! Energia %d%%." % int(g.energy)), g.money < 120)
	if g.gf_status != "none" and hub._maya_here():
		hub._btn(v, "Jantar romântico com a Maya — $160 (+16 vínculo, 2h)", func ():
			if g.spend(160):
				g.bond = mini(100, g.bond + 16)
				g.add_time(2.0)
				g.last_date_day = g.day
				hub._check_dating()
				hub._say("restaurant", "Noite inesquecível. Vínculo %d." % g.bond), g.money < 160)
	else:
		var l := Label.new()
		l.text = "Para um jantar romântico, a Maya precisa estar disponível (depois das 12h)."
		l.modulate = Color(0.8, 0.8, 0.85)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(520, 0)
		v.add_child(l)
	hub._back(v)

# ---------------- cinema ----------------
func _cinema() -> void:
	var g := GameState
	var movie: String = MOVIES[g.day % MOVIES.size()]
	var v: VBoxContainer = hub._panel("Cine Orla", "Em cartaz hoje: \"%s\"\nCaixa: $%d" % [movie, g.money])
	hub._btn(v, "Pipoca grande + refri — $15 (+4 energia)", func ():
		if g.spend(15):
			g.energy = minf(100.0, g.energy + 4.0)
			hub._say("cinema", "Pipoca crocante!"), g.money < 15)
	hub._btn(v, "Sessão sozinho — $30 (+8 energia, 2h)", func ():
		if g.spend(30):
			g.energy = minf(100.0, g.energy + 8.0)
			g.add_time(2.0)
			hub._say("cinema", "Você relaxou assistindo \"%s\"." % movie), g.money < 30)
	if g.gf_status != "none" and hub._maya_here():
		hub._btn(v, "Encontro com a Maya — $90 (+14 vínculo, 2.5h)", func ():
			if g.spend(90):
				g.bond = mini(100, g.bond + 14)
				g.add_time(2.5)
				g.last_date_day = g.day
				hub._check_dating()
				hub._say("cinema", "Vocês assistiram \"%s\" de mãos dadas. Vínculo %d." % [movie, g.bond]), g.money < 90)
	else:
		var l := Label.new()
		l.text = "A Maya só pode ir ao cinema se vocês estiverem saindo e ela estiver disponível (depois das 12h)."
		l.modulate = Color(0.8, 0.8, 0.85)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(520, 0)
		v.add_child(l)
	hub._back(v)

# ---------------- clínica ----------------
func _clinic() -> void:
	var g := GameState
	var v: VBoxContainer = hub._panel("Clínica Mar Azul — Fisioterapia",
		"Recupere a energia com a equipe de fisioterapia.\nEnergia %d%% · Caixa $%d" % [int(g.energy), g.money])
	var plans := [["Fisioterapia leve", 80, 30.0, 1.5], ["Massagem esportiva", 140, 50.0, 2.0], ["Tratamento completo", 240, 100.0, 3.0]]
	for p in plans:
		var nm: String = p[0]
		var cost: int = p[1]
		var gain: float = p[2]
		var hrs: float = p[3]
		var label := "%s — $%d (%s, %sh)" % [nm, cost, "energia 100%" if gain >= 100.0 else "+%d energia" % int(gain), str(hrs)]
		hub._btn(v, label, func ():
			if g.spend(cost):
				g.energy = minf(100.0, g.energy + gain)
				g.add_time(hrs)
				hub._say("clinic", "%s concluída. Energia %d%%." % [nm, int(g.energy)]), g.money < cost or g.energy >= 99.5)
	hub._back(v)

# ---------------- banco ----------------
func _bank_accrue() -> int:
	var c = hub.city
	var days: int = GameState.day - c.i("savings_day")
	var gained := 0
	if days > 0:
		var old: int = c.i("savings")
		var nw := int(float(old) * pow(1.004, float(mini(days, 365))))
		gained = nw - old
		c.put("savings", nw)
	c.put("savings_day", GameState.day)
	return gained

func _bank() -> void:
	var g := GameState
	var c = hub.city
	var gained := _bank_accrue()
	var body := "Poupança Banco Orla: rende 0,4%% ao dia.\nSaldo na poupança: $%d%s\nCarteira: $%d" % [
		c.i("savings"), (" (rendeu +$%d)" % gained) if gained > 0 else "", g.money]
	if c.i("fines_due") > 0:
		body += "\nMultas pendentes: $%d" % c.i("fines_due")
	var v: VBoxContainer = hub._panel("Banco Orla", body)
	for amt in [100, 500]:
		hub._btn(v, "Depositar $%d" % amt, func ():
			if g.spend(amt):
				c.add_i("savings", amt)
				hub._say("bank", "Depósito de $%d realizado." % amt), g.money < amt)
	hub._btn(v, "Depositar tudo", func ():
		var all := g.money
		if all > 0 and g.spend(all):
			c.add_i("savings", all)
			hub._say("bank", "Depósito de $%d realizado." % all), g.money <= 0)
	for amt in [100, 500]:
		hub._btn(v, "Sacar $%d" % amt, func ():
			if c.i("savings") >= amt:
				c.add_i("savings", -amt)
				g.money += amt
				hub._say("bank", "Saque de $%d realizado." % amt), c.i("savings") < amt)
	hub._btn(v, "Sacar tudo", func ():
		var all: int = c.i("savings")
		c.put("savings", 0)
		g.money += all
		hub._say("bank", "Saque de $%d realizado." % all), c.i("savings") <= 0)
	if c.i("fines_due") > 0:
		var due: int = c.i("fines_due")
		hub._btn(v, "Pagar multas pendentes ($%d)" % due, func ():
			if g.spend(due):
				c.put("fines_due", 0)
				hub._say("bank", "Multas quitadas."), g.money < due)
	hub._back(v)

# ---------------- eletrônicos ----------------
func _electro() -> void:
	var g := GameState
	var c = hub.city
	var v: VBoxContainer = hub._panel("Loja de Eletrônicos Volt", "Gadgets para a vida na cidade.\nCaixa: $%d" % g.money)
	for it in ITEMS:
		var owned: bool = c.has_item(str(it.id))
		hub._btn(v, "%s — $%d%s\n%s" % [it.name, it.price, " (comprado)" if owned else "", it.desc], func ():
			if g.spend(int(it.price)):
				c.give_item(str(it.id))
				hub._say("electro", "Você comprou: %s." % it.name), owned or g.money < int(it.price))
	hub._back(v)

# ---------------- posto de gasolina ----------------
func _gas() -> void:
	var g := GameState
	var c = hub.city
	var fuel: float = c.f("fuel")
	var body := "Posto Costa Azul · $1 por 1%% de combustível.\nCombustível: %d%% · Caixa: $%d" % [int(fuel), g.money]
	if not c.b("fuel_enabled"):
		body += "\n(O consumo de combustível está desligado nas opções.)"
	if not g.has_car():
		body += "\nVocê ainda não tem carro."
	var v: VBoxContainer = hub._panel("Posto de Gasolina", body)
	var need := int(ceil(100.0 - fuel))
	hub._btn(v, "Abastecer +25% — $25", func ():
		if g.spend(25):
			c.put("fuel", minf(100.0, c.f("fuel") + 25.0))
			hub._say("gas", "Tanque em %d%%." % int(c.f("fuel"))), not g.has_car() or g.money < 25 or need <= 0)
	hub._btn(v, "Encher o tanque — $%d" % need, func ():
		if g.spend(need):
			c.put("fuel", 100.0)
			hub._say("gas", "Tanque cheio!"), not g.has_car() or g.money < need or need <= 0)
	hub._btn(v, "Lanche da conveniência — $8 (+5 energia)", func ():
		if g.spend(8):
			g.energy = minf(100.0, g.energy + 5.0)
			hub._say("gas", "Lanche rápido. Energia %d%%." % int(g.energy)), g.money < 8)
	hub._back(v)

# ---------------- praia ----------------
func _beach() -> void:
	var g := GameState
	var v: VBoxContainer = hub._panel("Quiosque da Praia", "Brisa do mar e música baixinha.\nEnergia %d%% · Caixa $%d" % [int(g.energy), g.money])
	hub._btn(v, "Água de coco — $8 (+6 energia)", func ():
		if g.spend(8):
			g.energy = minf(100.0, g.energy + 6.0)
			hub._say("beach", "Geladinha! Energia %d%%." % int(g.energy)), g.money < 8)
	hub._btn(v, "Relaxar na areia (1h, grátis, +8 energia)", func ():
		g.energy = minf(100.0, g.energy + 8.0)
		g.add_time(1.0)
		hub._say("beach", "Uma hora de sol e ondas. Energia %d%%." % int(g.energy)))
	if g.gf_status != "none" and hub._maya_here():
		hub._btn(v, "Pedalinho com a Maya — $60 (+10 vínculo, 1.5h)", func ():
			if g.spend(60):
				g.bond = mini(100, g.bond + 10)
				g.add_time(1.5)
				g.last_date_day = g.day
				hub._check_dating()
				hub._say("beach", "Passeio de pedalinho! Vínculo %d." % g.bond), g.money < 60)
	hub._back(v)

# ---------------- central de missões ----------------
func _board() -> void:
	var m = hub.missions
	var body := "Escolha um trabalho. Missões podem ser repetidas uma vez por dia."
	if not m.active.is_empty():
		body = "Missão atual: %s\n%s" % [m.active.def.title, m.status_text()]
	var v: VBoxContainer = hub._panel("Central de Missões", body)
	for d in Missions.DEFS:
		var why: String = m.availability(d)
		var label := ""
		if why == "":
			label = "%s — %s" % [d.title, m.reward_text(d)]
		else:
			label = "%s — (%s)" % [d.title, why]
		var did: String = str(d.id)
		hub._btn(v, label, func (): _mission_detail(did), why != "")
	if not m.active.is_empty():
		hub._btn(v, "Cancelar missão atual", func ():
			m.cancel()
			hub._say("board", "Missão cancelada."))
	hub._back(v)

func _mission_detail(id: String) -> void:
	var m = hub.missions
	var d: Dictionary = m.def_of(id)
	var body := "%s\n\nRecompensa: %s" % [d.desc, m.reward_text(d)]
	if d.has("fee"):
		body += "\nInscrição: $%d" % int(d.fee)
	var v: VBoxContainer = hub._panel(str(d.title), body)
	hub._btn(v, "Aceitar missão", func ():
		var why: String = m.start(id)
		if why != "":
			hub._say("board", why)
		else:
			hub._close())
	hub._btn(v, "Voltar", func (): hub._open_spot("board"))

# ---------------- celular / GPS ----------------
func open_phone() -> void:
	var m = hub.missions
	var body := "GPS ligado em: %s" % (hub.waypoint_label if hub.has_waypoint else "nenhum destino")
	if not m.active.is_empty():
		body += "\nMissão: %s" % m.status_text()
	var v: VBoxContainer = hub._panel("Celular", body)
	if not m.active.is_empty():
		hub._btn(v, "Marcar o objetivo da missão no GPS", func ():
			hub.auto_gps_to_mission()
			hub._close())
		hub._btn(v, "Cancelar missão atual", func ():
			m.cancel()
			open_phone())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for id in hub.SPOTS.keys():
		var sp: Dictionary = hub.SPOTS[id]
		var b := Button.new()
		b.text = "GPS: %s" % sp.label
		b.custom_minimum_size = Vector2(250, 0)
		var sid: String = id
		b.pressed.connect(func ():
			hub.set_waypoint(m.door(sid), str(hub.SPOTS[sid].label))
			hub._close())
		grid.add_child(b)
	hub._btn(v, "Limpar GPS", func ():
		hub.clear_waypoint()
		hub._close())
	hub._btn(v, "Abrir mapa grande (M)", func (): open_map())
	hub._back(v)

# ---------------- mapa grande ----------------
func open_map() -> void:
	var v: VBoxContainer = hub._panel("Mapa da Cidade", "Clique no mapa para marcar o GPS (botão direito limpa). Bairros: Centro, Praia, Subúrbio, Zona de lojas e Distrito esportivo.", 800)
	var MapScript = load("res://scripts/city_map.gd")
	var mp: Control = MapScript.new()
	mp.hub = hub
	mp.full = true
	mp.custom_minimum_size = Vector2(760, 440)
	v.add_child(mp)
	hub.big_map = mp
	hub._btn(v, "Fechar mapa", hub._close)

# ---------------- pausa / opções ----------------
func open_menu() -> void:
	var v: VBoxContainer = hub._panel("Pausa", "O progresso é salvo quando você compra, descansa ou termina uma partida.\nDia %d · %s · $%d · Poupança $%d" % [
		GameState.day, GameState.time_text(), GameState.money, hub.city.i("savings")])
	hub.pause_world = true
	hub._btn(v, "Continuar", hub._close)
	hub._btn(v, "Salvar e continuar", func (): hub._save_all(); hub._close())
	hub._btn(v, "Celular / GPS / Missões (J)", func (): open_phone())
	hub._btn(v, "Mapa grande (M)", func (): open_map())
	hub._btn(v, "Opções", func (): open_options())
	hub._btn(v, "Controles", func (): open_controls())
	hub._btn(v, "Tela inicial", func (): hub._save_all(); hub.get_tree().change_scene_to_file("res://scenes/boot.tscn"))

func open_options() -> void:
	var c = hub.city
	var v: VBoxContainer = hub._panel("Opções", "Ajustes da cidade. As escolhas são salvas automaticamente.")
	hub.pause_world = true
	hub._btn(v, "Clima: %s" % hub.weather.mode_text(), func ():
		hub.weather.cycle_mode()
		c.put("weather_mode", hub.weather.mode)
		open_options())
	hub._btn(v, "Polícia (multas de velocidade): %s" % ("ligada" if c.b("police_enabled") else "desligada"), func ():
		c.put("police_enabled", not c.b("police_enabled"))
		hub.traffic.set_police(c.b("police_enabled"))
		open_options())
	hub._btn(v, "Combustível no carro: %s" % ("ligado" if c.b("fuel_enabled") else "desligado"), func ():
		c.put("fuel_enabled", not c.b("fuel_enabled"))
		open_options())
	hub._btn(v, "Minimapa: %s" % ("visível" if c.b("minimap") else "oculto"), func ():
		c.put("minimap", not c.b("minimap"))
		hub.apply_options()
		open_options())
	_slider(v, "Volume", c.f("volume"), 0.0, 1.0, func (val: float):
		c.put("volume", val)
		hub.apply_options())
	_slider(v, "Zoom da câmera", c.f("cam_zoom"), 0.7, 1.5, func (val: float):
		c.put("cam_zoom", val)
		hub.cam_zoom = val)
	hub._btn(v, "Voltar", func (): open_menu())

func _slider(parent: VBoxContainer, label: String, value: float, lo: float, hi: float, cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(140, 0)
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 0.05
	sl.value = value
	sl.custom_minimum_size = Vector2(340, 24)
	sl.value_changed.connect(cb)
	row.add_child(sl)
	parent.add_child(row)

func open_controls() -> void:
	var txt := "WASD mover / dirigir · Shift correr · F entrar/sair do carro · E entrar em local / fotografar\n" \
		+ "Espaço freio de mão · H buzina · R rádio (estações) · M mapa grande · J celular (GPS/missões)\n" \
		+ "G marcar objetivo da missão no GPS (de novo: limpar) · - / = zoom do minimapa · Roda do mouse zoom da câmera\n" \
		+ "Esc pausa / fechar painéis"
	var v: VBoxContainer = hub._panel("Controles", txt)
	hub.pause_world = true
	hub._btn(v, "Voltar", func (): open_menu())
