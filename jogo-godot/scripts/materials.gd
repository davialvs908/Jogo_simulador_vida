extends RefCounted
## Materiais PBR procedurais + Environment/ceu. Sem class_name: use
## const Mats = preload("res://scripts/materials.gd")
## Todas as texturas sao geradas em codigo (originais, sem licenca externa).

static var _tex_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}

# ---------------------------------------------------------------- basicos

static func mat(color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m

## Material compartilhado (mesmo resultado => mesma instancia, menos memoria).
static func shared(color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var key := "m%s_%.2f_%.2f" % [color.to_html(true), rough, metal]
	if not _mat_cache.has(key):
		_mat_cache[key] = mat(color, rough, metal)
	return _mat_cache[key]

# ---------------------------------------------------------------- texturas

## Textura de ruido em escala de cinza (0..1) como Image.
static func _noise_image(w: int, h: int, seed_v: int, freq: float, octaves := 3) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	var img := n.get_seamless_image(w, h, false)
	return img

static func noise_albedo(key: String, c_a: Color, c_b: Color, seed_v := 1, freq := 0.03, size := 128) -> ImageTexture:
	var k := "na_" + key
	if _tex_cache.has(k):
		return _tex_cache[k]
	var src := _noise_image(size, size, seed_v, freq)
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v: float = src.get_pixel(x, y).r
			img.set_pixel(x, y, c_a.lerp(c_b, v))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[k] = t
	return t

## Normal map a partir de ruido (relevo suave). strength ~ 1..6.
static func noise_normal(key: String, seed_v := 2, freq := 0.08, strength := 3.0, size := 128) -> ImageTexture:
	var k := "nn_" + key
	if _tex_cache.has(k):
		return _tex_cache[k]
	var src := _noise_image(size, size, seed_v, freq, 4)
	var img := Image.create(size, size, true, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var l: float = src.get_pixel((x - 1 + size) % size, y).r
			var r: float = src.get_pixel((x + 1) % size, y).r
			var u: float = src.get_pixel(x, (y - 1 + size) % size).r
			var d: float = src.get_pixel(x, (y + 1) % size).r
			var nv := Vector3((l - r) * strength, (u - d) * strength, 1.0).normalized()
			img.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[k] = t
	return t

## Trama de tecido (normal map fina, repetida).
static func weave_normal() -> ImageTexture:
	if _tex_cache.has("weave"):
		return _tex_cache["weave"]
	var s := 32
	var img := Image.create(s, s, true, Image.FORMAT_RGB8)
	for y in s:
		for x in s:
			var a := sin(float(x) / s * TAU * 4.0) * 0.5 + sin(float(y) / s * TAU * 4.0) * 0.5
			var nx := cos(float(x) / s * TAU * 4.0) * 0.18
			var ny := cos(float(y) / s * TAU * 4.0) * 0.18
			var nv := Vector3(nx, ny, 1.0 + a * 0.02).normalized()
			img.set_pixel(x, y, Color(nv.x * 0.5 + 0.5, nv.y * 0.5 + 0.5, nv.z * 0.5 + 0.5))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache["weave"] = t
	return t

# ---------------------------------------------------------------- materiais prontos

static func _tex_mat(albedo: Texture2D, normal: Texture2D, tint: Color, rough: float, uv_scale: Vector3, nstrength := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = albedo
	m.albedo_color = tint
	m.roughness = rough
	if normal:
		m.normal_enabled = true
		m.normal_texture = normal
		m.normal_scale = nstrength
	m.uv1_triplanar = true
	m.uv1_scale = uv_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func asphalt(uv_per_m := 0.25) -> StandardMaterial3D:
	var a := noise_albedo("asphalt", Color(0.11, 0.11, 0.115), Color(0.21, 0.21, 0.215), 11, 0.07, 128)
	return _tex_mat(a, noise_normal("asphalt", 12, 0.12, 1.4), Color.WHITE, 0.88, Vector3(uv_per_m, uv_per_m, uv_per_m))

static func concrete(tint := Color(0.78, 0.78, 0.76), uv_per_m := 0.3) -> StandardMaterial3D:
	var a := noise_albedo("concrete", Color(0.62, 0.62, 0.6), Color(0.9, 0.9, 0.88), 21, 0.05, 128)
	return _tex_mat(a, noise_normal("concrete", 22, 0.12, 1.5), tint, 0.92, Vector3(uv_per_m, uv_per_m, uv_per_m))

static func pavement(uv_per_m := 0.5) -> StandardMaterial3D:
	## calcada: lajotas cinza com juntas
	var key := "pave"
	var tex: ImageTexture
	if _tex_cache.has(key):
		tex = _tex_cache[key]
	else:
		var s := 128
		var img := Image.create(s, s, true, Image.FORMAT_RGB8)
		var base := _noise_image(s, s, 31, 0.06)
		for y in s:
			for x in s:
				var v: float = base.get_pixel(x, y).r
				var c := Color(0.55, 0.55, 0.54).lerp(Color(0.74, 0.73, 0.71), v)
				if x % 64 < 2 or y % 64 < 2:
					c = Color(0.28, 0.28, 0.28)
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		tex = ImageTexture.create_from_image(img)
		_tex_cache[key] = tex
	return _tex_mat(tex, noise_normal("pave", 32, 0.15, 1.5), Color.WHITE, 0.9, Vector3(uv_per_m, uv_per_m, uv_per_m))

static func grass(tint := Color.WHITE, uv_per_m := 0.35) -> StandardMaterial3D:
	var a := noise_albedo("grass", Color(0.12, 0.30, 0.10), Color(0.26, 0.48, 0.16), 41, 0.09, 128)
	return _tex_mat(a, noise_normal("grass", 42, 0.3, 2.0), tint, 0.95, Vector3(uv_per_m, uv_per_m, uv_per_m))

static func bark(tint := Color.WHITE) -> StandardMaterial3D:
	var a := noise_albedo("bark", Color(0.16, 0.10, 0.06), Color(0.36, 0.25, 0.16), 51, 0.12, 64)
	return _tex_mat(a, noise_normal("bark", 52, 0.2, 3.5, 64), tint, 0.95, Vector3(1.5, 1.0, 1.5), 1.0)

static func leaves(tint: Color) -> StandardMaterial3D:
	var a := noise_albedo("leaves", Color(0.55, 0.65, 0.5), Color(1.0, 1.0, 0.9), 61, 0.22, 64)
	var m := _tex_mat(a, noise_normal("leaves", 62, 0.3, 3.0, 64), tint, 0.85, Vector3(1.2, 1.2, 1.2), 1.0)
	m.rim_enabled = true
	m.rim = 0.15
	return m

static func wood(tint := Color(0.55, 0.38, 0.22)) -> StandardMaterial3D:
	var a := noise_albedo("wood", Color(0.7, 0.55, 0.4), Color(1, 0.85, 0.65), 71, 0.02, 64)
	return _tex_mat(a, noise_normal("wood", 72, 0.04, 2.0, 64), tint, 0.7, Vector3(1.0, 1.0, 1.0))

static func metal(color := Color(0.5, 0.52, 0.55), rough := 0.35) -> StandardMaterial3D:
	var m := mat(color, rough, 0.9)
	return m

static func rubber() -> StandardMaterial3D:
	return shared(Color(0.03, 0.03, 0.035), 0.92, 0.0)

## Tinta automotiva com verniz (clearcoat) e reflexo metalico.
static func car_paint(color: Color) -> StandardMaterial3D:
	var m := mat(color, 0.28, 0.55)
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.06
	return m

static func glass(alpha := 0.35) -> StandardMaterial3D:
	var m := mat(Color(0.12, 0.18, 0.24, alpha), 0.04, 0.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic_specular = 1.0
	return m

## Vidro escuro refletivo opaco (barato, bom para carros).
static func tinted_glass() -> StandardMaterial3D:
	return shared(Color(0.04, 0.07, 0.1), 0.06, 0.6)

## Vitrine de loja/lobby: vidro azulado com interior levemente iluminado.
static func storefront() -> StandardMaterial3D:
	var m := mat(Color(0.28, 0.4, 0.5), 0.1, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.6)
	m.emission_energy_multiplier = 0.18
	return m

static func emissive(color: Color, energy := 2.0) -> StandardMaterial3D:
	var m := mat(color, 0.3, 0.0)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

## Tecido de uniforme: trama fina + leve brilho de borda.
static func cloth(color: Color, rough := 0.78) -> StandardMaterial3D:
	var key := "cl%s_%.2f" % [color.to_html(false), rough]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := mat(color, rough, 0.0)
	m.normal_enabled = true
	m.normal_texture = weave_normal()
	m.normal_scale = 0.3
	m.uv1_scale = Vector3(28, 28, 28)
	m.uv1_triplanar = true
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.5
	_mat_cache[key] = m
	return m

static func skin(color: Color) -> StandardMaterial3D:
	var key := "sk%s" % color.to_html(false)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := mat(color, 0.52, 0.0)
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.25
	m.rim_enabled = true
	m.rim = 0.08
	m.rim_tint = 0.6
	_mat_cache[key] = m
	return m

static func hair(color: Color) -> StandardMaterial3D:
	var key := "hr%s" % color.to_html(false)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := mat(color, 0.5, 0.0)
	m.anisotropy_enabled = true
	m.anisotropy = 0.6
	m.normal_enabled = true
	m.normal_texture = noise_normal("hair", 81, 0.5, 2.0, 64)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(3, 3, 3)
	_mat_cache[key] = m
	return m

# ---------------------------------------------------------------- fachadas

## Textura de fachada (uma "baia": 1 janela x 1 andar). Retorna [albedo, emissao].
## style: apartment | office | shop | house | industrial
static func facade_textures(style: String, wall: Color) -> Array:
	var key := "fc_%s_%s" % [style, wall.to_html(false)]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var w := 128
	var h := 128
	var alb := Image.create(w, h, true, Image.FORMAT_RGB8)
	var emi := Image.create(w, h, true, Image.FORMAT_RGB8)
	var grain := _noise_image(w, h, 91, 0.12)
	emi.fill(Color.BLACK)
	var glass_top := Color(0.30, 0.42, 0.52)
	var glass_bot := Color(0.10, 0.16, 0.22)
	var frame := wall.darkened(0.55)
	var sill := wall.lightened(0.25)
	# regiao da janela (px)
	var wx0 := 24
	var wx1 := 104
	var wy0 := 28
	var wy1 := 104
	match style:
		"office":
			wx0 = 0
			wx1 = w
			wy0 = 14
			wy1 = 116
			glass_top = Color(0.32, 0.48, 0.62)
			glass_bot = Color(0.08, 0.16, 0.26)
			frame = Color(0.55, 0.57, 0.6)
		"shop":
			wx0 = 12
			wx1 = 116
			wy0 = 34
			wy1 = 112
		"industrial":
			wx0 = 20
			wx1 = 108
			wy0 = 40
			wy1 = 70
		"house":
			wx0 = 30
			wx1 = 98
			wy0 = 30
			wy1 = 100
	for y in h:
		for x in w:
			var g: float = grain.get_pixel(x, y).r
			var c := wall.lerp(wall.darkened(0.18), g)
			if style == "apartment":
				# juntas de tijolo
				var row := y / 8
				var off := 8 if row % 2 == 0 else 0
				if y % 8 == 0 or (x + off) % 16 == 0:
					c = c.darkened(0.16)
			if x >= wx0 and x < wx1 and y >= wy0 and y < wy1:
				var t := float(y - wy0) / float(wy1 - wy0)
				c = glass_top.lerp(glass_bot, t)
				# reflexo diagonal
				var dg := float((x + y) % 40) / 40.0
				if dg < 0.18:
					c = c.lightened(0.12)
				# moldura
				var bx := 3 if style != "office" else 2
				if x < wx0 + bx or x >= wx1 - bx or y < wy0 + bx or y >= wy1 - bx:
					c = frame
				elif style != "office" and absi(x - (wx0 + wx1) / 2) < 2:
					c = frame
				elif style == "office" and (x < 2 or x >= w - 2):
					c = frame
			elif style != "office" and y >= wy1 and y < wy1 + 4 and x >= wx0 - 3 and x < wx1 + 3:
				c = sill
			elif style == "office" and (y < wy0 or y >= wy1):
				c = wall.lerp(Color(0.5, 0.52, 0.55), 0.6)
			alb.set_pixel(x, y, c)
	# emissao: pixels de janela com cor quente, usados com energia baixa de dia
	for y in range(wy0 + 4, wy1 - 4):
		for x in range(wx0 + 4, wx1 - 4):
			emi.set_pixel(x, y, Color(1.0, 0.82, 0.5) * 0.9)
	alb.generate_mipmaps()
	emi.generate_mipmaps()
	var res := [ImageTexture.create_from_image(alb), ImageTexture.create_from_image(emi)]
	_tex_cache[key] = res
	return res

static func facade_material(style: String, wall: Color, bays_x: int, bays_z: int, floors: int, bw_x: float, bw_z: float, floor_h: float) -> StandardMaterial3D:
	var tx: Array = facade_textures(style, wall)
	var m := StandardMaterial3D.new()
	m.albedo_texture = tx[0]
	m.roughness = 0.55 if style == "office" else 0.82
	m.metallic = 0.25 if style == "office" else 0.0
	m.uv1_triplanar = true
	# escala por eixo: X e Z podem ter numero de baias diferente
	var sx := 1.0 / bw_x
	var sz := 1.0 / bw_z
	m.uv1_scale = Vector3(sx, 1.0 / floor_h, sz)
	m.uv1_offset = Vector3(0.5 if bays_x % 2 == 0 else 0.0, 0.5 if floors % 2 == 0 else 0.0, 0.5 if bays_z % 2 == 0 else 0.0)
	m.emission_enabled = true
	m.emission_texture = tx[1]
	m.emission_energy_multiplier = 0.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.set_meta("is_facade", true)
	return m

## Liga/desliga luz das janelas em materiais de fachada (noite = 1).
static func set_window_glow(root: Node, amount: float) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.material_override and mi.material_override.has_meta("is_facade"):
			(mi.material_override as StandardMaterial3D).emission_energy_multiplier = amount

# ---------------------------------------------------------------- ambiente

static func make_sky(day_factor: float) -> Sky:
	var d := clampf(day_factor, 0.0, 1.0)
	var psm := ProceduralSkyMaterial.new()
	var dusk := 1.0 - absf(d - 0.5) * 2.0 # 1 no entardecer/amanhecer
	psm.sky_top_color = Color(0.015, 0.025, 0.07).lerp(Color(0.18, 0.36, 0.72), d)
	psm.sky_horizon_color = Color(0.05, 0.06, 0.12).lerp(Color(0.62, 0.74, 0.88), d).lerp(Color(0.95, 0.55, 0.32), dusk * 0.35)
	psm.sky_curve = 0.18
	psm.sky_energy_multiplier = lerpf(0.35, 1.0, d)
	psm.ground_horizon_color = psm.sky_horizon_color.lerp(Color(0.25, 0.27, 0.28), 0.4)
	psm.ground_bottom_color = Color(0.06, 0.07, 0.08).lerp(Color(0.2, 0.22, 0.2), d)
	psm.ground_curve = 0.05
	psm.sun_angle_max = 28.0
	psm.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = psm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	return sky

## Environment completo. day_factor: 0 = noite, 1 = meio-dia.
static func make_env(day_factor: float = 1.0) -> Environment:
	var d := clampf(day_factor, 0.0, 1.0)
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = make_sky(d)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = lerpf(0.5, 0.95, d)
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = lerpf(1.15, 1.0, d)
	e.tonemap_white = 6.0
	# glow
	e.glow_enabled = true
	e.glow_intensity = lerpf(0.9, 0.5, d)
	e.glow_strength = 1.0
	e.glow_bloom = lerpf(0.12, 0.04, d)
	e.glow_hdr_threshold = 1.0
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	# SSAO + SSIL (baratos o bastante; sem SDFGI por custo)
	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 2.0
	e.ssao_power = 1.6
	e.ssao_detail = 0.6
	e.ssil_enabled = true
	e.ssil_radius = 4.0
	e.ssil_intensity = 0.8
	e.sdfgi_enabled = false
	# neblina de profundidade (perspectiva aerea)
	e.fog_enabled = true
	e.fog_light_color = Color(0.5, 0.6, 0.72).lerp(Color(0.04, 0.05, 0.1), 1.0 - d)
	e.fog_light_energy = lerpf(0.5, 1.0, d)
	e.fog_density = 0.0011
	e.fog_sky_affect = 0.35
	e.fog_aerial_perspective = 0.35
	e.fog_sun_scatter = 0.15
	# correcao de cor
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.1
	return e

## Sol coerente com make_env: direcao baixa ao entardecer.
static func make_sun(day_factor: float = 1.0) -> DirectionalLight3D:
	var d := clampf(day_factor, 0.0, 1.0)
	var s := DirectionalLight3D.new()
	s.name = "Sun"
	s.rotation_degrees = Vector3(lerpf(-8.0, -58.0, d), -35.0, 0.0)
	s.light_color = Color(1.0, 0.55, 0.3).lerp(Color(1.0, 0.96, 0.88), clampf(d * 1.6, 0.0, 1.0))
	if d < 0.2:
		s.light_color = Color(0.45, 0.55, 0.9)
	s.light_energy = lerpf(0.25, 1.35, d)
	s.shadow_enabled = true
	s.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	s.directional_shadow_max_distance = 140.0
	s.shadow_blur = 1.2
	s.light_angular_distance = 0.5
	return s
