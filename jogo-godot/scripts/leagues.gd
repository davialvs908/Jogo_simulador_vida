extends RefCounted
class_name Leagues
## 12 ligas fictícias (nomes originais, sem licenças). 8 clubes cada.
## pay = multiplicador de salário · power = força média dos clubes.

const DATA := [
	{"name": "Liga Sol Dourado", "region": "Costa Sul", "pay": 2.0, "power": 88, "suffix": "FC",
	 "towns": ["Porto Aurora", "Vila Serena", "Monte Real", "Campo Verde", "Baía Branca", "Rio Claro Sul", "Alto Mar", "Pedra Viva"]},
	{"name": "Premier Norte", "region": "Reino do Norte", "pay": 2.0, "power": 87, "suffix": "United",
	 "towns": ["Ashford Vale", "Kingsmoor", "Redbridge", "Northwick", "Stonehaven", "Eastgate", "Harlow Moor", "Brightfield"]},
	{"name": "Liga Ibérica Nova", "region": "Península Oeste", "pay": 1.9, "power": 86, "suffix": "CF",
	 "towns": ["Valdoro", "Santa Luna", "Cordela", "Nuevo Alcázar", "Riomar", "Torrealta", "Almenar", "Sierra Brava"]},
	{"name": "Bundes Central", "region": "Terra Central", "pay": 1.9, "power": 85, "suffix": "SV",
	 "towns": ["Eisental", "Waldburg", "Hohenfeld", "Rheinau", "Kaltenberg", "Steinbach", "Lindenau", "Grünwald"]},
	{"name": "Calcio Azzurro", "region": "Península Leste", "pay": 1.8, "power": 84, "suffix": "Calcio",
	 "towns": ["Montefiore", "Castelvento", "Borgo Alto", "San Marello", "Valcerro", "Portovino", "Lagonero", "Rocca Bella"]},
	{"name": "Ligue Lumière", "region": "Terras do Rio", "pay": 1.7, "power": 83, "suffix": "AS",
	 "towns": ["Beaurivage", "Montclair", "Saint-Orel", "Valmont", "Roche-Blanche", "Lacourt", "Pontrieux", "Clairefontaine"]},
	{"name": "Eredivisie Delta", "region": "Planície Baixa", "pay": 1.4, "power": 78, "suffix": "VV",
	 "towns": ["Dijkhoven", "Waterstad", "Zeeburg", "Molenkamp", "Veldhaven", "Brinkdorp", "Lindeveen", "Havenrust"]},
	{"name": "Série Brasa", "region": "Trópico Atlântico", "pay": 1.3, "power": 77, "suffix": "EC",
	 "towns": ["Palmeiral", "Serra Dourada", "Vale do Cacau", "Ilha Grande Norte", "Cajueiro", "Mar Vermelho", "Boa Esperança", "Ouro Fino"]},
	{"name": "Primera Pampa", "region": "Cone Sul", "pay": 1.3, "power": 76, "suffix": "Club",
	 "towns": ["Pampa Alta", "San Cristóbal Sur", "Río Plateado", "Villa Esperanza", "Cerro Negro", "La Quebrada", "Puerto Nuevo", "Tierra Brava"]},
	{"name": "Superliga Bósforo", "region": "Ponte Oriental", "pay": 1.2, "power": 75, "suffix": "Spor",
	 "towns": ["Karadağ", "Yeşilvadi", "Altınova", "Denizli Bay", "Kırmızı Tepe", "Mavi Liman", "Taşköprü", "Güneş Kent"]},
	{"name": "Liga Pacífico", "region": "América Norte", "pay": 1.1, "power": 72, "suffix": "FC",
	 "towns": ["Sol de Oro", "Cabo Dorado", "Sierra Azul", "Valle del Sol", "Puerto Coral", "Mesa Roja", "Costa Brava Oeste", "Lago Claro"]},
	{"name": "Liga Samurai", "region": "Arquipélago Leste", "pay": 1.1, "power": 71, "suffix": "FC",
	 "towns": ["Asahigawa", "Kitamori", "Shirakawa", "Minatoyama", "Aokita", "Fujimori", "Sakuraoka", "Tsukiyama"]},
]

static func count() -> int:
	return DATA.size()

static func club_name(league: int, idx: int) -> String:
	var l: Dictionary = DATA[league]
	return "%s %s" % [l.towns[idx], l.suffix]

static func club_strength(league: int, idx: int) -> int:
	var l: Dictionary = DATA[league]
	# determinístico: cada clube varia em torno da força da liga
	return int(l.power) + ((idx * 37 + league * 11) % 9) - 4

## Rodadas (método do círculo) para 8 clubes: 14 rodadas, ida e volta.
## Cada rodada: lista de [casa, fora].
static func schedule() -> Array:
	var n := 8
	var teams: Array = range(n)
	var first: Array = []
	for r in n - 1:
		var round_pairs: Array = []
		for i in n / 2:
			var a: int = teams[i]
			var b: int = teams[n - 1 - i]
			round_pairs.append([a, b] if (r + i) % 2 == 0 else [b, a])
		first.append(round_pairs)
		var last: int = teams.pop_back()
		teams.insert(1, last)
	var all: Array = first.duplicate(true)
	for rp in first:
		var rev: Array = []
		for pr in rp:
			rev.append([pr[1], pr[0]])
		all.append(rev)
	return all
