extends Node3D
## Cidade aberta: andar, dirigir, trânsito, missões, clima, comprar casa/carro, treinar e namorar.

const G = preload("res://scripts/city_graph.gd")
const CityState = preload("res://scripts/city_state.gd")
const CityWorld = preload("res://scripts/city_world.gd")
const CityTraffic = preload("res://scripts/city_traffic.gd")
const CityPeds = preload("res://scripts/city_peds.gd")
const CityMap = preload("res://scripts/city_map.gd")
const CityMissions = preload("res://scripts/city_missions.gd")
const CityWeather = preload("res://scripts/city_weather.gd")
const CityRadio = preload("res://scripts/city_radio.gd")
const CityPanels = preload("res://scripts/city_panels.gd")
const Props = preload("res://scripts/props.gd")
const Mats = preload("res://scripts/materials.gd")

var world_env: WorldEnvironment
var _last_df := -1.0
var _base_amb := 0.7
var _base_fog := Color(0.5, 0.6, 0.7)

const WALK_SPEED := 9.0
const SPRINT_SPEED := 14.0
const TIME_SCALE := 0.03
const ENERGY_DRAIN := 0.12

const SPOTS := {
	"stadium":    {"pos": Vector3(-35, 0, -35), "size": Vector3(16, 7, 12), "color": Color(0.30, 0.38, 0.48), "label": "Estádio"},
	"home":       {"pos": Vector3(35, 0, -35),  "size": Vector3(9, 6, 8),   "color": Color(0.38, 0.40, 0.42), "label": "Minha casa"},
	"cars":       {"pos": Vector3(-35, 0, 35),  "size": Vector3(14, 5, 8),  "color": Color(0.38, 0.34, 0.30), "label": "Concessionária"},
	"cafe":       {"pos": Vector3(35, 0, 35),   "size": Vector3(9, 5, 7),   "color": Color(0.45, 0.30, 0.32), "label": "Café"},
	"realestate": {"pos": Vector3(-82, 0, 28),  "size": Vector3(10, 7, 8),  "color": Color(0.28, 0.42, 0.40), "label": "Imobiliária"},
	"mall":       {"pos": Vector3(82, 0, 24),   "size": Vector3(14, 6, 10), "color": Color(0.50, 0.38, 0.52), "label": "Shopping"},
	"gym":        {"pos": Vector3(-35, 0, -75), "size": Vector3(12, 5, 8),  "color": Color(0.45, 0.25, 0.20), "label": "Academia"},
	"restaurant": {"pos": Vector3(82, 0, -28),  "size": Vector3(12, 5, 8),  "color": Color(0.55, 0.32, 0.18), "label": "Restaurante", "hours": [11.0, 23.0]},
	"cinema":     {"pos": Vector3(-82, 0, -28), "size": Vector3(14, 7, 10), "color": Color(0.36, 0.22, 0.42), "label": "Cinema", "hours": [12.0, 24.0]},
	"clinic":     {"pos": Vector3(-82, 0, 82),  "size": Vector3(12, 6, 8),  "color": Color(0.70, 0.78, 0.80), "label": "Clínica", "hours": [7.0, 21.0]},
	"bank":       {"pos": Vector3(140, 0, 28),  "size": Vector3(12, 6, 8),  "color": Color(0.22, 0.34, 0.50), "label": "Banco", "hours": [8.0, 18.0]},
	"electro":    {"pos": Vector3(140, 0, -28), "size": Vector3(12, 5, 8),  "color": Color(0.20, 0.45, 0.60), "label": "Eletrônicos", "hours": [9.0, 21.0]},
	"gas":        {"pos": Vector3(28, 0, 82),   "size": Vector3(10, 5, 6),  "color": Color(0.75, 0.25, 0.20), "label": "Posto"},
	"beach":      {"pos": Vector3(-30, 0, 138), "size": Vector3(12, 4, 6),  "color": Color(0.85, 0.65, 0.35), "label": "Quiosque da Praia", "hours": [8.0, 20.0]},
	"board":      {"pos": Vector3(30, 0, -82),  "size": Vector3(10, 4, 6),  "color": Color(0.20, 0.55, 0.50), "label": "Central de Missões"},
}
const SPOT_STYLE := {"stadium": "industrial", "cars": "shop", "cafe": "shop", "realestate": "office", "mall": "shop", "gym": "industrial"}
const FILLERS := [
	Vector3(82, 0, -82), Vector3(140, 0, -82), Vector3(140, 0, 82), Vector3(82, 0, 82), Vector3(-35, 0, 75),
]
const ACTION_KEYS := {
	"city_map": [KEY_M], "city_horn": [KEY_H], "city_radio": [KEY_R], "city_phone": [KEY_J],
	"city_brake": [KEY_SPACE], "city_gps": [KEY_G], "city_zoom_in": [KEY_EQUAL, KEY_KP_ADD], "city_zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],
}

var player: CharacterBody3D
var player_col: CollisionShape3D
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var near_spot := ""
var modal_open := false
var pause_world := false
var overlay: CanvasLayer
var panel_msg := ""

var hud_top: Label
var hud_status: Label
var hud_objective: Label
var hud_place: Label
var hud_hint: Label
var energy_bar: ProgressBar
var hud_layer: CanvasLayer
var hud_root: Control
var mission_card: PanelContainer
var car_card: PanelContainer
var hud_speed: Label
var hud_limit: Label
var fuel_bar: ProgressBar
var hud_radio: Label
var toast_box: VBoxContainer
var banner_label: Label
var flash_rect: ColorRect
var minimap
var big_map

var car: CharacterBody3D
var car_lights: Array = []
var car_label: Label3D
var in_car := false
var car_speed := 0.0
var lock_drive := false

var home_node: Node3D
var maya: Node3D
var lamps: Array = []

# sistemas da cidade (scripts city_*.gd)
var city
var world
var traffic
var peds_sys
var missions
var weather
var radio
var panels

# GPS
var waypoint := Vector3.ZERO
var has_waypoint := false
var waypoint_label := ""
var route_pts: Array = []
var route_mm: MultiMeshInstance3D
var beacon_wp: Node3D
var beacon_ms: Node3D
var _route_t := 0.0

# câmera
var cam_zoom := 1.0
var cam_focus := Vector3.ZERO
var cam_shake := 0.0
var map_radius := 80.0
var _bump_cd := 0.0
var _autosave_t := 0.0
var _fuel_warn := 100.0
var _minimap_t := 0
var horn_player: AudioStreamPlayer
var _last_district := ""

func _ready() -> void:
	city = CityState.new()
	_ensure_actions()
	_build_world()
	_build_home()
	_build_player()
	_build_maya()
	peds_sys = CityPeds.new()
	peds_sys.setup(self)
	traffic = CityTraffic.new()
	weather = CityWeather.new()
	weather.setup(self)
	weather.set_mode(city.s("weather_mode"))
	traffic.setup(self)
	traffic.set_police(city.b("police_enabled"))
	radio = CityRadio.new()
	radio.set_index(city.i("radio"))
	missions = CityMissions.new()
	missions.setup(self)
	panels = CityPanels.new()
	panels.setup(self)
	cam_zoom = city.f("cam_zoom") if city.f("cam_zoom") > 0.1 else 1.0
	_spawn_current_car()
	_build_camera()
	_build_gps_nodes()
	_build_hud()
	horn_player = AudioStreamPlayer.new()
	horn_player.stream = CityRadio.make_horn(330.0, 0.38)
	horn_player.volume_db = -6.0
	add_child(horn_player)
	apply_options()
	_update_lighting()
	_refresh_hud()

func _exit_tree() -> void:
	if city:
		city.save()

func _ensure_actions() -> void:
	for act in ACTION_KEYS.keys():
		if not InputMap.has_action(act):
			InputMap.add_action(act)
			for k in ACTION_KEYS[act]:
				var ev := InputEventKey.new()
				ev.physical_keycode = k
				InputMap.action_add_event(act, ev)

func apply_options() -> void:
	var vol: float = city.f("volume")
	AudioServer.set_bus_volume_db(0, -80.0 if vol <= 0.01 else linear_to_db(vol))
	if minimap:
		minimap.visible = city.b("minimap")

# ---------------- MUNDO ----------------
func _build_world() -> void:
	world_env = WorldEnvironment.new()
	env = Mats.make_env(0.0)
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)

	world = CityWorld.new()
	world.hub = self
	world.build()
	for l in world.lamps:
		lamps.append(l)

	for id in SPOTS.keys():
		if id == "home":
			continue
		var sp: Dictionary = SPOTS[id]
		_building(sp.pos, sp.color, sp.size, sp.label, SPOT_STYLE.get(id, "shop"))
		_door_pad(id)
	_door_pad("home")

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for p in FILLERS:
		var h := rng.randf_range(8.0, 22.0)
		var st: String = ["office", "apartment", "apartment", "industrial"][rng.randi() % 4]
		_building(p, Color(0.22, 0.24, 0.28).lerp(Color(0.45, 0.38, 0.36), rng.randf()), Vector3(rng.randf_range(9, 13), h, rng.randf_range(8, 11)), "", st)

func _door_pad(id: String) -> void:
	var sp: Dictionary = SPOTS[id]
	var p: Vector3 = sp.pos
	var s: Vector3 = sp.size
	var pad := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 2.0
	cy.bottom_radius = 2.0
	cy.height = 0.04
	pad.mesh = cy
	var m := HumanoidBuilder.make_mat((sp.color as Color).lightened(0.3), 0.5)
	m.emission_enabled = true
	m.emission = (sp.color as Color).lightened(0.4)
	m.emission_energy_multiplier = 0.9
	pad.material_override = m
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pad.position = Vector3(p.x, 0.14, p.z + s.z * 0.5 + 4.5)
	add_child(pad)

func _building(pos: Vector3, color: Color, size: Vector3, label: String, style := "apartment") -> Node3D:
	var root := StaticBody3D.new()
	root.position = pos
	root.add_child(Props.make_building(size, color, style))
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	col.shape = bs
	col.position = Vector3(0, size.y * 0.5, 0)
	root.add_child(col)
	if label != "":
		var tag := Label3D.new()
		tag.text = label
		tag.font_size = 72
		tag.pixel_size = 0.012
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.modulate = Color(1, 0.95, 0.75)
		tag.outline_size = 14
		tag.position = Vector3(0, size.y + 2.2, 0)
		root.add_child(tag)
	add_child(root)
	return root

# ---------------- CASA ----------------
func _build_home() -> void:
	if home_node:
		home_node.queue_free()
	var tier := GameState.house_id
	var pos: Vector3 = SPOTS.home.pos
	var sizes := [Vector3(7, 4, 6), Vector3(9, 7, 8), Vector3(12, 5, 9), Vector3(16, 7, 11)]
	var colors := [Color(0.40, 0.36, 0.32), Color(0.38, 0.40, 0.44), Color(0.55, 0.45, 0.35), Color(0.82, 0.82, 0.85)]
	var names := ["Quarto alugado", "Apartamento", "Casa", "Mansão"]
	home_node = _building(pos, colors[tier], sizes[tier], names[tier], ["apartment", "apartment", "house", "house"][tier])
	if tier >= 2:
		var yard := MeshInstance3D.new()
		var ym := PlaneMesh.new()
		ym.size = Vector2(sizes[tier].x + 8, sizes[tier].z + 8)
		yard.mesh = ym
		yard.material_override = HumanoidBuilder.make_mat(Color(0.18, 0.42, 0.22), 0.95)
		yard.position = Vector3(0, 0.14, 0)
		home_node.add_child(yard)
	if tier >= 3:
		var pool := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(8, 5)
		pool.mesh = pm
		var wm := HumanoidBuilder.make_mat(Color(0.2, 0.6, 0.9), 0.1, 0.2)
		wm.emission_enabled = true
		wm.emission = Color(0.1, 0.4, 0.8)
		wm.emission_energy_multiplier = 0.6
		pool.material_override = wm
		pool.position = Vector3(0, 0.16, sizes[tier].z * 0.5 + 4.5)
		home_node.add_child(pool)

# ---------------- PERSONAGENS / CARRO ----------------
func _build_player() -> void:
	player = CharacterBody3D.new()
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	player.position = Vector3(30, 0, -20)
	player.add_child(HumanoidBuilder.build(Color("c4b48a"), Color("1a1e24"), Color("d0d0d0"), 4, 1, true, 10))
	player_col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	player_col.shape = cap
	player_col.position = Vector3(0, 0.95, 0)
	player.add_child(player_col)
	add_child(player)

func _build_maya() -> void:
	maya = HumanoidBuilder.build(Color("a03a5a"), Color("2a2430"), Color("3a3438"), 2, 0, false, 0)
	add_child(maya)
	var tag := Label3D.new()
	tag.text = "Maya"
	tag.font_size = 64
	tag.pixel_size = 0.01
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.modulate = Color(1.0, 0.7, 0.8)
	tag.outline_size = 12
	tag.position = Vector3(0, 3.2, 0)
	maya.add_child(tag)
	_update_maya()

func _maya_here() -> bool:
	if GameState.gf_lives_with:
		return true
	return GameState.hour >= 12.0 and GameState.hour < 23.5

func _update_maya() -> void:
	var at_home := GameState.gf_lives_with
	maya.visible = _maya_here() and not (missions != null and missions.maya_aboard)
	var base: Vector3 = SPOTS.home.pos if at_home else SPOTS.cafe.pos
	maya.global_position = base + (Vector3(7, 0, 6) if at_home else Vector3(-8, 0, 0))
	maya.rotation_degrees.y = -50

func _spawn_current_car() -> void:
	if car:
		if in_car and player:
			in_car = false
			player.global_position = Vector3(car.global_position.x + 3.0, 0.0, car.global_position.z)
			player.visible = true
			player_col.set_deferred("disabled", false)
		car.queue_free()
		car = null
		car_lights = []
	if not GameState.has_car():
		return
	var def := GameState.car_data(GameState.current_car)
	car = CharacterBody3D.new()
	car.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	car.position = SPOTS.home.pos + Vector3(0, 0.5, 14)
	var model: Node3D = Props.make_car(def.color)
	model.name = "Model"
	model.position = Vector3(0, -0.2, 0)
	car.add_child(model)
	for sx in [-0.65, 0.65]:
		var sl := SpotLight3D.new()
		sl.spot_range = 28.0
		sl.spot_angle = 38.0
		sl.light_energy = 0.0
		sl.position = Vector3(sx, 0.3, -2.2)
		sl.rotation_degrees = Vector3(-4, 0, 0)
		car.add_child(sl)
		car_lights.append(sl)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.9, 1.2, 4.2)
	cs.shape = bs
	cs.position = Vector3(0, 0.3, 0)
	car.add_child(cs)
	car_label = Label3D.new()
	car_label.text = "BI-BIIIP!"
	car_label.font_size = 56
	car_label.pixel_size = 0.01
	car_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	car_label.no_depth_test = true
	car_label.modulate = Color(1.0, 0.95, 0.4)
	car_label.outline_size = 10
	car_label.position = Vector3(0, 2.8, 0)
	car_label.visible = false
	car.add_child(car_label)
	add_child(car)
	car_speed = 0.0

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 52
	camera.far = 600.0
	camera.position = player.position + Vector3(0, 14, 14) * cam_zoom
	camera.current = true
	add_child(camera)
	cam_focus = player.position + Vector3(0, 1.0, 0)
	camera.look_at(cam_focus)

# ---------------- GPS 3D ----------------
func _make_beacon(color: Color) -> Node3D:
	var root := Node3D.new()
	var pillar := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.9
	cy.bottom_radius = 0.9
	cy.height = 45.0
	pillar.mesh = cy
	var m := HumanoidBuilder.make_mat(Color(color.r, color.g, color.b, 0.28), 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar.material_override = m
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pillar.position = Vector3(0, 22.5, 0)
	root.add_child(pillar)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 3.4
	tm.outer_radius = 4.0
	ring.mesh = tm
	var rm := HumanoidBuilder.make_mat(color, 0.4)
	rm.emission_enabled = true
	rm.emission = color
	rm.emission_energy_multiplier = 2.0
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = Vector3(0, 0.2, 0)
	ring.scale = Vector3(1, 0.1, 1)
	root.add_child(ring)
	root.visible = false
	add_child(root)
	return root

func _build_gps_nodes() -> void:
	beacon_wp = _make_beacon(Color(1.0, 0.3, 0.8))
	beacon_ms = _make_beacon(Color(1.0, 0.85, 0.2))
	route_mm = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.05, 1.8)
	mm.mesh = bm
	mm.instance_count = 80
	mm.visible_instance_count = 0
	route_mm.multimesh = mm
	var m := HumanoidBuilder.make_mat(Color(0.2, 0.9, 1.0), 0.4)
	m.emission_enabled = true
	m.emission = Color(0.2, 0.9, 1.0)
	m.emission_energy_multiplier = 1.8
	route_mm.material_override = m
	route_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(route_mm)

func ref_pos() -> Vector3:
	if in_car and car:
		return car.global_position
	return player.global_position

func player_yaw() -> float:
	if in_car and car:
		return car.rotation.y
	return player.rotation.y

func set_waypoint(pos: Vector3, label: String) -> void:
	waypoint = Vector3(pos.x, 0.0, pos.z)
	has_waypoint = true
	waypoint_label = label
	_route_t = 0.0
	_update_route()
	toast("GPS: rota para %s" % label)

func clear_waypoint() -> void:
	has_waypoint = false
	route_pts = []
	if beacon_wp:
		beacon_wp.visible = false
	if route_mm:
		route_mm.multimesh.visible_instance_count = 0

func auto_gps_to_mission() -> void:
	var tg: Dictionary = missions.current_target()
	if tg.is_empty():
		return
	set_waypoint(tg.pos, str(tg.label))

func _update_route() -> void:
	if not has_waypoint:
		return
	var me := ref_pos()
	var a := G.nearest_node(me)
	var b := G.nearest_node(waypoint)
	var nodes := G.route(a, b)
	var pts: Array = [Vector3(me.x, 0.06, me.z)]
	for k in nodes.size():
		var p := G.node_pos(int(nodes[k]))
		if k == 0 and nodes.size() > 1:
			var p1 := G.node_pos(int(nodes[1]))
			if (p1 - p).dot(me - p) > 0.0:
				continue
		pts.append(Vector3(p.x, 0.06, p.z))
	pts.append(Vector3(waypoint.x, 0.06, waypoint.z))
	route_pts = pts
	# trilha 3D de setas
	var mm := route_mm.multimesh
	var count := 0
	var carry := 0.0
	for k in range(pts.size() - 1):
		var s0: Vector3 = pts[k]
		var s1: Vector3 = pts[k + 1]
		var seg := s1 - s0
		var l := seg.length()
		if l < 0.1:
			continue
		var dir := seg / l
		var bas := Basis.looking_at(dir, Vector3.UP)
		var d := carry
		while d < l and count < mm.instance_count:
			mm.set_instance_transform(count, Transform3D(bas, s0 + dir * d + Vector3(0, 0.05, 0)))
			count += 1
			d += 6.0
		carry = d - l
	mm.visible_instance_count = count

# ---------------- HUD ----------------
func _card_style(alpha := 0.72) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.09, alpha)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	return sb

func _build_hud() -> void:
	hud_layer = CanvasLayer.new()
	add_child(hud_layer)
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud_root)

	# cartão superior esquerdo
	var tl := PanelContainer.new()
	tl.position = Vector2(12, 12)
	tl.add_theme_stylebox_override("panel", _card_style())
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(tl)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tl.add_child(tv)
	hud_top = Label.new()
	hud_top.add_theme_font_size_override("font_size", 18)
	tv.add_child(hud_top)
	energy_bar = ProgressBar.new()
	energy_bar.custom_minimum_size = Vector2(260, 10)
	energy_bar.show_percentage = false
	tv.add_child(energy_bar)
	hud_status = Label.new()
	hud_status.add_theme_font_size_override("font_size", 13)
	hud_status.modulate = Color(0.85, 0.88, 0.95)
	tv.add_child(hud_status)

	# cartão de objetivo / missão
	mission_card = PanelContainer.new()
	mission_card.position = Vector2(12, 112)
	mission_card.add_theme_stylebox_override("panel", _card_style(0.62))
	mission_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(mission_card)
	hud_objective = Label.new()
	hud_objective.add_theme_font_size_override("font_size", 14)
	hud_objective.modulate = Color(1.0, 0.9, 0.5)
	hud_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_objective.custom_minimum_size = Vector2(380, 0)
	mission_card.add_child(hud_objective)

	# minimapa (canto superior direito)
	minimap = CityMap.new()
	minimap.hub = self
	minimap.full = false
	minimap.radius = map_radius
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -214
	minimap.offset_right = -14
	minimap.offset_top = 14
	minimap.offset_bottom = 214
	hud_root.add_child(minimap)
	hud_place = Label.new()
	hud_place.anchor_left = 1.0
	hud_place.anchor_right = 1.0
	hud_place.offset_left = -314
	hud_place.offset_right = -14
	hud_place.offset_top = 218
	hud_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_place.add_theme_font_size_override("font_size", 14)
	hud_place.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud_place.add_theme_constant_override("outline_size", 6)
	hud_root.add_child(hud_place)

	# dica inferior
	hud_hint = Label.new()
	hud_hint.anchor_left = 0.5
	hud_hint.anchor_right = 0.5
	hud_hint.anchor_top = 1.0
	hud_hint.anchor_bottom = 1.0
	hud_hint.offset_left = -420
	hud_hint.offset_right = 420
	hud_hint.offset_top = -34
	hud_hint.offset_bottom = -8
	hud_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_hint.add_theme_font_size_override("font_size", 14)
	hud_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud_hint.add_theme_constant_override("outline_size", 6)
	hud_root.add_child(hud_hint)

	# painel do carro (velocímetro, combustível, rádio)
	car_card = PanelContainer.new()
	car_card.anchor_left = 1.0
	car_card.anchor_right = 1.0
	car_card.anchor_top = 1.0
	car_card.anchor_bottom = 1.0
	car_card.offset_right = -14
	car_card.offset_bottom = -14
	car_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	car_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	car_card.add_theme_stylebox_override("panel", _card_style())
	car_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(car_card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 3)
	car_card.add_child(cv)
	hud_speed = Label.new()
	hud_speed.add_theme_font_size_override("font_size", 34)
	hud_speed.custom_minimum_size = Vector2(240, 0)
	cv.add_child(hud_speed)
	hud_limit = Label.new()
	hud_limit.add_theme_font_size_override("font_size", 13)
	cv.add_child(hud_limit)
	fuel_bar = ProgressBar.new()
	fuel_bar.custom_minimum_size = Vector2(240, 8)
	fuel_bar.show_percentage = false
	cv.add_child(fuel_bar)
	hud_radio = Label.new()
	hud_radio.add_theme_font_size_override("font_size", 12)
	hud_radio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_radio.custom_minimum_size = Vector2(240, 0)
	hud_radio.modulate = Color(0.75, 0.9, 1.0)
	cv.add_child(hud_radio)

	# avisos
	toast_box = VBoxContainer.new()
	toast_box.anchor_left = 0.5
	toast_box.anchor_right = 0.5
	toast_box.offset_left = -310
	toast_box.offset_right = 310
	toast_box.offset_top = 14
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_constant_override("separation", 4)
	hud_root.add_child(toast_box)
	banner_label = Label.new()
	banner_label.anchor_left = 0.0
	banner_label.anchor_right = 1.0
	banner_label.anchor_top = 0.3
	banner_label.anchor_bottom = 0.3
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 64)
	banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	banner_label.add_theme_constant_override("outline_size", 14)
	banner_label.modulate = Color(1, 0.95, 0.5, 0)
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(banner_label)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(flash_rect)

	overlay = CanvasLayer.new()
	overlay.layer = 5
	add_child(overlay)

func toast(text: String) -> void:
	if toast_box == null:
		return
	while toast_box.get_child_count() >= 4:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _card_style(0.82))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(580, 0)
	l.add_theme_font_size_override("font_size", 15)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc.add_child(l)
	toast_box.add_child(pc)
	var tw := pc.create_tween()
	tw.tween_interval(4.5)
	tw.tween_property(pc, "modulate:a", 0.0, 0.6)
	tw.tween_callback(pc.queue_free)

func banner(text: String, secs := 1.5) -> void:
	if banner_label == null:
		return
	banner_label.text = text
	banner_label.modulate = Color(1, 0.95, 0.5, 1)
	var tw := banner_label.create_tween()
	tw.tween_interval(secs)
	tw.tween_property(banner_label, "modulate:a", 0.0, 0.5)

func flash() -> void:
	if flash_rect == null:
		return
	flash_rect.color = Color(1, 1, 1, 0.85)
	var tw := flash_rect.create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.45)

func on_mission_changed() -> void:
	_refresh_hud()

func _objective() -> String:
	var g := GameState
	if g.gf_status == "none" and g.bond < 40:
		return "Objetivo: conheça a Maya no Café (depois das 12h)."
	if g.gf_status == "none":
		return "Objetivo: converse com a Maya até virar algo mais."
	if g.gf_status == "dating":
		return "Objetivo: peça a Maya em namoro (vínculo 60+)."
	if not g.has_car():
		return "Objetivo: compre seu primeiro carro na Concessionária."
	if g.house_id < 2:
		return "Objetivo: compre uma casa com quintal na Imobiliária."
	if g.gf_status == "girlfriend" and not g.gf_lives_with:
		return "Objetivo: convide a Maya para morar com você (vínculo 80+)."
	return "Objetivo: jogue partidas, suba a fama e compre a mansão."

func _refresh_hud() -> void:
	var g := GameState
	hud_top.text = "$%d  ·  Dia %d  %s  ·  %s" % [g.money, g.day, g.time_text(), weather.text()]
	energy_bar.value = g.energy
	var car_txt := g.car_name() if g.has_car() else "sem carro"
	hud_status.text = "Energia %d%%  ·  %s  ·  %s  ·  Maya: %s (%d)  ·  Fama %d" % [
		int(g.energy), g.house().name, car_txt, g.relationship_label(), g.bond, g.total_fame()]
	var ms: String = missions.status_text()
	if ms != "":
		hud_objective.text = "MISSÃO: " + ms
		hud_objective.modulate = Color(1.0, 0.85, 0.35)
	else:
		hud_objective.text = _objective()
		hud_objective.modulate = Color(0.95, 0.95, 0.8)
	var me := ref_pos()
	var district := G.district_at(me)
	var place := district.to_upper()
	if near_spot != "":
		place = SPOTS[near_spot].label.to_upper()
	elif in_car:
		place = "DIRIGINDO · " + district.to_upper()
	if has_waypoint:
		var dist := int(Vector2(me.x - waypoint.x, me.z - waypoint.z).length())
		place += "\nGPS: %s · %d m" % [waypoint_label, dist]
	hud_place.text = place
	var parts := ["WASD mover", "Shift correr"]
	if g.has_car():
		parts.append("F sair do carro" if in_car else "F entrar no carro")
	if in_car:
		parts.append("H buzina · R rádio · Espaço freio")
	if near_spot != "":
		parts.append("E entrar: %s" % SPOTS[near_spot].label)
	parts.append("M mapa · J celular · Esc pausa")
	hud_hint.text = " · ".join(parts)
	car_card.visible = in_car
	if in_car:
		var kmh := int(absf(car_speed) * 3.6)
		hud_speed.text = "%d km/h" % kmh
		var lim := int(traffic.SPEED_LIMIT * 3.6)
		hud_limit.text = "Limite %d km/h%s" % [lim, "  — acima!" if kmh > lim else ""]
		hud_speed.modulate = Color(1, 0.45, 0.4) if kmh > lim else Color(1, 1, 1)
		var fuel_txt := ""
		if city.b("fuel_enabled"):
			fuel_bar.visible = true
			fuel_bar.value = city.f("fuel")
			fuel_txt = "Combustível %d%%\n" % int(city.f("fuel"))
		else:
			fuel_bar.visible = false
		hud_radio.text = fuel_txt + radio.title()
		var rt: String = radio.current_text(weather.text())
		if rt != "":
			hud_radio.text += "\n" + rt

# ---------------- LOOP ----------------
func _process(delta: float) -> void:
	for n in GameState.pop_notifications():
		toast(str(n))
	if not pause_world:
		peds_sys.update(delta)
		traffic.update(delta)
		world.update_lights(traffic.t)
		weather.update(delta, ref_pos())
		radio.update(delta)
	_bump_cd = maxf(0.0, _bump_cd - delta)
	_update_camera(delta)
	_minimap_t += 1
	if _minimap_t % 2 == 0:
		if minimap and minimap.visible:
			minimap.radius = map_radius
			minimap.queue_redraw()
		if big_map and is_instance_valid(big_map):
			big_map.queue_redraw()
	_route_t -= delta
	if _route_t <= 0.0:
		_route_t = 0.7
		if has_waypoint:
			_update_route()
	_update_beacons()
	if modal_open:
		return
	GameState.add_time(delta * TIME_SCALE)
	var drain := ENERGY_DRAIN * (0.75 if city.has_item("fone") else 1.0)
	GameState.energy = maxf(0.0, GameState.energy - delta * drain)
	missions.tick(delta)
	_update_lighting()
	_update_maya()
	_autosave_t += delta
	if _autosave_t > 20.0:
		_autosave_t = 0.0
		city.save()
	if has_waypoint and Vector2(ref_pos().x - waypoint.x, ref_pos().z - waypoint.z).length() < 7.0:
		toast("Você chegou: %s" % waypoint_label)
		clear_waypoint()

func _update_beacons() -> void:
	if beacon_wp:
		beacon_wp.visible = has_waypoint
		beacon_wp.position = waypoint
	var tg: Dictionary = missions.current_target() if missions else {}
	if beacon_ms:
		beacon_ms.visible = not tg.is_empty()
		if not tg.is_empty():
			beacon_ms.position = tg.pos
			var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.005)
			beacon_ms.scale = Vector3(pulse, 1.0, pulse)

func _physics_process(delta: float) -> void:
	if modal_open:
		return
	if in_car:
		_drive(delta)
	else:
		_walk(delta)

	var ref := ref_pos()
	near_spot = ""
	for id in SPOTS.keys():
		var sp: Dictionary = SPOTS[id]
		var p: Vector3 = sp.pos
		var s: Vector3 = sp.size
		var reach := maxf(s.x, s.z) * 0.5 + 6.0
		if Vector2(ref.x - p.x, ref.z - p.z).length() < reach:
			near_spot = id
			break

	if Input.is_action_just_pressed("interact"):
		if missions.try_interact():
			pass
		elif near_spot != "":
			if in_car:
				car_speed = 0.0
			_open_spot(near_spot)
	elif Input.is_action_just_pressed("vehicle"):
		_toggle_car()
	_refresh_hud()

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		if modal_open:
			_close()
		else:
			_open_menu()
		get_viewport().set_input_as_handled()
	elif ev.is_action_pressed("city_map"):
		if modal_open and big_map:
			_close()
		elif not modal_open:
			panels.open_map()
	elif ev.is_action_pressed("city_phone"):
		if modal_open and not pause_world and not big_map:
			_close()
		elif not modal_open:
			panels.open_phone()
	elif modal_open:
		return
	elif ev.is_action_pressed("city_radio"):
		radio.next()
		city.put("radio", radio.idx)
		toast(radio.title())
	elif ev.is_action_pressed("city_horn"):
		if in_car:
			horn_player.play()
			traffic.player_honk()
			if car_label:
				car_label.visible = true
				get_tree().create_timer(0.7).timeout.connect(func ():
					if car_label and is_instance_valid(car_label):
						car_label.visible = false)
	elif ev.is_action_pressed("city_gps"):
		if has_waypoint:
			clear_waypoint()
		else:
			auto_gps_to_mission()
	elif ev.is_action_pressed("city_zoom_in"):
		map_radius = clampf(map_radius * 0.8, 35.0, 170.0)
	elif ev.is_action_pressed("city_zoom_out"):
		map_radius = clampf(map_radius * 1.25, 35.0, 170.0)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_zoom = clampf(cam_zoom * 0.92, 0.55, 1.8)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_zoom = clampf(cam_zoom * 1.08, 0.55, 1.8)

func _update_camera(delta: float) -> void:
	var ref := ref_pos()
	var ratio := 0.0
	var fwd := Vector3.ZERO
	var off := Vector3(0, 14, 14)
	if in_car and car:
		ratio = clampf(absf(car_speed) / 34.0, 0.0, 1.0)
		fwd = -car.global_transform.basis.z * signf(car_speed if absf(car_speed) > 0.5 else 1.0)
		off = Vector3(0, 17, 17)
	var zoom := cam_zoom * (1.0 + ratio * 0.5)
	var target := ref + off * zoom + fwd * ratio * 6.0
	var k := 1.0 - exp(-4.0 * delta)
	camera.global_position = camera.global_position.lerp(target, k)
	var look := ref + Vector3(0, 1.2, 0) + fwd * ratio * 8.0
	cam_focus = cam_focus.lerp(look, 1.0 - exp(-7.0 * delta))
	camera.look_at(cam_focus)
	camera.fov = lerpf(camera.fov, 52.0 + ratio * 14.0, k)
	if cam_shake > 0.001:
		camera.h_offset = randf_range(-1.0, 1.0) * cam_shake
		camera.v_offset = randf_range(-1.0, 1.0) * cam_shake
		cam_shake = maxf(0.0, cam_shake - delta * 1.8)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

func _walk(_delta: float) -> void:
	var dir := Vector3(Input.get_axis("move_left", "move_right"), 0, Input.get_axis("move_up", "move_down"))
	if dir.length() > 1.0:
		dir = dir.normalized()
	var spd := WALK_SPEED
	if Input.is_action_pressed("sprint"):
		spd = SPRINT_SPEED * (1.0 + 0.02 * float(city.i("fitness")) + (0.08 if city.has_item("fone") else 0.0))
	if GameState.energy < 10.0:
		spd *= 0.6
	player.velocity = dir * spd
	player.move_and_slide()
	if dir.length() > 0.1:
		player.look_at(player.global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)
	Props.update_walk(player.get_child(0), player.velocity.length(), _delta)

func _drive(delta: float) -> void:
	var def := GameState.car_data(GameState.current_car)
	var vmax: float = def.speed
	var fuel_on: bool = city.b("fuel_enabled")
	var fuel: float = city.f("fuel")
	if fuel_on and fuel <= 0.0:
		vmax *= 0.25
	var grip_k: float = weather.grip()
	var throttle := Input.get_axis("move_down", "move_up")
	if lock_drive:
		throttle = 0.0
	if throttle > 0.0:
		car_speed = move_toward(car_speed, vmax * throttle, 16.0 * grip_k * delta)
	elif throttle < 0.0:
		car_speed = move_toward(car_speed, -vmax * 0.35, 26.0 * delta)
	else:
		car_speed = move_toward(car_speed, 0.0, 9.0 * delta)
	if Input.is_action_pressed("city_brake") or lock_drive:
		car_speed = move_toward(car_speed, 0.0, 34.0 * delta)
	var steer := Input.get_axis("move_right", "move_left")
	if absf(car_speed) > 0.5:
		var grip := clampf(absf(car_speed) / 8.0, 0.0, 1.0)
		car.rotation.y += steer * 1.7 * delta * grip * signf(car_speed) * (0.88 + 0.12 * grip_k)
	var fwd := -car.global_transform.basis.z
	car.velocity = fwd * car_speed
	car.move_and_slide()
	if car.get_slide_collision_count() > 0:
		var imp := absf(car_speed)
		car_speed *= 0.4
		if imp > 6.0:
			on_bump(imp, false)
	player.global_position = car.global_position
	if fuel_on:
		fuel = maxf(0.0, fuel - absf(car_speed) * delta * 0.0075 * sqrt(vmax / 16.0))
		city.put("fuel", fuel)
		if fuel < 15.0 and _fuel_warn >= 15.0:
			toast("Combustível baixo! Procure o Posto.")
		if fuel <= 0.0 and _fuel_warn > 0.0:
			toast("Sem combustível! O carro anda na reserva. Vá ao Posto.")
		_fuel_warn = fuel
	else:
		_fuel_warn = 100.0

func on_bump(strength: float, police := false) -> void:
	if _bump_cd > 0.0:
		return
	_bump_cd = 0.9
	cam_shake = clampf(strength * 0.03, 0.12, 0.7)
	toast("Cuidado com a viatura da Guarda!" if police else "Batida leve! Sem danos, mas dirija com cuidado.")
	if missions:
		missions.on_bump(strength)

func fine_player(amount: int, reason: String) -> void:
	if GameState.spend(amount):
		toast("MULTA de $%d: %s." % [amount, reason])
	else:
		city.add_i("fines_due", amount)
		toast("Multa de $%d (%s) registrada. Pague no Banco." % [amount, reason])
	city.save()

func _toggle_car() -> void:
	if car == null:
		return
	if in_car:
		in_car = false
		car_speed = 0.0
		player.global_position = car.global_position + car.global_transform.basis.x * 2.8
		player.global_position.y = 0.0
		player.visible = true
		player_col.set_deferred("disabled", false)
	elif player.global_position.distance_to(car.global_position) < 5.5:
		if missions.blocks_car():
			toast("Treino em andamento: corra a pé!")
			return
		in_car = true
		player.visible = false
		player_col.set_deferred("disabled", true)

func _update_lighting() -> void:
	var t := (GameState.hour - 6.0) / 12.0
	var inside := t >= 0.0 and t <= 1.0
	var day_f := clampf(sin(t * PI), 0.0, 1.0) if inside else 0.0
	var tc := clampf(t, 0.0, 1.0)
	var elev := maxf(25.0, sin(tc * PI) * 60.0 + 5.0)
	sun.rotation_degrees = Vector3(-elev, -40.0 + tc * 80.0, 0.0)
	sun.light_energy = lerpf(0.18, 1.1, day_f)
	sun.light_color = Color(0.55, 0.65, 1.0).lerp(Color(1.0, 0.92, 0.78), day_f)
	if absf(day_f - _last_df) > 0.03:
		_last_df = day_f
		env = Mats.make_env(day_f)
		world_env.environment = env
		_base_amb = env.ambient_light_energy
		_base_fog = env.fog_light_color
	env.ambient_light_energy = _base_amb
	env.background_color = _base_fog
	weather.apply(env, sun, day_f)
	var dim: float = clampf(day_f * 1.5 - weather.rain_k * 0.6 - weather.fog_k * 0.4, 0.0, 1.0)
	var lamp_e := lerpf(2.5, 0.0, dim)
	for l in lamps:
		l.light_energy = lamp_e
		l.visible = lamp_e > 0.05
	var head_e := lerpf(3.0, 0.0, dim)
	for sl in car_lights:
		sl.light_energy = head_e

# ---------------- PAINÉIS ----------------
func _clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()

func _close() -> void:
	modal_open = false
	pause_world = false
	big_map = null
	panel_msg = ""
	_clear_overlay()

func _save_all() -> void:
	GameState.save_game()
	city.save()

func _panel(title: String, body: String, width := 560) -> VBoxContainer:
	_clear_overlay()
	modal_open = true
	pause_world = false
	big_map = null
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 200)
	center.add_child(panel)
	var m := MarginContainer.new()
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, 16)
	for k in ["margin_top", "margin_bottom"]:
		m.add_theme_constant_override(k, 12)
	panel.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 28)
	v.add_child(t)
	var b := Label.new()
	b.text = body
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(width - 40, 0)
	v.add_child(b)
	if panel_msg != "":
		var msg := Label.new()
		msg.text = panel_msg
		msg.modulate = Color(1.0, 0.9, 0.5)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.custom_minimum_size = Vector2(width - 40, 0)
		v.add_child(msg)
	return v

func _btn(parent: VBoxContainer, text: String, cb: Callable, disabled := false) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.pressed.connect(cb)
	parent.add_child(b)

func _back(parent: VBoxContainer) -> void:
	_btn(parent, "Sair", _close)

func _say(spot: String, msg: String) -> void:
	panel_msg = msg
	_save_all()
	_open_spot(spot)

func _open_menu() -> void:
	panels.open_menu()

func _open_spot(id: String) -> void:
	if id.begins_with("career"):
		_career_panel(id)
		return
	match id:
		"stadium": _spot_stadium()
		"home": _spot_home()
		"cars": _spot_cars()
		"realestate": _spot_realestate()
		"cafe": _spot_cafe()
		"mall": _spot_mall()
		"gym": _spot_gym()
		_: panels.open(id)

func _spot_stadium() -> void:
	var g := GameState
	if g.season_over():
		var pos := g.position()
		var table_snapshot := g.table_text()
		var bonus := g.finish_season()
		var v0 := _panel("Fim da temporada %d" % (g.season - 1),
			"Você terminou em %dº lugar na %s.\nBônus: $%d%s\n\n%s" % [
				pos, g.league().name, bonus, " · CAMPEÃO! +10 fama" if pos == 1 else "", table_snapshot])
		_btn(v0, "Começar nova temporada", func (): _open_spot("stadium"))
		_back(v0)
		return
	if g.retired:
		var vr := _panel("Estádio", "Você se aposentou dos gramados.\n\n%s" % g.retirement_summary())
		_back(vr)
		return
	var injured := not g.can_play()
	var tired := g.energy < 15.0 or injured
	var v := _panel("Estádio — %s" % g.club_name,
		"%s · Temporada %d · Posição %dº\n%s\nSalário/jogo: vitória $%d · empate $%d · derrota $%d · gasta 30%% de energia.\n\n%s" % [
			g.league().name, g.season, g.position(), g.next_fixture_text(),
			g.salary_for(1, 0), g.salary_for(0, 0), g.salary_for(0, 1), g.table_text()])
	if tired:
		var w := Label.new()
		w.text = ("Lesionado: " + g.injury_text()) if injured else "Você está exausto demais para jogar. Descanse em casa."
		w.modulate = Color(1, 0.5, 0.4)
		v.add_child(w)
	_btn(v, "Entrar em campo", func (): _save_all(); get_tree().change_scene_to_file("res://scenes/match.tscn"), tired)
	_back(v)

func _spot_home() -> void:
	var g := GameState
	var h := g.house()
	var body := "%s\n%s\nEnergia %d%% · Partidas %d · Vitórias %d\nVelocidade %d · Chute %d · Passe %d" % [
		h.name, h.desc, int(g.energy), g.matches_played, g.wins, g.pace, g.shoot, g.pass_skill]
	if g.house_id == 0:
		body += "\nAluguel: $%d por semana." % int(GameState.HOUSES[0].rent)
	var v := _panel("Minha casa", body)
	_btn(v, "Dormir até de manhã", func ():
		g.sleep_at_home()
		_update_lighting()
		_say("home", "Você dormiu. Dia %d, %s. Energia %d%%." % [g.day, g.time_text(), int(g.energy)]))
	_btn(v, "Salvar", func (): _say("home", "Jogo salvo."))
	_btn(v, "Carreira, contrato e finanças", func (): _open_spot("career"))
	if city.has_item("console"):
		_btn(v, "Jogar videogame (1h, +4 energia%s)" % (", +3 vínculo" if g.gf_lives_with else ""), func ():
			g.energy = minf(100.0, g.energy + 4.0)
			g.add_time(1.0)
			if g.gf_lives_with:
				g.bond = mini(100, g.bond + 3)
			_say("home", "Partidas divertidas no console."))
	if g.gf_status == "girlfriend" and not g.gf_lives_with:
		var can_move: bool = g.house_id >= 2 and g.bond >= 80
		_btn(v, "Convidar Maya para morar (casa com quintal + vínculo 80)", func ():
			g.gf_lives_with = true
			g.bond = mini(100, g.bond + 10)
			g.last_date_day = g.day
			_update_maya()
			_say("home", "Maya disse sim! Ela se mudou para a sua casa."), not can_move)
	elif g.gf_lives_with:
		_btn(v, "Passar a noite com a Maya (+vínculo)", func ():
			g.bond = mini(100, g.bond + 6)
			g.add_time(3.0)
			g.energy = minf(100.0, g.energy + 15.0)
			g.last_date_day = g.day
			_say("home", "Uma noite tranquila com a Maya. Vínculo %d." % g.bond))
	_back(v)

func _spot_cars() -> void:
	var g := GameState
	var v := _panel("Concessionária", "Dirija com WASD (F entra/sai do carro).\nCaixa: $%d" % g.money)
	for c in GameState.CARS:
		var owned: bool = g.owned_cars.has(c.id)
		if owned:
			var using: bool = g.current_car == c.id
			_btn(v, "%s — %s" % [c.name, "em uso" if using else "usar este"], func ():
				g.current_car = c.id
				_spawn_current_car()
				_say("cars", "Agora você usa o %s. Está estacionado na sua casa." % c.name), using)
		else:
			_btn(v, "%s — $%d (vel. %d)" % [c.name, c.price, int(c.speed)], func ():
				if g.spend(c.price):
					g.owned_cars.append(c.id)
					g.current_car = c.id
					_spawn_current_car()
					_say("cars", "Comprou o %s! Está estacionado na sua casa." % c.name), g.money < c.price)
	_back(v)

func _spot_realestate() -> void:
	var g := GameState
	var v := _panel("Imobiliária", "Moradia atual: %s\nCaixa: $%d" % [g.house().name, g.money])
	for h in GameState.HOUSES:
		if h.id <= g.house_id:
			continue
		_btn(v, "%s — $%d" % [h.name, h.price], func ():
			if g.spend(h.price):
				g.house_id = h.id
				_build_home()
				_update_maya()
				_say("realestate", "Parabéns! Você comprou: %s." % h.name), g.money < h.price)
	if g.house_id >= GameState.HOUSES.size() - 1:
		var l := Label.new()
		l.text = "Você já tem a melhor casa da cidade."
		v.add_child(l)
	_back(v)

func _spot_cafe() -> void:
	var g := GameState
	if not _maya_here():
		var v0 := _panel("Café", "A Maya costuma aparecer depois das 12h.\nVocê pode tomar um café sozinho ($10, +10 energia).")
		_btn(v0, "Tomar um café ($10)", func ():
			if g.spend(10):
				g.energy = minf(100.0, g.energy + 10.0)
				g.add_time(0.5)
				_say("cafe", "Você tomou um café."), g.money < 10)
		_back(v0)
		return
	var line := ""
	match g.gf_status:
		"none": line = "Maya sorri: \"Ah, é você! Quer sentar um pouco?\""
		"dating": line = "Maya: \"Estou gostando de passar tempo com você.\""
		"girlfriend": line = "Maya: \"Meu amor! Que bom te ver.\""
	var v := _panel("Café — Maya", "%s\n" + g.maya_status_text() + "\nStatus: %s · Vínculo %d/100 · Caixa $%d" % [line, g.relationship_label(), g.bond, g.money])
	_btn(v, "Conversar (grátis, +3 vínculo)", func ():
		g.bond = mini(100, g.bond + 3)
		g.add_time(1.0)
		g.last_date_day = g.day
		_check_dating()
		_say("cafe", "Vocês conversaram por uma hora. Vínculo %d." % g.bond))
	_btn(v, "Jantar juntos ($80, +18 vínculo)", func ():
		if g.spend(80):
			g.bond = mini(100, g.bond + 18)
			g.add_time(2.0)
			g.last_date_day = g.day
			_check_dating()
			_say("cafe", "Jantar perfeito. Vínculo %d." % g.bond), g.money < 80)
	for gift in GameState.GIFTS:
		var n := g.gift_count(gift.id)
		if n > 0:
			_btn(v, "Dar presente: %s (x%d, +%d)" % [gift.name, n, gift.bond], func ():
				g.gifts[gift.id] = n - 1
				g.bond = mini(100, g.bond + int(gift.bond))
				g.last_date_day = g.day
				_check_dating()
				_say("cafe", "Maya adorou o presente! Vínculo %d." % g.bond))
	if g.gf_status == "dating":
		_btn(v, "Pedir em namoro (vínculo 60+)", func ():
			if g.bond >= 60:
				g.gf_status = "girlfriend"
				g.fame += 2
				_say("cafe", "Ela disse SIM! Vocês agora estão namorando.")
			else:
				_say("cafe", "Maya: \"Ainda é cedo... vamos nos conhecer melhor.\""))
	var ev: String = g.maya_event_text()
	if ev != "":
		var evl := Label.new()
		evl.text = ev
		evl.modulate = Color(1.0, 0.8, 0.9)
		evl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		evl.custom_minimum_size = Vector2(520, 0)
		v.add_child(evl)
		for o in g.maya_event_options():
			var oid: String = str(o.id)
			_btn(v, str(o.label), func (): _say("cafe", g.resolve_maya_event(oid)))
	if g.gf_status == "girlfriend" and not g.maya_married:
		_btn(v, "Pedir Maya em casamento", func (): _say("cafe", g.propose_marriage()))
	elif g.maya_married:
		_btn(v, "Tentar ter um filho", func (): _say("cafe", g.try_for_child()))
	_back(v)

func _check_dating() -> void:
	var g := GameState
	if g.gf_status == "none" and g.bond >= 40:
		g.gf_status = "dating"

func _spot_mall() -> void:
	var g := GameState
	var v := _panel("Shopping", "Roupas aumentam a fama. Presentes encantam a Maya.\nCaixa: $%d" % g.money)
	for c in GameState.CLOTHES:
		if c.id <= g.clothes_id:
			continue
		_btn(v, "%s — $%d (fama +%d)" % [c.name, c.price, c.fame], func ():
			if g.spend(c.price):
				g.clothes_id = c.id
				_say("mall", "Você comprou: %s." % c.name), g.money < c.price)
	for gift in GameState.GIFTS:
		_btn(v, "Presente: %s — $%d (você tem %d)" % [gift.name, gift.price, g.gift_count(gift.id)], func ():
			if g.spend(gift.price):
				g.gifts[gift.id] = g.gift_count(gift.id) + 1
				_say("mall", "Comprou: %s. Entregue à Maya no café." % gift.name), g.money < gift.price)
	_back(v)

func _spot_gym() -> void:
	var g := GameState
	var v := _panel("Academia", "Treino: $60, 2h, -20%% energia. Máximo nível 10.\nVelocidade %d · Chute %d · Passe %d · Energia %d%%" % [g.pace, g.shoot, g.pass_skill, int(g.energy)])
	for k in ["pace", "shoot", "pass"]:
		_btn(v, "Treinar %s" % GameState.STAT_NAMES[k], func (): _say("gym", g.train(k)))
	_back(v)

# ---------------- CARREIRA / FINANÇAS ----------------
func _career_say(id: String, msg: String) -> void:
	panel_msg = msg
	_save_all()
	_open_spot(id)

func _career_panel(id: String) -> void:
	var g := GameState
	match id:
		"career_contract":
			var v := _panel("Contrato e propostas", g.contract_text() + "\n\n" + g.offers_text(), 620)
			_btn(v, "Renovar contrato", func (): _career_say("career_contract", g.try_renew_contract()))
			_btn(v, "Pedir propostas ao agente", func (): _career_say("career_contract", g.ask_agent_offers()))
			if g.transfer_window_open():
				for i in g.offers.size():
					var k := i
					_btn(v, "Aceitar proposta %d" % (i + 1), func (): _career_say("career_contract", g.accept_offer(k)))
					_btn(v, "Recusar proposta %d" % (i + 1), func (): _career_say("career_contract", g.reject_offer(k)))
			_btn(v, "Voltar", func (): _open_spot("career"))
		"career_squad":
			var v := _panel("Elenco e estatísticas", g.attrs_text() + "\n\n" + g.stats_text() + "\n\nArtilheiros:\n" + g.top_scorers_text(5) + "\n\n" + g.squad_text(), 620)
			_btn(v, "Voltar", func (): _open_spot("career"))
		"career_history":
			var v := _panel("Histórico e troféus", g.trophies_text() + "\n\n" + g.history_text(), 620)
			_btn(v, "Voltar", func (): _open_spot("career"))
		"career_money":
			var v := _panel("Finanças e patrocínios", g.finance_text() + "\n\n" + g.sponsors_text() + "\n\n" + g.investments_text(), 640)
			for sid in ["bike", "drink", "boots", "bank", "watch", "car"]:
				var sk: String = sid
				_btn(v, "Patrocínio: assinar %s" % sk, func (): _career_say("career_money", str(g.sign_sponsor(sk))))
				_btn(v, "Patrocínio: cancelar %s" % sk, func (): _career_say("career_money", str(g.drop_sponsor(sk))))
			for iid in ["kiosk", "shop", "flat", "gymbiz"]:
				var ik: String = iid
				_btn(v, "Investir: comprar %s" % ik, func (): _career_say("career_money", str(g.buy_investment(ik))))
				_btn(v, "Investir: vender %s" % ik, func (): _career_say("career_money", str(g.sell_investment(ik))))
			_btn(v, "Voltar", func (): _open_spot("career"))
		"career_press":
			var v := _panel("Imprensa e reputação", g.press_text(), 560)
			_btn(v, "Dar entrevista", func (): _career_say("career_press", str(g.give_interview())))
			_btn(v, "Doar $100 para caridade", func (): _career_say("career_press", str(g.charity(100))))
			_btn(v, "Voltar", func (): _open_spot("career"))
		_:
			var v := _panel("Carreira", g.career_summary_text(), 640)
			_btn(v, "Contrato e propostas", func (): _open_spot("career_contract"))
			_btn(v, "Elenco e estatísticas", func (): _open_spot("career_squad"))
			_btn(v, "Histórico e troféus", func (): _open_spot("career_history"))
			_btn(v, "Finanças, patrocínios e investimentos", func (): _open_spot("career_money"))
			_btn(v, "Imprensa", func (): _open_spot("career_press"))
			if g.injury_days > 0:
				_btn(v, "Fisioterapia", func (): _career_say("career", str(g.physio())))
			if g.can_retire() and not g.retired:
				_btn(v, "Aposentar-se (definitivo)", func (): _career_say("career", g.retire_player()))
			_btn(v, "Voltar", func (): _open_spot("home"))
