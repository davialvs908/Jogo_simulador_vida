extends Node3D
## Partida 12v12: regras (laterais, escanteios, tiro de meta, faltas, cartões, impedimento),
## controle do jogador, bola, câmera dinâmica, replay de gol, intervalo e resultado.
## IA em match_ai.gd · bola em match_ball.gd · HUD em match_hud.gd · radar em match_radar.gd

const C := preload("res://scripts/match_consts.gd")
const BallScript := preload("res://scripts/match_ball.gd")
const AIScript := preload("res://scripts/match_ai.gd")
const HudScript := preload("res://scripts/match_hud.gd")

# constantes legadas (outros scripts podem ler)
const PITCH_W := C.PITCH_W
const PITCH_D := C.PITCH_D
const HALF_W := C.HALF_W
const HALF_D := C.HALF_D
const MATCH_SECONDS := 90.0

const ATT_SPOTS := [Vector2(-5, 8), Vector2(5, 8), Vector2(0, 5), Vector2(-9, 11), Vector2(9, 11), Vector2(0, 15), Vector2(-4, 12)]
const DEF_SPOTS := [Vector2(-7, 3), Vector2(-3, 3), Vector2(3, 3), Vector2(7, 3), Vector2(-5, 7), Vector2(0, 7), Vector2(5, 7), Vector2(0, 11)]

var players: Array[Footballer] = []
var gks: Array = [null, null]
var ball
var camera: Camera3D
var ai
var hud
var rng := RandomNumberGenerator.new()

var home_score := 0
var away_score := 0
var running := true
var state: int = C.State.RESTART
var half := 1
var half_elapsed := 0.0
var clock_min := 0.0
var sim_time := 0.0

var carrier: Footballer = null
var controlled: Footballer = null
var last_touch: Footballer = null
var last_touch_team := -1
var intended: Footballer = null
var taker: Footballer = null
var shot_id := 0
var kick_time := -10.0
var offside_set: Array = []

var restart_type: int = C.Restart.KICKOFF
var restart_team := 0
var restart_pos := Vector3.ZERO
var restart_t := 0.0

var goal_t := 0.0
var goal_side := 0
var scorer: Footballer = null
var ht_t := 0.0
var team_skill := [0.6, 0.6]

var rec: Array = []
var rec_acc := 0.0
var replay_frames: Array = []
var replay_i := 0.0

var pass_held := false
var pass_hold := 0.0
var shoot_held := false
var shoot_charge := 0.0
var shoot_time := 0.0
var switch_lock := 0.0

var stats := {"shots": [0, 0], "fouls": [0, 0], "yellow": [0, 0], "red": [0, 0], "poss": [0.0, 0.0], "saves": [0, 0], "passes": [0, 0], "tackles": [0, 0], "intercepts": [0, 0]}
var result_text := ""
var finished_called := false
var autoplay := false   # depuração/demonstração: a IA também controla o seu jogador

var cam_focus := Vector3.ZERO
var cam_fov := 42.0

# ================================================================= setup
func _ready() -> void:
	rng.randomize()
	_ensure_actions()
	_compute_skills()
	_build_world()
	_spawn_ball()
	_spawn_teams()
	ai = AIScript.new()
	ai.m = self
	hud = HudScript.new()
	add_child(hud)
	hud.build(self)
	_setup_kickoff(0)
	hud.banner("APITO INICIAL", Color(1, 1, 1), 2.2, 54)
	cam_focus = Vector3.ZERO
	_update_camera(1.0)

func _ensure_actions() -> void:
	if not InputMap.has_action("switch_player"):
		InputMap.add_action("switch_player")
		for k in [KEY_TAB, KEY_Q]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event("switch_player", ev)

func _compute_skills() -> void:
	var own := Leagues.club_strength(GameState.league_id, GameState.club_idx)
	var opp := Leagues.club_strength(GameState.league_id, GameState.opponent_idx())
	team_skill[0] = clampf((float(own) - 55.0) / 45.0 + 0.05, 0.3, 0.95)
	team_skill[1] = clampf((float(opp) - 55.0) / 45.0, 0.3, 0.95)

func _physics_process(delta: float) -> void:
	tick(delta)

# ================================================================= mundo
func _build_world() -> void:
	var Mats := preload("res://scripts/materials.gd")
	var env := WorldEnvironment.new()
	env.environment = Mats.make_env(0.22)   # crepúsculo, com os holofotes do estádio
	add_child(env)
	add_child(Mats.make_sun(0.22))

	var pitch := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(PITCH_W + 10.0, PITCH_D + 10.0)
	pitch.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.16, 0.38, 0.22)
	grass.roughness = 0.95
	pitch.material_override = grass
	add_child(pitch)
	for i in range(-6, 7):
		if i % 2 == 0:
			continue
		var stripe := MeshInstance3D.new()
		var sp := PlaneMesh.new()
		sp.size = Vector2(PITCH_W, PITCH_D / 13.0)
		stripe.mesh = sp
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.21, 0.47, 0.27)
		stripe.material_override = sm
		stripe.position = Vector3(0, 0.01, i * PITCH_D / 13.0)
		add_child(stripe)
	_build_lines()

	_make_goal(Vector3(0, 0, -HALF_D), -1.0)
	_make_goal(Vector3(0, 0, HALF_D), 1.0)
	for p in [Vector3(-HALF_W - 4, 0, -HALF_D - 2), Vector3(HALF_W + 4, 0, -HALF_D - 2), Vector3(-HALF_W - 4, 0, HALF_D + 2), Vector3(HALF_W + 4, 0, HALF_D + 2)]:
		_make_flood(p)
	for z in [-HALF_D - 5.0, HALF_D + 5.0]:
		var stand := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(PITCH_W + 8, 4, 4)
		stand.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.22, 0.3)
		stand.material_override = mat
		stand.position = Vector3(0, 2, z)
		add_child(stand)
	# bandeirinhas de escanteio
	for cx in [-HALF_W, HALF_W]:
		for cz in [-HALF_D, HALF_D]:
			var flag := MeshInstance3D.new()
			var fc := CylinderMesh.new()
			fc.top_radius = 0.03
			fc.bottom_radius = 0.03
			fc.height = 1.5
			flag.mesh = fc
			var fm := StandardMaterial3D.new()
			fm.albedo_color = Color(1.0, 0.85, 0.2)
			flag.material_override = fm
			flag.position = Vector3(cx, 0.75, cz)
			add_child(flag)

	camera = Camera3D.new()
	camera.fov = cam_fov
	camera.position = Vector3(-31, 15.5, 0)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0, 0.5, 0))

func _line(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var len := a.distance_to(b)
	bm.size = Vector3(0.14, 0.02, len)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.95, 0.97, 0.95)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = (a + b) * 0.5 + Vector3(0, 0.025, 0)
	add_child(mi)
	mi.look_at_from_position(mi.position, Vector3(b.x, 0.025, b.z), Vector3.UP)

func _build_lines() -> void:
	var c := [Vector3(-HALF_W, 0, -HALF_D), Vector3(HALF_W, 0, -HALF_D), Vector3(HALF_W, 0, HALF_D), Vector3(-HALF_W, 0, HALF_D)]
	for i in 4:
		_line(c[i], c[(i + 1) % 4])
	_line(Vector3(-HALF_W, 0, 0), Vector3(HALF_W, 0, 0))
	for s in [-1.0, 1.0]:
		var gz: float = s * HALF_D
		var bz: float = gz - s * C.BOX_DEPTH
		_line(Vector3(-C.BOX_HALF_W, 0, bz), Vector3(C.BOX_HALF_W, 0, bz))
		_line(Vector3(-C.BOX_HALF_W, 0, gz), Vector3(-C.BOX_HALF_W, 0, bz))
		_line(Vector3(C.BOX_HALF_W, 0, gz), Vector3(C.BOX_HALF_W, 0, bz))
		var sz: float = gz - s * 5.0
		_line(Vector3(-6, 0, sz), Vector3(6, 0, sz))
		_line(Vector3(-6, 0, gz), Vector3(-6, 0, sz))
		_line(Vector3(6, 0, gz), Vector3(6, 0, sz))
	var prev := Vector3(6.0, 0, 0)
	for i in range(1, 25):
		var a := TAU * float(i) / 24.0
		var cur := Vector3(cos(a) * 6.0, 0, sin(a) * 6.0)
		_line(prev, cur)
		prev = cur

func _make_goal(at: Vector3, s: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.96, 0.98)
	mat.metallic = 0.4
	mat.roughness = 0.3
	for x in [-C.GOAL_HALF, C.GOAL_HALF]:
		var post := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.08
		c.bottom_radius = 0.08
		c.height = C.GOAL_H
		post.mesh = c
		post.material_override = mat
		post.position = at + Vector3(x, C.GOAL_H * 0.5, 0)
		add_child(post)
	var cross := MeshInstance3D.new()
	var cb := CylinderMesh.new()
	cb.top_radius = 0.07
	cb.bottom_radius = 0.07
	cb.height = C.GOAL_HALF * 2.0 + 0.2
	cross.mesh = cb
	cross.material_override = mat
	cross.rotation_degrees = Vector3(0, 0, 90)
	cross.position = at + Vector3(0, C.GOAL_H, 0)
	add_child(cross)
	# rede (caixa translúcida)
	var net := MeshInstance3D.new()
	var nb := BoxMesh.new()
	nb.size = Vector3(C.GOAL_HALF * 2.0, C.GOAL_H, 2.4)
	net.mesh = nb
	var nm := StandardMaterial3D.new()
	nm.albedo_color = Color(1, 1, 1, 0.12)
	nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nm.cull_mode = BaseMaterial3D.CULL_DISABLED
	net.material_override = nm
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	net.position = at + Vector3(0, C.GOAL_H * 0.5, s * 1.2)
	add_child(net)

func _make_flood(at: Vector3) -> void:
	var pole := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.18
	c.bottom_radius = 0.25
	c.height = 16
	pole.mesh = c
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.55, 0.58, 0.62)
	pm.metallic = 0.7
	pole.material_override = pm
	pole.position = at + Vector3(0, 8, 0)
	add_child(pole)
	var light := SpotLight3D.new()
	light.light_color = Color(1.0, 0.95, 0.85)
	light.light_energy = 4.5
	light.spot_range = 90
	light.spot_angle = 48
	light.shadow_enabled = true
	light.position = at + Vector3(0, 16, 0)
	add_child(light)
	light.look_at(Vector3(0, 0, at.z * 0.1), Vector3.UP)

func _spawn_ball() -> void:
	ball = BallScript.new()
	ball.position = Vector3(0, C.BALL_R, 0)
	add_child(ball)

func _spawn_teams() -> void:
	var skin_i := 0
	for side in 2:
		for i in C.FORM.size():
			var f: Dictionary = C.FORM[i]
			var sg := C.sgn(side)
			var num: int = f.num
			if side == 1 and num == 17:
				num = 19
			var role: int = f.role
			var p := Footballer.new()
			var user: bool = side == 0 and i == 10
			p.setup(side, role, user, num, Vector3(f.x * sg, 0, f.d * sg), skin_i, skin_i + 2)
			p.slot = i
			p.skill = clampf(team_skill[side] + rng.randfn(0.0, 0.04), 0.2, 0.97)
			p.pace_attr = (0.94 + 0.12 * p.skill) * rng.randf_range(0.97, 1.03)
			add_child(p)
			players.append(p)
			if role == 0:
				gks[side] = p
			if user:
				controlled = p
			skin_i += 1

func _user() -> Footballer:
	return controlled

# ================================================================= loop
func tick(dt: float) -> void:
	if not running:
		_update_camera(dt)
		return
	sim_time += dt
	if Input.is_action_just_pressed("ui_cancel"):
		_finish(true)
		return
	if state == C.State.PLAY:
		_tick_play(dt)
	elif state == C.State.RESTART:
		_tick_restart(dt)
	elif state == C.State.GOAL:
		_tick_goal(dt)
	elif state == C.State.REPLAY:
		_tick_replay(dt)
	elif state == C.State.HALFTIME:
		_tick_halftime(dt)
	if not running:
		return
	_update_camera(dt)
	hud.update(self, dt)

func _tick_play(dt: float) -> void:
	_advance_clock(dt)
	if state != C.State.PLAY:
		return
	stats.poss[carrier.team_side if carrier != null else maxi(last_touch_team, 0)] += dt
	_user_control(dt)
	ai.update(dt)
	_step_players(dt)
	_step_ball(dt)
	_check_contacts()
	if state != C.State.PLAY:
		return
	_check_bounds_goal()
	if state != C.State.PLAY:
		return
	_auto_switch(dt)
	_rec_frame(dt)

func _step_players(dt: float) -> void:
	for p in players:
		if p.active:
			p.tick(dt)
	var n := players.size()
	for i in n:
		var a := players[i]
		if not a.active:
			continue
		for j in range(i + 1, n):
			var b := players[j]
			if not b.active:
				continue
			var d := Vector3(a.position.x - b.position.x, 0, a.position.z - b.position.z)
			var l := d.length()
			if l < 0.9 and l > 0.001:
				var push := (0.9 - l) * 0.5
				var dn := d / l
				a.position += dn * push
				b.position -= dn * push

func _step_ball(dt: float) -> void:
	if state == C.State.RESTART:
		ball.update_visual(dt)
		return
	if carrier != null:
		var c := carrier
		var touch := 0.62 + 0.12 * sin(sim_time * 9.0 * (0.4 + c.vel.length() * 0.1))
		var target := c.position + c.facing * touch
		target.y = C.BALL_R
		ball.position = ball.position.lerp(target, minf(1.0, dt * 18.0))
		ball.vel = c.vel
		ball.update_visual(dt)
	else:
		ball.step(dt)

func _advance_clock(dt: float) -> void:
	half_elapsed += dt
	clock_min = float(half - 1) * C.HALF_GAME_MIN + minf(half_elapsed / C.HALF_REAL_SECONDS, 1.0) * C.HALF_GAME_MIN
	if half_elapsed >= C.HALF_REAL_SECONDS:
		if half == 1:
			state = C.State.HALFTIME
			ht_t = 0.0
			carrier = null
			for p in players:
				p.vel = Vector3.ZERO
			hud.banner("FIM DO 1º TEMPO\n%d – %d" % [home_score, away_score], Color(1, 1, 1), 4.0, 56)
		else:
			clock_min = 90.0
			hud.banner("FIM DE JOGO", Color(1, 1, 1), 2.0, 60)
			_finish(false)

# ================================================================= controle do usuário
func charge_active() -> bool:
	return shoot_held or pass_held

func charge_value() -> float:
	if shoot_held:
		return shoot_charge
	return minf(pass_hold / 0.6, 1.0)

func _user_control(dt: float) -> void:
	var u := controlled
	if u == null or not u.active:
		_pick_new_control()
		return
	if autoplay:
		return
	u.has_look = false
	var h := Input.get_axis("move_left", "move_right")
	var v := Input.get_axis("move_up", "move_down")
	var dir := Vector3(-v, 0, h)
	if dir.length() > 1.0:
		dir = dir.normalized()
	if Input.is_action_just_pressed("switch_player"):
		_manual_switch()
		u = controlled
	var has_ball := carrier == u
	if state == C.State.RESTART and u == taker:
		u.drive(Vector3.ZERO, false, dt)
		if dir.length() > 0.2:
			u.facing = u.facing.lerp(dir.normalized(), minf(1.0, dt * 8.0)).normalized()
	else:
		u.drive(dir, Input.is_action_pressed("sprint"), dt, 0.94 if has_ball else 1.0)
	if has_ball:
		if Input.is_action_just_pressed("pass_ball") and not shoot_held:
			pass_held = true
			pass_hold = 0.0
		if pass_held:
			pass_hold += dt
			if not Input.is_action_pressed("pass_ball"):
				pass_held = false
				_user_pass(u, dir, pass_hold)
				return
		if Input.is_action_just_pressed("shoot") and not pass_held:
			shoot_held = true
			shoot_charge = 0.0
			shoot_time = 0.0
		if shoot_held:
			shoot_time += dt
			shoot_charge = minf(1.0, shoot_time / 0.85)
			if not Input.is_action_pressed("shoot") or shoot_time > 1.35:
				shoot_held = false
				_user_shoot(u, dir, shoot_charge)
				return
	else:
		pass_held = false
		shoot_held = false
		if state != C.State.PLAY:
			return
		if Input.is_action_just_pressed("shoot") and u.slide_cd <= 0.0:
			u.start_slide(dir if dir.length() > 0.2 else u.facing)
		elif Input.is_action_just_pressed("pass_ball") and u.tackle_cd <= 0.0 and u.lunge_t <= 0.0:
			u.tackle_cd = 0.8
			u.lunge_t = 0.32
			u.lunge_done = false
			if carrier != null and carrier.team_side != u.team_side:
				var to := Vector3(carrier.position.x - u.position.x, 0, carrier.position.z - u.position.z)
				if to.length() < 6.0:
					u.vel += to.normalized() * 3.0
		if u.lunge_t > 0.0 and not u.lunge_done and carrier != null and carrier.team_side != u.team_side:
			if C.fd(u.position, carrier.position) < 1.35:
				u.lunge_done = true
				try_tackle(u, carrier, false)

func _user_pass(u: Footballer, dir: Vector3, hold: float) -> void:
	var ref := dir if dir.length() > 0.3 else u.facing
	ref = ref.normalized()
	var best: Footballer = null
	var best_sc := -999.0
	for t in players:
		if not t.active or t.team_side != u.team_side or t == u:
			continue
		var v := Vector3(t.position.x - u.position.x, 0, t.position.z - u.position.z)
		var d := v.length()
		if d < 2.5:
			continue
		var cosang := ref.dot(v / d)
		if cosang < 0.55:
			continue
		var sc := cosang * 2.0 - d * 0.03
		if t.player_role == 0:
			sc -= 1.5
		if sc > best_sc:
			best_sc = sc
			best = t
	var lob := hold > 0.35
	var mult := 1.0 + (GameState.pass_skill - 1) * 0.04 + minf(hold, 0.6) * 0.2
	if best != null:
		kick_pass(u, best, C.Kick.LOB if lob else C.Kick.GROUND, mult)
	else:
		var far: Vector3 = ball.position + ref * (24.0 if lob else 14.0)
		far.x = clampf(far.x, -HALF_W + 1.0, HALF_W - 1.0)
		far.z = clampf(far.z, -HALF_D + 1.0, HALF_D - 1.0)
		if lob:
			kick_lob_to(u, far, 1.0)
		else:
			var d2 := Vector3(far.x - ball.position.x, 0, far.z - ball.position.z)
			var ang := rng.randfn(0.0, 0.05)
			ball.vel = d2.normalized().rotated(Vector3.UP, ang) * 15.0 * mult
			ball.curl = 0.0
			_post_kick(u, null)

func _user_shoot(u: Footballer, dir: Vector3, charge: float) -> void:
	var sg := C.sgn(u.team_side)
	var goal_z := sg * HALF_D
	var aim_x := rng.randf_range(-1.2, 1.2)
	if absf(dir.x) > 0.25:
		aim_x = clampf(dir.x * 3.0, -3.1, 3.1)
	var power := lerpf(14.0, 28.0, charge) * (1.0 + (GameState.shoot - 1) * 0.025)
	var ty := lerpf(0.5, 1.7, charge)
	var gd := C.fd(ball.position, Vector3(0, 0, goal_z))
	var err := lerpf(0.09, 0.035, charge) * (1.0 - minf(0.7, (GameState.shoot - 1) * 0.07))
	if charge > 0.92:
		err += 0.05
	err *= 1.0 + gd / 30.0
	kick_shot_at(u, Vector3(aim_x, ty, goal_z), power, err, clampf(dir.z * 0.0, -0.3, 0.3))

func _pick_new_control() -> void:
	var best: Footballer = null
	var bd := 999.0
	for p in players:
		if p.active and p.team_side == 0 and p.player_role != 0:
			var d := C.fd(p.position, ball.position)
			if d < bd:
				bd = d
				best = p
	if best != null:
		set_controlled(best)

func set_controlled(p: Footballer) -> void:
	if p == controlled:
		return
	if controlled != null:
		controlled.set_controlled(false)
	controlled = p
	p.set_controlled(true)
	pass_held = false
	shoot_held = false

func _manual_switch() -> void:
	var list: Array = []
	for p in players:
		if p.active and p.team_side == 0 and p.player_role != 0:
			list.append([C.fd(p.position, ball.position), p])
	list.sort_custom(func (a, b): return a[0] < b[0])
	if list.is_empty():
		return
	var tgt: Footballer = list[0][1]
	if tgt == controlled and list.size() > 1:
		tgt = list[1][1]
	set_controlled(tgt)
	switch_lock = 1.2

func _auto_switch(dt: float) -> void:
	if switch_lock > 0.0:
		switch_lock -= dt
		return
	if controlled == null or not controlled.active:
		_pick_new_control()
		return
	if shoot_held or pass_held:
		return
	if carrier != null and carrier.team_side == 0:
		if carrier != controlled and carrier.player_role != 0:
			set_controlled(carrier)
			switch_lock = 0.3
		return
	var focus: Vector3 = carrier.position if carrier != null else ball.predict(0.3)
	var cur := C.fd(controlled.position, focus)
	var best: Footballer = null
	var bd := cur - 2.5
	for p in players:
		if p.active and p.team_side == 0 and p.player_role != 0 and p != controlled and not p.busy():
			var d := C.fd(p.position, focus)
			if d < bd:
				bd = d
				best = p
	if best != null:
		set_controlled(best)
		switch_lock = 0.7

# ================================================================= chutes e passes
func _post_kick(p: Footballer, target) -> void:
	var no_off := state == C.State.RESTART and restart_type in [C.Restart.THROW_IN, C.Restart.CORNER, C.Restart.GOAL_KICK, C.Restart.KICKOFF]
	carrier = null
	last_touch = p
	last_touch_team = p.team_side
	p.kick_cd = 0.45
	p.hold_t = 0.0
	intended = target
	kick_time = sim_time
	ball.frozen = false
	pass_held = false
	shoot_held = false
	offside_set.clear()
	if not no_off:
		_register_offside(p)
	if state == C.State.RESTART:
		_end_restart()

func kick_pass(p: Footballer, target: Footballer, kind: int, power_mult := 1.0) -> void:
	var from: Vector3 = ball.position
	var tp := target.position
	var dist := C.fd(from, tp)
	var spd_est := clampf(dist * 0.75 + 6.5, 8.0, 24.0)
	var t_fly := dist / spd_est
	var lead := 0.8
	if kind == C.Kick.THROUGH:
		lead = 1.3
	var to := tp + target.vel * t_fly * lead
	if kind == C.Kick.THROUGH:
		to.z += C.sgn(p.team_side) * 3.0
	to.x = clampf(to.x, -HALF_W + 0.5, HALF_W - 0.5)
	to.z = clampf(to.z, -HALF_D + 0.5, HALF_D - 0.5)
	dist = C.fd(from, to)
	var perr := lerpf(0.14, 0.025, p.skill) * (0.6 + dist / 40.0)
	if p.is_user:
		perr = 0.10 * (1.0 - minf(0.8, (GameState.pass_skill - 1) * 0.06)) * (0.6 + dist / 40.0)
	var d3 := Vector3(to.x - from.x, 0, to.z - from.z)
	var dir := d3.normalized().rotated(Vector3.UP, rng.randfn(0.0, perr))
	if kind == C.Kick.LOB or kind == C.Kick.THROW:
		var T := clampf(0.55 + dist / 20.0, 0.7, 2.2)
		if kind == C.Kick.THROW:
			T = clampf(0.5 + dist / 26.0, 0.6, 1.6)
		var hv := dist / T * 1.04
		var vy := (C.BALL_R - from.y) / T + 0.5 * C.GRAVITY * T
		ball.vel = dir * hv + Vector3(0, vy, 0)
	else:
		var spd := clampf(dist * 0.75 + 6.5, 8.0, 24.0) * power_mult
		ball.vel = dir * spd
	ball.curl = 0.0
	stats.passes[p.team_side] += 1
	var was_user := p.is_user
	_post_kick(p, target)
	if was_user and target.team_side == 0 and target.player_role != 0:
		set_controlled(target)
		switch_lock = 0.5

func kick_lob_to(p: Footballer, pt: Vector3, err_mult := 1.0) -> void:
	var from: Vector3 = ball.position
	var dist := maxf(C.fd(from, pt), 1.0)
	var d3 := Vector3(pt.x - from.x, 0, pt.z - from.z)
	var perr := lerpf(0.14, 0.03, p.skill) * (0.6 + dist / 40.0) * err_mult
	var dir := d3.normalized().rotated(Vector3.UP, rng.randfn(0.0, perr))
	var T := clampf(0.55 + dist / 20.0, 0.7, 2.2)
	var hv := dist / T * 1.04
	var vy := (C.BALL_R - from.y) / T + 0.5 * C.GRAVITY * T
	ball.vel = dir * hv + Vector3(0, vy, 0)
	ball.curl = 0.0
	_post_kick(p, null)

func kick_shot_at(p: Footballer, target: Vector3, speed: float, err: float, curl := 0.0) -> void:
	var from: Vector3 = ball.position
	var dxz := Vector3(target.x - from.x, 0, target.z - from.z)
	var dist := maxf(dxz.length(), 1.0)
	var dir := (dxz / dist).rotated(Vector3.UP, rng.randfn(0.0, err))
	var T := dist / speed
	var vy := (target.y - from.y) / T + 0.5 * C.GRAVITY * T + rng.randfn(0.0, err * 4.0)
	vy = clampf(vy, -2.0, 11.0)
	ball.vel = dir * speed + Vector3(0, vy, 0)
	ball.curl = curl
	shot_id += 1
	stats.shots[p.team_side] += 1
	_post_kick(p, null)

func ai_clear(p: Footballer) -> void:
	var sg := C.sgn(p.team_side)
	var side := signf(p.position.x) if absf(p.position.x) > 2.0 else (1.0 if rng.randf() < 0.5 else -1.0)
	var tgt := Vector3(side * (HALF_W - 6.0 if rng.randf() < 0.6 else HALF_W + 1.5), 0, clampf(p.position.z + sg * 32.0, -HALF_D + 4.0, HALF_D - 4.0))
	kick_lob_to(p, tgt, 1.4)

func _register_offside(p: Footballer) -> void:
	offside_set.clear()
	if not C.OFFSIDE_ON:
		return
	var s := p.team_side
	var sg := C.sgn(s)
	var top1 := -999.0
	var top2 := -999.0
	for o in players:
		if o.active and o.team_side != s:
			var d := o.position.z * sg
			if d > top1:
				top2 = top1
				top1 = d
			elif d > top2:
				top2 = d
	var bd: float = ball.position.z * sg
	for t in players:
		if t.active and t.team_side == s and t != p:
			var dt_ := t.position.z * sg
			if dt_ > top2 + 0.3 and dt_ > bd + 0.3 and dt_ > 0.0:
				offside_set.append(t)

# ================================================================= contatos
func _check_contacts() -> void:
	_gk_saves()
	if state != C.State.PLAY:
		return
	_slide_contacts()
	if state != C.State.PLAY:
		return
	if carrier == null:
		_try_pickup()

func _try_pickup() -> void:
	var bp: Vector3 = ball.position
	if bp.y > 1.25:
		return
	var best: Footballer = null
	var best_d := 99.0
	for p in players:
		if not p.active or p.kick_cd > 0.0 or p.stun_t > 0.0 or p.dive_t > 0.0:
			continue
		var d := Vector2(p.position.x - bp.x, p.position.z - bp.z).length()
		var reach := 0.9 + (0.15 if p.player_role == 0 else 0.0) + (0.2 if p.slide_t > 0.0 else 0.0)
		var score := d - p.skill * 0.2
		if d < reach and score < best_d:
			best_d = score
			best = p
	if best == null:
		return
	var sp: float = ball.speed_xz()
	var chance := clampf(1.05 - maxf(0.0, sp - 11.0) * 0.06 + (best.skill - 0.5) * 0.35, 0.12, 1.0)
	if best.is_user:
		chance = minf(1.0, chance + 0.12)
	if rng.randf() <= chance:
		_take_possession(best)
	else:
		best.kick_cd = 0.3
		ball.vel = ball.vel * 0.45 + Vector3(rng.randf_range(-3, 3), rng.randf_range(0.5, 2.5), rng.randf_range(-3, 3))
		last_touch = best
		last_touch_team = best.team_side
		offside_set.clear()
		intended = null

func _take_possession(p: Footballer) -> void:
	if C.OFFSIDE_ON and state == C.State.PLAY and last_touch != p and p.team_side == last_touch_team and p in offside_set:
		_call_offside(p)
		return
	offside_set.clear()
	if last_touch_team >= 0 and last_touch_team != p.team_side and intended != null:
		stats.intercepts[p.team_side] += 1
	carrier = p
	last_touch = p
	last_touch_team = p.team_side
	p.hold_t = 0.0
	ball.vel = p.vel
	intended = null

func _call_offside(p: Footballer) -> void:
	hud.banner("IMPEDIMENTO", Color(1, 0.8, 0.3), 1.6, 54)
	hud.toast("Impedimento de #%d" % p.shirt_number, 2.5)
	var spot := Vector3(clampf(p.position.x, -HALF_W + 1.0, HALF_W - 1.0), C.BALL_R, clampf(p.position.z, -HALF_D + 2.0, HALF_D - 2.0))
	begin_restart(C.Restart.INDIRECT, 1 - p.team_side, spot)

func _gk_saves() -> void:
	if carrier != null:
		return
	for s in 2:
		var gk: Footballer = gks[s]
		if gk == null or not gk.active or gk.kick_cd > 0.0:
			continue
		var sg := C.sgn(s)
		var hands := gk.position + Vector3(0, 1.0 + gk.dive_h * 0.8, 0)
		var reach := 1.0 if gk.dive_t <= 0.0 else 1.9
		var d := hands.distance_to(ball.position)
		if d > reach:
			continue
		var sp: float = ball.vel.length()
		var in_box: bool = absf(ball.position.x) < C.BOX_HALF_W and ball.position.z * sg < -HALF_D + C.BOX_DEPTH
		if sp < 6.0 and in_box:
			_gk_catch(gk)
			return
		var gz := -sg * HALF_D
		var toward: bool = (gz - ball.position.z) * ball.vel.z > 0.0
		if not toward or last_touch_team == s:
			continue
		var p_save := clampf(0.92 - maxf(0.0, sp - 12.0) * 0.028 + (gk.skill - 0.5) * 0.45 - (d / reach) * 0.25, 0.10, 0.95)
		if gk.dive_t > 0.0:
			p_save += 0.05
		gk.kick_cd = 0.35
		if rng.randf() < p_save:
			stats.saves[s] += 1
			if sp < 17.0 and in_box:
				_gk_catch(gk)
				hud.toast("Defesa de %s!" % _team_name(s), 1.5)
			else:
				var sx := signf(ball.position.x - gk.position.x)
				if sx == 0.0:
					sx = 1.0 if rng.randf() < 0.5 else -1.0
				ball.vel = Vector3(sx * rng.randf_range(3.0, 8.0), rng.randf_range(2.0, 5.0), -ball.vel.z * 0.35)
				last_touch = gk
				last_touch_team = s
				offside_set.clear()
				hud.toast("Espalmou!", 1.5)
			return

func _gk_catch(gk: Footballer) -> void:
	carrier = gk
	last_touch = gk
	last_touch_team = gk.team_side
	gk.hold_t = 0.0
	ball.vel = Vector3.ZERO
	offside_set.clear()
	intended = null

func _slide_contacts() -> void:
	for p in players:
		if not p.active or p.slide_t <= 0.0 or p.slide_hit:
			continue
		if carrier != null and carrier.team_side != p.team_side and C.fd(p.position, carrier.position) < 1.2:
			p.slide_hit = true
			try_tackle(p, carrier, true)
			if state != C.State.PLAY:
				return
		elif carrier == null and ball.position.y < 0.7 and C.fd(p.position, ball.position) < 1.1:
			p.slide_hit = true
			ball.vel = p.slide_dir * 11.0 + Vector3(0, 1.5, 0)
			last_touch = p
			last_touch_team = p.team_side
			offside_set.clear()
		else:
			for o in players:
				if o.active and o.team_side != p.team_side and o != carrier and o.stun_t <= 0.0 and C.fd(p.position, o.position) < 0.95:
					p.slide_hit = true
					var behind := p.slide_dir.dot(o.facing) > 0.45
					if rng.randf() < 0.55:
						_foul(p, o, true, behind)
						return
					break

func try_tackle(def: Footballer, atk: Footballer, slide: bool) -> bool:
	if carrier != atk:
		return false
	def.tackle_cd = 0.8
	var behind := def.facing.dot(atk.facing) > 0.45
	var p_win := 0.30 + (def.skill - atk.skill) * 0.35 + (0.12 if slide else 0.0) + (1.0 - atk.stamina) * 0.1
	if def.is_user:
		p_win += 0.08
	if behind:
		p_win -= 0.1
	p_win = clampf(p_win, 0.08, 0.75)
	if rng.randf() < p_win:
		stats.tackles[def.team_side] += 1
		carrier = null
		var away := Vector3(def.position.x - atk.position.x, 0, def.position.z - atk.position.z).normalized()
		var side := Vector3(-away.z, 0, away.x) * rng.randf_range(-2.0, 2.0)
		ball.vel = away * 3.0 + side + Vector3(0, 1.0, 0)
		atk.kick_cd = 0.5
		atk.hold_t = 0.0
		last_touch = def
		last_touch_team = def.team_side
		offside_set.clear()
		intended = null
		if slide:
			atk.stun_t = 0.25
		return true
	var foul_p := (0.30 if slide else 0.08) * (1.5 if behind else 1.0)
	if rng.randf() < foul_p:
		_foul(def, atk, slide, behind)
	return false

# ================================================================= faltas e cartões
func _team_name(side: int) -> String:
	return GameState.club_name if side == 0 else GameState.opponent_name()

func _foul(def: Footballer, atk: Footballer, slide: bool, behind: bool) -> void:
	stats.fouls[def.team_side] += 1
	var spot := Vector3(clampf(atk.position.x, -HALF_W + 0.8, HALF_W - 0.8), C.BALL_R, clampf(atk.position.z, -HALF_D + 0.8, HALF_D - 0.8))
	atk.fall(1.1)
	var yp := (0.45 if slide else 0.15) * (1.5 if behind else 1.0)
	var rp := (0.05 if slide else 0.01) + (0.05 if (behind and slide) else 0.0)
	var roll := rng.randf()
	var msg := "Falta de #%d (%s)" % [def.shirt_number, _team_name(def.team_side)]
	if def.player_role != 0:
		if roll < rp:
			_send_off(def)
			msg = "CARTÃO VERMELHO — #%d (%s)" % [def.shirt_number, _team_name(def.team_side)]
		elif roll < rp + yp:
			def.yellow += 1
			stats.yellow[def.team_side] += 1
			if def.yellow >= 2:
				_send_off(def)
				msg = "SEGUNDO AMARELO — #%d expulso (%s)" % [def.shirt_number, _team_name(def.team_side)]
			else:
				msg = "Cartão amarelo — #%d (%s)" % [def.shirt_number, _team_name(def.team_side)]
	hud.banner("FALTA", Color(1, 0.9, 0.4), 1.4, 54)
	hud.toast(msg, 3.2, Color(1, 0.85, 0.3))
	var own_goal_z := -C.sgn(def.team_side) * HALF_D
	if absf(spot.z - own_goal_z) < C.BOX_DEPTH and absf(spot.x) < C.BOX_HALF_W:
		hud.banner("PÊNALTI!", Color(1, 0.4, 0.3), 1.8, 64)
		begin_restart(C.Restart.PENALTY, atk.team_side, Vector3(0, C.BALL_R, own_goal_z + C.sgn(def.team_side) * 8.0))
	else:
		begin_restart(C.Restart.FREE_KICK, atk.team_side, spot)

func _send_off(p: Footballer) -> void:
	stats.red[p.team_side] += 1
	p.active = false
	p.visible = false
	p.position = Vector3(60, 0, 60)
	if carrier == p:
		carrier = null
	if controlled == p:
		controlled.set_controlled(false)
		controlled = null
		_pick_new_control()

# ================================================================= bola fora / gol
func _check_bounds_goal() -> void:
	var b: Vector3 = ball.position
	if absf(b.x) < C.GOAL_HALF - 0.05 and b.y < C.GOAL_H and absf(b.z) > HALF_D + C.BALL_R:
		_goal(0 if b.z > 0.0 else 1)
		return
	if absf(b.x) > HALF_W + 0.15:
		var team := 1 - maxi(last_touch_team, 0)
		var spot := Vector3(signf(b.x) * HALF_W, 1.9, clampf(b.z, -HALF_D + 2.0, HALF_D - 2.0))
		hud.toast("Lateral", 1.2)
		begin_restart(C.Restart.THROW_IN, team, spot)
	elif absf(b.z) > HALF_D + 0.15:
		var defender := 1 if b.z > 0.0 else 0
		var zs := signf(b.z)
		if last_touch_team == defender:
			var cs := Vector3(signf(b.x if absf(b.x) > 0.1 else 1.0) * (HALF_W - 0.4), C.BALL_R, zs * (HALF_D - 0.4))
			hud.toast("Escanteio", 1.5)
			begin_restart(C.Restart.CORNER, 1 - defender, cs)
		else:
			hud.toast("Tiro de meta", 1.5)
			begin_restart(C.Restart.GOAL_KICK, defender, Vector3(0, C.BALL_R, zs * (HALF_D - 5.5)))

func _goal(side: int) -> void:
	if side == 0:
		home_score += 1
	else:
		away_score += 1
	state = C.State.GOAL
	goal_t = 0.0
	goal_side = side
	carrier = null
	scorer = last_touch if (last_touch != null and last_touch.team_side == side) else null
	var who := ""
	if scorer != null:
		who = "#%d" % scorer.shirt_number
	else:
		who = "contra"
	hud.banner("GOOOOL!", Color(1.0, 0.9, 0.2) if side == 0 else Color(1.0, 0.5, 0.45), 3.2, 96)
	hud.toast("%s  %d – %d   (%s)" % [_team_name(side), home_score, away_score, who], 4.0)
	replay_frames = rec.duplicate()

func _tick_goal(dt: float) -> void:
	goal_t += dt
	ball.step(dt * 0.5)
	var sg := C.sgn(goal_side)
	for p in players:
		if not p.active:
			continue
		if scorer != null and p == scorer:
			var tgt := Vector3(HALF_W - 6.0, 0, sg * (HALF_D - 8.0))
			var d := tgt - p.position
			d.y = 0.0
			p.drive(d.normalized() * minf(1.0, d.length() * 0.5), true, dt)
		elif scorer != null and p.team_side == goal_side and goal_t > 0.6 and C.fd(p.position, scorer.position) > 3.0:
			var d2 := scorer.position - p.position
			d2.y = 0.0
			p.drive(d2.normalized(), false, dt)
		else:
			p.drive(Vector3.ZERO, false, dt)
		p.tick(dt)
	if goal_t > 2.4:
		if replay_frames.size() > 30:
			state = C.State.REPLAY
			replay_i = 0.0
			hud.set_replay(true)
			hud.banner("", Color.WHITE, 0.01)
		else:
			_after_goal()

func _tick_replay(dt: float) -> void:
	replay_i += dt * C.REPLAY_FPS * 0.65
	var skip := Input.is_action_just_pressed("pass_ball") or Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("ui_accept")
	var idx := int(replay_i)
	if skip or idx >= replay_frames.size() - 1:
		_after_goal()
		return
	var f0: PackedFloat32Array = replay_frames[idx]
	var f1: PackedFloat32Array = replay_frames[idx + 1]
	var k := replay_i - float(idx)
	ball.position = Vector3(lerpf(f0[0], f1[0], k), lerpf(f0[1], f1[1], k), lerpf(f0[2], f1[2], k))
	ball.update_visual(0.0)
	for i in players.size():
		var o := 3 + i * 3
		if o + 2 >= f0.size() or o + 2 >= f1.size():
			break
		var p := players[i]
		if not p.active:
			continue
		p.position = Vector3(lerpf(f0[o], f1[o], k), 0, lerpf(f0[o + 1], f1[o + 1], k))
		p.rotation.y = lerp_angle(f0[o + 2], f1[o + 2], k)

func _after_goal() -> void:
	hud.set_replay(false)
	replay_frames = []
	rec.clear()
	_setup_kickoff(1 - goal_side)
	hud.banner("BOLA AO CENTRO", Color(1, 1, 1), 1.4, 44)

func _rec_frame(dt: float) -> void:
	rec_acc += dt
	if rec_acc < 1.0 / C.REPLAY_FPS:
		return
	rec_acc -= 1.0 / C.REPLAY_FPS
	var f := PackedFloat32Array()
	f.resize(3 + players.size() * 3)
	f[0] = ball.position.x
	f[1] = ball.position.y
	f[2] = ball.position.z
	for i in players.size():
		var p := players[i]
		f[3 + i * 3] = p.position.x
		f[4 + i * 3] = p.position.z
		f[5 + i * 3] = p.rotation.y
	rec.append(f)
	var maxf_ := int(C.REPLAY_FPS * C.REPLAY_SECONDS)
	while rec.size() > maxf_:
		rec.pop_front()

# ================================================================= intervalo
func _tick_halftime(dt: float) -> void:
	ht_t += dt
	for p in players:
		if p.active:
			p.drive(Vector3.ZERO, false, dt)
			p.tick(dt)
	if ht_t > 4.5:
		half = 2
		half_elapsed = 0.0
		for p in players:
			p.stamina = minf(1.0, p.stamina + 0.45)
		_setup_kickoff(1)
		hud.banner("2º TEMPO", Color(1, 1, 1), 1.8, 60)

# ================================================================= reinícios
func _kickoff_pos(p: Footballer, kicking: int) -> Vector3:
	var f: Dictionary = C.FORM[p.slot]
	var sg := C.sgn(p.team_side)
	var team_kick: bool = p.team_side == kicking
	if p.slot == 10:
		return Vector3(0, 0, -sg * (0.9 if team_kick else 8.0))
	var d := -33.0
	match int(f.role):
		1: d = -17.0
		2: d = -8.0
		3: d = -3.0 if team_kick else -7.5
	var x: float = f.x * sg
	if p.slot == 9 and team_kick:
		return Vector3(-5.0 * sg, 0, -sg * 2.0)
	return Vector3(x, 0, d * sg)

func _setup_kickoff(team: int) -> void:
	for p in players:
		if not p.active:
			continue
		p.stun_t = 0.0
		p.fallen = false
		p.slide_t = 0.0
		p.dive_t = 0.0
		p.vel = Vector3.ZERO
		p.mark = null
		p.position = _kickoff_pos(p, team)
		p.facing = Vector3(0, 0, C.sgn(p.team_side))
		p.anchor = p.position
		p.ai_target = p.position
	begin_restart(C.Restart.KICKOFF, team, Vector3(0, C.BALL_R, 0))

func _pick_taker(type: int, team: int, pos: Vector3) -> Footballer:
	if type == C.Restart.GOAL_KICK:
		var gk: Footballer = gks[team]
		if gk.active:
			return gk
	var best: Footballer = null
	var bd := 999.0
	for p in players:
		if not p.active or p.team_side != team:
			continue
		if type == C.Restart.KICKOFF:
			if p.slot == 10:
				return p
			continue
		if type == C.Restart.PENALTY:
			var d0 := 0.0 if p.slot == 10 else 10.0 + float(p.slot)
			if p.player_role == 0:
				d0 += 100.0
			if d0 < bd:
				bd = d0
				best = p
			continue
		if p.player_role == 0:
			continue
		var d := C.fd(p.position, pos)
		if d < bd:
			bd = d
			best = p
	if best == null:
		for p in players:
			if p.active and p.team_side == team:
				return p
	return best

func begin_restart(type: int, team: int, pos: Vector3) -> void:
	state = C.State.RESTART
	restart_type = type
	restart_team = team
	restart_pos = pos
	restart_t = 0.0
	pass_held = false
	shoot_held = false
	offside_set.clear()
	intended = null
	for p in players:
		p.stun_t = 0.0
		p.fallen = false
		p.slide_t = 0.0
		p.dive_t = 0.0
		p.lunge_t = 0.0
		p.think_t = 0.0
	taker = _pick_taker(type, team, pos)
	var sgt := C.sgn(team)
	var tp := pos
	if type == C.Restart.KICKOFF:
		tp = Vector3(0, 0, -sgt * 0.9)
	elif type == C.Restart.THROW_IN:
		tp = Vector3(pos.x + signf(pos.x) * 0.5, 0, pos.z)
	elif type == C.Restart.CORNER:
		tp = pos + Vector3(-signf(pos.x) * 0.8, 0, -signf(pos.z) * 0.8)
	elif type == C.Restart.GOAL_KICK:
		tp = pos + Vector3(0, 0, -signf(pos.z) * 0.9)
	elif type == C.Restart.PENALTY:
		tp = Vector3(pos.x, 0, pos.z - signf(pos.z) * 3.0)
	else:
		var gdir := Vector3(0, 0, sgt * HALF_D) - pos
		gdir.y = 0.0
		tp = pos - gdir.normalized() * 0.9
	tp.y = 0.0
	taker.position = tp
	taker.vel = Vector3.ZERO
	var face := Vector3(pos.x - tp.x, 0, pos.z - tp.z)
	if face.length() < 0.1:
		face = Vector3(0, 0, sgt)
	taker.facing = face.normalized()
	ball.frozen = true
	ball.vel = Vector3.ZERO
	ball.position = Vector3(pos.x, 1.9 if type == C.Restart.THROW_IN else C.BALL_R, pos.z)
	carrier = taker
	last_touch = taker
	last_touch_team = team
	if type == C.Restart.PENALTY:
		var def_side := 1 - team
		for p in players:
			if not p.active or p == taker:
				continue
			if p == gks[def_side]:
				p.position = Vector3(0, 0, signf(pos.z) * (HALF_D - 0.6))
			else:
				var a = restart_anchor(p)
				if a != null:
					p.position = a
			p.vel = Vector3.ZERO
	if team == 0 and taker.player_role != 0:
		set_controlled(taker)
	hud.update(self, 0.0)

func _end_restart() -> void:
	state = C.State.PLAY
	ball.frozen = false
	taker = null

func restart_anchor(p: Footballer):
	if state != C.State.RESTART:
		return null
	if restart_type == C.Restart.KICKOFF:
		return _kickoff_pos(p, restart_team)
	if restart_type == C.Restart.CORNER:
		var sg := signf(restart_pos.z)
		var gz := sg * HALF_D
		if p.player_role == 0:
			return null
		if p.team_side == restart_team:
			if p.slot >= 5:
				var sp: Vector2 = ATT_SPOTS[(p.slot - 5) % ATT_SPOTS.size()]
				return Vector3(sp.x, 0, gz - sg * sp.y)
			return null
		var dp: Vector2 = DEF_SPOTS[(p.slot - 1) % DEF_SPOTS.size()]
		return Vector3(dp.x, 0, gz - sg * dp.y)
	if restart_type == C.Restart.PENALTY:
		if p == taker or p.player_role == 0:
			return null
		var gz2 := signf(restart_pos.z) * HALF_D
		return Vector3(-16.0 + float(p.slot) * 3.0, 0, gz2 - signf(restart_pos.z) * (C.BOX_DEPTH + 5.0))
	return null

func _tick_restart(dt: float) -> void:
	restart_t += dt
	_user_control(dt)
	ai.update(dt)
	_step_players(dt)
	_enforce_restart(dt)
	_step_ball(dt)
	if state != C.State.RESTART:
		return
	if taker != null and taker.active:
		# mantém a bola no ponto
		ball.position = Vector3(restart_pos.x, 1.9 if restart_type == C.Restart.THROW_IN else C.BALL_R, restart_pos.z)
	var wait := 2.4 if restart_type == C.Restart.KICKOFF else (1.8 if restart_type == C.Restart.PENALTY else 1.2)
	var auto_t := 7.0
	if taker == null or not taker.active:
		_end_restart()
		return
	if ((not taker.is_user or autoplay) and restart_t > wait) or restart_t > auto_t:
		_ai_restart_kick()

func _enforce_restart(dt: float) -> void:
	var radius := 0.0
	if restart_type == C.Restart.THROW_IN:
		radius = 3.0
	elif restart_type == C.Restart.GOAL_KICK:
		radius = 11.0
	elif restart_type == C.Restart.PENALTY:
		radius = 0.0
	else:
		radius = 7.0
	if radius <= 0.0:
		return
	for p in players:
		if not p.active or p.team_side == restart_team or p.player_role == 0:
			continue
		var d := Vector3(p.position.x - restart_pos.x, 0, p.position.z - restart_pos.z)
		var l := d.length()
		if l < radius:
			var dn := d / l if l > 0.01 else Vector3(1, 0, 0)
			p.position += dn * minf(radius - l, 14.0 * dt)

func _ai_restart_kick() -> void:
	var t := taker
	var s := t.team_side
	var sg := C.sgn(s)
	var goal_z := sg * HALF_D
	var gd: float = C.fd(restart_pos, Vector3(0, 0, goal_z))
	var rtype := restart_type
	if rtype == C.Restart.KICKOFF:
		var r = ai.best_pass(t, 3.0, 22.0)
		if r == null:
			ai_clear(t)
		else:
			kick_pass(t, r, C.Kick.GROUND, 0.8)
	elif rtype == C.Restart.PENALTY:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		kick_shot_at(t, Vector3(side * rng.randf_range(2.0, 3.1), rng.randf_range(0.3, 1.2), goal_z), 21.0 + 5.0 * t.skill, 0.04)
	elif rtype == C.Restart.FREE_KICK and gd < 30.0 and t.player_role != 1:
		var side2 := 1.0 if rng.randf() < 0.5 else -1.0
		kick_shot_at(t, Vector3(side2 * rng.randf_range(1.5, 3.0), rng.randf_range(1.2, 2.0), goal_z), 20.0 + 6.0 * t.skill, 0.05 + gd / 400.0, side2 * 0.25)
	elif rtype == C.Restart.CORNER:
		kick_lob_to(t, Vector3(rng.randf_range(-4.0, 4.0), 0, goal_z - sg * 7.0), 0.9)
	elif rtype == C.Restart.GOAL_KICK:
		var r2 = ai.best_pass(t, 10.0, 55.0)
		if r2 == null:
			ai_clear(t)
		else:
			kick_pass(t, r2, C.Kick.LOB, 1.0)
	elif rtype == C.Restart.THROW_IN:
		var r3 = ai.best_pass(t, 4.0, 24.0)
		if r3 == null:
			ai_clear(t)
		else:
			kick_pass(t, r3, C.Kick.THROW, 1.0)
	else:
		var r4 = ai.best_pass(t, 5.0, 45.0)
		if r4 == null:
			ai_clear(t)
		else:
			var d4: float = C.fd(t.position, r4.position)
			kick_pass(t, r4, C.Kick.LOB if d4 > 22.0 else C.Kick.GROUND, 1.0)

# ================================================================= câmera
func _update_camera(dt: float) -> void:
	if camera == null:
		return
	var focus: Vector3 = ball.position
	var u := controlled
	if state == C.State.GOAL and scorer != null:
		focus = scorer.position
	elif u != null and state != C.State.REPLAY:
		focus = focus.lerp(u.position, 0.2)
	focus.z += clampf(ball.vel.z * 0.22, -6.0, 6.0)
	focus.z = clampf(focus.z, -HALF_D + 9.0, HALF_D - 9.0)
	focus.x = 0.0
	cam_focus = cam_focus.lerp(focus, 1.0 - exp(-dt * 3.2))
	var spread := 0.0
	if u != null:
		spread = absf(ball.position.z - u.position.z)
	var target_fov := 38.0 + clampf(spread * 0.3, 0.0, 9.0)
	if absf(ball.position.z) > HALF_D - 16.0:
		target_fov -= 3.0
	if state == C.State.GOAL:
		target_fov = 30.0
	cam_fov = lerpf(cam_fov, target_fov, 1.0 - exp(-dt * 2.5))
	camera.fov = cam_fov
	var cpos := Vector3(-31.0, 15.5, cam_focus.z + 3.0)
	if state == C.State.REPLAY:
		cpos = Vector3(27.0, 8.0, ball.position.z + 2.0)
	camera.position = camera.position.lerp(cpos, 1.0 - exp(-dt * 3.0))
	camera.look_at(Vector3(0.0, 0.5, cam_focus.z) if state != C.State.REPLAY else ball.position, Vector3.UP)

# ================================================================= fim de jogo
func _finish(forfeit: bool) -> void:
	if not running:
		return
	running = false
	state = C.State.FULLTIME
	if forfeit and home_score == 0 and away_score == 0:
		away_score = 1
	var payout: int = GameState.salary_for(home_score, away_score)
	GameState.record_league_round(home_score, away_score)
	GameState.money += payout
	GameState.matches_played += 1
	GameState.energy = maxf(0.0, GameState.energy - 30.0)
	GameState.add_time(2.0)
	if home_score > away_score:
		GameState.wins += 1
		GameState.fame += 1
		if GameState.gf_status == "girlfriend":
			GameState.bond = mini(100, GameState.bond + 3)
	GameState.last_home = home_score
	GameState.last_away = away_score
	GameState.last_payout = payout
	GameState.save_game()
	finished_called = true
	var result := "VITÓRIA" if home_score > away_score else ("EMPATE" if home_score == away_score else "DERROTA")
	result_text = result
	_show_result(result, payout, forfeit)

func _show_result(result: String, payout: int, forfeit: bool) -> void:
	hud.set_replay(false)
	var tp: float = stats.poss[0] + stats.poss[1]
	var pc := 50 if tp <= 0.0 else int(round(stats.poss[0] / tp * 100.0))
	var st := "Chutes %d–%d · Defesas %d–%d · Faltas %d–%d\nAmarelos %d–%d · Vermelhos %d–%d · Posse %d%%–%d%%" % [
		stats.shots[0], stats.shots[1], stats.saves[0], stats.saves[1], stats.fouls[0], stats.fouls[1],
		stats.yellow[0], stats.yellow[1], stats.red[0], stats.red[1], pc, 100 - pc]
	var sub := "%s %d – %d %s%s\nSalário $%d · Caixa $%d · Energia %d%%" % [
		GameState.club_name, home_score, away_score, GameState.last_opponent,
		" (encerrado antes)" if forfeit else "", payout, GameState.money, int(GameState.energy)]
	hud.show_result("Fim de jogo — %s" % result, sub, st, func (): get_tree().change_scene_to_file("res://scenes/hub.tscn"))
