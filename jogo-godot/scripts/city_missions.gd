extends RefCounted
## Missões e atividades da cidade (entregas, corridas, passeio com a Maya, treino, patrocínio e fotos).

const G = preload("res://scripts/city_graph.gd")

const DEFS := [
	{"id": "d_express", "title": "Entrega Expressa", "kind": "delivery", "from": "mall", "to": "cafe", "money": 130, "fame": 1,
		"desc": "Uma loja do Shopping precisa de uma encomenda no Café. Moto, carro ou a pé: o relógio corre!"},
	{"id": "d_docs", "title": "Malote do Banco", "kind": "delivery", "from": "bank", "to": "realestate", "money": 170, "fame": 1,
		"desc": "Leve os documentos do Banco Orla até a Imobiliária antes do fechamento."},
	{"id": "d_tech", "title": "Pacote Eletrônico", "kind": "delivery", "from": "electro", "to": "home", "money": 150, "fame": 1,
		"desc": "Um console recém-chegado precisa ser entregue na sua casa. Cuidado com as curvas."},
	{"id": "d_food", "title": "Marmitas para a Academia", "kind": "delivery", "from": "restaurant", "to": "gym", "money": 120, "fame": 1, "energy": -8,
		"desc": "O pessoal da Academia pediu marmitas fitness. Entrega quente, de preferência correndo."},
	{"id": "race_center", "title": "Racha no Centro", "kind": "race", "money": 420, "fame": 3, "fee": 50,
		"rival": "Dudu Faísca", "rival_k": 0.74, "color": Color(0.9, 0.35, 0.1),
		"desc": "Corrida de rua legal e sem contato contra o Dudu Faísca: 6 checkpoints ao redor do Centro. Taxa de inscrição $50."},
	{"id": "race_beach", "title": "Corrida da Orla", "kind": "race", "money": 1100, "fame": 6, "fee": 150,
		"rival": "Valéria Cometa", "rival_k": 0.80, "color": Color(0.5, 0.2, 0.8),
		"desc": "A Valéria Cometa desafia você na Avenida da Praia. Exige o Esportivo GT ou melhor. Inscrição $150."},
	{"id": "maya_ride", "title": "Passeio com a Maya", "kind": "maya", "money": 0, "fame": 0, "bond": 15, "energy": 6,
		"desc": "Busque a Maya no Café, passeie até o Mirante da Praia e termine no Restaurante. Dirija com calma: 3 sustos e ela desce!"},
	{"id": "run_city", "title": "Volta da Cidade (treino)", "kind": "run", "money": 90, "fame": 1, "energy": -15,
		"desc": "Treino extra de condicionamento: corra a pé por 8 checkpoints no anel externo da cidade. Mantenha o Shift!"},
	{"id": "sp_mall", "title": "Sessão de Autógrafos", "kind": "sponsor", "to": "mall", "hold": 8.0, "money": 230, "fame": 2,
		"sponsor": "Tênis Raio",
		"desc": "A marca Tênis Raio promove um evento no Shopping. Fique no estande por alguns segundos assinando fotos."},
	{"id": "sp_gala", "title": "Gala do Patrocinador", "kind": "sponsor", "to": "restaurant", "hold": 10.0, "money": 540, "fame": 4,
		"sponsor": "Isotônico Vigor",
		"desc": "Jantar de gala da Isotônico Vigor no Restaurante (18h às 23h). Exige fama 8+ e roupa melhor que a básica."},
	{"id": "photo_press", "title": "Ensaio para a Imprensa", "kind": "photo", "money": 170, "fame": 2,
		"desc": "A revista Gol & Estilo quer 3 fotos suas: Estádio, Mirante da Praia e Shopping. Aperte E em cada ponto (7h às 18h)."},
]

const MIRANTE := Vector3(60, 0, 140)

var hub
var active := {}
var rival: Node3D
var rival_path: Array = []
var rival_dist := 0.0
var rival_total := 0.0
var rival_speed := 0.0
var maya_aboard := false
var _strike_cd := 0.0
var _over_t := 0.0

func setup(h) -> void:
	hub = h

func def_of(id: String) -> Dictionary:
	for d in DEFS:
		if d.id == id:
			return d
	return {}

func door(id: String) -> Vector3:
	var sp: Dictionary = hub.SPOTS[id]
	var p: Vector3 = sp.pos
	var s: Vector3 = sp.size
	return Vector3(p.x, 0.0, p.z + s.z * 0.5 + 4.5)

func reward_text(d: Dictionary) -> String:
	var parts: Array = []
	if int(d.get("money", 0)) > 0:
		parts.append("$%d" % int(d.money))
	if int(d.get("fame", 0)) > 0:
		parts.append("fama +%d" % int(d.fame))
	if int(d.get("bond", 0)) > 0:
		parts.append("vínculo +%d" % int(d.bond))
	if int(d.get("energy", 0)) != 0:
		parts.append("energia %+d" % int(d.energy))
	return " · ".join(parts)

## Retorna "" se a missão pode ser aceita, ou o motivo de não poder.
func availability(d: Dictionary) -> String:
	var g := GameState
	if not active.is_empty():
		return "Termine ou cancele a missão atual primeiro."
	if hub.city.done_today(str(d.id), g.day):
		return "Já concluída hoje. Volte amanhã."
	match str(d.kind):
		"race":
			if not g.has_car():
				return "Precisa de um carro."
			if g.energy < 30.0:
				return "Você está cansado demais (energia 30+)."
			if g.money < int(d.fee):
				return "Faltam $%d para a inscrição." % int(d.fee)
			if str(d.id) == "race_beach" and float(g.car_data(g.current_car).get("speed", 0.0)) < 27.0:
				return "Exige o Esportivo GT ou melhor."
		"maya":
			if not g.has_car():
				return "Precisa de um carro."
			if g.gf_status == "none" and g.bond < 30:
				return "Precisa de vínculo 30+ com a Maya."
			if not g.gf_lives_with and g.hour < 12.0:
				return "A Maya só sai depois das 12h."
		"run":
			if g.energy < 40.0:
				return "Energia 40+ necessária para o treino."
		"sponsor":
			if str(d.id) == "sp_mall" and (g.hour < 10.0 or g.hour >= 21.0):
				return "Evento só das 10h às 21h."
			if str(d.id) == "sp_gala":
				if g.hour < 18.0 or g.hour >= 23.0:
					return "Gala só das 18h às 23h."
				if g.total_fame() < 8 or g.clothes_id < 1:
					return "Exige fama 8+ e roupa melhor."
		"photo":
			if g.hour < 7.0 or g.hour >= 18.0:
				return "Só com luz do dia (7h às 18h)."
	return ""

func _man(a: Vector3, b: Vector3) -> float:
	return absf(a.x - b.x) + absf(a.z - b.z)

func _stage(pos: Vector3, label: String, radius := 9.0, kind := "reach", hold := 0.0, need_car := false) -> Dictionary:
	return {"pos": pos, "label": label, "radius": radius, "kind": kind, "hold": hold, "need_car": need_car}

func start(id: String) -> String:
	var d := def_of(id)
	if d.is_empty():
		return "Missão desconhecida."
	var why := availability(d)
	if why != "":
		return why
	var g := GameState
	var stages: Array = []
	var total := 0.0
	var phase := ""
	match str(d.kind):
		"delivery":
			var a := door(str(d["from"]))
			var b := door(str(d["to"]))
			var lf: String = hub.SPOTS[d["from"]].label
			var lt: String = hub.SPOTS[d["to"]].label
			stages.append(_stage(a, "Pegar a encomenda: %s" % lf))
			stages.append(_stage(b, "Entregar em: %s" % lt))
			var spd := 12.0 if g.has_car() else 8.0
			total = (_man(hub.ref_pos(), a) + _man(a, b)) / spd + 22.0
		"race":
			var nodes: Array = [G.node_id(3, 2), G.node_id(4, 2), G.node_id(4, 3), G.node_id(3, 3), G.node_id(2, 3), G.node_id(2, 2)]
			if str(d.id) == "race_beach":
				nodes = [G.node_id(1, 4), G.node_id(3, 4), G.node_id(5, 4), G.node_id(5, 3), G.node_id(3, 3), G.node_id(1, 3)]
			stages.append(_stage(G.node_pos(int(nodes[0])), "Vá até a largada (de carro)", 9.0, "reach", 0.0, true))
			for k in range(1, nodes.size()):
				stages.append(_stage(G.node_pos(int(nodes[k])), "Checkpoint %d/%d" % [k, nodes.size() - 1], 11.0, "reach", 0.0, true))
			stages.append(_stage(G.node_pos(int(nodes[0])), "Linha de chegada!", 11.0, "reach", 0.0, true))
			phase = "to_start"
			_build_rival(nodes, d)
			g.spend(int(d.fee))
		"maya":
			stages.append(_stage(door("cafe"), "Buscar a Maya no Café (de carro)", 9.0, "reach", 0.0, true))
			stages.append(_stage(MIRANTE, "Levar a Maya ao Mirante da Praia", 10.0, "reach", 1.5, true))
			stages.append(_stage(door("restaurant"), "Jantar no Restaurante com a Maya", 10.0, "reach", 0.0, true))
		"run":
			var ring: Array = [Vector3(-110, 0, -110), Vector3(0, 0, -110), Vector3(110, 0, -110), Vector3(110, 0, 0),
				Vector3(110, 0, 110), Vector3(0, 0, 110), Vector3(-110, 0, 110), Vector3(-110, 0, 0)]
			var me: Vector3 = hub.ref_pos()
			var bi := 0
			var bd := 1e9
			for k in ring.size():
				var dd := me.distance_to(ring[k])
				if dd < bd:
					bd = dd
					bi = k
			for k in ring.size():
				var p: Vector3 = ring[(bi + k) % ring.size()]
				stages.append(_stage(p, "Checkpoint %d/%d" % [k + 1, ring.size()], 9.0))
			total = (bd + 880.0) / 13.0 + 8.0
		"sponsor":
			stages.append(_stage(door(str(d["to"])), "Estande de %s: %s" % [hub.SPOTS[d["to"]].label, d.sponsor], 9.0, "reach", float(d.hold)))
		"photo":
			stages.append(_stage(door("stadium"), "Foto 1/3: fachada do Estádio (E)", 11.0, "photo"))
			stages.append(_stage(MIRANTE, "Foto 2/3: Mirante da Praia (E)", 11.0, "photo"))
			stages.append(_stage(door("mall"), "Foto 3/3: Shopping (E)", 11.0, "photo"))
	active = {"id": d.id, "def": d, "kind": d.kind, "stage": 0, "stages": stages, "time_total": total, "time_left": total,
		"hold": 0.0, "strikes": 0, "phase": phase, "cd": 0.0, "elapsed": 0.0}
	maya_aboard = false
	_strike_cd = 0.0
	hub.on_mission_changed()
	hub.toast("Missão iniciada: %s" % d.title)
	hub.auto_gps_to_mission()
	return ""

func cancel() -> void:
	if active.is_empty():
		return
	hub.toast("Missão cancelada: %s" % active.def.title)
	_cleanup()
	hub.on_mission_changed()

func _cleanup() -> void:
	active = {}
	maya_aboard = false
	hub.lock_drive = false
	if rival:
		rival.queue_free()
		rival = null
	rival_path = []

func blocks_car() -> bool:
	return not active.is_empty() and str(active.kind) == "run"

func current_stage() -> Dictionary:
	if active.is_empty():
		return {}
	var st: Array = active.stages
	var i := mini(int(active.stage), st.size() - 1)
	return st[i]

func current_target() -> Dictionary:
	if active.is_empty():
		return {}
	var s := current_stage()
	if s.is_empty():
		return {}
	return {"pos": s.pos, "label": s.label}

func status_text() -> String:
	if active.is_empty():
		return ""
	var d: Dictionary = active.def
	var s := current_stage()
	var txt := "%s — %s" % [d.title, s.label]
	var k := str(active.kind)
	if float(active.time_total) > 0.0:
		var tl := maxi(0, int(ceil(float(active.time_left))))
		txt += "  [%d:%02d]" % [tl / 60, tl % 60]
	if k == "race":
		match str(active.phase):
			"countdown": txt = "%s — Prepare-se! %d" % [d.title, int(ceil(float(active.cd)))]
			"race":
				txt += "  [tempo %ds · rival no checkpoint %d]" % [int(active.elapsed), _rival_cp()]
	elif k == "maya" and maya_aboard:
		txt += "  [sustos %d/3]" % int(active.strikes)
	elif float(s.hold) > 0.0 and float(active.hold) > 0.0:
		txt += "  [%d%%]" % int(100.0 * float(active.hold) / float(s.hold))
	elif k == "run" or k == "photo":
		txt += "  (%d/%d)" % [int(active.stage) + 1, (active.stages as Array).size()]
	return txt

# ---------------- corrida: rival ----------------
func _build_rival(nodes: Array, d: Dictionary) -> void:
	var full: Array = []
	var loop: Array = nodes.duplicate()
	loop.append(nodes[0])
	for k in range(loop.size() - 1):
		var seg := G.route(int(loop[k]), int(loop[k + 1]))
		for q in seg:
			if full.is_empty() or int(full[full.size() - 1]) != int(q):
				full.append(int(q))
	rival_path = []
	var total := 0.0
	var prev := Vector3.ZERO
	for k in full.size():
		var p := G.node_pos(int(full[k]))
		p.y = 0.5
		rival_path.append(p)
		if k > 0:
			total += prev.distance_to(p)
		prev = p
	rival_total = total
	rival_dist = 0.0
	var vmax: float = float(GameState.car_data(GameState.current_car).get("speed", 16.0))
	rival_speed = vmax * float(d.rival_k)
	var info: Dictionary = hub.traffic._make_model("civil", d.color)
	rival = info.node
	rival.visible = false
	var tag := Label3D.new()
	tag.text = str(d.rival)
	tag.font_size = 48
	tag.pixel_size = 0.01
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.modulate = Color(1.0, 0.6, 0.4)
	tag.outline_size = 10
	tag.position = Vector3(0, 3.0, 0)
	rival.add_child(tag)
	hub.add_child(rival)
	rival.position = rival_path[0] + Vector3(2.5, 0, 0)

func _rival_cp() -> int:
	# quantos checkpoints (nós da lista original) o rival já passou, aproximado pelo comprimento
	var stages: Array = active.stages
	var n := stages.size() - 1
	return clampi(int(float(n) * rival_dist / maxf(rival_total, 1.0)), 0, n)

func _move_rival(dt: float) -> void:
	if rival == null or rival_path.size() < 2:
		return
	rival_dist = minf(rival_total, rival_dist + rival_speed * dt)
	var acc := 0.0
	for k in range(rival_path.size() - 1):
		var a: Vector3 = rival_path[k]
		var b: Vector3 = rival_path[k + 1]
		var l := a.distance_to(b)
		if rival_dist <= acc + l or k == rival_path.size() - 2:
			var f := clampf((rival_dist - acc) / maxf(l, 0.01), 0.0, 1.0)
			var dir := (b - a).normalized()
			var pos := a.lerp(b, f) + G.right_of(dir) * 2.5
			rival.position = pos
			rival.rotation.y = lerp_angle(rival.rotation.y, atan2(-dir.x, -dir.z), minf(1.0, dt * 8.0))
			return
		acc += l

# ---------------- ciclo ----------------
func tick(delta: float) -> void:
	_strike_cd = maxf(0.0, _strike_cd - delta)
	if active.is_empty():
		return
	var a := active
	a.elapsed = float(a.elapsed) + delta
	if float(a.time_total) > 0.0:
		a.time_left = float(a.time_left) - delta
		if float(a.time_left) <= 0.0:
			fail("O tempo acabou!")
			return
	var k := str(a.kind)
	if k == "race":
		_tick_race(delta)
		return
	if k == "maya":
		_tick_maya(delta)
	_tick_reach(delta)

func _tick_reach(delta: float) -> void:
	var s := current_stage()
	if s.is_empty():
		return
	if str(s.kind) == "photo":
		return
	if bool(s.need_car) and not hub.in_car:
		return
	var pos: Vector3 = hub.ref_pos()
	var dd := Vector2(pos.x - s.pos.x, pos.z - s.pos.z).length()
	if dd < float(s.radius):
		if float(s.hold) > 0.0:
			active.hold = float(active.hold) + delta
			if float(active.hold) >= float(s.hold):
				_advance()
		else:
			_advance()
	else:
		active.hold = maxf(0.0, float(active.hold) - delta * 0.5)

func _tick_maya(delta: float) -> void:
	if not maya_aboard:
		return
	if hub.in_car and absf(hub.car_speed) > 21.0:
		_over_t += delta
		if _over_t > 1.5:
			_over_t = 0.0
			_strike("Maya: \"Mais devagar, por favor!\"")
	else:
		_over_t = maxf(0.0, _over_t - delta)

func _strike(msg: String) -> void:
	if _strike_cd > 0.0:
		return
	_strike_cd = 2.5
	active.strikes = int(active.strikes) + 1
	hub.toast(msg)
	if int(active.strikes) >= 3:
		GameState.bond = maxi(0, GameState.bond - 4)
		fail("A Maya se assustou e pediu para descer. Vínculo -4.")

func on_bump(_strength: float) -> void:
	if not active.is_empty() and str(active.kind) == "maya" and maya_aboard:
		_strike("Maya: \"Cuidado!!\" (batida)")

func _tick_race(delta: float) -> void:
	var a := active
	match str(a.phase):
		"to_start":
			_tick_reach(delta)
		"countdown":
			hub.lock_drive = true
			var prev := int(ceil(float(a.cd)))
			a.cd = float(a.cd) - delta
			var cur := int(ceil(float(a.cd)))
			if cur != prev and cur > 0:
				hub.banner(str(cur), 0.8)
			if float(a.cd) <= 0.0:
				a.phase = "race"
				a.stage = 1
				a.elapsed = 0.0
				hub.lock_drive = false
				hub.banner("JÁ!", 1.0)
				if rival:
					rival.visible = true
				rival_dist = 0.0
				hub.auto_gps_to_mission()
		"race":
			_move_rival(delta)
			_tick_reach(delta)
			if not active.is_empty() and rival_dist >= rival_total - 0.01:
				fail("%s cruzou a linha primeiro! Tente de novo amanhã." % active.def.rival)

func _advance() -> void:
	var a := active
	var d: Dictionary = a.def
	var k := str(a.kind)
	var idx := int(a.stage)
	if k == "delivery" and idx == 0:
		hub.toast("Encomenda coletada! Corra para a entrega.")
	elif k == "maya":
		if idx == 0:
			maya_aboard = true
			hub.toast("Maya entrou no carro. Dirija com calma.")
		elif idx == 1:
			hub.toast("Maya adorou a vista do Mirante!")
	elif k == "race" and idx == 0:
		a.phase = "countdown"
		a.cd = 3.5
		hub.banner("Prepare-se!", 1.0)
		return
	elif k == "race" and idx < (a.stages as Array).size() - 1:
		hub.toast("Checkpoint %d!" % idx)
	elif k == "photo":
		hub.flash()
	a.stage = idx + 1
	a.hold = 0.0
	if int(a.stage) >= (a.stages as Array).size():
		complete()
	else:
		hub.auto_gps_to_mission()
		hub.on_mission_changed()

func try_interact() -> bool:
	if active.is_empty() or str(active.kind) != "photo":
		return false
	var s := current_stage()
	var pos: Vector3 = hub.ref_pos()
	if Vector2(pos.x - s.pos.x, pos.z - s.pos.z).length() < float(s.radius):
		GameState.add_time(0.2)
		_advance()
		return true
	return false

func complete() -> void:
	var d: Dictionary = active.def
	var g := GameState
	var k := str(active.kind)
	var money := int(d.get("money", 0))
	money = int(money * (1.0 + minf(float(g.total_fame()), 60.0) * 0.01))
	var extra := ""
	if k == "delivery" and float(active.time_left) > 0.0:
		var tip := mini(int(money * 0.3), int(float(active.time_left) * 1.2))
		money += tip
		extra = " (gorjeta $%d)" % tip
	if k == "photo" and hub.city.has_item("camera"):
		money = int(money * 1.3)
		extra = " (bônus da Câmera Pro)"
	g.money += money
	g.fame += int(d.get("fame", 0))
	g.bond = mini(100, g.bond + int(d.get("bond", 0)))
	g.energy = clampf(g.energy + float(d.get("energy", 0)), 0.0, 100.0)
	if k == "run":
		hub.city.put("fitness", mini(10, hub.city.i("fitness") + 1))
	if k == "race":
		hub.city.add_i("races_won", 1)
	if k == "photo":
		hub.city.add_i("photos", 3)
	if k == "maya":
		g.last_date_day = g.day
		if g.gf_status == "none" and g.bond >= 40:
			g.gf_status = "dating"
	hub.city.mark_done(str(d.id), g.day)
	var msg := "MISSÃO CUMPRIDA: %s — %s%s" % [d.title, reward_text({"money": money, "fame": d.get("fame", 0), "bond": d.get("bond", 0), "energy": d.get("energy", 0)}), extra]
	hub.banner("Missão cumprida!", 2.2)
	hub.toast(msg)
	g.save_game()
	hub.city.save()
	_cleanup()
	hub.on_mission_changed()

func fail(reason: String) -> void:
	if active.is_empty():
		return
	hub.banner("Missão falhou", 2.0)
	hub.toast("%s — %s" % [active.def.title, reason])
	_cleanup()
	hub.on_mission_changed()
