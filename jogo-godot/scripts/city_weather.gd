extends RefCounted
## Clima: chuva e neblina aleatórias (ou fixas pelo menu de pausa).

const NAMES := {"clear": "Céu limpo", "rain": "Chuva", "fog": "Neblina"}

var hub
var mode := "auto"        # auto / clear / rain / fog
var kind := "clear"       # estado atual alvo
var rain_k := 0.0
var fog_k := 0.0
var timer := 40.0
var rain_node: CPUParticles3D

func setup(h) -> void:
	hub = h
	rain_node = CPUParticles3D.new()
	rain_node.amount = 900
	rain_node.lifetime = 0.8
	rain_node.preprocess = 0.8
	rain_node.local_coords = false
	rain_node.emitting = false
	rain_node.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain_node.emission_box_extents = Vector3(34, 0.5, 34)
	rain_node.direction = Vector3(0.12, -1, 0.05)
	rain_node.spread = 2.0
	rain_node.gravity = Vector3(0, -12, 0)
	rain_node.initial_velocity_min = 24.0
	rain_node.initial_velocity_max = 30.0
	var qm := BoxMesh.new()
	qm.size = Vector3(0.025, 0.7, 0.025)
	rain_node.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.85, 1.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rain_node.material_override = mat
	rain_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hub.add_child(rain_node)
	set_mode(mode)

func set_mode(m: String) -> void:
	mode = m
	if m != "auto":
		kind = m
	else:
		timer = 5.0

func mode_text() -> String:
	match mode:
		"auto": return "Automático"
		"clear": return "Sempre limpo"
		"rain": return "Sempre chuva"
		"fog": return "Sempre neblina"
	return mode

func text() -> String:
	return str(NAMES.get(kind, "Céu limpo"))

func cycle_mode() -> void:
	var order := ["auto", "clear", "rain", "fog"]
	set_mode(order[(order.find(mode) + 1) % order.size()])

func grip() -> float:
	return 1.0 - rain_k * 0.22

func update(delta: float, focus: Vector3) -> void:
	if mode == "auto":
		timer -= delta
		if timer <= 0.0:
			var r := randf()
			if kind != "clear":
				kind = "clear"
				timer = randf_range(80.0, 200.0)
			else:
				kind = "rain" if r < 0.5 else "fog"
				timer = randf_range(50.0, 130.0)
	var rain_t := 1.0 if kind == "rain" else 0.0
	var fog_t := 1.0 if kind == "fog" else (0.35 if kind == "rain" else 0.0)
	rain_k = move_toward(rain_k, rain_t, delta * 0.25)
	fog_k = move_toward(fog_k, fog_t, delta * 0.2)
	rain_node.emitting = rain_k > 0.02
	rain_node.global_position = focus + Vector3(0, 20, 0)
	if hub.world and hub.world.road_mat:
		hub.world.road_mat.roughness = lerpf(0.9, 0.25, rain_k)
		hub.world.road_mat.metallic = lerpf(0.0, 0.35, rain_k)

## Aplica o clima por cima da iluminação base calculada pelo hub.
func apply(env: Environment, sun: DirectionalLight3D, day_f: float) -> void:
	var dark := clampf(rain_k * 0.55 + fog_k * 0.25, 0.0, 0.8)
	sun.light_energy *= (1.0 - dark)
	var grey := Color(0.55, 0.58, 0.62).lerp(Color(0.05, 0.06, 0.09), 1.0 - day_f)
	env.background_color = env.background_color.lerp(grey, clampf(rain_k * 0.8 + fog_k * 0.9, 0.0, 0.95))
	env.fog_light_color = env.background_color
	env.fog_density = 0.0016 + fog_k * 0.034 + rain_k * 0.006
	env.ambient_light_energy *= (1.0 - dark * 0.4)
