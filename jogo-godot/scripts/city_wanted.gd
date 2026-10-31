extends RefCounted
## Nível de procurado (design próprio, sem violência).
## Infrações somam "calor" (0-5 estrelas). Mais estrelas = mais viaturas e mais rápidas.
## Se uma viatura ficar perto de você, e você parado, há abordagem (multa e zera).
## Se ficar fora da vista por um tempo, as estrelas caem uma a uma.

const G = preload("res://scripts/city_graph.gd")
const MAX_HEAT := 5.0
const SPAWN_MIN := 75.0
const SPAWN_MAX := 130.0
const FAR_REMOVE := 190.0
const CATCH_DIST := 9.0

var hub
var heat := 0.0
var unseen := 0.0
var held := 0.0
var spawn_cd := 0.0
var label: Label
var _blink := 0.0

func setup(h) -> void:
	hub = h
	var layer := CanvasLayer.new()
	layer.layer = 4
	hub.add_child(layer)
	label = Label.new()
	label.position = Vector2(1000, 40)
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color(1.0, 0.35, 0.3)
	label.visible = false
	layer.add_child(label)

func stars() -> int:
	return clampi(int(ceil(heat - 0.001)), 0, int(MAX_HEAT))

func _police_on() -> bool:
	return hub.traffic != null and hub.traffic.police_on

func add_heat(amount: float, why: String) -> void:
	if not _police_on():
		return
	var before := stars()
	heat = minf(MAX_HEAT, heat + amount)
	if stars() > before:
		hub.toast("PROCURADO %s — %s" % ["★".repeat(stars()), why])

func clear() -> void:
	heat = 0.0
	unseen = 0.0
	held = 0.0
	_remove_extras(true)

func _player_pos() -> Vector3:
	return hub.ref_pos()

func _player_speed() -> float:
	return absf(hub.car_speed) if hub.in_car else hub.player.velocity.length()

func _police_cars() -> Array:
	var out: Array = []
	for c in hub.traffic.cars:
		if c.kind == "police":
			out.append(c)
	return out

func _remove_extras(all: bool) -> void:
	var pp := _player_pos()
	for c in hub.traffic.cars.duplicate():
		if not c.get("extra", false):
			continue
		var n: Node3D = c.node
		var d := n.position.distance_to(pp)
		if all or d > FAR_REMOVE:
			hub.traffic.cars.erase(c)
			n.queue_free()

func update(dt: float) -> void:
	if not _police_on():
		label.visible = false
		return
	var st := stars()
	# viaturas mais rápidas conforme o nível (o jogador em carro esportivo ainda escapa)
	for c in _police_cars():
		c.vmax = 10.0 + 1.6 * float(st)
	if heat <= 0.0:
		label.visible = false
		_remove_extras(false)
		return

	var pp := _player_pos()
	var nearest := 9999.0
	for c in _police_cars():
		if not (c.node as Node3D).visible:
			continue
		nearest = minf(nearest, (c.node as Node3D).position.distance_to(pp))

	# reforços: nascem fora da vista, em um anel ao redor do jogador
	spawn_cd = maxf(0.0, spawn_cd - dt)
	var extras := 0
	for c in hub.traffic.cars:
		if c.get("extra", false):
			extras += 1
	if extras < st and spawn_cd <= 0.0:
		spawn_cd = 3.0
		_spawn_reinforcement(pp)
	_remove_extras(false)

	# abordagem: viatura perto e você praticamente parado
	if nearest < CATCH_DIST and _player_speed() < 5.0:
		held += dt
		if held > 2.5:
			_busted()
			return
	else:
		held = maxf(0.0, held - dt * 2.0)

	# despiste: fora da vista de qualquer viatura
	if nearest > 55.0:
		unseen += dt
		heat = maxf(0.0, heat - 0.02 * dt)
		if unseen >= 7.0 + 3.0 * float(st):
			unseen = 0.0
			heat = maxf(0.0, float(st - 1))
			if heat <= 0.0:
				hub.toast("Você despistou a polícia.")
				clear()
				return
			hub.toast("Procurado diminuiu: %s" % "★".repeat(stars()))
	else:
		unseen = 0.0

	_blink += dt * (4.0 if nearest < 40.0 else 1.5)
	label.visible = true
	label.text = "PROCURADO  %s%s" % ["★".repeat(stars()), "☆".repeat(int(MAX_HEAT) - stars())]
	label.modulate.a = 0.65 + 0.35 * absf(sin(_blink))

func _busted() -> void:
	var st := stars()
	var amount := 120 * st
	hub.fine_player(amount, "abordagem policial (%d estrela%s)" % [st, "" if st == 1 else "s"])
	GameState.add_time(1.0)
	GameState.energy = maxf(0.0, GameState.energy - 10.0)
	hub.banner("ABORDADO — multa e liberado", 2.0)
	clear()

func _spawn_reinforcement(pp: Vector3) -> void:
	var cam: Camera3D = hub.camera
	var best := -1
	var tries := 0
	var order: Array = range(G.count())
	order.shuffle()
	for i in order:
		var np: Vector3 = G.node_pos(int(i))
		var d := Vector2(np.x - pp.x, np.z - pp.z).length()
		if d < SPAWN_MIN or d > SPAWN_MAX:
			continue
		if cam and cam.is_position_in_frustum(np + Vector3(0, 1, 0)) and d < SPAWN_MAX * 0.8:
			continue
		best = int(i)
		break
	if best < 0:
		return
	var c = hub.traffic.spawn_at("police", Color(0.93, 0.93, 0.96), best)
	if c:
		c.extra = true
