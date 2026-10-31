extends RefCounted
## Constantes e dados compartilhados da partida (sem class_name: use preload).

const PITCH_W := 48.0
const PITCH_D := 72.0
const HALF_W := 24.0
const HALF_D := 36.0
const BALL_R := 0.22
const GRAVITY := 13.0
const GOAL_HALF := 3.5
const GOAL_H := 2.5
const BOX_HALF_W := 14.0
const BOX_DEPTH := 12.0
const HALF_REAL_SECONDS := 45.0   # segundos reais por tempo
const HALF_GAME_MIN := 45.0       # minutos de jogo por tempo
const OFFSIDE_ON := true
const REPLAY_FPS := 30.0
const REPLAY_SECONDS := 4.5

enum State { PLAY, RESTART, GOAL, REPLAY, HALFTIME, FULLTIME }
enum Restart { KICKOFF, THROW_IN, CORNER, GOAL_KICK, FREE_KICK, PENALTY, INDIRECT }
enum Kick { GROUND, LOB, THROUGH, THROW }

# role: 0 GK, 1 DEF, 2 MID, 3 FWD  (igual a Footballer.PlayerRole)
# x lateral, d profundidade (negativo = perto do próprio gol), num camisa
const FORM := [
	{"role": 0, "x": 0.0, "d": -33.0, "num": 1},
	{"role": 1, "x": -17.0, "d": -16.0, "num": 2},
	{"role": 1, "x": -5.5, "d": -16.0, "num": 3},
	{"role": 1, "x": 5.5, "d": -16.0, "num": 4},
	{"role": 1, "x": 17.0, "d": -16.0, "num": 5},
	{"role": 2, "x": -17.0, "d": -4.0, "num": 6},
	{"role": 2, "x": -5.5, "d": -4.0, "num": 7},
	{"role": 2, "x": 5.5, "d": -4.0, "num": 8},
	{"role": 2, "x": 17.0, "d": -4.0, "num": 11},
	{"role": 3, "x": -13.0, "d": 6.0, "num": 9},
	{"role": 3, "x": 0.0, "d": 6.0, "num": 10},
	{"role": 3, "x": 13.0, "d": 6.0, "num": 17},
]

static func sgn(side: int) -> float:
	return 1.0 if side == 0 else -1.0

static func fd(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
