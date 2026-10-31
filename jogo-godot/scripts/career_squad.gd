extends RefCounted
## Elencos determinísticos (sem precisar salvar 96 clubes) e fórmulas de overall.

const Names = preload("res://scripts/career_names.gd")

const POSITIONS := ["GOL", "ZAG", "LAT", "VOL", "MEI", "ATA"]
const POS_NAMES := {"GOL": "Goleiro", "ZAG": "Zagueiro", "LAT": "Lateral", "VOL": "Volante", "MEI": "Meia", "ATA": "Atacante"}
const ATTR_KEYS := ["pace", "shoot", "pass", "dribble", "defense", "physical"]
const ATTR_NAMES := {"pace": "Ritmo", "shoot": "Chute", "pass": "Passe", "dribble": "Drible", "defense": "Defesa", "physical": "Físico"}

# pesos por posição na ordem ATTR_KEYS: ritmo, chute, passe, drible, defesa, físico
const WEIGHTS := {
	"GOL": [0.10, 0.05, 0.10, 0.00, 0.55, 0.20],
	"ZAG": [0.10, 0.05, 0.10, 0.05, 0.45, 0.25],
	"LAT": [0.25, 0.05, 0.15, 0.15, 0.25, 0.15],
	"VOL": [0.05, 0.05, 0.30, 0.10, 0.30, 0.20],
	"MEI": [0.10, 0.15, 0.30, 0.25, 0.10, 0.10],
	"ATA": [0.20, 0.35, 0.10, 0.20, 0.05, 0.10],
}
const GOAL_W := {"GOL": 0.0, "ZAG": 0.8, "LAT": 1.2, "VOL": 1.2, "MEI": 4.0, "ATA": 8.0}
const ASSIST_W := {"GOL": 0.0, "ZAG": 0.5, "LAT": 3.0, "VOL": 2.0, "MEI": 6.0, "ATA": 4.0}

# [posição, titular?] — 20 jogadores por clube (+ o jogador do usuário no clube dele)
const SLOTS := [
	["GOL", 1], ["GOL", 0], ["ZAG", 1], ["ZAG", 1], ["ZAG", 0], ["ZAG", 0],
	["LAT", 1], ["LAT", 1], ["LAT", 0], ["VOL", 1], ["VOL", 1], ["VOL", 0],
	["MEI", 1], ["MEI", 1], ["MEI", 0], ["MEI", 0], ["ATA", 1], ["ATA", 1], ["ATA", 0], ["ATA", 0],
]
const NUMBERS := [1, 12, 3, 4, 13, 15, 2, 6, 16, 5, 8, 18, 10, 7, 14, 17, 9, 11, 19, 20]

static var _cache := {}

static func overall(pos: String, attrs: Dictionary) -> int:
	var w: Array = WEIGHTS.get(pos, WEIGHTS["MEI"])
	var s := 0.0
	for i in ATTR_KEYS.size():
		s += float(attrs.get(ATTR_KEYS[i], 40)) * float(w[i])
	return clampi(int(round(s)), 1, 99)

## Atributos iniciais de um jogador novo (ênfase na posição).
static func starting_attrs(pos: String, rng: RandomNumberGenerator, base := 50) -> Dictionary:
	var w: Array = WEIGHTS.get(pos, WEIGHTS["MEI"])
	var a := {}
	for i in ATTR_KEYS.size():
		var wi: float = w[i]
		var bonus := 8 if wi >= 0.2 else (-6 if wi <= 0.06 else 0)
		a[ATTR_KEYS[i]] = clampi(base + bonus + rng.randi_range(-3, 3), 35, 99)
	return a

static func squad(league: int, club: int, season: int) -> Array:
	var key := "%d_%d_%d" % [league, club, season]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 400:
		_cache.clear()
	var strength: int = Leagues.club_strength(league, club)
	var out: Array = []
	for k in SLOTS.size():
		var pos: String = SLOTS[k][0]
		var starter: bool = SLOTS[k][1] == 1
		var life := 3 + (k % 4)
		var off := (k * 7 + league * 3 + club) % life
		var t := maxi(season - 1, 0) + off
		var cohort := t / life
		var within := t % life
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("sq_%d_%d_%d_%d" % [league, club, k, cohort])
		var start_age := 18 + int(rng.randi() % 10)
		var age := start_age + within
		var quality := rng.randf_range(-4.0, 4.0) + (2.0 if starter else -3.0)
		var curve := 0.0
		if age <= 22:
			curve = -float(23 - age) * 1.5
		elif age >= 31:
			curve = -float(age - 30) * 1.6
		var ovr := clampi(int(round(strength + quality + curve)), 40, 94)
		var nm: Dictionary = Names.make(league, rng)
		out.append({
			"slot": k, "club": club, "league": league, "name": nm.full, "short": nm.short,
			"pos": pos, "ovr": ovr, "age": age, "num": NUMBERS[k], "starter": starter, "user": false,
		})
	_cache[key] = out
	return out

## Elenco do clube do usuário com ele incluído (ordenado por posição e overall).
static func squad_with_user(league: int, club: int, season: int, user: Dictionary) -> Array:
	var out: Array = squad(league, club, season).duplicate(true)
	out.append(user)
	out.sort_custom(func (a, b):
		var ia: int = POSITIONS.find(a.pos)
		var ib: int = POSITIONS.find(b.pos)
		if ia != ib:
			return ia < ib
		return int(a.ovr) > int(b.ovr))
	return out

static func average_top(sq: Array, n := 14) -> float:
	var v: Array = []
	for p in sq:
		v.append(int(p.ovr))
	v.sort()
	v.reverse()
	var s := 0.0
	var c := mini(n, v.size())
	for i in c:
		s += float(v[i])
	return s / maxf(1.0, float(c))

## Escolhe um índice do elenco ponderado por posição e overall (para gols/assistências da IA).
static func weighted_pick(sq: Array, assists: bool, exclude := -1) -> int:
	var tot := 0.0
	var ws: Array = []
	for p in sq:
		var w: float = float((ASSIST_W if assists else GOAL_W).get(p.pos, 0.0))
		w *= pow(float(p.ovr) / 70.0, 3.0)
		if int(p.slot) == exclude:
			w = 0.0
		ws.append(w)
		tot += w
	if tot <= 0.0:
		return 0
	var r := randf() * tot
	for i in ws.size():
		r -= float(ws[i])
		if r <= 0.0:
			return i
	return ws.size() - 1
