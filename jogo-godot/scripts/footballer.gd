extends CharacterBody3D
class_name Footballer
## Jogador de futebol: movimento por aceleração, stamina, carrinho, mergulho (goleiro),
## queda e animação simples do corpo. A física de movimento é própria (sem colisão engine);
## quem chama `tick()` é a partida (match.gd), para ficar determinístico e pausável.

enum TeamSide { HOME, AWAY }
enum PlayerRole { GK, DEF, MID, FWD }

@export var team_side: TeamSide = TeamSide.HOME
@export var player_role: PlayerRole = PlayerRole.MID
@export var is_user: bool = false   # verdadeiro = jogador atualmente controlado por você
@export var shirt_number: int = 10
@export var home_pos: Vector3 = Vector3.ZERO

const SPEED := 7.0
const SPRINT := 10.6
const SLIDE_TIME := 0.55
const DIVE_TIME := 0.6

var stamina: float = 1.0
var kick_cd: float = 0.0
var speed_mult: float = 1.0
var skill := 0.6
var pace_attr := 1.0
var slot := 0
var active := true
var yellow := 0
var vel := Vector3.ZERO
var facing := Vector3(0, 0, 1)
var look_pt := Vector3.ZERO
var has_look := false
var anchor := Vector3.ZERO
var ai_target := Vector3.ZERO
var ai_sprint := false
var ai_dir := Vector3.ZERO
var think_t := 0.0
var hold_t := 0.0
var mark: Footballer = null
var run_target := Vector3.ZERO
var run_until := 0.0
var slide_t := 0.0
var slide_dir := Vector3.ZERO
var slide_cd := 0.0
var slide_hit := false
var stun_t := 0.0
var fallen := false
var tackle_cd := 0.0
var lunge_t := 0.0
var lunge_done := false
var dive_t := 0.0
var dive_dir := Vector3.ZERO
var dive_speed := 0.0
var dive_h := 0.0
var gk_err := 0.0
var gk_shot_id := -1
var body: Node3D
var ring: MeshInstance3D
var _phase := 0.0

func setup(p_side: TeamSide, p_role: PlayerRole, p_user: bool, num: int, pos: Vector3, skin_i: int, hair_i: int) -> void:
	team_side = p_side
	player_role = p_role
	shirt_number = num
	home_pos = pos
	position = pos
	anchor = pos
	facing = Vector3(0, 0, 1.0 if p_side == TeamSide.HOME else -1.0)
	var kit := Color("e8c96a") if p_user else (Color("1e4a9a") if p_side == TeamSide.HOME else Color("8b2a28"))
	var shorts := Color("0e1420") if p_side == TeamSide.HOME else Color("140c0c")
	var socks := Color("d8dde8") if p_side == TeamSide.HOME else Color("c8c0bc")
	body = HumanoidBuilder.build(kit, shorts, socks, skin_i, hair_i, p_user, num)
	add_child(body)
	ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.58
	t.outer_radius = 0.74
	ring.mesh = t
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.9, 0.2)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.85, 0.15)
	rm.emission_energy_multiplier = 1.6
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	ring.position.y = 0.06
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	set_controlled(p_user)

func set_controlled(c: bool) -> void:
	is_user = c
	if ring:
		ring.visible = c
	speed_mult = GameState.speed_multiplier() if c else 1.0

func role_text() -> String:
	match player_role:
		PlayerRole.GK: return "GOL"
		PlayerRole.DEF: return "ZAG"
		PlayerRole.MID: return "MEI"
	return "ATA"

func busy() -> bool:
	return slide_t > 0.0 or stun_t > 0.0 or dive_t > 0.0

## Move com aceleração. dir com módulo 0..1 (mundo XZ).
func drive(dir: Vector3, want_sprint: bool, delta: float, scale := 1.0) -> void:
	if busy():
		return
	dir.y = 0.0
	var mag := minf(dir.length(), 1.0)
	var n := dir.normalized() if mag > 0.001 else Vector3.ZERO
	var sprinting := want_sprint and stamina > 0.06 and mag > 0.3
	var top := (SPRINT if sprinting else SPEED) * pace_attr * speed_mult * scale
	top *= lerpf(0.8, 1.0, clampf(stamina * 2.5, 0.0, 1.0))
	if lunge_t > 0.0:
		top *= 1.3
	var want := n * mag * top
	var acc := 34.0 if mag > 0.05 else 26.0
	vel = vel.move_toward(want, acc * delta)
	if sprinting:
		stamina = maxf(0.0, stamina - delta * 0.16)
	else:
		stamina = minf(1.0, stamina + delta * (0.05 if mag > 0.3 else 0.10))

func start_slide(dir: Vector3) -> bool:
	if slide_cd > 0.0 or busy():
		return false
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = facing
	slide_dir = dir.normalized()
	facing = slide_dir
	slide_t = SLIDE_TIME
	slide_cd = 1.4
	slide_hit = false
	stamina = maxf(0.0, stamina - 0.08)
	return true

func start_dive(dir: Vector3, spd: float, h: float) -> void:
	dive_dir = dir.normalized()
	dive_speed = spd
	dive_h = h
	dive_t = DIVE_TIME

func fall(t: float) -> void:
	stun_t = t
	fallen = true
	slide_t = 0.0
	vel *= 0.2

func tick(delta: float) -> void:
	if kick_cd > 0.0:
		kick_cd -= delta
	if tackle_cd > 0.0:
		tackle_cd -= delta
	if slide_cd > 0.0:
		slide_cd -= delta
	if lunge_t > 0.0:
		lunge_t -= delta
	if slide_t > 0.0:
		slide_t -= delta
		var f := clampf(slide_t / SLIDE_TIME, 0.0, 1.0)
		vel = slide_dir * (10.5 * f + 1.5)
		if slide_t <= 0.0:
			stun_t = 0.55
			vel *= 0.3
	elif dive_t > 0.0:
		dive_t -= delta
		vel = dive_dir * dive_speed * clampf(dive_t / DIVE_TIME + 0.25, 0.0, 1.0)
		if dive_t <= 0.0:
			stun_t = 0.7
			vel *= 0.2
	elif stun_t > 0.0:
		stun_t -= delta
		vel = vel.move_toward(Vector3.ZERO, 18.0 * delta)
		if stun_t <= 0.0:
			fallen = false
	position += vel * delta
	position.x = clampf(position.x, -28.0, 28.0)
	position.z = clampf(position.z, -41.0, 41.0)
	position.y = 0.0
	if not busy():
		var sp := vel.length()
		if sp > 0.8:
			facing = facing.lerp(vel / sp, clampf(delta * 14.0, 0.0, 1.0))
		elif has_look:
			var to := Vector3(look_pt.x - position.x, 0, look_pt.z - position.z)
			if to.length() > 0.5:
				facing = facing.lerp(to.normalized(), clampf(delta * 5.0, 0.0, 1.0))
		if facing.length() < 0.01:
			facing = Vector3(0, 0, 1)
		facing = facing.normalized()
	rotation.y = atan2(-facing.x, -facing.z)
	_animate(delta)

func _animate(delta: float) -> void:
	if body == null:
		return
	var sp := vel.length()
	_phase += sp * delta * 1.3
	var tx := 0.0
	var tz := 0.0
	var ty := 0.0
	if slide_t > 0.0:
		tx = 1.25
		ty = -0.35
	elif dive_t > 0.0:
		var sg := signf(dive_dir.dot(global_transform.basis.x))
		tz = -sg * 1.3
		ty = 0.05
	elif stun_t > 0.0 and fallen:
		tx = 1.45
		ty = -0.4
	elif stun_t > 0.0:
		tx = 0.5
		ty = -0.15
	else:
		tx = -clampf(sp / SPRINT, 0.0, 1.0) * 0.2
		ty = absf(sin(_phase * 2.2)) * 0.05 * clampf(sp / 4.0, 0.0, 1.0)
	var k := clampf(delta * 14.0, 0.0, 1.0)
	body.rotation.x = lerpf(body.rotation.x, tx, k)
	body.rotation.z = lerpf(body.rotation.z, tz, k)
	body.position.y = lerpf(body.position.y, ty, k)
