extends RefCounted
## Trânsito de IA: carros seguindo as ruas (retas e curvas), semáforos, buzina, colisão leve e patrulha.

const G = preload("res://scripts/city_graph.gd")
const Radio = preload("res://scripts/city_radio.gd")

const SPEED_LIMIT := 18.0        # unidades/s (~65 km/h)
const CAR_LEN := 4.6

var hub
var cars: Array = []
var t := 0.0
var horn_stream: AudioStreamWAV
var fine_cd := 0.0
var over_timer := 0.0
var warn_cd := 0.0
var police_on := true
var _wheel_mesh: CylinderMesh
var _wheel_mat: StandardMaterial3D
var _glass_mat: StandardMaterial3D

func setup(h, civil := 14, police := 2) -> void:
	hub = h
	horn_stream = Radio.make_horn(400.0, 0.3)
	_wheel_mesh = CylinderMesh.new()
	_wheel_mesh.top_radius = 0.38
	_wheel_mesh.bottom_radius = 0.38
	_wheel_mesh.height = 0.3
	_wheel_mat = HumanoidBuilder.make_mat(Color(0.05, 0.05, 0.05), 0.9)
	_glass_mat = HumanoidBuilder.make_mat(Color(0.08, 0.1, 0.14), 0.15, 0.6)
	var palette := [Color(0.75, 0.75, 0.78), Color(0.2, 0.3, 0.55), Color(0.6, 0.15, 0.15), Color(0.9, 0.85, 0.7),
		Color(0.15, 0.45, 0.35), Color(0.85, 0.5, 0.15), Color(0.25, 0.25, 0.28), Color(0.5, 0.35, 0.6)]
	for k in civil:
		_spawn("civil", palette[k % palette.size()])
	for k in police:
		_spawn("police", Color(0.93, 0.93, 0.96))

func set_police(on: bool) -> void:
	police_on = on
	for c in cars:
		if c.kind == "police":
			(c.node as Node3D).visible = on

# ---------------- criação ----------------
func _make_model(kind: String, color: Color) -> Dictionary:
	var root := Node3D.new()
	var model: Node3D = preload("res://scripts/props.gd").make_car(color)
	model.position = Vector3(0, -0.2, 0)
	root.add_child(model)
	var info := {"node": root, "bar_a": null, "bar_b": null}
	if kind == "police":
		var bar_blue := HumanoidBuilder.make_mat(Color(0.1, 0.2, 1.0))
		bar_blue.emission_enabled = true
		bar_blue.emission = Color(0.1, 0.2, 1.0)
		var bar_red := HumanoidBuilder.make_mat(Color(1.0, 0.1, 0.1))
		bar_red.emission_enabled = true
		bar_red.emission = Color(1.0, 0.1, 0.1)
		for k in 2:
			var bx := MeshInstance3D.new()
			var bbm := BoxMesh.new()
			bbm.size = Vector3(0.6, 0.18, 0.3)
			bx.mesh = bbm
			bx.material_override = bar_blue if k == 0 else bar_red
			bx.position = Vector3(-0.4 if k == 0 else 0.4, 1.3, 0.1)
			root.add_child(bx)
		var tag := Label3D.new()
		tag.text = "GUARDA"
		tag.font_size = 40
		tag.pixel_size = 0.008
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.modulate = Color(0.7, 0.8, 1.0)
		tag.position = Vector3(0, 2.0, 0)
		root.add_child(tag)
		info["bar_a"] = bar_blue
		info["bar_b"] = bar_red
	var horn := AudioStreamPlayer3D.new()
	horn.stream = horn_stream
	horn.unit_size = 22.0
	horn.max_distance = 90.0
	horn.volume_db = -4.0
	root.add_child(horn)
	info["horn"] = horn
	var hl_label := Label3D.new()
	hl_label.text = "BIIIP!"
	hl_label.font_size = 56
	hl_label.pixel_size = 0.01
	hl_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hl_label.no_depth_test = true
	hl_label.modulate = Color(1.0, 0.9, 0.3)
	hl_label.outline_size = 10
	hl_label.position = Vector3(0, 2.6, 0)
	hl_label.visible = false
	root.add_child(hl_label)
	info["honk_label"] = hl_label
	return info

func spawn_at(kind: String, color: Color, start_node: int):
	_spawn(kind, color, start_node)
	return cars.back() if not cars.is_empty() else null

func _spawn(kind: String, color: Color, start_node := -1) -> void:
	var info := _make_model(kind, color)
	var root: Node3D = info.node
	var from := 0
	var to := 0
	var pos := Vector3.ZERO
	var fd := Vector3.FORWARD
	for attempt in 30:
		from = start_node if start_node >= 0 else randi() % G.count()
		var nb := G.neighbors(from)
		to = nb[randi() % nb.size()]
		fd = G.dir_between(from, to)
		var frac := randf_range(0.25, 0.7)
		pos = G.node_pos(from).lerp(G.node_pos(to), frac) + G.right_of(fd) * G.LANE
		var free := true
		for o in cars:
			if (o.node as Node3D).position.distance_to(pos) < 10.0:
				free = false
				break
		if Vector2(pos.x - 30.0, pos.z + 20.0).length() < 14.0:
			free = false
		if free:
			break
	pos.y = 0.5
	root.position = pos
	root.rotation.y = atan2(-fd.x, -fd.z)
	hub.add_child(root)
	var entry := G.node_pos(to) - fd * 5.0 + G.right_of(fd) * G.LANE
	entry.y = 0.5
	var c := {
		"node": root, "kind": kind, "speed": 0.0, "vmax": randf_range(8.0, 12.5) if kind == "civil" else 10.0,
		"path": [entry], "pi": 0, "bez_end": 0, "from": from, "to": to, "fdir": fd, "dir": fd,
		"hold": 0.0, "blocked": 0.0, "honk_cd": randf_range(0.0, 4.0), "honk_t": 0.0,
		"horn": info.horn, "honk_label": info.honk_label, "bar_a": info.bar_a, "bar_b": info.bar_b,
	}
	cars.append(c)

# ---------------- rota ----------------
func _extend(c: Dictionary) -> void:
	var tnode: int = c.to
	var fd: Vector3 = c.fdir
	var T := G.node_pos(tnode)
	var r1 := G.right_of(fd)
	var cands: Array = []
	var weights: Array = []
	for n in G.neighbors(tnode):
		if int(n) == int(c.from):
			continue
		var d2 := G.dir_between(tnode, int(n))
		var dp := fd.dot(d2)
		var w := 0.55 if dp > 0.5 else (0.25 if d2.dot(r1) > 0.5 else 0.2)
		if c.kind == "police" and hub.wanted != null and hub.wanted.stars() > 0:
			var dd: float = G.node_pos(int(n)).distance_to(hub.ref_pos())
			w = 0.1 + 6.0 * pow(maxf(0.0, 1.0 - dd / 160.0), 2.0)
		cands.append(int(n))
		weights.append(w)
	var nxt: int = int(c.from)
	if not cands.is_empty():
		var sum := 0.0
		for w in weights:
			sum += float(w)
		var roll := randf() * sum
		nxt = int(cands[cands.size() - 1])
		for k in cands.size():
			roll -= float(weights[k])
			if roll <= 0.0:
				nxt = int(cands[k])
				break
	var d2n := G.dir_between(tnode, nxt)
	var r2 := G.right_of(d2n)
	var p0: Vector3 = T - fd * 5.0 + r1 * G.LANE
	var p2: Vector3 = T + d2n * 5.0 + r2 * G.LANE
	var pts: Array = []
	if fd.dot(d2n) > 0.5:
		pts.append(p2)
	else:
		var p1: Vector3 = T + r1 * G.LANE + r2 * G.LANE
		if fd.dot(d2n) < -0.5:
			p1 = T + r1 * G.LANE * 4.0
		for k in range(1, 7):
			var tt := float(k) / 6.0
			pts.append(p0 * (1.0 - tt) * (1.0 - tt) + p1 * 2.0 * (1.0 - tt) * tt + p2 * tt * tt)
	var entry := G.node_pos(nxt) - d2n * 5.0 + r2 * G.LANE
	for k in pts.size():
		var q: Vector3 = pts[k]
		q.y = 0.5
		pts[k] = q
	entry.y = 0.5
	var path: Array = pts
	path.append(entry)
	c.path = path
	c.pi = 0
	c.bez_end = pts.size()
	c.from = tnode
	c.to = nxt
	c.fdir = d2n

# ---------------- atualização ----------------
func update(delta: float) -> void:
	t += delta
	fine_cd = maxf(0.0, fine_cd - delta)
	warn_cd = maxf(0.0, warn_cd - delta)
	var rain_k: float = hub.weather.rain_k if hub.weather else 0.0
	var obstacles := _gather_obstacles()
	for c in cars:
		if c.kind == "police" and not police_on:
			continue
		_update_car(c, delta, obstacles, 1.0 - rain_k * 0.15)
	if hub.in_car and hub.car:
		_player_collisions()
	_update_police(delta)

func _gather_obstacles() -> Array:
	var out: Array = []
	if hub.car:
		var cp: Vector3 = hub.car.global_position
		out.append({"pos": cp, "who": "player", "speed": absf(hub.car_speed), "lat": 2.1})
	if not hub.in_car and hub.player:
		var pp: Vector3 = hub.player.global_position
		out.append({"pos": pp, "who": "walker", "speed": 0.0, "lat": 1.6})
	if hub.peds_sys:
		for p in hub.peds_sys.peds:
			var n: Node3D = p.node
			out.append({"pos": n.global_position, "who": "ped", "speed": 0.0, "lat": 1.3})
	return out

func _update_car(c: Dictionary, dt: float, obstacles: Array, vmult: float) -> void:
	var n: Node3D = c.node
	var pos: Vector3 = n.position
	var path: Array = c.path
	if int(c.pi) >= path.size():
		_extend(c)
		path = c.path
	var on_curve: bool = int(c.pi) < int(c.bez_end)
	var fwd: Vector3 = c.dir
	var right := G.right_of(fwd)
	var want: float = float(c.vmax) * vmult
	if on_curve:
		want = minf(want, 5.5)
	var limiter := ""
	# semáforo
	if not on_curve:
		var fdv: Vector3 = c.fdir
		var st := G.light_state(int(c.to), G.axis_of(fdv), t)
		if st != 0:
			var tp := G.node_pos(int(c.to))
			var gap := (tp - pos).dot(fdv) - G.CAR_STOP
			if gap > -1.5:
				var bd := float(c.speed) * float(c.speed) / 18.0
				if st == 2 or gap > bd + 1.0:
					want = minf(want, sqrt(maxf(0.0, 18.0 * maxf(gap, 0.0))))
	# obstáculos à frente (outros carros, jogador, pedestres)
	var ghost: bool = float(c.blocked) > 6.0
	if not ghost:
		for o in cars:
			if o == c:
				continue
			var on: Node3D = o.node
			if not on.visible:
				continue
			var rel := on.position - pos
			var ahead := rel.dot(fwd)
			if ahead < 0.5 or ahead > 14.0:
				continue
			if absf(rel.dot(right)) > 2.0:
				continue
			var gap2 := ahead - CAR_LEN
			want = minf(want, sqrt(maxf(0.0, 16.0 * maxf(gap2, 0.0))))
			if gap2 < 1.5:
				limiter = "car"
		for o in obstacles:
			var rel2: Vector3 = (o.pos as Vector3) - pos
			rel2.y = 0.0
			var ahead2 := rel2.dot(fwd)
			if ahead2 < 0.5 or ahead2 > 13.0:
				continue
			if absf(rel2.dot(right)) > float(o.lat):
				continue
			var gap3 := ahead2 - (CAR_LEN if o.who == "player" else 3.0)
			want = minf(want, sqrt(maxf(0.0, 16.0 * maxf(gap3, 0.0))))
			if gap3 < 2.0:
				limiter = String(o.who)
	if float(c.hold) > 0.0:
		c.hold = float(c.hold) - dt
		want = 0.0
	var sp: float = c.speed
	sp = move_toward(sp, want, (6.0 if want > sp else 16.0) * dt)
	c.speed = sp
	if sp < 0.3 and want < 0.5:
		c.blocked = float(c.blocked) + dt
	else:
		c.blocked = maxf(0.0, float(c.blocked) - dt * 2.0)
	# buzina quando bloqueado pelo jogador
	c.honk_cd = float(c.honk_cd) - dt
	if (limiter == "player" or limiter == "walker") and float(c.blocked) > 2.0 and float(c.honk_cd) <= 0.0:
		honk(c)
	if float(c.honk_t) > 0.0:
		c.honk_t = float(c.honk_t) - dt
		if float(c.honk_t) <= 0.0:
			(c.honk_label as Label3D).visible = false
	# movimento ao longo do caminho
	var remaining := sp * dt
	var moved_dir := fwd
	var guard := 0
	while remaining > 0.0001 and guard < 6:
		guard += 1
		if int(c.pi) >= path.size():
			break
		var tgt: Vector3 = path[int(c.pi)]
		var vec := tgt - pos
		vec.y = 0.0
		var dist := vec.length()
		if dist <= remaining:
			pos = Vector3(tgt.x, 0.5, tgt.z)
			remaining -= dist
			if dist > 0.01:
				moved_dir = vec / dist
			c.pi = int(c.pi) + 1
		else:
			moved_dir = vec / dist
			pos += moved_dir * remaining
			remaining = 0.0
	if int(c.pi) < path.size() and sp < 0.05:
		var tv: Vector3 = path[int(c.pi)] - pos
		tv.y = 0.0
		if tv.length() > 0.1:
			moved_dir = tv.normalized()
	c.dir = moved_dir
	n.position = pos
	var want_yaw := atan2(-moved_dir.x, -moved_dir.z)
	n.rotation.y = lerp_angle(n.rotation.y, want_yaw, minf(1.0, dt * 8.0))
	if c.kind == "police" and c.bar_a:
		var on_a := fmod(t, 0.5) < 0.25
		(c.bar_a as StandardMaterial3D).emission_energy_multiplier = 4.0 if on_a else 0.2
		(c.bar_b as StandardMaterial3D).emission_energy_multiplier = 0.2 if on_a else 4.0

func honk(c: Dictionary) -> void:
	c.honk_cd = randf_range(3.5, 6.0)
	(c.horn as AudioStreamPlayer3D).play()
	(c.honk_label as Label3D).visible = true
	c.honk_t = 0.9

## Buzina do jogador: carros próximos à frente reagem.
func player_honk() -> void:
	if not hub.car:
		return
	var cp: Vector3 = hub.car.global_position
	for c in cars:
		var n: Node3D = c.node
		if n.position.distance_to(cp) < 14.0 and float(c.honk_cd) < 1.0 and randf() < 0.35:
			c.honk_cd = randf_range(0.5, 1.5)

func _player_collisions() -> void:
	var cp: Vector3 = hub.car.global_position
	for c in cars:
		var n: Node3D = c.node
		if not n.visible:
			continue
		var flat := Vector3(cp.x - n.position.x, 0.0, cp.z - n.position.z)
		var dist := flat.length()
		if dist < 3.1:
			var nrm := flat / maxf(dist, 0.01)
			hub.car.global_position += nrm * (3.1 - dist)
			var imp := absf(hub.car_speed)
			if imp > 1.5:
				hub.car_speed *= 0.45
				hub.on_bump(imp, c.kind == "police")
				c.hold = 1.4
				c.speed *= 0.3
				honk(c)

# ---------------- polícia ----------------
func _update_police(dt: float) -> void:
	if not police_on or not hub.in_car or not hub.car:
		over_timer = 0.0
		return
	var cp: Vector3 = hub.car.global_position
	var sp := absf(hub.car_speed)
	var near := false
	var near_d := 999.0
	for c in cars:
		if c.kind != "police":
			continue
		var d: float = (c.node as Node3D).position.distance_to(cp)
		near_d = minf(near_d, d)
		if d < 42.0:
			near = true
	if near and hub.city.has_item("radar") and warn_cd <= 0.0 and near_d > 14.0:
		warn_cd = 25.0
		hub.toast("Detector de radar: viatura da Guarda por perto (limite 65 km/h).")
	if near and sp > SPEED_LIMIT + 2.0:
		over_timer += dt
	else:
		over_timer = maxf(0.0, over_timer - dt)
	if over_timer > 1.2 and fine_cd <= 0.0:
		over_timer = 0.0
		fine_cd = 30.0
		var amount := 30 + int((sp - SPEED_LIMIT) * 5.0)
		if hub.city.has_item("radar"):
			amount = int(amount * 0.6)
		hub.fine_player(amount, "excesso de velocidade (%d km/h)" % int(sp * 3.6))
		if hub.wanted != null:
			hub.wanted.add_heat(1.0 if sp < SPEED_LIMIT * 1.6 else 2.0, "excesso de velocidade")
