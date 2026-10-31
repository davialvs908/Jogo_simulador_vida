extends Node3D
## Bola com física própria: gravidade, quique, atrito de grama, arrasto, efeito (curl),
## rotação visual, traves/travessão/rede e sombra projetada.

const C := preload("res://scripts/match_consts.gd")

var vel := Vector3.ZERO
var curl := 0.0
var frozen := false
var _pivot: Node3D
var _shadow: MeshInstance3D

func _init() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = C.BALL_R
	sph.height = C.BALL_R * 2.0
	mi.mesh = sph
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.95, 0.95, 0.95)
	bm.roughness = 0.5
	mi.material_override = bm
	_pivot.add_child(mi)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.1)
	var dirs := [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK,
		Vector3(1, 1, 1), Vector3(-1, 1, -1), Vector3(1, -1, -1), Vector3(-1, -1, 1)]
	for d in dirs:
		var n: Vector3 = d.normalized()
		var patch := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.075
		ps.height = 0.07
		patch.mesh = ps
		patch.material_override = dark
		patch.position = n * (C.BALL_R - 0.012)
		patch.look_at_from_position(patch.position, Vector3.ZERO, Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT)
		_pivot.add_child(patch)
	_shadow = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.2
	cm.bottom_radius = 0.2
	cm.height = 0.01
	_shadow.mesh = cm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0, 0, 0, 0.45)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow.material_override = sm
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	add_child(_shadow)

func on_ground() -> bool:
	return position.y <= C.BALL_R + 0.04

func speed_xz() -> float:
	return Vector2(vel.x, vel.z).length()

func step(delta: float) -> void:
	if frozen:
		vel = Vector3.ZERO
		_update_shadow()
		return
	var sp := vel.length()
	var n := clampi(ceili(sp * delta / 0.15), 1, 6)
	var h := delta / float(n)
	for i in n:
		_phys(h)
	update_visual(delta)

func _phys(dt: float) -> void:
	var v := vel
	v.y -= C.GRAVITY * dt
	if position.y > C.BALL_R + 0.04:
		var k := 0.07
		v.x *= 1.0 - k * dt
		v.z *= 1.0 - k * dt
		if absf(curl) > 0.01:
			var perp := Vector3(-v.z, 0.0, v.x)
			var pl := perp.length()
			if pl > 0.01:
				var hs := Vector2(v.x, v.z).length()
				var acc := perp / pl * curl * hs * 0.5
				v.x += acc.x * dt
				v.z += acc.z * dt
			curl *= maxf(0.0, 1.0 - 0.6 * dt)
	else:
		var hs2 := Vector2(v.x, v.z).length()
		if hs2 > 0.0:
			var ns := maxf(0.0, hs2 * exp(-0.6 * dt) - 0.4 * dt)
			var f := ns / hs2
			v.x *= f
			v.z *= f
		curl = 0.0
	position += v * dt
	if position.y < C.BALL_R:
		position.y = C.BALL_R
		if v.y < 0.0:
			if v.y < -1.8:
				v.y = -v.y * 0.58
				v.x *= 0.92
				v.z *= 0.92
			else:
				v.y = 0.0
	vel = v
	_goal_collide()

func _goal_collide() -> void:
	for gz in [-C.HALF_D, C.HALF_D]:
		if absf(position.z - gz) > 3.5:
			continue
		var sgz := signf(gz)
		for px in [-C.GOAL_HALF, C.GOAL_HALF]:
			if position.y < C.GOAL_H + C.BALL_R:
				var dx: float = position.x - px
				var dz: float = position.z - gz
				var d := Vector2(dx, dz).length()
				if d < C.BALL_R + 0.08 and d > 0.001:
					var nrm := Vector3(dx, 0, dz) / d
					position += nrm * (C.BALL_R + 0.08 - d)
					var vn := vel.dot(nrm)
					if vn < 0.0:
						vel -= nrm * vn * 1.6
		if absf(position.x) < C.GOAL_HALF:
			var dz2: float = position.z - gz
			var dy: float = position.y - C.GOAL_H
			var d2 := Vector2(dz2, dy).length()
			if d2 < C.BALL_R + 0.07 and d2 > 0.001:
				var nrm2 := Vector3(0, dy, dz2) / d2
				position += nrm2 * (C.BALL_R + 0.07 - d2)
				var vn2 := vel.dot(nrm2)
				if vn2 < 0.0:
					vel -= nrm2 * vn2 * 1.55
		# rede
		if position.z * sgz > C.HALF_D + 0.1 and absf(position.x) < C.GOAL_HALF + 0.1 and position.y < C.GOAL_H + 0.2:
			if position.z * sgz > C.HALF_D + 2.4:
				position.z = sgz * (C.HALF_D + 2.4)
				vel.z *= -0.12
				vel.x *= 0.5
			if absf(position.x) > C.GOAL_HALF - 0.1:
				position.x = clampf(position.x, -C.GOAL_HALF + 0.1, C.GOAL_HALF - 0.1)
				vel.x *= -0.2
			if position.y > C.GOAL_H - 0.05:
				position.y = C.GOAL_H - 0.05
				vel.y = minf(vel.y, 0.0) * 0.1

func update_visual(delta: float) -> void:
	var hv := Vector3(vel.x, 0, vel.z)
	var l := hv.length()
	if l > 0.05:
		var axis := Vector3.UP.cross(hv).normalized()
		_pivot.rotate(axis, l * delta / C.BALL_R)
	_update_shadow()

func _update_shadow() -> void:
	var h := maxf(0.0, position.y - C.BALL_R)
	_shadow.global_position = Vector3(position.x, 0.03, position.z)
	var s := clampf(1.0 - h * 0.12, 0.35, 1.0)
	_shadow.scale = Vector3(s, 1, s)

## Posição prevista em t segundos (balística simples, sem atrito).
func predict(t: float) -> Vector3:
	var p := position + Vector3(vel.x, 0, vel.z) * t
	var y := position.y + vel.y * t - 0.5 * C.GRAVITY * t * t
	p.y = maxf(C.BALL_R, y)
	return p

## Ponto de aterrissagem aproximado.
func landing() -> Vector3:
	var a := 0.5 * C.GRAVITY
	var disc := vel.y * vel.y + 4.0 * a * maxf(0.0, position.y - C.BALL_R)
	var t := (vel.y + sqrt(maxf(0.0, disc))) / (2.0 * a)
	return predict(maxf(0.0, t))
