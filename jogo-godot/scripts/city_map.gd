extends Control
## Minimapa (HUD) e mapa grande da cidade: bairros, locais, rota do GPS, waypoint e missão.

const G = preload("res://scripts/city_graph.gd")

var hub
var full := false
var radius := 80.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if full else Control.MOUSE_FILTER_IGNORE

func _focus() -> Vector3:
	if full:
		return Vector3(0, 0, -16)
	return hub.ref_pos()

func _scale() -> float:
	if full:
		return minf(size.x / 410.0, size.y / 392.0)
	return minf(size.x, size.y) * 0.5 / radius

func _w2s(w: Vector3, focus: Vector3, sc: float) -> Vector2:
	return size * 0.5 + Vector2(w.x - focus.x, w.z - focus.z) * sc

func _s2w(s: Vector2, focus: Vector3, sc: float) -> Vector3:
	var v := (s - size * 0.5) / sc
	return Vector3(focus.x + v.x, 0.0, focus.z + v.y)

func _rect(x0: float, z0: float, x1: float, z1: float, col: Color, focus: Vector3, sc: float) -> void:
	var a := _w2s(Vector3(x0, 0, z0), focus, sc)
	var b := _w2s(Vector3(x1, 0, z1), focus, sc)
	draw_rect(Rect2(a, b - a), col)

func _gui_input(ev: InputEvent) -> void:
	if not full or hub == null:
		return
	if ev is InputEventMouseButton and ev.pressed:
		var w := _s2w(ev.position, _focus(), _scale())
		if ev.button_index == MOUSE_BUTTON_LEFT:
			hub.set_waypoint(w, "Ponto marcado no mapa")
			queue_redraw()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			hub.clear_waypoint()
			queue_redraw()

func _draw() -> void:
	if hub == null:
		return
	var focus := _focus()
	var sc := _scale()
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.06, 0.09))
	# bairros
	_rect(-200, -200, 200, 114, Color(0.12, 0.17, 0.14), focus, sc)
	_rect(-200, -200, -58, 114, Color(0.13, 0.25, 0.15), focus, sc)     # subúrbio
	_rect(58, -200, 200, 114, Color(0.26, 0.22, 0.16), focus, sc)       # zona de lojas
	_rect(-58, -200, 58, -58, Color(0.15, 0.22, 0.22), focus, sc)       # distrito esportivo
	_rect(-58, -58, 58, 114, Color(0.18, 0.19, 0.22), focus, sc)        # centro
	_rect(-200, 114, 200, 165, Color(0.62, 0.56, 0.38), focus, sc)      # praia
	_rect(-200, 165, 200, 260, Color(0.08, 0.25, 0.42), focus, sc)      # mar
	# ruas
	var rc := Color(0.36, 0.38, 0.43)
	for x in G.XS:
		_rect(x - 4, -114, x + 4, 114, rc, focus, sc)
	for z in G.ZS:
		_rect(-169, z - 4, 169, z + 4, rc, focus, sc)
	# locais
	for id in hub.SPOTS.keys():
		var sp: Dictionary = hub.SPOTS[id]
		var p: Vector3 = sp.pos
		var s: Vector3 = sp.size
		var col: Color = (sp.color as Color).lightened(0.35)
		_rect(p.x - s.x * 0.5, p.z - s.z * 0.5, p.x + s.x * 0.5, p.z + s.z * 0.5, col, focus, sc)
		var lab: String = str(sp.label)
		var sp2 := _w2s(p, focus, sc)
		if full:
			draw_string(font, sp2 + Vector2(-lab.length() * 3.2, -s.z * 0.5 * sc - 4), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
		elif sc > 1.0:
			draw_string(font, sp2 + Vector2(-4, 4), lab.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.05, 0.05, 0.05))
	if full:
		for cfg in [["SUBÚRBIO", Vector3(-137, 0, 100)], ["CENTRO", Vector3(0, 0, 100)], ["ZONA DE LOJAS", Vector3(137, 0, 100)],
				["DISTRITO ESPORTIVO", Vector3(0, 0, -100)], ["PRAIA", Vector3(0, 0, 140)]]:
			var q := _w2s(cfg[1], focus, sc)
			draw_string(font, q + Vector2(-cfg[0].length() * 4.0, 0), cfg[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.55))
	# rota do GPS
	var rp: Array = hub.route_pts
	if rp.size() >= 2:
		var pts := PackedVector2Array()
		for q in rp:
			pts.append(_w2s(q, focus, sc))
		draw_polyline(pts, Color(0.2, 0.9, 1.0), 3.0 if full else 2.5, true)
	# polícia (só com detector de radar)
	if hub.city.has_item("radar") and hub.traffic:
		for c in hub.traffic.cars:
			if c.kind == "police" and (c.node as Node3D).visible:
				var pp := _w2s((c.node as Node3D).position, focus, sc)
				draw_circle(pp, 4.0, Color(0.2, 0.4, 1.0))
	# marcador de missão
	var tgt: Dictionary = hub.missions.current_target()
	if not tgt.is_empty():
		_marker(tgt.pos, Color(1.0, 0.85, 0.2), focus, sc, "!")
	if hub.has_waypoint:
		_marker(hub.waypoint, Color(1.0, 0.3, 0.8), focus, sc, "")
	# jogador
	var me := _w2s(hub.ref_pos(), focus, sc)
	var yaw: float = hub.player_yaw()
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var perp := Vector2(-fwd.y, fwd.x)
	var tri := PackedVector2Array([me + fwd * 9.0, me - fwd * 6.0 + perp * 6.0, me - fwd * 3.0, me - fwd * 6.0 - perp * 6.0])
	draw_colored_polygon(tri, Color(0.95, 0.95, 1.0))
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[3], tri[0]]), Color(0.1, 0.4, 0.9), 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 2.0)
	if not full:
		draw_string(font, Vector2(size.x - 14, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))

func _marker(w: Vector3, col: Color, focus: Vector3, sc: float, txt: String) -> void:
	var p := _w2s(w, focus, sc)
	var half := size * 0.5 - Vector2(12, 12)
	var rel := p - size * 0.5
	var inside := absf(rel.x) < half.x and absf(rel.y) < half.y
	var pulse := 1.0 + 0.25 * sin(Time.get_ticks_msec() * 0.006)
	if inside:
		draw_circle(p, 8.0 * pulse, Color(col.r, col.g, col.b, 0.35))
		draw_circle(p, 5.0, col)
		draw_circle(p, 5.0, Color(0, 0, 0, 0.8), false, 1.0)
		if txt != "":
			draw_string(ThemeDB.fallback_font, p + Vector2(-3, 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0))
	else:
		var k := minf(half.x / maxf(absf(rel.x), 0.01), half.y / maxf(absf(rel.y), 0.01))
		var edge := size * 0.5 + rel * k
		var dir := rel.normalized()
		var perp := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([edge + dir * 8.0, edge - dir * 4.0 + perp * 6.0, edge - dir * 4.0 - perp * 6.0]), col)
