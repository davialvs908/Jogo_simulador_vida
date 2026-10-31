extends RefCounted
class_name HumanoidBuilder

## Humanoide procedural ORIGINAL (proporcao realista ~1.80 m antes da escala 1.12).
## Frente = +Z. Articulacoes sao Node3D (quadril, joelho, tornozelo, ombro,
## cotovelo, tronco, cabeca) guardadas em meta "rig" para animacao por
## Props.animate_walk / Props.update_walk (scripts/props.gd).
## Khronos CesiumMan/RiggedFigure (assets/characters) continuam so como referencia.

const Mats = preload("res://scripts/materials.gd")

const SKIN := [
	Color("f2d9c0"), Color("e8c4a0"), Color("d9b08a"), Color("d4a574"),
	Color("c9956c"), Color("b88860"), Color("a87850"), Color("8d623f"),
	Color("6b4a30"), Color("4a3220"),
]
const HAIR := [
	Color("0e0c0a"), Color("1a1210"), Color("2a1a12"), Color("3a2818"),
	Color("4a3020"), Color("5c4030"), Color("1c1c1c"),
]

static var _mesh_cache: Dictionary = {}

static func make_mat(color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

# ---------------------------------------------------------------- malhas compartilhadas

static func _cyl(top: float, bottom: float, h: float, seg := 14) -> CylinderMesh:
	var key := "c%.3f_%.3f_%.3f_%d" % [top, bottom, h, seg]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	_mesh_cache[key] = c
	return c

static func _sphere(seg := 14, hemi := false) -> SphereMesh:
	var key := "s%d_%s" % [seg, str(hemi)]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 1.0 if hemi else 2.0
	s.is_hemisphere = hemi
	s.radial_segments = seg
	s.rings = maxi(seg / 2, 4)
	_mesh_cache[key] = s
	return s

static func _box(size: Vector3) -> BoxMesh:
	var key := "b%s" % str(size)
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var b := BoxMesh.new()
	b.size = size
	_mesh_cache[key] = b
	return b

static func _torus(inner: float, outer: float) -> TorusMesh:
	var key := "t%.3f_%.3f" % [inner, outer]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 16
	t.ring_segments = 8
	_mesh_cache[key] = t
	return t

## detail: 0 = sempre, 1 = detalhe de rosto (some a distancia), sombra desligada.
static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scale := Vector3.ONE, rot := Vector3.ZERO, detail := 0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	if rot != Vector3.ZERO:
		mi.rotation = rot
	if detail == 1:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 16.0
	else:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

static func _pivot(parent: Node3D, nm: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = pos
	parent.add_child(n)
	return n

static func _accent_for(kit: Color) -> Color:
	var lum := kit.r * 0.3 + kit.g * 0.59 + kit.b * 0.11
	return kit.darkened(0.45) if lum > 0.5 else kit.lightened(0.6)

# ---------------------------------------------------------------- construcao

static func build(kit: Color, shorts: Color, socks: Color, skin_i: int, hair_i: int, is_user: bool, number: int = 10) -> Node3D:
	var root := Node3D.new()
	root.name = "Humanoid"
	var skin_c: Color = SKIN[skin_i % SKIN.size()]
	var hair_c: Color = HAIR[hair_i % HAIR.size()]
	var player_kit := number > 0 or is_user  # numero 0 = civil (calca + tenis)
	var kit_m := Mats.cloth(kit, 0.74)
	var short_m := Mats.cloth(shorts, 0.8)
	var sock_m := Mats.cloth(socks, 0.7)
	var skin_m := Mats.skin(skin_c)
	var hair_m := Mats.hair(hair_c)
	var accent := _accent_for(kit)
	var accent_m := Mats.cloth(accent, 0.7)
	var boot_m: StandardMaterial3D
	if player_kit:
		boot_m = Mats.shared(Color(0.04, 0.04, 0.045), 0.28, 0.2)
	else:
		boot_m = Mats.shared(Color(0.88, 0.88, 0.86), 0.5, 0.0)
	var sole_m := Mats.shared(Color(0.92, 0.92, 0.92) if player_kit else Color(0.15, 0.15, 0.16), 0.5, 0.0)

	var rig := {}

	# ---- pernas
	for s_i in [-1, 1]:
		var sx := float(s_i)
		var tag := "L" if s_i < 0 else "R"
		var hip := _pivot(root, "Hip" + tag, Vector3(sx * 0.095, 0.93, 0))
		# coxa (pele) + calcao/calca
		_mesh(hip, _cyl(0.083, 0.062, 0.44), skin_m if player_kit else short_m, Vector3(0, -0.215, 0))
		if player_kit:
			_mesh(hip, _cyl(0.094, 0.104, 0.27), short_m, Vector3(0, -0.125, 0))
		var knee := _pivot(hip, "Knee", Vector3(0, -0.43, 0))
		_mesh(knee, _cyl(0.062, 0.046, 0.46), sock_m if player_kit else short_m, Vector3(0, -0.20, 0))
		if player_kit:
			# faixa no topo da meiao
			_mesh(knee, _cyl(0.0635, 0.0615, 0.03), accent_m, Vector3(0, 0.0, 0), Vector3.ONE, Vector3.ZERO, 1)
			# canela/panturrilha
			_mesh(knee, _sphere(10), sock_m, Vector3(0, -0.12, -0.008), Vector3(0.05, 0.09, 0.054))
		var ankle := _pivot(knee, "Ankle", Vector3(0, -0.43, 0))
		_mesh(ankle, _sphere(12), boot_m, Vector3(0, -0.022, 0.05), Vector3(0.053, 0.046, 0.14))
		_mesh(ankle, _box(Vector3(0.09, 0.012, 0.2)), sole_m, Vector3(0, -0.062, 0.06), Vector3.ONE, Vector3.ZERO, 1)
		rig["hip" + tag] = hip
		rig["knee" + tag] = knee
		rig["ankle" + tag] = ankle

	# ---- pelve
	_mesh(root, _sphere(14), short_m, Vector3(0, 0.96, 0), Vector3(0.165, 0.1, 0.105))

	# ---- tronco
	var torso := _pivot(root, "Torso", Vector3(0, 0.97, 0))
	var chest := _mesh(torso, _cyl(0.175, 0.145, 0.56, 20), kit_m, Vector3(0, 0.28, 0))
	chest.scale = Vector3(1.0, 1.0, 0.62)
	# ombros arredondados
	_mesh(torso, _sphere(14), kit_m, Vector3(0, 0.525, 0), Vector3(0.185, 0.075, 0.112))
	# gola
	_mesh(torso, _torus(0.042, 0.066), accent_m, Vector3(0, 0.575, 0.003), Vector3.ONE, Vector3.ZERO, 1)
	# pescoco
	_mesh(torso, _cyl(0.046, 0.052, 0.13), skin_m, Vector3(0, 0.62, 0))
	if player_kit:
		# escudo no peito
		_mesh(torso, _cyl(0.026, 0.026, 0.006, 12), accent_m, Vector3(0.085, 0.42, 0.099), Vector3.ONE, Vector3(PI / 2.0, 0, 0), 1)
		# numero nas costas
		if number > 0:
			var lum := kit.r * 0.3 + kit.g * 0.59 + kit.b * 0.11
			var lab := Label3D.new()
			lab.name = "Number"
			lab.text = str(number)
			lab.font_size = 96
			lab.pixel_size = 0.0017
			lab.modulate = Color(0.08, 0.08, 0.1) if lum > 0.55 else Color(0.97, 0.97, 0.97)
			lab.outline_size = 0
			lab.shaded = false
			lab.double_sided = false
			lab.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			lab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lab.visibility_range_end = 40.0
			lab.position = Vector3(0, 0.33, -0.101)
			lab.rotation = Vector3(0, PI, 0)
			torso.add_child(lab)
			var lab2 := Label3D.new()
			lab2.name = "NumberFront"
			lab2.text = str(number)
			lab2.font_size = 64
			lab2.pixel_size = 0.0009
			lab2.modulate = lab.modulate
			lab2.outline_size = 0
			lab2.shaded = false
			lab2.alpha_cut = Label3D.ALPHA_CUT_DISCARD
			lab2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lab2.visibility_range_end = 20.0
			lab2.position = Vector3(-0.085, 0.42, 0.102)
			torso.add_child(lab2)
	rig["torso"] = torso

	# ---- bracos
	for s_i in [-1, 1]:
		var sx := float(s_i)
		var tag := "L" if s_i < 0 else "R"
		var sh := _pivot(torso, "Shoulder" + tag, Vector3(sx * 0.205, 0.49, 0))
		sh.rotation.z = -sx * 0.07
		_mesh(sh, _sphere(12), kit_m, Vector3(0, -0.005, 0), Vector3(0.062, 0.062, 0.06))
		_mesh(sh, _cyl(0.05, 0.043, 0.30), skin_m, Vector3(0, -0.15, 0))
		_mesh(sh, _cyl(0.062, 0.057, 0.17), kit_m, Vector3(0, -0.075, 0))
		_mesh(sh, _cyl(0.0585, 0.0585, 0.022), accent_m, Vector3(0, -0.155, 0), Vector3.ONE, Vector3.ZERO, 1)
		var elbow := _pivot(sh, "Elbow", Vector3(0, -0.30, 0))
		_mesh(elbow, _cyl(0.044, 0.033, 0.26), skin_m, Vector3(0, -0.125, 0))
		var hand := _pivot(elbow, "Hand", Vector3(0, -0.26, 0))
		_mesh(hand, _sphere(10), skin_m, Vector3(0, -0.045, 0.004), Vector3(0.033, 0.06, 0.024))
		_mesh(hand, _sphere(8), skin_m, Vector3(sx * -0.026, -0.03, 0.016), Vector3(0.012, 0.03, 0.012), Vector3.ZERO, 1)
		rig["shoulder" + tag] = sh
		rig["elbow" + tag] = elbow

	# ---- cabeca
	var head := _pivot(torso, "Head", Vector3(0, 0.79, 0))
	_build_head(head, skin_c, skin_m, hair_m, hair_c, hair_i)
	rig["head"] = head

	if is_user:
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.5
		t.outer_radius = 0.62
		ring.mesh = t
		var rm := StandardMaterial3D.new()
		rm.albedo_color = Color(0.94, 0.82, 0.25, 0.85)
		rm.emission_enabled = true
		rm.emission = Color(0.9, 0.7, 0.2)
		rm.emission_energy_multiplier = 1.4
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = rm
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.name = "UserRing"
		ring.position = Vector3(0, 0.04, 0)
		root.add_child(ring)

	root.set_meta("rig", rig)
	root.set_meta("walk_t", 0.0)
	root.scale = Vector3(1.12, 1.12, 1.12)
	return root

static func _build_head(head: Node3D, skin_c: Color, skin_m: Material, hair_m: Material, hair_c: Color, hair_i: int) -> void:
	# cranio + mandibula
	_mesh(head, _sphere(18), skin_m, Vector3(0, 0.01, -0.005), Vector3(0.088, 0.108, 0.1))
	_mesh(head, _sphere(14), skin_m, Vector3(0, -0.075, 0.035), Vector3(0.068, 0.062, 0.075))
	# nariz
	_mesh(head, _sphere(8), skin_m, Vector3(0, -0.02, 0.1), Vector3(0.016, 0.026, 0.026), Vector3(0.25, 0, 0), 1)
	_mesh(head, _sphere(8), skin_m, Vector3(0, -0.04, 0.108), Vector3(0.019, 0.012, 0.016), Vector3.ZERO, 1)
	# orelhas
	for sx in [-0.088, 0.088]:
		_mesh(head, _sphere(8), skin_m, Vector3(sx, -0.005, 0.0), Vector3(0.011, 0.026, 0.019), Vector3.ZERO, 1)
	# olhos
	var white := Mats.shared(Color(0.95, 0.95, 0.93), 0.3)
	var iris := Mats.shared(Color(0.12, 0.09, 0.07), 0.2)
	for sx in [-0.036, 0.036]:
		_mesh(head, _sphere(8), white, Vector3(sx, 0.025, 0.085), Vector3(0.0195, 0.013, 0.012), Vector3.ZERO, 1)
		_mesh(head, _sphere(6), iris, Vector3(sx, 0.025, 0.0955), Vector3(0.0085, 0.0085, 0.004), Vector3.ZERO, 1)
	# sobrancelhas
	var brow_m := Mats.shared(hair_c.darkened(0.1), 0.8)
	for s_i in [-1, 1]:
		var sx := float(s_i) * 0.036
		_mesh(head, _box(Vector3(0.032, 0.006, 0.01)), brow_m, Vector3(sx, 0.05, 0.088), Vector3.ONE, Vector3(0, 0, -float(s_i) * 0.12), 1)
	# boca
	var mouth_m := Mats.shared(skin_c.darkened(0.45).lerp(Color(0.5, 0.15, 0.15), 0.4), 0.5)
	_mesh(head, _box(Vector3(0.04, 0.006, 0.008)), mouth_m, Vector3(0, -0.062, 0.106), Vector3.ONE, Vector3.ZERO, 1)

	# cabelo
	var style := hair_i % 7
	var dome := _sphere(16, true)
	match style:
		0: # curto
			_mesh(head, dome, hair_m, Vector3(0, 0.045, -0.004), Vector3(0.098, 0.1, 0.108), Vector3(-0.35, 0, 0))
		1: # curto com franja
			_mesh(head, dome, hair_m, Vector3(0, 0.045, -0.004), Vector3(0.098, 0.1, 0.108), Vector3(-0.35, 0, 0))
			_mesh(head, _box(Vector3(0.1, 0.022, 0.03)), hair_m, Vector3(0.012, 0.088, 0.096), Vector3.ONE, Vector3(0.35, 0, -0.12), 1)
		2: # raspado
			_mesh(head, dome, Mats.shared(hair_c.lerp(skin_c, 0.45), 0.9), Vector3(0, 0.05, -0.004), Vector3(0.093, 0.093, 0.1), Vector3(-0.35, 0, 0))
		3: # black power
			_mesh(head, _sphere(16), hair_m, Vector3(0, 0.085, -0.03), Vector3(0.125, 0.115, 0.12))
		4: # penteado para tras + costeletas
			_mesh(head, dome, hair_m, Vector3(0, 0.045, -0.008), Vector3(0.096, 0.088, 0.108), Vector3(-0.5, 0, 0))
			for sx in [-0.083, 0.083]:
				_mesh(head, _box(Vector3(0.012, 0.045, 0.03)), hair_m, Vector3(sx, 0.045, 0.01), Vector3.ONE, Vector3.ZERO, 1)
		5: # longo
			_mesh(head, dome, hair_m, Vector3(0, 0.045, -0.004), Vector3(0.1, 0.1, 0.11), Vector3(-0.35, 0, 0))
			_mesh(head, _sphere(12), hair_m, Vector3(0, -0.07, -0.07), Vector3(0.095, 0.17, 0.055))
		6: # cacheado
			_mesh(head, dome, hair_m, Vector3(0, 0.045, -0.004), Vector3(0.098, 0.1, 0.108), Vector3(-0.35, 0, 0))
			for p in [Vector3(-0.05, 0.12, 0.02), Vector3(0.05, 0.12, 0.02), Vector3(0, 0.135, -0.03), Vector3(0, 0.125, 0.05), Vector3(-0.07, 0.09, -0.04), Vector3(0.07, 0.09, -0.04)]:
				_mesh(head, _sphere(8), hair_m, p, Vector3(0.035, 0.035, 0.035), Vector3.ZERO, 1)
