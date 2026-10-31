extends RefCounted
## Interior andável de cada local. E na porta entra; E no balcão abre o serviço; sair pela porta volta à rua.

const Mats = preload("res://scripts/materials.gd")
const Props = preload("res://scripts/props.gd")

const ORIGIN := Vector3(820, 0, 0)

const THEME := {
	"home": {"floor": "wood", "wall": Color(0.86, 0.80, 0.70), "accent": Color(0.42, 0.26, 0.16), "w": 14.0, "d": 12.0},
	"stadium": {"floor": "concrete", "wall": Color(0.32, 0.38, 0.44), "accent": Color(0.12, 0.42, 0.28), "w": 18.0, "d": 14.0},
	"cars": {"floor": "tile", "wall": Color(0.78, 0.78, 0.80), "accent": Color(0.15, 0.35, 0.55), "w": 16.0, "d": 12.0},
	"cafe": {"floor": "wood", "wall": Color(0.72, 0.58, 0.48), "accent": Color(0.45, 0.22, 0.16), "w": 12.0, "d": 10.0},
	"realestate": {"floor": "tile", "wall": Color(0.80, 0.84, 0.82), "accent": Color(0.20, 0.45, 0.42), "w": 12.0, "d": 10.0},
	"mall": {"floor": "tile", "wall": Color(0.82, 0.78, 0.84), "accent": Color(0.55, 0.25, 0.48), "w": 18.0, "d": 12.0},
	"gym": {"floor": "rubber", "wall": Color(0.28, 0.28, 0.30), "accent": Color(0.75, 0.25, 0.15), "w": 14.0, "d": 11.0},
	"restaurant": {"floor": "wood", "wall": Color(0.62, 0.32, 0.24), "accent": Color(0.72, 0.55, 0.28), "w": 14.0, "d": 11.0},
	"cinema": {"floor": "carpet", "wall": Color(0.16, 0.12, 0.22), "accent": Color(0.55, 0.15, 0.35), "w": 14.0, "d": 12.0},
	"clinic": {"floor": "tile", "wall": Color(0.86, 0.90, 0.90), "accent": Color(0.25, 0.55, 0.62), "w": 13.0, "d": 10.0},
	"bank": {"floor": "tile", "wall": Color(0.74, 0.78, 0.84), "accent": Color(0.15, 0.28, 0.48), "w": 14.0, "d": 10.0},
	"electro": {"floor": "tile", "wall": Color(0.70, 0.78, 0.84), "accent": Color(0.10, 0.55, 0.75), "w": 13.0, "d": 10.0},
	"gas": {"floor": "tile", "wall": Color(0.82, 0.82, 0.78), "accent": Color(0.75, 0.20, 0.15), "w": 10.0, "d": 8.0},
	"beach": {"floor": "wood", "wall": Color(0.90, 0.78, 0.55), "accent": Color(0.15, 0.55, 0.62), "w": 10.0, "d": 8.0},
	"board": {"floor": "concrete", "wall": Color(0.30, 0.42, 0.40), "accent": Color(0.85, 0.7, 0.25), "w": 12.0, "d": 9.0},
}

const PROMPT := {
	"home": "usar a casa (descanso e carreira)",
	"stadium": "ir ao vestiário",
	"cars": "falar com o vendedor",
	"cafe": "pedir no balcão",
	"realestate": "falar com o corretor",
	"mall": "ver as lojas",
	"gym": "treinar",
	"restaurant": "pedir uma mesa",
	"cinema": "comprar ingresso",
	"clinic": "atendimento",
	"bank": "ir ao caixa",
	"electro": "ver os produtos",
	"gas": "pagar no caixa",
	"beach": "pedir no quiosque",
	"board": "ver missões",
}

var hub
var root: Node3D
var active := ""
var place_title := ""
var return_pos := Vector3.ZERO
var stations: Array = []
var door_z := 0.0

func setup(h) -> void:
	hub = h

func enter(id: String) -> void:
	if active != "":
		_clear()
	var sp: Dictionary = hub.SPOTS[id]
	active = id
	place_title = str(sp.label)
	return_pos = _door_world(id)
	_build(id)
	hub.player.velocity = Vector3.ZERO
	hub.player.global_position = ORIGIN + Vector3(0, 0, door_z - 1.7)
	hub.player.rotation.y = 0.0
	if hub.panels.is_open(id):
		hub.toast("Você entrou em %s. Caminhe até o balcão." % place_title)
	else:
		hub.toast("%s está fechado, mas dá para olhar por dentro." % place_title)

func leave() -> void:
	var back := return_pos
	_clear()
	if hub.player:
		hub.player.velocity = Vector3.ZERO
		hub.player.global_position = back
		hub.player.rotation.y = 0.0

func tick() -> void:
	if active == "":
		return
	var p: Vector3 = hub.player.global_position
	if p.z > ORIGIN.z + door_z + 0.35:
		leave()
		return
	if not Input.is_action_just_pressed("interact"):
		return
	var best := nearest(p)
	if best.is_empty():
		return
	if str(best.kind) == "exit":
		leave()
	else:
		hub._open_spot(active)

func nearest(p: Vector3) -> Dictionary:
	var best := {}
	var best_d := 2.6
	for s in stations:
		var sp: Vector3 = s.pos
		var d := Vector2(p.x - sp.x, p.z - sp.z).length()
		if d < best_d:
			best_d = d
			best = s
	return best

func hint() -> String:
	var best := nearest(hub.player.global_position)
	if best.is_empty():
		return "WASD andar · vá ao balcão ou saia pela porta"
	return "WASD andar · E %s" % str(best.prompt)

func _clear() -> void:
	if root and is_instance_valid(root):
		root.queue_free()
	root = null
	stations.clear()
	active = ""
	place_title = ""

func _door_world(id: String) -> Vector3:
	var sp: Dictionary = hub.SPOTS[id]
	var p: Vector3 = sp.pos
	var s: Vector3 = sp.size
	return Vector3(p.x, 0.0, p.z + s.z * 0.5 + 5.6)

func _build(id: String) -> void:
	var th: Dictionary = THEME[id] if THEME.has(id) else THEME["cafe"]
	var w := float(th.w)
	var d := float(th.d)
	var h := 3.5
	var wall: Color = th.wall
	var accent: Color = th.accent
	door_z = d * 0.5
	root = Node3D.new()
	root.name = "Interior"
	root.position = ORIGIN
	hub.add_child(root)

	var floor_m := _floor_mat(str(th.floor), accent)
	var wall_m := Mats.concrete(wall)
	var trim := Mats.concrete(wall.lightened(0.25))
	_box(Vector3(0, -0.06, 0), Vector3(w + 0.4, 0.12, d + 0.4), floor_m, true)
	_box(Vector3(0, 0.02, d * 0.05), Vector3(w * 0.55, 0.03, d * 0.42), Mats.cloth(accent.darkened(0.15), 0.9))

	var t := 0.28
	_box(Vector3(0, h * 0.5, -d * 0.5), Vector3(w, h, t), wall_m, true)
	_box(Vector3(-w * 0.5, h * 0.5, 0), Vector3(t, h, d), wall_m, true)
	_box(Vector3(w * 0.5, h * 0.5, 0), Vector3(t, h, d), wall_m, true)
	var door_w := 2.4
	var side := (w - door_w) * 0.5
	_box(Vector3(-(door_w + side) * 0.5, h * 0.5, d * 0.5), Vector3(side, h, t), wall_m, true)
	_box(Vector3((door_w + side) * 0.5, h * 0.5, d * 0.5), Vector3(side, h, t), wall_m, true)
	_box(Vector3(0, h - 0.35, d * 0.5), Vector3(door_w, 0.7, t), trim, true)
	_box(Vector3(0, 0.08, d * 0.5 + 0.3), Vector3(door_w + 0.4, 0.08, 0.8), trim)

	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, h - 0.25, 0)
	lamp.omni_range = maxf(w, d)
	lamp.light_energy = 1.6
	lamp.light_color = Color(1.0, 0.94, 0.82)
	lamp.shadow_enabled = true
	root.add_child(lamp)
	var bulb := Mats.emissive(Color(1.0, 0.92, 0.7), 2.2)
	_box(Vector3(-w * 0.28, h - 0.18, -d * 0.15), Vector3(1.4, 0.08, 0.4), bulb)
	_box(Vector3(w * 0.28, h - 0.18, d * 0.15), Vector3(1.4, 0.08, 0.4), bulb)

	var exit_local := Vector3(0, 0, door_z - 1.15)
	stations.append({"pos": ORIGIN + exit_local, "kind": "exit", "prompt": "sair para a rua"})
	_label(exit_local + Vector3(0, 2.3, 0), "SAÍDA")

	var counter_z := -d * 0.5 + 1.55
	_counter(Vector3(0, 0, counter_z), accent, w * 0.62)
	var use_local := Vector3(0, 0, counter_z + 1.15)
	stations.append({
		"pos": ORIGIN + use_local,
		"kind": "use",
		"prompt": str(PROMPT.get(id, "falar no balcão")),
	})
	_label(Vector3(0, 2.15, counter_z), place_title if place_title != "" else "Balcão")
	_furnish(id, w, d, accent, wall)
	if id != "home":
		_clerk(Vector3(-1.8, 0, counter_z - 0.75), accent)

func _floor_mat(kind: String, accent: Color) -> Material:
	match kind:
		"wood":
			return Mats.wood(Color(0.72, 0.52, 0.32))
		"rubber":
			return Mats.shared(Color(0.12, 0.12, 0.13), 0.92)
		"carpet":
			return Mats.cloth(accent.darkened(0.35), 0.95)
		"tile":
			return Mats.pavement(0.8)
		_:
			return Mats.concrete(Color(0.7, 0.7, 0.68))

func _furnish(id: String, w: float, d: float, accent: Color, wall: Color) -> void:
	var wood := Mats.wood(Color(0.5, 0.34, 0.2))
	var cloth := Mats.cloth(accent, 0.8)
	match id:
		"home":
			_sofa(Vector3(-w * 0.22, 0, -0.4), cloth, wood)
			_tv(Vector3(-w * 0.22, 0, -d * 0.28))
			_table(Vector3(0.2, 0, 0.6), wood)
			_bed(Vector3(w * 0.28, 0, d * 0.12), cloth)
		"stadium":
			_bench_row(Vector3(0, 0, -1.0), 4, accent)
			_trophy(Vector3(w * 0.32, 0, d * 0.15))
			_stripes(Vector3(0, 0.02, 0.8), accent)
		"cars":
			_show_car(Vector3(-3.2, 0, -0.2), Color(0.75, 0.08, 0.1))
			_show_car(Vector3(3.2, 0, -0.2), Color(0.1, 0.25, 0.55))
		"cafe", "restaurant", "beach":
			_dining(Vector3(-2.4, 0, -0.6), wood, cloth)
			_dining(Vector3(2.2, 0, 0.8), wood, cloth)
		"cinema":
			_screen(Vector3(0, 1.7, -d * 0.5 + 0.35))
			_seat_rows(Vector3(0, 0, -0.4), accent)
		"gym":
			_mat(Vector3(-2.2, 0.02, -0.2), Color(0.15, 0.35, 0.55))
			_mat(Vector3(1.6, 0.02, 0.6), Color(0.55, 0.15, 0.15))
			_weights(Vector3(w * 0.28, 0, -d * 0.2))
		"clinic":
			_bed(Vector3(-2.4, 0, -0.2), Mats.cloth(Color(0.85, 0.9, 0.92), 0.8))
			_bed(Vector3(2.2, 0, 0.4), Mats.cloth(Color(0.85, 0.9, 0.92), 0.8))
		"bank":
			_glass_line(Vector3(0, 0, -d * 0.5 + 2.6), w * 0.7)
		"mall":
			_kiosk(Vector3(-4.2, 0, -0.2), Color(0.85, 0.35, 0.4), "ROUPAS")
			_kiosk(Vector3(4.0, 0, 0.4), Color(0.3, 0.55, 0.85), "ELETRÔNICOS")
		"electro":
			_shelf(Vector3(-3.0, 0, -0.4), Color(0.15, 0.7, 0.85))
			_shelf(Vector3(3.0, 0, 0.2), Color(0.9, 0.4, 0.2))
		"gas":
			_shelf(Vector3(-2.2, 0, -0.2), Color(0.2, 0.65, 0.3))
			_shelf(Vector3(2.0, 0, 0.3), Color(0.85, 0.2, 0.15))
		"board":
			_board(Vector3(0, 1.6, -d * 0.5 + 0.3), accent)
		"realestate":
			_table(Vector3(0, 0, 0.2), wood)
			_poster(Vector3(-w * 0.5 + 0.2, 1.6, -1.0), Color(0.2, 0.55, 0.5), true)
			_poster(Vector3(w * 0.5 - 0.2, 1.6, 0.6), Color(0.55, 0.35, 0.2), false)
		_:
			_table(Vector3(0, 0, 0), wood)
	if id == "cafe":
		_poster(Vector3(-w * 0.5 + 0.16, 1.7, 0.4), wall.darkened(0.2), true)

func _clerk(local: Vector3, accent: Color) -> void:
	var npc := HumanoidBuilder.build(accent, Color(0.15, 0.15, 0.18), Color(0.4, 0.4, 0.42), 3, 1, false, 0)
	npc.position = local
	npc.rotation.y = PI
	root.add_child(npc)

func _counter(local: Vector3, accent: Color, width: float) -> void:
	var top := Mats.wood(Color(0.45, 0.3, 0.18))
	var body := Mats.shared(accent.darkened(0.25), 0.7)
	_box(local + Vector3(0, 0.95, 0), Vector3(width, 0.1, 0.8), top)
	_box(local + Vector3(0, 0.48, 0.05), Vector3(width - 0.2, 0.9, 0.6), body)

func _sofa(local: Vector3, cloth: Material, wood: Material) -> void:
	_box(local + Vector3(0, 0.4, 0), Vector3(2.6, 0.45, 0.9), cloth)
	_box(local + Vector3(0, 0.85, 0.38), Vector3(2.6, 0.7, 0.18), cloth)
	_box(local + Vector3(-1.2, 0.7, 0), Vector3(0.18, 0.7, 0.9), wood)
	_box(local + Vector3(1.2, 0.7, 0), Vector3(0.18, 0.7, 0.9), wood)

func _tv(local: Vector3) -> void:
	_box(local + Vector3(0, 0.35, 0), Vector3(1.4, 0.5, 0.4), Mats.shared(Color(0.15, 0.15, 0.16), 0.6))
	_box(local + Vector3(0, 1.15, 0), Vector3(1.5, 0.9, 0.08), Mats.emissive(Color(0.35, 0.55, 0.85), 1.4))

func _table(local: Vector3, wood: Material) -> void:
	_box(local + Vector3(0, 0.72, 0), Vector3(1.3, 0.08, 0.8), wood)
	for sx in [-0.5, 0.5]:
		for sz in [-0.28, 0.28]:
			_box(local + Vector3(sx, 0.35, sz), Vector3(0.08, 0.7, 0.08), wood)

func _bed(local: Vector3, linen: Material) -> void:
	var frame := Mats.wood(Color(0.4, 0.26, 0.16))
	_box(local + Vector3(0, 0.35, 0), Vector3(2.1, 0.4, 1.3), frame)
	_box(local + Vector3(0, 0.62, 0), Vector3(2.0, 0.18, 1.2), linen)
	_box(local + Vector3(0, 0.8, 0.5), Vector3(1.2, 0.22, 0.35), linen)

func _dining(local: Vector3, wood: Material, cloth: Material) -> void:
	_table(local, wood)
	_box(local + Vector3(-0.7, 0.45, 0), Vector3(0.4, 0.5, 0.4), cloth)
	_box(local + Vector3(0.7, 0.45, 0), Vector3(0.4, 0.5, 0.4), cloth)

func _bench_row(local: Vector3, n: int, accent: Color) -> void:
	var m := Mats.shared(accent, 0.7)
	for i in n:
		_box(local + Vector3(-3.0 + float(i) * 2.0, 0.45, 0), Vector3(1.5, 0.4, 0.5), m)

func _trophy(local: Vector3) -> void:
	var gold := Mats.metal(Color(0.85, 0.7, 0.25), 0.25)
	_box(local + Vector3(0, 0.15, 0), Vector3(0.7, 0.3, 0.7), Mats.shared(Color(0.2, 0.2, 0.22), 0.5))
	_cyl(local + Vector3(0, 0.7, 0), 0.18, 0.7, gold)
	_cyl(local + Vector3(0, 1.15, 0), 0.28, 0.25, gold)

func _stripes(local: Vector3, accent: Color) -> void:
	var m := Mats.shared(accent, 0.8)
	for i in 5:
		_box(local + Vector3(-2.0 + float(i) * 1.0, 0, 0), Vector3(0.35, 0.02, 3.0), m)

func _show_car(local: Vector3, color: Color) -> void:
	var car := Props.make_car(color)
	car.position = local + Vector3(0, 0.15, 0)
	car.rotation.y = PI * 0.15
	root.add_child(car)
	_box(local + Vector3(0, 0.04, 0), Vector3(3.2, 0.06, 5.0), Mats.shared(Color(0.2, 0.2, 0.22), 0.5))

func _screen(local: Vector3) -> void:
	_box(local, Vector3(6.5, 2.6, 0.12), Mats.emissive(Color(0.15, 0.35, 0.7), 1.8))
	_box(local + Vector3(0, -1.5, 0.1), Vector3(6.8, 0.2, 0.3), Mats.shared(Color(0.08, 0.08, 0.1), 0.5))

func _seat_rows(local: Vector3, accent: Color) -> void:
	var m := Mats.cloth(accent, 0.85)
	for row in 3:
		for i in 5:
			_box(local + Vector3(-2.4 + float(i) * 1.2, 0.45, float(row) * 1.3), Vector3(0.7, 0.55, 0.55), m)

func _mat(local: Vector3, color: Color) -> void:
	_box(local, Vector3(2.4, 0.04, 3.2), Mats.shared(color, 0.9))

func _weights(local: Vector3) -> void:
	var iron := Mats.metal(Color(0.35, 0.35, 0.38), 0.4)
	_box(local + Vector3(0, 0.35, 0), Vector3(1.2, 0.5, 0.5), iron)
	_cyl(local + Vector3(0, 0.9, 0), 0.08, 1.4, iron)

func _glass_line(local: Vector3, width: float) -> void:
	_box(local + Vector3(0, 1.1, 0), Vector3(width, 1.3, 0.08), Mats.glass(0.45))
	for i in 3:
		_box(local + Vector3(-width * 0.33 + float(i) * width * 0.33, 1.1, 0), Vector3(0.08, 1.4, 0.12), Mats.metal(Color(0.6, 0.62, 0.66), 0.4))

func _kiosk(local: Vector3, color: Color, text: String) -> void:
	var m := Mats.shared(color, 0.6)
	_box(local + Vector3(0, 1.0, 0), Vector3(2.4, 2.0, 1.4), m)
	_box(local + Vector3(0, 1.1, 0.72), Vector3(1.6, 1.0, 0.06), Mats.storefront())
	_label(local + Vector3(0, 2.3, 0), text)

func _shelf(local: Vector3, glow: Color) -> void:
	var m := Mats.shared(Color(0.25, 0.27, 0.3), 0.6, 0.2)
	_box(local + Vector3(0, 0.9, 0), Vector3(1.6, 1.8, 0.45), m)
	_box(local + Vector3(0, 1.2, 0.24), Vector3(1.3, 0.7, 0.06), Mats.emissive(glow, 1.2))

func _board(local: Vector3, accent: Color) -> void:
	_box(local, Vector3(4.5, 2.2, 0.1), Mats.shared(Color(0.12, 0.16, 0.18), 0.7))
	_box(local + Vector3(-1.0, 0.3, 0.06), Vector3(1.4, 0.8, 0.04), Mats.emissive(accent, 0.8))
	_box(local + Vector3(0.9, -0.2, 0.06), Vector3(1.6, 0.6, 0.04), Mats.shared(Color(0.9, 0.9, 0.85), 0.8))

func _poster(local: Vector3, color: Color, on_left: bool) -> void:
	var n := Vector3(0.06 if on_left else -0.06, 0, 0)
	_box(local, Vector3(0.06, 1.3, 0.9), Mats.shared(color, 0.6))
	_box(local + n, Vector3(0.02, 0.9, 0.6), Mats.emissive(color.lightened(0.3), 0.4))

func _label(local: Vector3, text: String) -> void:
	var tag := Label3D.new()
	tag.text = text
	tag.font_size = 56
	tag.pixel_size = 0.01
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.modulate = Color(1, 0.95, 0.8)
	tag.outline_size = 10
	tag.position = local
	root.add_child(tag)

func _box(local: Vector3, size: Vector3, mat: Material, collide := false) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = local
	root.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)

func _cyl(local: Vector3, radius: float, height: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 12
	mi.mesh = c
	mi.material_override = mat
	mi.position = local
	root.add_child(mi)
