extends RefCounted
## Props procedurais ORIGINAIS: carros, predios, arvores, bancos, postes e
## animacao de caminhada/corrida dos humanoides. Sem class_name; use:
##   const Props = preload("res://scripts/props.gd")
## Convencao: Y para cima, origem na base. Carro: frente = -Z (4.2 x 1.9 m).
## Predio/banco: frente (porta/assento) = +Z.

const Mats = preload("res://scripts/materials.gd")

static var _cache: Dictionary = {}
static var _counter: int = 0

# ================================================================ utilitarios de malha

static func _prim_box(size: Vector3) -> BoxMesh:
	var key := "pb%s" % str(size)
	if _cache.has(key):
		return _cache[key]
	var b := BoxMesh.new()
	b.size = size
	_cache[key] = b
	return b

static func _prim_cyl(top: float, bottom: float, h: float, seg := 16) -> CylinderMesh:
	var key := "pc%.3f_%.3f_%.3f_%d" % [top, bottom, h, seg]
	if _cache.has(key):
		return _cache[key]
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	_cache[key] = c
	return c

static func _prim_sphere(seg := 12) -> SphereMesh:
	var key := "ps%d" % seg
	if _cache.has(key):
		return _cache[key]
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = seg
	s.rings = maxi(seg / 2, 4)
	_cache[key] = s
	return s

static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, scale := Vector3.ONE, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func _xf(pos: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO) -> Transform3D:
	var b := Basis.from_euler(rot)
	b = b.scaled(scale)
	return Transform3D(b, pos)

## Funde varias primitivas em UMA superficie (cor por vertice opcional).
## items: Array de {mesh, xf, color?}
static func _merge_surface(am: ArrayMesh, items: Array) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for it in items:
		var mesh: Mesh = it["mesh"]
		var xf: Transform3D = it["xf"]
		var col: Color = it.get("color", Color.WHITE)
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var arr := mesh.surface_get_arrays(0)
		if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
			continue
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var uv = arr[Mesh.ARRAY_TEX_UV]
		var idx = arr[Mesh.ARRAY_INDEX]
		var base := verts.size()
		var nb := xf.basis.inverse().transposed()
		for i in v.size():
			verts.append(xf * v[i])
			normals.append((nb * n[i]).normalized())
			uvs.append(uv[i] if uv != null and uv.size() == v.size() else Vector2.ZERO)
			colors.append(col)
		if idx != null and idx.size() > 0:
			for i in idx.size():
				indices.append(base + idx[i])
		else:
			for i in v.size():
				indices.append(base + i)
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

static func _merged(items: Array) -> ArrayMesh:
	var am := ArrayMesh.new()
	_merge_surface(am, items)
	return am

static func _item(mesh: Mesh, pos: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO, color := Color.WHITE) -> Dictionary:
	return {"mesh": mesh, "xf": _xf(pos, scale, rot), "color": color}

## Cria MeshInstance3D a partir de itens fundidos (nulo se vazio, ex.: headless).
static func _merged_mi(parent: Node3D, items: Array, mat: Material, shadow := true) -> MeshInstance3D:
	var am := _merged(items)
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mat
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

# ================================================================ loft (carroceria)

static func _ring_pts(w: float, y0: float, y1: float, r: float, steps: int) -> PackedVector2Array:
	var rr := maxf(0.001, minf(r, minf(w, (y1 - y0) * 0.5)))
	var pts := PackedVector2Array()
	var cs := [
		[w - rr, y0 + rr, -90.0],
		[w - rr, y1 - rr, 0.0],
		[-w + rr, y1 - rr, 90.0],
		[-w + rr, y0 + rr, 180.0],
	]
	for c in cs:
		for s in steps + 1:
			var a := deg_to_rad(float(c[2]) + 90.0 * float(s) / float(steps))
			pts.append(Vector2(float(c[0]) + cos(a) * rr, float(c[1]) + sin(a) * rr))
	return pts

## stations: [z, meia_largura, y_baixo, y_cima, raio]. Normais suaves, tampas nas pontas.
static func _loft(stations: Array, steps := 4) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for s in stations:
		var pts := _ring_pts(float(s[1]), float(s[2]), float(s[3]), float(s[4]), steps)
		var z := float(s[0])
		var arr: Array[Vector3] = []
		for p in pts:
			arr.append(Vector3(p.x, p.y, z))
		rings.append(arr)
	var n: int = (rings[0] as Array).size()
	for k in rings.size() - 1:
		var r0: Array = rings[k]
		var r1: Array = rings[k + 1]
		for i in n:
			var j := (i + 1) % n
			var a: Vector3 = r0[i]
			var b: Vector3 = r1[i]
			var c: Vector3 = r0[j]
			var d: Vector3 = r1[j]
			st.add_vertex(a)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(d)
			st.add_vertex(c)
	# tampas
	for e in 2:
		var ring: Array = rings[0] if e == 0 else rings[rings.size() - 1]
		var ctr := Vector3.ZERO
		for p in ring:
			ctr += p
		ctr /= float(ring.size())
		for i in n:
			var j := (i + 1) % n
			if e == 0:
				st.add_vertex(ctr)
				st.add_vertex(ring[i])
				st.add_vertex(ring[j])
			else:
				st.add_vertex(ctr)
				st.add_vertex(ring[j])
				st.add_vertex(ring[i])
	st.generate_normals()
	return st.commit()

# ================================================================ CARRO

static var _paint_cache: Dictionary = {}

static func _paint(color: Color) -> StandardMaterial3D:
	var k := color.to_html(false)
	if not _paint_cache.has(k):
		_paint_cache[k] = Mats.car_paint(color)
	return _paint_cache[k]

static func _wheel_mesh() -> ArrayMesh:
	if _cache.has("wheel"):
		return _cache["wheel"]
	var am := ArrayMesh.new()
	var rot_x := Vector3(0, 0, PI / 2.0)
	# superficie 0: pneu
	_merge_surface(am, [
		_item(_prim_cyl(0.34, 0.34, 0.24, 24), Vector3.ZERO, Vector3.ONE, rot_x),
	])
	# superficie 1: aro + raios + miolo
	var rim: Array = [
		_item(_prim_cyl(0.235, 0.235, 0.25, 20), Vector3.ZERO, Vector3.ONE, rot_x),
		_item(_prim_cyl(0.05, 0.05, 0.27, 10), Vector3.ZERO, Vector3.ONE, rot_x),
	]
	for i in 5:
		var ang := float(i) * TAU / 10.0
		rim.append(_item(_prim_box(Vector3(0.03, 0.46, 0.045)), Vector3(0.122, 0, 0), Vector3.ONE, Vector3(ang, 0, 0)))
	_merge_surface(am, rim)
	_cache["wheel"] = am
	return am

static func _wheel_arches() -> ArrayMesh:
	if _cache.has("arches"):
		return _cache["arches"]
	var items: Array = []
	for sx in [-1.0, 1.0]:
		for z in [-1.32, 1.32]:
			items.append(_item(_prim_cyl(0.40, 0.40, 0.03, 20), Vector3(sx * 0.945, 0.34, z), Vector3.ONE, Vector3(0, 0, PI / 2.0)))
	var am := _merged(items)
	_cache["arches"] = am
	return am

static func _car_body_mesh() -> ArrayMesh:
	if _cache.has("car_body"):
		return _cache["car_body"]
	var m := _loft([
		[-2.10, 0.66, 0.44, 0.64, 0.12],
		[-2.03, 0.80, 0.37, 0.70, 0.18],
		[-1.85, 0.89, 0.31, 0.80, 0.22],
		[-1.40, 0.94, 0.28, 0.88, 0.22],
		[-0.60, 0.95, 0.27, 0.92, 0.22],
		[0.80, 0.95, 0.27, 0.93, 0.22],
		[1.50, 0.94, 0.28, 0.95, 0.22],
		[1.95, 0.88, 0.33, 0.92, 0.2],
		[2.08, 0.76, 0.39, 0.82, 0.16],
		[2.10, 0.66, 0.43, 0.74, 0.12],
	], 5)
	_cache["car_body"] = m
	return m

static func _car_cabin_mesh() -> ArrayMesh:
	if _cache.has("car_cabin"):
		return _cache["car_cabin"]
	var m := _loft([
		[-0.72, 0.82, 0.86, 0.90, 0.02],
		[-0.25, 0.78, 0.86, 1.33, 0.2],
		[0.20, 0.78, 0.86, 1.40, 0.2],
		[0.75, 0.78, 0.86, 1.39, 0.2],
		[1.15, 0.80, 0.86, 1.24, 0.2],
		[1.45, 0.84, 0.86, 0.98, 0.1],
		[1.52, 0.84, 0.86, 0.90, 0.05],
	], 5)
	_cache["car_cabin"] = m
	return m

static func _car_roof_mesh() -> ArrayMesh:
	if _cache.has("car_roof"):
		return _cache["car_roof"]
	var m := _loft([
		[-0.25, 0.784, 1.275, 1.335, 0.2],
		[0.20, 0.784, 1.345, 1.405, 0.2],
		[0.75, 0.784, 1.335, 1.395, 0.2],
		[1.15, 0.804, 1.185, 1.245, 0.2],
	], 5)
	_cache["car_roof"] = m
	return m

## Carro com carroceria arredondada (loft), vidros, rodas giraveis, farois e lanternas.
## Frente = -Z, ~4.2 m x 1.9 m x 1.42 m. Nos: WheelFL/FR/RL/RR (pivo) > Spin (malha).
static func make_car(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Car"
	var paint := _paint(color)
	var dark := Mats.shared(Color(0.02, 0.02, 0.025), 0.5, 0.2)
	var chrome := Mats.metal(Color(0.75, 0.77, 0.8), 0.18)

	_mi(root, _car_body_mesh(), paint)
	_mi(root, _car_cabin_mesh(), Mats.tinted_glass())
	_mi(root, _car_roof_mesh(), paint)
	# colunas (B) ao redor do vidro
	_mi(root, _prim_box(Vector3(1.58, 0.52, 0.09)), paint, Vector3(0, 1.12, 0.33))
	# soleira/assoalho escuro e para-choques
	_mi(root, _prim_box(Vector3(1.7, 0.1, 3.9)), dark, Vector3(0, 0.24, 0), Vector3.ONE, Vector3.ZERO, false)
	_mi(root, _prim_box(Vector3(1.45, 0.1, 0.12)), dark, Vector3(0, 0.35, -2.04), Vector3.ONE, Vector3.ZERO, false)
	_mi(root, _prim_box(Vector3(1.5, 0.08, 0.12)), dark, Vector3(0, 0.36, 2.03), Vector3.ONE, Vector3.ZERO, false)
	# grade + placas
	_mi(root, _prim_box(Vector3(0.7, 0.075, 0.02)), dark, Vector3(0, 0.58, -2.095), Vector3.ONE, Vector3(0.15, 0, 0), false)
	_mi(root, _prim_box(Vector3(0.7, 0.012, 0.022)), chrome, Vector3(0, 0.62, -2.098), Vector3.ONE, Vector3(0.15, 0, 0), false)
	var plate := Mats.shared(Color(0.93, 0.93, 0.9), 0.4)
	_mi(root, _prim_box(Vector3(0.46, 0.11, 0.012)), plate, Vector3(0, 0.49, -2.105), Vector3.ONE, Vector3.ZERO, false)
	_mi(root, _prim_box(Vector3(0.46, 0.11, 0.012)), plate, Vector3(0, 0.62, 2.1), Vector3.ONE, Vector3.ZERO, false)
	# farois (frente) e lanternas (tras)
	var head_m := Mats.emissive(Color(1.0, 0.95, 0.8), 1.2)
	var tail_m := Mats.emissive(Color(0.9, 0.04, 0.03), 1.4)
	for sx in [-1.0, 1.0]:
		_mi(root, _prim_sphere(10), head_m, Vector3(sx * 0.62, 0.68, -1.93), Vector3(0.2, 0.06, 0.09), Vector3(0.1, sx * -0.35, 0), false)
		_mi(root, _prim_box(Vector3(0.3, 0.09, 0.05)), tail_m, Vector3(sx * 0.66, 0.78, 2.01), Vector3.ONE, Vector3(0, sx * 0.25, 0), false)
		# retrovisores
		_mi(root, _prim_box(Vector3(0.13, 0.09, 0.07)), paint, Vector3(sx * 1.0, 1.0, -0.5), Vector3.ONE, Vector3(0, sx * 0.2, 0), false)
		_mi(root, _prim_box(Vector3(0.05, 0.03, 0.05)), dark, Vector3(sx * 0.92, 0.97, -0.5), Vector3.ONE, Vector3.ZERO, false)
	# arcos de roda (sombra) e rodas
	_mi(root, _wheel_arches(), dark, Vector3.ZERO, Vector3.ONE, Vector3.ZERO, false)
	var tire := Mats.rubber()
	var rim_m := Mats.metal(Color(0.72, 0.74, 0.78), 0.25)
	var wheels := {}
	for sx_i in [-1, 1]:
		for zi in [-1, 1]:
			var nm := "Wheel" + ("F" if zi < 0 else "R") + ("L" if sx_i < 0 else "R")
			var piv := Node3D.new()
			piv.name = nm
			piv.position = Vector3(float(sx_i) * 0.91, 0.34, float(zi) * 1.32)
			root.add_child(piv)
			var spin := MeshInstance3D.new()
			spin.name = "Spin"
			spin.mesh = _wheel_mesh()
			spin.set_surface_override_material(0, tire)
			if spin.mesh.get_surface_count() > 1:
				spin.set_surface_override_material(1, rim_m)
			piv.add_child(spin)
			wheels[nm] = piv
	root.set_meta("wheels", wheels)
	return root

## Gira as rodas conforme a distancia percorrida (m) para frente (-Z).
static func spin_wheels(car: Node3D, distance: float) -> void:
	if not car.has_meta("wheels"):
		return
	var w: Dictionary = car.get_meta("wheels")
	for k in w:
		var spin: Node3D = (w[k] as Node3D).get_node_or_null("Spin")
		if spin:
			spin.rotation.x = wrapf(spin.rotation.x - distance / 0.34, -TAU, TAU)

## Esterca as rodas dianteiras (rad; positivo = esquerda).
static func steer_wheels(car: Node3D, angle: float) -> void:
	if not car.has_meta("wheels"):
		return
	var w: Dictionary = car.get_meta("wheels")
	for k in ["WheelFL", "WheelFR"]:
		if w.has(k):
			(w[k] as Node3D).rotation.y = angle

# ================================================================ PREDIO

static func _roof_tile_mat(color: Color) -> StandardMaterial3D:
	var a := Mats.noise_albedo("tiles", Color(0.7, 0.7, 0.7), Color(1.0, 1.0, 1.0), 101, 0.08, 64)
	var m := StandardMaterial3D.new()
	m.albedo_texture = a
	m.albedo_color = color
	m.roughness = 0.8
	m.normal_enabled = true
	m.normal_texture = Mats.noise_normal("tiles", 102, 0.15, 3.0, 64)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.2, 1.2, 1.2)
	return m

## Predio com fachada texturizada (janelas), base, platibanda, entrada e telhado.
## style: "apartment" | "office" | "shop" | "house" | "industrial". Frente = +Z.
static func make_building(size: Vector3, color: Color, style: String = "apartment") -> Node3D:
	_counter += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = _counter * 7919 + int(size.x * 13.0 + size.y * 7.0)
	var root := Node3D.new()
	root.name = "Building_" + style
	var floor_target := 2.9 if style == "house" else (3.6 if style == "industrial" else 3.2)
	var floors := maxi(1, roundi(size.y / floor_target))
	var floor_h := size.y / float(floors)
	var bays_x := maxi(1, roundi(size.x / 3.4))
	var bays_z := maxi(1, roundi(size.z / 3.4))
	var bw_x := size.x / float(bays_x)
	var bw_z := size.z / float(bays_z)
	var wall_mat := Mats.facade_material(style, color, bays_x, bays_z, floors, bw_x, bw_z, floor_h)
	var body := _mi(root, _prim_box(size), wall_mat, Vector3(0, size.y * 0.5, 0))
	body.name = "Walls"
	var trim := Mats.concrete(color.lightened(0.35).lerp(Color(0.8, 0.8, 0.78), 0.5))
	var dark := Mats.shared(Color(0.08, 0.08, 0.09), 0.6, 0.3)
	var glass := Mats.tinted_glass()
	var fz := size.z * 0.5

	# embasamento
	_mi(root, _prim_box(Vector3(size.x + 0.12, 0.45, size.z + 0.12)), Mats.concrete(Color(0.5, 0.5, 0.5)), Vector3(0, 0.225, 0))

	# entrada / loja na frente (+Z)
	match style:
		"shop", "office":
			var sh := 3.0
			var sw := maxf(size.x - 0.8, 2.0)
			var gl := Mats.storefront()
			_mi(root, _prim_box(Vector3(sw, sh, 0.16)), gl, Vector3(0, sh * 0.5 + 0.3, fz + 0.04), Vector3.ONE, Vector3.ZERO, false)
			# montantes
			var mull: Array = []
			var n_m := maxi(2, roundi(sw / 1.6))
			for i in n_m + 1:
				mull.append(_item(_prim_box(Vector3(0.1, sh, 0.2)), Vector3(-sw * 0.5 + sw * float(i) / float(n_m), sh * 0.5 + 0.3, fz + 0.05)))
			mull.append(_item(_prim_box(Vector3(sw + 0.1, 0.12, 0.2)), Vector3(0, sh + 0.3, fz + 0.05)))
			_merged_mi(root, mull, dark, false)
			# faixa de letreiro
			var sign_col := Color.from_hsv(rng.randf(), 0.55, 0.85)
			_mi(root, _prim_box(Vector3(sw + 0.2, 0.55, 0.14)), Mats.shared(sign_col, 0.5), Vector3(0, sh + 0.7, fz + 0.1))
			if style == "shop":
				# toldo listrado inclinado
				var aw := Mats.cloth(sign_col.lightened(0.15), 0.8)
				_mi(root, _prim_box(Vector3(sw + 0.1, 0.06, 1.0)), aw, Vector3(0, sh + 0.28, fz + 0.5), Vector3.ONE, Vector3(0.22, 0, 0))
			else:
				_mi(root, _prim_box(Vector3(sw * 0.4, 0.15, 1.6)), trim, Vector3(0, sh + 0.2, fz + 0.8))
		"house":
			_mi(root, _prim_box(Vector3(1.1, 2.15, 0.12)), Mats.wood(Color(0.35, 0.22, 0.14)), Vector3(0, 1.1, fz + 0.04))
			_mi(root, _prim_box(Vector3(1.9, 0.12, 1.2)), trim, Vector3(0, 2.45, fz + 0.5))
			# degraus
			_mi(root, _prim_box(Vector3(1.6, 0.25, 0.9)), trim, Vector3(0, 0.12, fz + 0.45))
		"industrial":
			_mi(root, _prim_box(Vector3(size.x * 0.4, 3.4, 0.2)), Mats.metal(Color(0.45, 0.5, 0.52), 0.55), Vector3(0, 1.7, fz + 0.02))
			for i in 6:
				_mi(root, _prim_box(Vector3(size.x * 0.4, 0.04, 0.22)), dark, Vector3(0, 0.5 + float(i) * 0.55, fz + 0.04), Vector3.ONE, Vector3.ZERO, false)
		_:
			# porta de predio residencial + marquise + escada
			_mi(root, _prim_box(Vector3(1.5, 2.3, 0.14)), glass, Vector3(0, 1.15 + 0.2, fz + 0.04), Vector3.ONE, Vector3.ZERO, false)
			_mi(root, _prim_box(Vector3(2.4, 0.14, 1.3)), trim, Vector3(0, 2.75, fz + 0.65))
			_mi(root, _prim_box(Vector3(2.0, 0.2, 1.0)), trim, Vector3(0, 0.1, fz + 0.5))
			for sx in [-1.0, 1.0]:
				_mi(root, _prim_cyl(0.06, 0.06, 2.6, 8), trim, Vector3(sx * 1.1, 1.3, fz + 1.2))

	# sacadas (apartment): fundidas em 1 malha
	if style == "apartment" and floors >= 3:
		var slabs: Array = []
		var rails: Array = []
		for f in range(1, floors):
			for bi in bays_x:
				if (bi + f) % 2 == 0:
					continue
				var cx := -size.x * 0.5 + (float(bi) + 0.5) * bw_x
				var by := float(f) * floor_h
				slabs.append(_item(_prim_box(Vector3(bw_x * 0.8, 0.12, 0.9)), Vector3(cx, by + 0.06, fz + 0.45)))
				rails.append(_item(_prim_box(Vector3(bw_x * 0.8, 1.0, 0.04)), Vector3(cx, by + 0.62, fz + 0.88)))
		_merged_mi(root, slabs, trim)
		_merged_mi(root, rails, Mats.glass(0.3), false)

	# telhado
	var top := size.y
	if style == "house":
		var along := maxf(size.x, size.z)
		var across := minf(size.x, size.z)
		var rh := across * 0.38
		var prism := PrismMesh.new()
		prism.size = Vector3(across + 0.8, rh, along + 0.8)
		prism.left_to_right = 0.5
		var roof_c := Color.from_hsv(rng.randf_range(0.0, 0.08), rng.randf_range(0.5, 0.7), rng.randf_range(0.4, 0.6))
		var rmi := _mi(root, prism, _roof_tile_mat(roof_c), Vector3(0, top + rh * 0.5, 0))
		if size.x >= size.z:
			rmi.rotation.y = PI / 2.0
		_mi(root, _prim_box(Vector3(0.55, rh + 0.8, 0.55)), Mats.concrete(Color(0.55, 0.3, 0.25)), Vector3(size.x * 0.25, top + rh * 0.6, -size.z * 0.15))
	else:
		var roof_m := Mats.concrete(Color(0.42, 0.42, 0.42))
		_mi(root, _prim_box(Vector3(size.x + 0.2, 0.2, size.z + 0.2)), roof_m, Vector3(0, top + 0.1, 0))
		var par: Array = []
		var ph := 0.7
		par.append(_item(_prim_box(Vector3(size.x + 0.3, ph, 0.25)), Vector3(0, top + ph * 0.5, fz + 0.05)))
		par.append(_item(_prim_box(Vector3(size.x + 0.3, ph, 0.25)), Vector3(0, top + ph * 0.5, -fz - 0.05)))
		par.append(_item(_prim_box(Vector3(0.25, ph, size.z + 0.3)), Vector3(size.x * 0.5 + 0.05, top + ph * 0.5, 0)))
		par.append(_item(_prim_box(Vector3(0.25, ph, size.z + 0.3)), Vector3(-size.x * 0.5 - 0.05, top + ph * 0.5, 0)))
		_merged_mi(root, par, trim)
		# equipamentos de telhado
		var units: Array = []
		var n_u := clampi(roundi(size.x * size.z / 90.0), 1, 5)
		for i in n_u:
			var ux := rng.randf_range(-size.x * 0.35, size.x * 0.35)
			var uz := rng.randf_range(-size.z * 0.35, size.z * 0.3)
			var us := Vector3(rng.randf_range(1.0, 2.0), rng.randf_range(0.6, 1.2), rng.randf_range(1.0, 1.6))
			units.append(_item(_prim_box(us), Vector3(ux, top + 0.2 + us.y * 0.5, uz)))
		_merged_mi(root, units, Mats.metal(Color(0.6, 0.62, 0.64), 0.5))
		if style == "apartment" or style == "industrial":
			# caixa d'agua
			var tank := Node3D.new()
			tank.position = Vector3(-size.x * 0.25, top + 0.2, -size.z * 0.2)
			root.add_child(tank)
			_mi(tank, _prim_cyl(0.9, 0.9, 1.5, 18), Mats.metal(Color(0.5, 0.5, 0.52), 0.6), Vector3(0, 1.6, 0))
			_mi(tank, _prim_cyl(0.0, 0.95, 0.4, 18), Mats.metal(Color(0.45, 0.45, 0.47), 0.6), Vector3(0, 2.55, 0))
			for sx in [-0.6, 0.6]:
				for sz in [-0.6, 0.6]:
					_mi(tank, _prim_box(Vector3(0.1, 1.0, 0.1)), dark, Vector3(sx, 0.5, sz), Vector3.ONE, Vector3.ZERO, false)
	root.set_meta("size", size)
	return root

# ================================================================ VEGETACAO

static func make_tree(kind: String = "") -> Node3D:
	_counter += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = _counter * 104729
	if kind == "":
		kind = ["oak", "oak", "round", "pine"][rng.randi() % 4]
	var root := Node3D.new()
	root.name = "Tree_" + kind
	var trunk_h := rng.randf_range(2.0, 2.8)
	var bark := Mats.bark(Color(0.9, 0.85, 0.8))
	var leaf_mat := Mats.leaves(Color.WHITE)
	leaf_mat.vertex_color_use_as_albedo = true
	var items: Array = []
	var base_col := Color.from_hsv(rng.randf_range(0.24, 0.31), rng.randf_range(0.55, 0.75), rng.randf_range(0.34, 0.5))
	match kind:
		"pine":
			trunk_h = rng.randf_range(1.2, 1.8)
			_mi(root, _prim_cyl(0.1, 0.22, trunk_h + 2.5, 10), bark, Vector3(0, (trunk_h + 2.5) * 0.5, 0))
			var tiers := 5
			var pc := base_col.darkened(0.25)
			for i in tiers:
				var f := float(i) / float(tiers - 1)
				var r := lerpf(1.7, 0.55, f)
				var y := trunk_h + f * 3.4
				items.append(_item(_prim_cyl(0.0, r, 1.5, 12), Vector3(0, y + 0.6, 0), Vector3.ONE, Vector3.ZERO, pc.lerp(pc.lightened(0.15), f)))
		"round":
			_mi(root, _prim_cyl(0.12, 0.22, trunk_h, 10), bark, Vector3(0, trunk_h * 0.5, 0))
			items.append(_item(_prim_sphere(14), Vector3(0, trunk_h + 1.3, 0), Vector3(1.7, 1.55, 1.7), Vector3.ZERO, base_col))
			items.append(_item(_prim_sphere(10), Vector3(0.5, trunk_h + 1.9, 0.3), Vector3(1.0, 0.9, 1.0), Vector3.ZERO, base_col.lightened(0.12)))
		_:
			_mi(root, _prim_cyl(0.13, 0.28, trunk_h + 0.8, 10), bark, Vector3(0, (trunk_h + 0.8) * 0.5, 0))
			# galhos
			for i in 3:
				var a := rng.randf() * TAU
				_mi(root, _prim_cyl(0.04, 0.09, 1.3, 6), bark, Vector3(cos(a) * 0.35, trunk_h + 0.3, sin(a) * 0.35), Vector3.ONE, Vector3(sin(a) * 0.7, 0, -cos(a) * 0.7), false)
			var n_b := rng.randi_range(6, 9)
			for i in n_b:
				var a := rng.randf() * TAU
				var rad := rng.randf_range(0.0, 1.3)
				var s := rng.randf_range(0.9, 1.5)
				var cc := base_col.lerp(base_col.lightened(0.25), rng.randf())
				items.append(_item(_prim_sphere(10), Vector3(cos(a) * rad, trunk_h + 1.0 + rng.randf_range(0.0, 1.6), sin(a) * rad), Vector3(s, s * 0.85, s), Vector3.ZERO, cc))
	_merged_mi(root, items, leaf_mat)
	return root

static func make_bush() -> Node3D:
	_counter += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = _counter * 15485863
	var root := Node3D.new()
	root.name = "Bush"
	var leaf_mat := Mats.leaves(Color.WHITE)
	leaf_mat.vertex_color_use_as_albedo = true
	var base_col := Color.from_hsv(rng.randf_range(0.22, 0.32), 0.65, rng.randf_range(0.3, 0.45))
	var items: Array = []
	for i in 5:
		var s := rng.randf_range(0.35, 0.6)
		items.append(_item(_prim_sphere(8), Vector3(rng.randf_range(-0.5, 0.5), s * 0.8, rng.randf_range(-0.4, 0.4)), Vector3(s, s * 0.85, s), Vector3.ZERO, base_col.lerp(base_col.lightened(0.25), rng.randf())))
	_merged_mi(root, items, leaf_mat)
	return root

# ================================================================ MOBILIARIO URBANO

## Banco de praca (assento voltado para +Z), ~1.8 x 0.55 m, altura 0.85 m.
static func make_bench() -> Node3D:
	var root := Node3D.new()
	root.name = "Bench"
	var wood_items: Array = []
	for i in 4:
		wood_items.append(_item(_prim_box(Vector3(1.8, 0.04, 0.1)), Vector3(0, 0.45, -0.18 + float(i) * 0.12)))
	for i in 3:
		wood_items.append(_item(_prim_box(Vector3(1.8, 0.1, 0.035)), Vector3(0, 0.62 + float(i) * 0.12, -0.27), Vector3.ONE, Vector3(-0.12, 0, 0)))
	_merged_mi(root, wood_items, Mats.wood(Color(0.62, 0.42, 0.24)))
	var metal_items: Array = []
	for sx in [-0.8, 0.8]:
		metal_items.append(_item(_prim_box(Vector3(0.06, 0.45, 0.06)), Vector3(sx, 0.225, 0.2)))
		metal_items.append(_item(_prim_box(Vector3(0.06, 0.45, 0.06)), Vector3(sx, 0.225, -0.25)))
		metal_items.append(_item(_prim_box(Vector3(0.06, 0.5, 0.06)), Vector3(sx, 0.62, -0.3), Vector3.ONE, Vector3(-0.12, 0, 0)))
		metal_items.append(_item(_prim_box(Vector3(0.05, 0.05, 0.55)), Vector3(sx, 0.62, -0.02)))
		metal_items.append(_item(_prim_box(Vector3(0.07, 0.04, 0.4)), Vector3(sx, 0.7, 0.0)))
		metal_items.append(_item(_prim_box(Vector3(0.06, 0.06, 0.55)), Vector3(sx, 0.43, 0.0)))
	_merged_mi(root, metal_items, Mats.metal(Color(0.12, 0.13, 0.14), 0.45))
	return root

## Poste de luz (altura ~6.5 m). lit = true adiciona OmniLight3D e lampada emissiva.
static func make_streetlamp(lit: bool = false) -> Node3D:
	var root := Node3D.new()
	root.name = "Streetlamp"
	var pole_m := Mats.metal(Color(0.22, 0.24, 0.26), 0.4)
	_mi(root, _prim_cyl(0.07, 0.12, 6.2, 10), pole_m, Vector3(0, 3.1, 0))
	_mi(root, _prim_cyl(0.16, 0.16, 0.5, 10), pole_m, Vector3(0, 0.25, 0))
	_mi(root, _prim_box(Vector3(0.07, 0.07, 1.4)), pole_m, Vector3(0, 6.15, 0.6), Vector3.ONE, Vector3(0.08, 0, 0))
	_mi(root, _prim_box(Vector3(0.32, 0.1, 0.7)), pole_m, Vector3(0, 6.2, 1.25), Vector3.ONE, Vector3.ZERO, false)
	var bulb := Mats.emissive(Color(1.0, 0.9, 0.65), 3.0 if lit else 0.2)
	_mi(root, _prim_box(Vector3(0.26, 0.04, 0.55)), bulb, Vector3(0, 6.13, 1.25), Vector3.ONE, Vector3.ZERO, false)
	if lit:
		var l := OmniLight3D.new()
		l.position = Vector3(0, 5.8, 1.25)
		l.omni_range = 14.0
		l.light_energy = 2.2
		l.light_color = Color(1.0, 0.88, 0.62)
		l.shadow_enabled = false
		root.add_child(l)
	return root

## Plano com material PBR. kind: "asphalt" | "pavement" | "grass" | "concrete".
static func make_ground(size: Vector2, kind: String = "asphalt") -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	var mi := MeshInstance3D.new()
	mi.name = "Ground_" + kind
	mi.mesh = pm
	match kind:
		"pavement":
			mi.material_override = Mats.pavement()
		"grass":
			mi.material_override = Mats.grass()
		"concrete":
			mi.material_override = Mats.concrete()
		_:
			mi.material_override = Mats.asphalt()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# ================================================================ ANIMACAO

static func _rig(h: Node3D) -> Dictionary:
	if h == null:
		return {}
	if h.has_meta("rig"):
		return h.get_meta("rig")
	var sub := h.find_child("Humanoid", true, false)
	if sub and sub.has_meta("rig"):
		return sub.get_meta("rig")
	return {}

static func _pose(rig: Dictionary, speed: float, ph: float, t: float) -> void:
	var k := clampf(speed / 6.0, 0.0, 1.0)  # 0 = parado/andando, 1 = sprint
	var moving := clampf(speed / 0.8, 0.0, 1.0)
	var swing := lerpf(0.45, 0.95, k) * moving
	var bend := lerpf(0.7, 1.7, k) * moving
	var arm := lerpf(0.4, 0.95, k) * moving
	var s := sin(ph)
	var c := cos(ph)
	var s2 := sin(ph + PI)
	var c2 := cos(ph + PI)
	var breathe := sin(t * 1.7) * 0.012
	(rig["hipL"] as Node3D).rotation.x = -s * swing
	(rig["hipR"] as Node3D).rotation.x = -s2 * swing
	(rig["kneeL"] as Node3D).rotation.x = maxf(0.0, c) * bend + 0.04
	(rig["kneeR"] as Node3D).rotation.x = maxf(0.0, c2) * bend + 0.04
	(rig["ankleL"] as Node3D).rotation.x = -maxf(0.0, -c) * 0.25 * moving + 0.05 * moving
	(rig["ankleR"] as Node3D).rotation.x = -maxf(0.0, -c2) * 0.25 * moving + 0.05 * moving
	(rig["shoulderL"] as Node3D).rotation.x = s * arm
	(rig["shoulderR"] as Node3D).rotation.x = s2 * arm
	var elbow_base := -0.12 - lerpf(0.25, 1.35, k) * moving
	(rig["elbowL"] as Node3D).rotation.x = elbow_base - maxf(0.0, -s) * 0.3 * moving
	(rig["elbowR"] as Node3D).rotation.x = elbow_base - maxf(0.0, -s2) * 0.3 * moving
	var torso: Node3D = rig["torso"]
	torso.rotation.x = k * 0.22 * moving + breathe
	torso.rotation.y = s * 0.12 * moving * (0.6 + k)
	torso.position.y = 0.97 + absf(c) * 0.012 * moving * (1.0 + k * 2.0)
	(rig["head"] as Node3D).rotation.y = -torso.rotation.y * 0.8
	(rig["head"] as Node3D).rotation.x = -k * 0.15 * moving

## Pose de caminhada/corrida. speed em m/s (0 = parado, ~2 anda, 5+ corre).
## t = tempo acumulado em segundos. Para fase continua com velocidade variavel,
## prefira update_walk (integra a fase internamente).
static func animate_walk(humanoid: Node3D, speed: float, t: float) -> void:
	var rig := _rig(humanoid)
	if rig.is_empty():
		return
	var k := clampf(speed / 6.0, 0.0, 1.0)
	var freq := lerpf(0.95, 1.8, k)
	_pose(rig, speed, t * freq * TAU, t)

## Versao com delta: acumula a fase no proprio no (sem saltos ao mudar a velocidade).
static func update_walk(humanoid: Node3D, speed: float, delta: float) -> void:
	var rig := _rig(humanoid)
	if rig.is_empty():
		return
	var host: Node3D = humanoid if humanoid.has_meta("rig") else humanoid.find_child("Humanoid", true, false)
	var k := clampf(speed / 6.0, 0.0, 1.0)
	var freq := lerpf(0.95, 1.8, k)
	var ph: float = host.get_meta("walk_ph", 0.0)
	var tt: float = host.get_meta("walk_t", 0.0) + delta
	ph = wrapf(ph + delta * freq * TAU * clampf(speed / 0.8, 0.0, 1.0), 0.0, TAU * 8.0)
	host.set_meta("walk_ph", ph)
	host.set_meta("walk_t", tt)
	_pose(rig, speed, ph, tt)

## Chute com a perna direita. p de 0 a 1 (preparar, bater, recuperar).
## Chame depois de update_walk/animate_walk no mesmo frame para sobrepor a perna.
static func animate_kick(humanoid: Node3D, p: float) -> void:
	var rig := _rig(humanoid)
	if rig.is_empty():
		return
	p = clampf(p, 0.0, 1.0)
	var hip := 0.0
	var knee := 0.0
	if p < 0.3:
		var q := p / 0.3
		hip = 0.7 * q
		knee = 1.4 * q
	elif p < 0.55:
		var q := (p - 0.3) / 0.25
		q = q * q
		hip = lerpf(0.7, -1.25, q)
		knee = lerpf(1.4, 0.15, q)
	else:
		var q := (p - 0.55) / 0.45
		hip = lerpf(-1.25, 0.0, q)
		knee = lerpf(0.15, 0.04, q)
	(rig["hipR"] as Node3D).rotation.x = hip
	(rig["kneeR"] as Node3D).rotation.x = knee
	var env := sin(p * PI)
	(rig["torso"] as Node3D).rotation.y += env * 0.18
	(rig["shoulderL"] as Node3D).rotation.x = -env * 0.5
