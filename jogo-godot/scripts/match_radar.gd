extends Control
## Mini-radar do campo (desenhado em _draw).

const C := preload("res://scripts/match_consts.gd")
var match_ref

func _init() -> void:
	custom_minimum_size = Vector2(176, 118)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _pt(x: float, z: float) -> Vector2:
	var w := size.x - 8.0
	var h := size.y - 8.0
	return Vector2(4.0 + (z + C.HALF_D) / C.PITCH_D * w, 4.0 + (C.HALF_W - x) / C.PITCH_W * h)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.12, 0.06, 0.72))
	var a := _pt(-C.HALF_W, -C.HALF_D)
	var b := _pt(C.HALF_W, C.HALF_D)
	var line := Color(1, 1, 1, 0.55)
	draw_rect(Rect2(Vector2(a.x, b.y), Vector2(b.x - a.x, a.y - b.y)), line, false, 1.0)
	var mid_top := _pt(C.HALF_W, 0.0)
	var mid_bot := _pt(-C.HALF_W, 0.0)
	draw_line(mid_top, mid_bot, line, 1.0)
	draw_arc(_pt(0, 0), 8.0, 0, TAU, 20, line, 1.0)
	for gz in [-C.HALF_D, C.HALF_D]:
		var p1 := _pt(C.BOX_HALF_W, gz)
		var p2 := _pt(-C.BOX_HALF_W, gz - signf(gz) * C.BOX_DEPTH)
		draw_rect(Rect2(Vector2(minf(p1.x, p2.x), minf(p1.y, p2.y)), Vector2(absf(p1.x - p2.x), absf(p1.y - p2.y))), line, false, 1.0)
	if match_ref == null or not is_instance_valid(match_ref):
		return
	for p in match_ref.players:
		if not p.active:
			continue
		var col := Color(0.3, 0.55, 1.0) if p.team_side == 0 else Color(1.0, 0.35, 0.3)
		var r := 2.4
		if p.is_user:
			col = Color(1.0, 0.9, 0.2)
			r = 3.8
		draw_circle(_pt(p.position.x, p.position.z), r, col)
	draw_circle(_pt(match_ref.ball.position.x, match_ref.ball.position.z), 2.4, Color.WHITE)
