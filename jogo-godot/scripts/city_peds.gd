extends RefCounted
## Pedestres com rotina: andam nas calçadas, esperam o sinal, atravessam na faixa e sentam em bancos.

const G = preload("res://scripts/city_graph.gd")

var hub
var peds: Array = []
var t := 0.0

func setup(h, count := 26) -> void:
	hub = h
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in count:
		var kit := Color.from_hsv(rng.randf(), 0.45, 0.55)
		var n: Node3D = HumanoidBuilder.build(kit, Color(0.12, 0.12, 0.16), Color(0.4, 0.4, 0.45), rng.randi() % 10, rng.randi() % 7, false, 0)
		hub.add_child(n)
		var from := rng.randi() % G.count()
		var nb := G.neighbors(from)
		var to: int = nb[rng.randi() % nb.size()]
		var p := {
			"node": n, "from": from, "to": to, "s": rng.randf_range(7.0, 48.0), "lat": G.WALK_LAT,
			"speed": rng.randf_range(1.4, 2.4), "state": "walk", "wait_t": 0.0, "bench_s": -1.0,
			"sit_t": 0.0, "dodge": Vector3.ZERO, "phase": rng.randf() * 6.0, "yaw": 0.0,
		}
		_pick_bench(p)
		peds.append(p)
		_place(p)

func _edge_len(p: Dictionary) -> float:
	return G.node_pos(int(p.from)).distance_to(G.node_pos(int(p.to)))

func _pick_bench(p: Dictionary) -> void:
	p.bench_s = -1.0
	var key: int = int(p.from) * 1000 + int(p.to)
	if hub.world and hub.world.benches.has(key) and randf() < 0.35:
		var half := _edge_len(p) * 0.5
		if float(p.s) < half - 1.0:
			p.bench_s = half

func _pos_on_edge(p: Dictionary) -> Vector3:
	var a := G.node_pos(int(p.from))
	var d := G.dir_between(int(p.from), int(p.to))
	return a + d * float(p.s) + G.right_of(d) * float(p.lat)

func _place(p: Dictionary) -> void:
	var n: Node3D = p.node
	var pos := _pos_on_edge(p) + (p.dodge as Vector3)
	pos.y = 0.12
	n.position = pos
	var d := G.dir_between(int(p.from), int(p.to))
	p.yaw = atan2(-d.x, -d.z)
	n.rotation.y = p.yaw

func update(delta: float) -> void:
	t += delta
	var car_pos := Vector3.ZERO
	var car_fast := false
	if hub.car and hub.in_car:
		car_pos = hub.car.global_position
		car_fast = absf(hub.car_speed) > 3.0
	for p in peds:
		_update_ped(p, delta, car_pos, car_fast)

func _update_ped(p: Dictionary, dt: float, car_pos: Vector3, car_fast: bool) -> void:
	var n: Node3D = p.node
	var a := G.node_pos(int(p.from))
	var tnode := int(p.to)
	var d := G.dir_between(int(p.from), tnode)
	var r := G.right_of(d)
	var L := _edge_len(p)
	var moving := false
	match String(p.state):
		"walk":
			p.s = float(p.s) + float(p.speed) * dt
			moving = true
			p.lat = move_toward(float(p.lat), G.WALK_LAT, dt * 3.0)
			if float(p.bench_s) > 0.0 and float(p.s) >= float(p.bench_s):
				p.state = "sit"
				p.sit_t = randf_range(9.0, 24.0)
				p.bench_s = -1.0
			elif float(p.s) >= L - 5.0:
				_decide(p, d, r, L)
		"wait":
			p.wait_t = float(p.wait_t) + dt
			if G.green_left(tnode, G.axis_of(d), t) > 4.5:
				p.state = "cross"
		"cross":
			p.s = float(p.s) + float(p.speed) * 1.25 * dt
			moving = true
			if float(p.s) >= L + 5.0:
				var nxt := _find_dir(tnode, d)
				if nxt < 0:
					nxt = int(p.from)
				p.from = tnode
				p.to = nxt
				p.s = 5.0
				p.state = "walk"
				_pick_bench(p)
		"sit":
			p.sit_t = float(p.sit_t) - dt
			if float(p.sit_t) <= 0.0:
				p.state = "walk"
				p.s = float(p.s) + 0.3
	# posição
	var pos: Vector3
	if String(p.state) == "sit":
		var key: int = int(p.from) * 1000 + int(p.to)
		var bench: Dictionary = hub.world.benches.get(key, {})
		if bench.is_empty():
			p.state = "walk"
			pos = a + d * float(p.s) + r * float(p.lat)
		else:
			pos = bench.pos
			pos.y = 0.0
			n.position = pos + Vector3(0, 0.12, 0)
			n.rotation.y = lerp_angle(n.rotation.y, float(bench.yaw), minf(1.0, dt * 6.0))
			return
	else:
		pos = a + d * float(p.s) + r * float(p.lat)
	# desvio do carro do jogador
	var dg: Vector3 = p.dodge
	if car_fast and Vector2(pos.x - car_pos.x, pos.z - car_pos.z).length() < 4.0:
		var away := Vector3(pos.x - car_pos.x, 0.0, pos.z - car_pos.z).normalized()
		dg = (dg + away * dt * 16.0).limit_length(3.5)
	else:
		dg = dg.move_toward(Vector3.ZERO, dt * 2.5)
	p.dodge = dg
	pos += dg
	var crossing := String(p.state) == "cross" or String(p.state) == "wait"
	pos.y = 0.02 if crossing else 0.12
	if moving:
		p.phase = float(p.phase) + dt * 8.0
		pos.y += absf(sin(float(p.phase))) * 0.06
	n.position = pos
	var want_yaw := atan2(-d.x, -d.z)
	n.rotation.y = lerp_angle(n.rotation.y, want_yaw, minf(1.0, dt * 8.0))
	preload("res://scripts/props.gd").update_walk(n, 1.8 if moving else 0.0, dt)

func _find_dir(tnode: int, d: Vector3) -> int:
	for nb in G.neighbors(tnode):
		if G.dir_between(tnode, int(nb)).dot(d) > 0.9:
			return int(nb)
	return -1

func _decide(p: Dictionary, d: Vector3, r: Vector3, _len: float) -> void:
	var tnode := int(p.to)
	var straight := _find_dir(tnode, d)
	var right := _find_dir(tnode, r)
	var opts: Array = []
	if straight >= 0:
		opts.append("straight")
	if right >= 0:
		opts.append("right")
		if straight >= 0:
			opts.append("right")
	if opts.is_empty():
		# canto da cidade: dá meia-volta
		var back := int(p.from)
		p.from = tnode
		p.to = back
		p.s = 5.0
		p.lat = -G.WALK_LAT
		_pick_bench(p)
		return
	var choice: String = opts[randi() % opts.size()]
	if choice == "straight":
		p.state = "wait"
		p.s = G.node_pos(tnode).distance_to(G.node_pos(int(p.from))) - 5.0
		p.wait_t = 0.0
	else:
		p.from = tnode
		p.to = right
		p.s = 6.0
		p.lat = 5.0
		_pick_bench(p)
