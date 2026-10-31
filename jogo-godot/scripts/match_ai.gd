extends RefCounted
## IA da partida: formação dinâmica por função, linha defensiva que sobe/desce, marcação,
## pressão no portador, apoio, desmarque, decisão passe/chute/drible, goleiro.
## `m` é o nó da partida (match.gd).

const C := preload("res://scripts/match_consts.gd")

var m
var rng := RandomNumberGenerator.new()
var _ctx_t := 0.0
var poss := [false, false]
var chaser: Array = [null, null]
var cover: Array = [null, null]
var supports: Array = [[], []]
var off_line := [30.0, 30.0]

func _init() -> void:
	rng.randomize()

# ---------------------------------------------------------------- utilidades
func fd(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var l2 := ab.length_squared()
	var t := 0.0 if l2 < 0.0001 else clampf(ap.dot(ab) / l2, 0.0, 1.0)
	return (ap - ab * t).length()

func _opp_min_dist(side: int, pos: Vector3) -> float:
	var best := 99.0
	for o in m.players:
		if o.active and o.team_side != side:
			best = minf(best, fd(o.position, pos))
	return best

func _lane_min(side: int, a: Vector3, b: Vector3, skip_gk := false) -> float:
	var best := 99.0
	for o in m.players:
		if not o.active or o.team_side == side:
			continue
		if skip_gk and o.player_role == 0:
			continue
		best = minf(best, _seg_dist(a, b, o.position))
	return best

func _nearest_opp(side: int, pos: Vector3):
	var best = null
	var bd := 99.0
	for o in m.players:
		if o.active and o.team_side != side:
			var d := fd(o.position, pos)
			if d < bd:
				bd = d
				best = o
	return best

func own_goal(side: int) -> Vector3:
	return Vector3(0, 0, -C.sgn(side) * C.HALF_D)

# ---------------------------------------------------------------- contexto
func update(dt: float) -> void:
	_ctx_t -= dt
	if _ctx_t <= 0.0:
		_ctx_t = 0.12
		_refresh()
	for p in m.players:
		if p.active and (not p.is_user or m.autoplay):
			_act(p, dt)

func _refresh() -> void:
	var ball_pos: Vector3 = m.ball.position
	for s in 2:
		var carrier = m.carrier
		poss[s] = (carrier != null and carrier.team_side == s) or (carrier == null and m.last_touch_team == s)
		var sg := C.sgn(s)
		var top1 := -999.0
		var top2 := -999.0
		for o in m.players:
			if o.active and o.team_side != s:
				var d: float = o.position.z * sg
				if d > top1:
					top2 = top1
					top1 = d
				elif d > top2:
					top2 = d
		if top2 < -900.0:
			top2 = C.HALF_D
		off_line[s] = top2
		_pick_chasers(s, ball_pos)
		_pick_supports(s)
		_assign_marks(s)

func _chaser_ok_gk(side: int, bp: Vector3) -> bool:
	var sg := C.sgn(side)
	return absf(bp.x) < C.BOX_HALF_W + 2.0 and bp.z * sg < -C.HALF_D + C.BOX_DEPTH + 2.0

func _pick_chasers(s: int, bp: Vector3) -> void:
	var target: Vector3 = bp + Vector3(m.ball.vel.x, 0, m.ball.vel.z) * 0.3
	if m.carrier != null:
		target = m.carrier.position
	var sg := C.sgn(s)
	var best = null
	var second = null
	var bd := 999.0
	var sd := 999.0
	var bdepth: float = bp.z * sg
	for p in m.players:
		if not p.active or p.team_side != s or p.busy():
			continue
		if p.player_role == 0 and not _chaser_ok_gk(s, bp):
			continue
		var eff := fd(p.position, target)
		if p.player_role == 3 and bdepth < 10.0:
			eff += 4.0
		elif p.player_role == 1 and bdepth > 15.0:
			eff += 3.0
		if m.intended == p:
			eff -= 7.0
		if eff < bd:
			second = best
			sd = bd
			best = p
			bd = eff
		elif eff < sd:
			second = p
			sd = eff
	if best != null and (best.is_user and not m.autoplay):
		best = second
		second = null
	if second != null and (second.is_user and not m.autoplay):
		second = null
	chaser[s] = best
	cover[s] = second

func _pick_supports(s: int) -> void:
	supports[s] = []
	var c = m.carrier
	if c == null or c.team_side != s:
		return
	var cand: Array = []
	for p in m.players:
		if p.active and p.team_side == s and p != c and p.player_role != 0 and (not p.is_user or m.autoplay):
			cand.append([fd(p.position, c.position), p])
	cand.sort_custom(func (a, b): return a[0] < b[0])
	for i in mini(2, cand.size()):
		supports[s].append(cand[i][1])

func _assign_marks(s: int) -> void:
	var cands: Array = []
	for p in m.players:
		if p.team_side == s:
			p.mark = null
			if p.active and p.player_role != 0 and p.player_role != 3 and (not p.is_user or m.autoplay) and p != chaser[s] and p != cover[s]:
				cands.append(p)
	if m.carrier == null or m.carrier.team_side == s:
		return
	var sg := C.sgn(s)
	var opps: Array = []
	for o in m.players:
		if o.active and o.team_side != s and o != m.carrier and o.player_role != 0:
			opps.append(o)
	opps.sort_custom(func (a, b): return a.position.z * sg < b.position.z * sg)
	var used := {}
	for o in opps:
		var best = null
		var bd := 20.0
		for p in cands:
			if used.has(p):
				continue
			var d := fd(p.anchor, o.position)
			if d < bd:
				bd = d
				best = p
		if best != null:
			best.mark = o
			used[best] = true

# ---------------------------------------------------------------- âncora
func anchor_for(p) -> Vector3:
	var over = m.restart_anchor(p)
	if over != null:
		return over
	var s: int = p.team_side
	var sg := C.sgn(s)
	var f: Dictionary = C.FORM[p.slot]
	var bp: Vector3 = m.ball.position
	var bd := clampf(bp.z * sg, -C.HALF_D, C.HALF_D)
	var t := (bd + C.HALF_D) / C.PITCH_D
	var atk: bool = poss[s]
	var depth: float = f.d
	var role: int = p.player_role
	if role == 1:
		depth += lerpf(-6.0, 16.0, t) + (3.0 if atk else -2.0)
		depth = clampf(depth, -C.HALF_D + 8.0, 12.0 if atk else 3.0)
	elif role == 2:
		depth += lerpf(-8.0, 18.0, t) + (5.0 if atk else -3.0)
		depth = clampf(depth, -C.HALF_D + 12.0, C.HALF_D - 8.0)
	elif role == 3:
		depth += lerpf(-4.0, 8.0, t) + (6.0 if atk else -4.0)
		depth = clampf(depth, -6.0, C.HALF_D - 4.0)
		if C.OFFSIDE_ON:
			depth = minf(depth, off_line[s] - 0.9)
	else:
		depth = f.d
	# time mais fraco = linha mais baixa (reage a força relativa)
	var x: float = f.x * sg
	if role != 0:
		var squeeze := 1.0 if atk else 0.82
		x = x * squeeze
		x = lerpf(x, bp.x, 0.2 if atk else 0.28)
	var res := Vector3(clampf(x, -C.HALF_W + 2.0, C.HALF_W - 2.0), 0.0, depth * sg)
	if m.state == C.State.RESTART and m.restart_type == C.Restart.GOAL_KICK and s != m.restart_team:
		res.z = signf(res.z) * minf(absf(res.z), C.HALF_D - C.BOX_DEPTH - 4.0)
	return res

# ---------------------------------------------------------------- ação por jogador
func _move_to(p, tgt: Vector3, dt: float, sprint: bool) -> void:
	var d := Vector3(tgt.x - p.position.x, 0.0, tgt.z - p.position.z)
	var l := d.length()
	if l < 0.25:
		p.drive(Vector3.ZERO, false, dt)
		return
	var sc: float = 0.84 + 0.16 * p.skill
	p.drive(d / l * minf(1.0, l * 0.6), sprint, dt, sc)

func _act(p, dt: float) -> void:
	if p.busy():
		return
	p.look_pt = m.ball.position
	p.has_look = true
	if m.state == C.State.RESTART and p == m.taker:
		p.drive(Vector3.ZERO, false, dt)
		return
	if p.player_role == 0:
		_gk(p, dt)
		return
	if p == m.carrier:
		_carrier(p, dt)
		return
	p.think_t -= dt
	var s: int = p.team_side
	if p.think_t <= 0.0 or p == chaser[s]:
		if p.think_t <= 0.0:
			p.think_t = lerpf(0.36, 0.12, p.skill) * rng.randf_range(0.8, 1.2)
		p.anchor = anchor_for(p)
		_decide_target(p)
	_move_to(p, p.ai_target, dt, p.ai_sprint)
	_try_defend(p, dt)

func _decide_target(p) -> void:
	var s: int = p.team_side
	var sg := C.sgn(s)
	var c = m.carrier
	var tgt: Vector3 = p.anchor
	var sprint := false
	var restart: bool = m.state == C.State.RESTART
	if c == null:
		var react: float = 0.25 + 0.5 * (1.0 - p.skill)
		if p == chaser[s] and (p.team_side == m.last_touch_team or m.sim_time - m.kick_time > react):
			tgt = _intercept(p)
			sprint = true
	elif c.team_side == s:
		var bdepth: float = c.position.z * sg
		if p.player_role == 3:
			if m.sim_time >= p.run_until or fd(p.position, p.run_target) < 1.5:
				_pick_run(p)
			tgt = p.run_target
			sprint = fd(p.position, tgt) > 5.0 and not restart
		elif p in supports[s] and fd(p.position, c.position) < 26.0:
			var lat := signf(p.anchor.x - c.position.x)
			if lat == 0.0:
				lat = 1.0
			var sup: Vector3 = c.position + Vector3(lat * 8.0, 0, sg * 5.0)
			if C.OFFSIDE_ON:
				var dd: float = sup.z * sg
				if dd > off_line[s] - 0.6:
					sup.z = (off_line[s] - 0.6) * sg
			sup.x = clampf(sup.x, -C.HALF_W + 2.0, C.HALF_W - 2.0)
			tgt = p.anchor.lerp(sup, 0.7)
			sprint = fd(p.position, tgt) > 7.0 and not restart
		else:
			tgt = p.anchor
	else:
		var goal := own_goal(s)
		if not restart and p == chaser[s]:
			tgt = c.position + c.vel * 0.3 + (goal - c.position).normalized() * 0.7
			sprint = fd(p.position, c.position) > 2.5
		elif not restart and p == cover[s]:
			tgt = c.position + (goal - c.position).normalized() * 5.0
			sprint = fd(p.position, tgt) > 5.0
		elif p.mark != null and p.mark.position.z * sg < 12.0:
			var o = p.mark
			var mt: Vector3 = o.position + (goal - o.position).normalized() * 1.8
			tgt = p.anchor.lerp(mt, 0.7)
			sprint = fd(p.position, tgt) > 6.0 and not restart
		else:
			tgt = p.anchor
	p.ai_target = tgt
	p.ai_sprint = sprint

func _intercept(p) -> Vector3:
	var b = m.ball
	if b.position.y > 1.2:
		return b.landing()
	var d := fd(p.position, b.position)
	var t := clampf(d / 9.0, 0.0, 0.9)
	return b.predict(t)

func _pick_run(p) -> void:
	var s: int = p.team_side
	var sg := C.sgn(s)
	var line := C.HALF_D - 4.0
	if C.OFFSIDE_ON:
		line = minf(off_line[s] - 0.8, line)
	var best := Vector3.ZERO
	var best_open := -999.0
	for i in 3:
		var x := clampf(p.anchor.x * 0.6 + rng.randf_range(-12.0, 12.0), -C.HALF_W + 3.0, C.HALF_W - 3.0)
		var dp := clampf(line - rng.randf_range(0.0, 7.0), -4.0, C.HALF_D - 4.0)
		var pos := Vector3(x, 0, dp * sg)
		var open := minf(_opp_min_dist(s, pos), 15.0)
		if m.carrier != null:
			open -= absf(x - m.carrier.position.x) * 0.05
		if open > best_open:
			best_open = open
			best = pos
	p.run_target = best
	p.run_until = m.sim_time + rng.randf_range(1.8, 3.2)

# defesa: desarme / carrinho da IA
func _try_defend(p, dt: float) -> void:
	var c = m.carrier
	if c == null or c.team_side == p.team_side or m.state != C.State.PLAY:
		return
	if p != chaser[p.team_side] and p != cover[p.team_side]:
		return
	var d := fd(p.position, c.position)
	if d < 1.25 and p.tackle_cd <= 0.0:
		p.tackle_cd = lerpf(1.0, 0.5, p.skill)
		m.try_tackle(p, c, false)
	elif d > 1.5 and d < 3.0 and p.slide_cd <= 0.0 and p.tackle_cd <= 0.0 and c.vel.length() > 3.0:
		var in_own_box: bool = absf(p.position.x) < C.BOX_HALF_W + 1.0 and p.position.z * C.sgn(p.team_side) < -C.HALF_D + C.BOX_DEPTH
		var chance: float = (0.18 if p.player_role == 1 else 0.12) * (0.5 + 0.5 * (1.0 - p.skill)) * (0.3 if in_own_box else 1.0)
		if rng.randf() < chance * dt:
			p.start_slide(c.position - p.position)

# ---------------------------------------------------------------- portador
func _carrier(p, dt: float) -> void:
	p.hold_t += dt
	p.think_t -= dt
	if p.think_t <= 0.0:
		p.think_t = lerpf(0.40, 0.16, p.skill) * rng.randf_range(0.8, 1.2)
		if _carrier_decide(p):
			return
	p.drive(p.ai_dir, p.ai_sprint, dt, 0.93)

func _carrier_decide(p) -> bool:
	var s: int = p.team_side
	var sg := C.sgn(s)
	var pp: Vector3 = p.position
	var goal := Vector3(0, 0, sg * C.HALF_D)
	var gd := fd(pp, goal)
	var depth: float = pp.z * sg
	var nd := 99.0
	var rep := Vector3.ZERO
	var dirv := (goal - pp)
	dirv.y = 0.0
	dirv = dirv.normalized()
	var front_open := 99.0
	for o in m.players:
		if not o.active or o.team_side == s:
			continue
		var v: Vector3 = pp - o.position
		v.y = 0.0
		var d := v.length()
		nd = minf(nd, d)
		if d < 6.5 and dirv.dot(-v) > 0.0 and d > 0.01:
			rep += v.normalized() * (6.5 - d) / 6.5 * 1.4
		if d > 0.01 and dirv.dot(-v / d) > 0.35:
			front_open = minf(front_open, d)
	var pressured := nd < 2.8
	dirv = (dirv + rep).normalized()
	if absf(pp.x) > C.HALF_W - 3.0 and dirv.x * pp.x > 0.0:
		dirv.x *= -0.3
		dirv = dirv.normalized()
	p.ai_dir = dirv
	p.ai_sprint = nd > 4.0 and p.stamina > 0.3 and gd > 10.0
	var role: int = p.player_role
	# ---- chute
	var srange: float = (26.0 if role == 3 else (20.0 if role == 2 else 13.0)) + p.skill * 5.0
	if gd < srange and absf(pp.x) < C.HALF_W - 1.5 and p.hold_t > 0.2:
		var lane := _lane_min(s, pp, goal, true)
		if lane > 1.6 or gd < 12.0 or pressured:
			var pr := (0.55 if role == 3 else (0.33 if role == 2 else 0.12)) + (0.2 if pressured else 0.0)
			if rng.randf() < pr:
				_ai_shoot(p, gd)
				return true
	# ---- passe
	var best = null
	var best_sc := -999.0
	for r in m.players:
		if not r.active or r.team_side != s or r == p:
			continue
		var sc := pass_score(p, r)
		if sc > best_sc:
			best_sc = sc
			best = r
	if role == 0:
		return false
	var want := false
	var thr: float = 7.0 - p.skill * 2.0
	if front_open > 9.0 and role != 1 and gd < 42.0:
		thr = 11.5
	if pressured:
		want = best_sc > -4.0 and p.hold_t > 0.25
	elif p.hold_t > 3.0 - 1.4 * p.skill:
		want = best_sc > -2.0
	else:
		want = best_sc > thr and p.hold_t > 0.8
	if want and best != null:
		_ai_pass(p, best)
		return true
	if pressured and role == 1 and depth < -C.HALF_D + 18.0:
		m.ai_clear(p)
		return true
	return false

func _ai_pass(p, r) -> void:
	var d := fd(p.position, r.position)
	var lane := _lane_min(p.team_side, p.position, r.position)
	var kind := C.Kick.GROUND
	if d > 24.0 or (lane < 1.3 and d > 12.0):
		kind = C.Kick.LOB
	elif r.player_role == 3 and d > 10.0 and rng.randf() < 0.4:
		kind = C.Kick.THROUGH
	m.kick_pass(p, r, kind, 1.0)

func _ai_shoot(p, gd: float) -> void:
	var s: int = p.team_side
	var sg := C.sgn(s)
	var gk = m.gks[1 - s]
	var side := -1.0 if gk.position.x > 0.0 else 1.0
	if absf(gk.position.x) < 0.6:
		side = 1.0 if rng.randf() < 0.5 else -1.0
	var tx := side * rng.randf_range(1.6, 3.0)
	var ty := rng.randf_range(0.3, 1.9)
	var power: float = 19.0 + 8.0 * p.skill + (2.0 if p.player_role == 3 else 0.0)
	var err := lerpf(0.11, 0.025, p.skill) * (1.0 + gd / 28.0)
	m.kick_shot_at(p, Vector3(tx, ty, sg * C.HALF_D), power, err, side * rng.randf_range(0.0, 0.3))

func pass_score(p, r) -> float:
	var s: int = p.team_side
	var sg := C.sgn(s)
	var d := fd(p.position, r.position)
	if d < 3.5:
		return -50.0
	var depth_r: float = r.position.z * sg
	var depth_p: float = p.position.z * sg
	if C.OFFSIDE_ON and depth_r > off_line[s] + 0.4 and depth_r > m.ball.position.z * sg + 0.4 and depth_r > 0.0:
		return -60.0
	var openv := minf(_opp_min_dist(s, r.position), 12.0)
	var lane := minf(_lane_min(s, p.position, r.position), 5.0)
	var sc := (depth_r - depth_p) * 0.38 + openv * 0.5 + lane * 1.5 - d * 0.07
	if lane < 2.4:
		sc -= 7.0 - lane * 1.5
	if d > 30.0:
		sc -= (d - 30.0) * 0.5
	if r.player_role == 0:
		sc -= 6.0
	if r.player_role == 3 and depth_r > 12.0:
		sc += 1.0
	if r.stun_t > 0.0:
		sc -= 20.0
	sc += rng.randf_range(-1.0, 1.0) * (1.0 - p.skill) * 2.0
	return sc

func best_pass(p, min_d := 4.0, max_d := 60.0):
	var best = null
	var bs := -999.0
	for r in m.players:
		if not r.active or r.team_side != p.team_side or r == p:
			continue
		var d := fd(p.position, r.position)
		if d < min_d or d > max_d:
			continue
		var sc := pass_score(p, r)
		if sc > bs:
			bs = sc
			best = r
	return best

# ---------------------------------------------------------------- goleiro
func _gk(p, dt: float) -> void:
	var s: int = p.team_side
	var sg := C.sgn(s)
	if p == m.carrier:
		if m.state == C.State.RESTART:
			p.drive(Vector3.ZERO, false, dt)
			return
		p.hold_t += dt
		p.drive(Vector3.ZERO, false, dt)
		if p.hold_t > 1.0 + (1.0 - p.skill) * 1.2:
			var r = best_pass(p, 6.0, 50.0)
			if r == null:
				m.ai_clear(p)
			else:
				var d := fd(p.position, r.position)
				m.kick_pass(p, r, C.Kick.LOB if d > 20.0 else C.Kick.GROUND, 1.0)
		return
	if _gk_shot(p, dt):
		return
	var gz := -sg * C.HALF_D
	var bp: Vector3 = m.ball.position
	if chaser[s] == p and m.carrier == null and m.state == C.State.PLAY:
		_move_to(p, _intercept(p), dt, true)
		return
	var gc := Vector3(0, 0, gz)
	var to_ball := bp - gc
	to_ball.y = 0.0
	var dist := to_ball.length()
	var off := clampf(dist * 0.2, 1.2, 6.5)
	if m.carrier != null and m.carrier.team_side != s and dist < 22.0:
		off = clampf(dist * 0.28, 1.5, 6.0)
	var pos := gc + to_ball.normalized() * off
	pos.x = clampf(pos.x, -3.4, 3.4)
	if m.state == C.State.RESTART and m.restart_type == C.Restart.PENALTY:
		pos = Vector3(0, 0, gz + sg * 0.6)
	_move_to(p, pos, dt, dist < 20.0 and off > 3.0)

func _gk_shot(p, dt: float) -> bool:
	var b = m.ball
	if m.carrier != null or m.state != C.State.PLAY:
		return false
	var s: int = p.team_side
	if m.last_touch_team == s:
		return false
	var sg := C.sgn(s)
	var gz := -sg * C.HALF_D
	var vz: float = b.vel.z
	var dz: float = gz - b.position.z
	if vz * dz <= 0.0 or absf(vz) < 4.0:
		return false
	var t := dz / vz
	if t > 1.3 or t < 0.0:
		return false
	var xi: float = b.position.x + b.vel.x * t
	var yi: float = maxf(C.BALL_R, b.position.y + b.vel.y * t - 0.5 * C.GRAVITY * t * t)
	if absf(xi) > 5.0 or yi > 3.2:
		return false
	if p.gk_shot_id != m.shot_id:
		p.gk_shot_id = m.shot_id
		p.gk_err = rng.randf_range(-1.0, 1.0) * (1.0 - p.skill) * 1.6
	xi += p.gk_err
	var dx: float = xi - p.position.x
	if absf(dx) > 0.9 and p.dive_t <= 0.0:
		var need := absf(dx) / maxf(t, 0.12)
		if need > 5.5 or t < 0.45:
			p.start_dive(Vector3(signf(dx), 0, 0), clampf(absf(dx) / 0.38, 4.0, 11.0), clampf(yi - 0.6, 0.0, 1.3))
		else:
			_move_to(p, Vector3(xi, 0, p.position.z), dt, true)
	else:
		_move_to(p, Vector3(xi, 0, p.position.z), dt, false)
	return true
