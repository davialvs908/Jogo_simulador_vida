extends RefCounted
## Grade viária da cidade: nós = cruzamentos, semáforos e busca de rota (GPS / rival).

const XS := [-165.0, -110.0, -55.0, 0.0, 55.0, 110.0, 165.0]
const ZS := [-110.0, -55.0, 0.0, 55.0, 110.0]
const NX := 7
const NZ := 5
const ROAD_HALF := 4.0
const LANE := 2.0          # deslocamento da faixa (mão direita)
const CAR_STOP := 8.5      # distância do centro do cruzamento onde o carro para
const WALK_LAT := 6.0      # deslocamento da calçada
const CYCLE := 26.0

static func count() -> int:
	return NX * NZ

static func node_id(i: int, j: int) -> int:
	return j * NX + i

static func node_i(id: int) -> int:
	return id % NX

static func node_j(id: int) -> int:
	return id / NX

static func node_pos(id: int) -> Vector3:
	return Vector3(XS[id % NX], 0.0, ZS[id / NX])

static func neighbors(id: int) -> Array:
	var out: Array = []
	var i := id % NX
	var j := id / NX
	if i > 0: out.append(node_id(i - 1, j))
	if i < NX - 1: out.append(node_id(i + 1, j))
	if j > 0: out.append(node_id(i, j - 1))
	if j < NZ - 1: out.append(node_id(i, j + 1))
	return out

static func nearest_node(p: Vector3) -> int:
	var best := 0
	var bd := 1e12
	for id in count():
		var d := Vector2(p.x - XS[id % NX], p.z - ZS[id / NX]).length_squared()
		if d < bd:
			bd = d
			best = id
	return best

## Rota mais curta (todas as arestas têm o mesmo tamanho -> BFS).
static func route(from_id: int, to_id: int) -> Array:
	if from_id == to_id:
		return [from_id]
	var prev := {}
	prev[from_id] = -1
	var queue: Array = [from_id]
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		if cur == to_id:
			break
		for n in neighbors(cur):
			if not prev.has(n):
				prev[n] = cur
				queue.append(n)
	var path: Array = []
	var c := to_id
	while c != -1:
		path.push_front(c)
		c = int(prev.get(c, -1))
	return path

static func axis_of(dir: Vector3) -> int:
	return 0 if absf(dir.x) > absf(dir.z) else 1

## 0 verde, 1 amarelo, 2 vermelho. axis 0 = tráfego no eixo X, 1 = eixo Z.
static func light_state(id: int, axis: int, t: float) -> int:
	var tt := fmod(t + float(id) * 3.7, CYCLE)
	if axis == 1:
		if tt < 10.0:
			return 0
		if tt < 12.0:
			return 1
		return 2
	if tt >= 13.0 and tt < 23.0:
		return 0
	if tt >= 23.0 and tt < 25.0:
		return 1
	return 2

static func green_left(id: int, axis: int, t: float) -> float:
	var tt := fmod(t + float(id) * 3.7, CYCLE)
	if axis == 1:
		return maxf(0.0, 10.0 - tt) if tt < 10.0 else 0.0
	return maxf(0.0, 23.0 - tt) if (tt >= 13.0 and tt < 23.0) else 0.0

static func right_of(dir: Vector3) -> Vector3:
	return dir.cross(Vector3.UP)

## Direção unitária de um nó para outro.
static func dir_between(a: int, b: int) -> Vector3:
	return (node_pos(b) - node_pos(a)).normalized()

static func district_at(p: Vector3) -> String:
	if p.z > 112.0:
		return "Praia"
	if p.x < -58.0:
		return "Subúrbio"
	if p.x > 58.0:
		return "Zona de lojas"
	if p.z < -58.0:
		return "Distrito esportivo"
	return "Centro"
