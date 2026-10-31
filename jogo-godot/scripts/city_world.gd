extends RefCounted
## Geometria da cidade: ruas, calçadas, faixas, semáforos, bairros (centro, praia, subúrbio, lojas).

const G = preload("res://scripts/city_graph.gd")
const Mats = preload("res://scripts/materials.gd")
const Props = preload("res://scripts/props.gd")

var hub
var road_mat: StandardMaterial3D
var lamps: Array = []
var benches := {}          # a*1000+b -> {"pos": Vector3, "yaw": float}
var light_mats := {}       # node*2+axis -> StandardMaterial3D
var _light_last := {}
var parked_marks: Array = []

func _m(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	return HumanoidBuilder.make_mat(c, rough, metal)

func _box(pos: Vector3, size: Vector3, mat: Material, collide := false, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	(parent if parent else hub).add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

func _plane(pos: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hub.add_child(mi)
	return mi

func _multi(mesh: Mesh, mat: Material, xforms: Array, shadows := false) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hub.add_child(mmi)

func build() -> void:
	_ground()
	_roads()
	_blocks()
	_lights_and_lamps()
	_beach()
	_suburb_and_decor()
	_street_life()
	_gas_station()
	_labels()

# ---------------- terreno ----------------
func _ground() -> void:
	_plane(Vector3.ZERO, Vector2(460, 460), Mats.grass(Color(0.82, 0.95, 0.78)))
	var fb := StaticBody3D.new()
	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(460, 0.2, 460)
	fc.shape = fs
	fc.position = Vector3(0, -0.1, 0)
	fb.add_child(fc)
	hub.add_child(fb)
	# limites do mundo (paredes invisíveis)
	var walls := StaticBody3D.new()
	for w in [[Vector3(-200, 10, -15), Vector3(2, 20, 400)], [Vector3(200, 10, -15), Vector3(2, 20, 400)],
			[Vector3(0, 10, -200), Vector3(400, 20, 2)], [Vector3(0, 10, 168), Vector3(400, 20, 2)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = w[1]
		cs.shape = bs
		cs.position = w[0]
		walls.add_child(cs)
	hub.add_child(walls)

func _roads() -> void:
	road_mat = Mats.asphalt(0.45)
	for x in G.XS:
		_plane(Vector3(x, 0.02, 0), Vector2(8, 228), road_mat)
	for z in G.ZS:
		_plane(Vector3(0, 0.02, z), Vector2(338, 8), road_mat)
	# faixas tracejadas
	var dash_mat := _m(Color(0.85, 0.8, 0.45), 0.8)
	var dmv := BoxMesh.new()
	dmv.size = Vector3(0.25, 0.02, 2.6)
	var dmh := BoxMesh.new()
	dmh.size = Vector3(2.6, 0.02, 0.25)
	var xf_v: Array = []
	var xf_h: Array = []
	for x in G.XS:
		var z := -108.0
		while z <= 108.0:
			if _near_line(z, G.ZS, 11.0):
				z += 6.0
				continue
			xf_v.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.04, z)))
			z += 6.0
	for z in G.ZS:
		var x := -163.0
		while x <= 163.0:
			if _near_line(x, G.XS, 11.0):
				x += 6.0
				continue
			xf_h.append(Transform3D(Basis.IDENTITY, Vector3(x, 0.04, z)))
			x += 6.0
	_multi(dmv, dash_mat, xf_v)
	_multi(dmh, dash_mat, xf_h)
	# faixas de pedestre
	var cw_mat := _m(Color(0.88, 0.88, 0.86), 0.8)
	var cwa := BoxMesh.new()
	cwa.size = Vector3(2.4, 0.02, 0.5)   # listras sobre rua do eixo X
	var cwb := BoxMesh.new()
	cwb.size = Vector3(0.5, 0.02, 2.4)   # listras sobre rua do eixo Z
	var xa: Array = []
	var xb: Array = []
	for id in G.count():
		var p := G.node_pos(id)
		for sgn in [-1.0, 1.0]:
			var cx: float = p.x + sgn * G.WALK_LAT
			if absf(cx) <= 169.0:
				for k in 8:
					xa.append(Transform3D(Basis.IDENTITY, Vector3(cx, 0.045, p.z - 3.5 + k)))
			var cz: float = p.z + sgn * G.WALK_LAT
			if absf(cz) <= 114.0:
				for k in 8:
					xb.append(Transform3D(Basis.IDENTITY, Vector3(p.x - 3.5 + k, 0.045, cz)))
	_multi(cwa, cw_mat, xa)
	_multi(cwb, cw_mat, xb)

func _near_line(v: float, lines: Array, d: float) -> bool:
	for l in lines:
		if absf(v - float(l)) < d:
			return true
	return false

# ---------------- quarteirões / calçadas ----------------
func _blocks() -> void:
	var walk_mat := Mats.pavement(0.55)
	var shop_walk := Mats.pavement(0.42)
	var lawn := Mats.grass(Color(0.9, 1.0, 0.85))
	var lawn2 := Mats.grass(Color(1.05, 1.0, 0.8))
	for i in G.NX - 1:
		for j in G.NZ - 1:
			var x0: float = G.XS[i] + 4.0
			var x1: float = G.XS[i + 1] - 4.0
			var z0: float = G.ZS[j] + 4.0
			var z1: float = G.ZS[j + 1] - 4.0
			var c := Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
			var sz := Vector3(x1 - x0, 0.12, z1 - z0)
			var wm: StandardMaterial3D = shop_walk if i >= 4 else walk_mat
			_box(c + Vector3(0, 0.06, 0), sz, wm)
			if i <= 1:
				_plane(c + Vector3(0, 0.13, 0), Vector2(sz.x - 8.0, sz.z - 8.0), lawn if (i + j) % 2 == 0 else lawn2)
	# calçadas externas
	_box(Vector3(0, 0.06, -116), Vector3(342, 0.12, 4), walk_mat)
	_box(Vector3(0, 0.06, 116), Vector3(342, 0.12, 4), walk_mat)
	_box(Vector3(-171, 0.06, 0), Vector3(4, 0.12, 228), walk_mat)
	_box(Vector3(171, 0.06, 0), Vector3(4, 0.12, 228), walk_mat)

# ---------------- semáforos, postes, bancos ----------------
func _lights_and_lamps() -> void:
	var pole_mat := _m(Color(0.25, 0.26, 0.28), 0.5, 0.5)
	var head_mat := _m(Color(0.06, 0.06, 0.07), 0.6)
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = 4.2
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.5, 0.6, 0.5)
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.2
	bulb_mesh.height = 0.4
	bulb_mesh.radial_segments = 8
	bulb_mesh.rings = 4
	for id in G.count():
		for axis in [0, 1]:
			var bm := _m(Color(0.2, 1.0, 0.3), 0.3)
			bm.emission_enabled = true
			bm.emission = Color(0.2, 1.0, 0.3)
			bm.emission_energy_multiplier = 2.0
			light_mats[id * 2 + axis] = bm
		var p := G.node_pos(id)
		# [dx, dz, eixo, lado da lâmpada em z]
		for cfg in [[-7.0, -7.0, 1, -0.3], [7.0, 7.0, 1, 0.3], [-7.0, 7.0, 0, -0.3], [7.0, -7.0, 0, 0.3]]:
			var base := Vector3(p.x + float(cfg[0]), 0.0, p.z + float(cfg[1]))
			var pole := MeshInstance3D.new()
			pole.mesh = pole_mesh
			pole.material_override = pole_mat
			pole.position = base + Vector3(0, 2.1, 0)
			hub.add_child(pole)
			var head := MeshInstance3D.new()
			head.mesh = head_mesh
			head.material_override = head_mat
			head.position = base + Vector3(0, 4.4, 0)
			hub.add_child(head)
			var bulb := MeshInstance3D.new()
			bulb.mesh = bulb_mesh
			bulb.material_override = light_mats[id * 2 + int(cfg[2])]
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var off := Vector3(0, 0, float(cfg[3])) if int(cfg[2]) == 1 else Vector3(float(cfg[3]), 0, 0)
			bulb.position = base + Vector3(0, 4.4, 0) + off
			hub.add_child(bulb)
	# postes de rua e bancos nos pontos médios das ruas
	var lamp_pole := CylinderMesh.new()
	lamp_pole.top_radius = 0.07
	lamp_pole.bottom_radius = 0.1
	lamp_pole.height = 5.0
	var lamp_head := SphereMesh.new()
	lamp_head.radius = 0.28
	lamp_head.height = 0.56
	lamp_head.radial_segments = 10
	lamp_head.rings = 5
	var lp_mat := _m(Color(0.3, 0.3, 0.33), 0.5, 0.5)
	var lh_mat := _m(Color(1, 0.9, 0.6))
	lh_mat.emission_enabled = true
	lh_mat.emission = Color(1.0, 0.85, 0.5)
	lh_mat.emission_energy_multiplier = 2.0
	var idx := 0
	var bench_mat := _m(Color(0.42, 0.28, 0.16), 0.8)
	var bench_leg := _m(Color(0.15, 0.15, 0.17), 0.5, 0.4)
	for a in G.count():
		for b in G.neighbors(a):
			var A := G.node_pos(a)
			var B := G.node_pos(int(b))
			var d := (B - A).normalized()
			var r := G.right_of(d)
			var mid := (A + B) * 0.5
			# banco na calçada direita (para quem anda de a para b)
			if (a + int(b)) % 3 != 1:
				var bp := mid + r * 7.3
				benches[a * 1000 + int(b)] = {"pos": bp, "yaw": atan2(r.x, r.z)}
				_bench(bp, atan2(r.x, r.z), bench_mat, bench_leg)
			# poste (apenas uma vez por aresta: a < b)
			if a < int(b):
				var lp := mid - r * 7.9 + d * 8.0
				var pm := MeshInstance3D.new()
				pm.mesh = lamp_pole
				pm.material_override = lp_mat
				pm.position = lp + Vector3(0, 2.5, 0)
				hub.add_child(pm)
				var hm := MeshInstance3D.new()
				hm.mesh = lamp_head
				hm.material_override = lh_mat
				hm.position = lp + Vector3(0, 5.1, 0)
				hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				hub.add_child(hm)
				if idx % 2 == 0:
					var l := OmniLight3D.new()
					l.light_color = Color(1.0, 0.85, 0.55)
					l.omni_range = 18.0
					l.light_energy = 0.0
					l.position = lp + Vector3(0, 5.0, 0)
					hub.add_child(l)
					lamps.append(l)
				idx += 1

func _bench(pos: Vector3, yaw: float, wood: Material, legs: Material) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw   # frente do banco (+Z local) aponta para fora da rua? ajustado abaixo
	hub.add_child(root)
	_box(Vector3(0, 0.5, 0), Vector3(1.8, 0.1, 0.55), wood, false, root)
	_box(Vector3(0, 0.85, 0.28), Vector3(1.8, 0.45, 0.08), wood, false, root)
	_box(Vector3(-0.75, 0.25, 0), Vector3(0.1, 0.5, 0.5), legs, false, root)
	_box(Vector3(0.75, 0.25, 0), Vector3(0.1, 0.5, 0.5), legs, false, root)

func update_lights(t: float) -> void:
	for id in G.count():
		for axis in [0, 1]:
			var st := G.light_state(id, axis, t)
			var key: int = id * 2 + axis
			if _light_last.get(key, -1) == st:
				continue
			_light_last[key] = st
			var c := Color(0.2, 1.0, 0.3)
			if st == 1:
				c = Color(1.0, 0.85, 0.1)
			elif st == 2:
				c = Color(1.0, 0.12, 0.1)
			var m: StandardMaterial3D = light_mats[key]
			m.albedo_color = c
			m.emission = c

# ---------------- praia ----------------
func _beach() -> void:
	_plane(Vector3(0, 0.01, 139.5), Vector2(460, 51), Mats.sand(0.5))
	var sea_mat := _m(Color(0.08, 0.30, 0.50), 0.12, 0.25)
	sea_mat.emission_enabled = true
	sea_mat.emission = Color(0.04, 0.16, 0.30)
	sea_mat.emission_energy_multiplier = 0.5
	_plane(Vector3(0, -0.2, 285), Vector2(460, 240), sea_mat)
	var foam := _m(Color(0.92, 0.95, 0.96), 0.6)
	_plane(Vector3(0, 0.03, 164), Vector2(460, 2.0), foam)
	# calçadão
	_box(Vector3(0, 0.06, 118), Vector3(342, 0.12, 4), _m(Color(0.62, 0.58, 0.5), 0.9))
	# guarda-sóis
	var cols := [Color(0.9, 0.25, 0.25), Color(0.95, 0.75, 0.2), Color(0.25, 0.6, 0.9), Color(0.95, 0.95, 0.95)]
	var pole := CylinderMesh.new()
	pole.top_radius = 0.04
	pole.bottom_radius = 0.04
	pole.height = 2.4
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.7
	cone.height = 0.6
	cone.radial_segments = 10
	cone.rings = 1
	var pole_m := _m(Color(0.8, 0.8, 0.8), 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 14:
		var px := -140.0 + k * 21.0 + rng.randf_range(-4, 4)
		var pz := rng.randf_range(130.0, 156.0)
		if absf(px - 60.0) < 12.0 and pz < 146.0:
			continue
		var pi := MeshInstance3D.new()
		pi.mesh = pole
		pi.material_override = pole_m
		pi.position = Vector3(px, 1.2, pz)
		hub.add_child(pi)
		var ci := MeshInstance3D.new()
		ci.mesh = cone
		ci.material_override = _m(cols[k % cols.size()], 0.8)
		ci.position = Vector3(px, 2.5, pz)
		hub.add_child(ci)
		_box(Vector3(px + 1.6, 0.05, pz + 1.2), Vector3(0.9, 0.04, 1.8), _m(cols[(k + 1) % cols.size()], 0.9))
	# palmeiras
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.28
	trunk.height = 5.5
	trunk.radial_segments = 6
	var crown := SphereMesh.new()
	crown.radius = 2.0
	crown.height = 1.8
	crown.radial_segments = 8
	crown.rings = 4
	var trunk_m := Mats.bark(Color(0.85, 0.7, 0.5))
	var crown_m := Mats.leaves(Color(0.35, 0.62, 0.28))
	var xt: Array = []
	var xc: Array = []
	for k in 16:
		var px := -150.0 + k * 20.0
		var pz := 121.0 + (k % 3) * 1.2
		xt.append(Transform3D(Basis.IDENTITY, Vector3(px, 2.75, pz)))
		xc.append(Transform3D(Basis.IDENTITY, Vector3(px, 5.8, pz)))
	_multi(trunk, trunk_m, xt, true)
	_multi(crown, crown_m, xc, true)
	# mirante (deck de madeira) com guarda-corpo
	var wood := _m(Color(0.55, 0.40, 0.25), 0.85)
	_box(Vector3(60, 0.05, 144), Vector3(16, 0.1, 9), wood)
	for sx in [-8.0, 8.0]:
		_box(Vector3(60 + sx, 0.7, 144), Vector3(0.2, 1.4, 9), wood)
	_box(Vector3(60, 0.7, 148.4), Vector3(16, 1.4, 0.2), wood)
	var tag := Label3D.new()
	tag.text = "Mirante da Praia"
	tag.font_size = 64
	tag.pixel_size = 0.012
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.modulate = Color(0.8, 0.95, 1.0)
	tag.outline_size = 12
	tag.position = Vector3(60, 4.0, 144)
	hub.add_child(tag)

# ---------------- subúrbio, parque e árvores ----------------
func _suburb_and_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var house_cols := [Color(0.80, 0.72, 0.60), Color(0.70, 0.78, 0.72), Color(0.82, 0.62, 0.55), Color(0.68, 0.72, 0.82), Color(0.85, 0.82, 0.70)]
	var roof_m := _m(Color(0.45, 0.20, 0.16), 0.85)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.2
	trunk.bottom_radius = 0.3
	trunk.height = 2.4
	trunk.radial_segments = 6
	var crown := SphereMesh.new()
	crown.radius = 1.7
	crown.height = 3.2
	crown.radial_segments = 8
	crown.rings = 4
	var trunk_m := Mats.bark()
	var crown_m := Mats.leaves(Color(0.42, 0.72, 0.32))
	var xt: Array = []
	var xc: Array = []
	for i in G.NX - 1:
		for j in G.NZ - 1:
			var cx: float = (G.XS[i] + G.XS[i + 1]) * 0.5
			var cz: float = (G.ZS[j] + G.ZS[j + 1]) * 0.5
			if i == 0:
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						var hs := Vector3(rng.randf_range(7.5, 9.0), 3.6, rng.randf_range(6.5, 8.0))
						var hp := Vector3(cx + sx * 11.0, 0.0, cz + sz * 11.0)
						var h: Node3D = hub._building(hp, house_cols[rng.randi() % house_cols.size()], hs, "")
						var roof := MeshInstance3D.new()
						var pr := PrismMesh.new()
						pr.size = Vector3(hs.x + 1.0, 2.2, hs.z + 1.0)
						roof.mesh = pr
						roof.material_override = roof_m
						roof.position = Vector3(0, hs.y + 1.1, 0)
						h.add_child(roof)
						xt.append(Transform3D(Basis.IDENTITY, Vector3(hp.x + sx * 7.0, 1.2, hp.z + sz * 5.0 + 0.5)))
						xc.append(Transform3D(Basis.IDENTITY, Vector3(hp.x + sx * 7.0, 3.6, hp.z + sz * 5.0 + 0.5)))
			elif i == 1 and j == 0:
				# parque com fonte e árvores de verdade
				var fm := _m(Color(0.3, 0.55, 0.75), 0.15, 0.2)
				fm.emission_enabled = true
				fm.emission = Color(0.1, 0.3, 0.5)
				var fountain := CylinderMesh.new()
				fountain.top_radius = 4.0
				fountain.bottom_radius = 4.2
				fountain.height = 0.5
				var fi := MeshInstance3D.new()
				fi.mesh = fountain
				fi.material_override = fm
				fi.position = Vector3(cx, 0.3, cz)
				hub.add_child(fi)
				for k in 8:
					var ang := TAU * float(k) / 8.0
					var tree := Props.make_tree(["oak", "round", "pine", "oak"][k % 4])
					tree.position = Vector3(cx + cos(ang) * 13.5, 0.0, cz + sin(ang) * 13.5)
					hub.add_child(tree)
					if k % 2 == 0:
						var bush := Props.make_bush()
						bush.position = Vector3(cx + cos(ang + 0.4) * 8.0, 0.0, cz + sin(ang + 0.4) * 8.0)
						hub.add_child(bush)
			elif i == 1 and _clear_lot(Vector3(cx, 0, cz)):
				hub._building(Vector3(cx, 0, cz), house_cols[j % house_cols.size()], Vector3(11.0, 4.4, 9.0), "", "house")
			else:
				if i >= 2 and _clear_lot(Vector3(cx, 0, cz)):
					var bh := 8.0 + float((i * 3 + j * 5) % 5) * 4.0
					var bcol := Color(0.62, 0.64, 0.68).lerp(Color(0.32, 0.38, 0.5), clampf(float(i) / 5.0, 0.0, 1.0))
					var bstyle := "office" if i >= 4 or bh > 18.0 else "apartment"
					hub._building(Vector3(cx, 0, cz), bcol, Vector3(14.0, bh, 12.0), "", bstyle)
				for sx in [-1.0, 1.0]:
					for sz in [-1.0, 1.0]:
						var tx: float = cx + sx * 18.5
						var tz: float = cz + sz * 18.5
						xt.append(Transform3D(Basis.IDENTITY, Vector3(tx, 1.2, tz)))
						xc.append(Transform3D(Basis.IDENTITY, Vector3(tx, 3.6, tz)))
	_multi(trunk, trunk_m, xt, true)
	_multi(crown, crown_m, xc, true)

func _clear_lot(p: Vector3) -> bool:
	for id in hub.SPOTS.keys():
		var sp: Vector3 = hub.SPOTS[id].pos
		if Vector2(p.x - sp.x, p.z - sp.z).length() < 20.0:
			return false
	for f in hub.FILLERS:
		var fp: Vector3 = f
		if Vector2(p.x - fp.x, p.z - fp.z).length() < 16.0:
			return false
	return true

func _street_life() -> void:
	var bin_m := Mats.metal(Color(0.16, 0.4, 0.26), 0.55)
	var roof_m := Mats.metal(Color(0.78, 0.8, 0.84), 0.32)
	var pole_m := Mats.metal(Color(0.32, 0.34, 0.38), 0.45)
	var bench_m := Mats.wood(Color(0.48, 0.32, 0.18))
	for id in range(0, G.count(), 4):
		var p := G.node_pos(id)
		_box(p + Vector3(7.4, 0.45, 7.4), Vector3(0.55, 0.9, 0.55), bin_m)
	for sx in [-78.0, 22.0, 108.0]:
		var base := Vector3(sx, 0, 7.6)
		_box(base + Vector3(0, 2.55, 0), Vector3(3.4, 0.1, 1.5), roof_m)
		_box(base + Vector3(-1.45, 1.25, -0.55), Vector3(0.1, 2.5, 0.1), pole_m)
		_box(base + Vector3(1.45, 1.25, -0.55), Vector3(0.1, 2.5, 0.1), pole_m)
		_box(base + Vector3(0, 0.48, 0.15), Vector3(1.7, 0.1, 0.42), bench_m)
		var sign := Label3D.new()
		sign.text = "ÔNIBUS"
		sign.font_size = 40
		sign.pixel_size = 0.01
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.modulate = Color(0.9, 0.95, 1.0)
		sign.position = base + Vector3(0, 3.05, 0)
		hub.add_child(sign)
	var paints := [Color(0.8, 0.1, 0.12), Color(0.1, 0.22, 0.55), Color(0.92, 0.92, 0.9), Color(0.12, 0.12, 0.14), Color(0.18, 0.46, 0.3), Color(0.72, 0.55, 0.12)]
	var parks := [Vector3(-96, 0, 7.8), Vector3(-36, 0, -7.8), Vector3(46, 0, 7.8), Vector3(132, 0, -7.8), Vector3(-140, 0, 7.8), Vector3(70, 0, 62)]
	for i in parks.size():
		var car := Props.make_car(paints[i])
		car.position = parks[i]
		car.rotation.y = PI * 0.5 if parks[i].z > 0.0 else -PI * 0.5
		hub.add_child(car)

func _gas_station() -> void:
	var sp: Dictionary = hub.SPOTS["gas"]
	var p: Vector3 = sp.pos
	var base := Vector3(p.x, 0.0, p.z + 11.0)
	var roof_m := _m(Color(0.85, 0.85, 0.88), 0.4, 0.3)
	_box(base + Vector3(0, 4.7, 0), Vector3(14, 0.4, 8), roof_m)
	var pm := _m(Color(0.7, 0.7, 0.72), 0.5, 0.3)
	for sx in [-6.0, 6.0]:
		for sz in [-3.0, 3.0]:
			_box(base + Vector3(sx, 2.3, sz), Vector3(0.3, 4.6, 0.3), pm)
	var pump_m := _m(Color(0.85, 0.15, 0.12), 0.5)
	for sx in [-3.0, 3.0]:
		_box(base + Vector3(sx, 0.9, 0), Vector3(0.7, 1.8, 0.5), pump_m, true)
	var stripe := _m(Color(0.2, 0.7, 0.3), 0.5)
	stripe.emission_enabled = true
	stripe.emission = Color(0.2, 0.7, 0.3)
	stripe.emission_energy_multiplier = 0.8
	_box(base + Vector3(0, 4.7, 4.05), Vector3(14, 0.3, 0.1), stripe)

func _labels() -> void:
	for cfg in [["PRAIA", Vector3(0, 0.15, 150), 0.0], ["SUBÚRBIO", Vector3(-186, 0.15, 0), 90.0],
			["ZONA DE LOJAS", Vector3(186, 0.15, 0), -90.0], ["DISTRITO ESPORTIVO", Vector3(0, 0.15, -127), 0.0]]:
		var l := Label3D.new()
		l.text = cfg[0]
		l.font_size = 64
		l.pixel_size = 0.07
		l.modulate = Color(1, 1, 1, 0.55)
		l.outline_size = 0
		l.position = cfg[1]
		l.rotation_degrees = Vector3(-90, float(cfg[2]), 0)
		hub.add_child(l)
