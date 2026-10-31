extends RefCounted
## Gerador de nomes inventados (combinação de sílabas por região). Nenhum nome real é usado de propósito.

# sabor de nomes por liga (índice = league_id)
const FLAVOR_BY_LEAGUE := ["br", "eng", "es", "ger", "ita", "fr", "nl", "br", "es", "tr", "es", "jp"]

const T := {
	"br": {
		"fs": ["Ro", "Ca", "Jo", "Fe", "Ma", "Lu", "Ga", "Vi", "Ra", "Di", "Be", "Ti", "Ná", "Ne"],
		"fe": ["drigo", "rlos", "ão", "lipe", "teus", "cas", "briel", "ctor", "fael", "ego", "ito", "ago", "dson", "lton"],
		"ls": ["Sil", "Mont", "Per", "Cord", "Alm", "Barr", "Torr", "Vel", "Nasc", "Fon", "Lem", "Rib", "Cav", "Mor"],
		"le": ["veira", "eiro", "ana", "ero", "ada", "oso", "edo", "inho", "ares", "andes", "oza", "eira", "ento", "ário"],
	},
	"es": {
		"fs": ["Ál", "Die", "Sa", "Ma", "Ra", "Ig", "Lu", "Pa", "Ni", "Ox", "Jai", "Eu", "Ro", "Tom"],
		"fe": ["varo", "go", "ntiago", "teo", "món", "nacio", "ciano", "blo", "colás", "car", "me", "genio", "mán", "ás"],
		"ls": ["Mar", "Gal", "Her", "Ruiz", "Cas", "Ort", "Nav", "Vás", "Cab", "Rey", "Sol", "Ber", "Pal", "Lar"],
		"le": ["tínez", "indo", "rera", "ano", "tillo", "ega", "arro", "quez", "allero", "ner", "ís", "mudio", "ores", "eda"],
	},
	"eng": {
		"fs": ["Al", "Ja", "Har", "Os", "Ed", "Wil", "Tom", "Lew", "Ben", "Ry", "Cal", "Mar", "Fin", "Gar"],
		"fe": ["fie", "mes", "ry", "car", "win", "liam", "my", "is", "jamin", "an", "lum", "cus", "nley", "eth"],
		"ls": ["Ash", "King", "Red", "North", "Stone", "East", "Har", "Bright", "Wood", "Black", "Whit", "Thorn", "Hol", "Pen"],
		"le": ["ford", "ley", "bridge", "wick", "haven", "gate", "low", "field", "ton", "worth", "croft", "ing", "well", "by"],
	},
	"ger": {
		"fs": ["Kl", "Ma", "Fe", "Jo", "Lu", "Ni", "Ste", "Til", "Ba", "Ha", "Da", "Fa", "El", "Ru"],
		"fe": ["aus", "ximilian", "lix", "nas", "kas", "klas", "fan", "mo", "stian", "nnes", "vid", "bian", "ias", "dolf"],
		"ls": ["Brand", "Eisen", "Wald", "Hoch", "Rhein", "Stein", "Linden", "Kalt", "Wein", "Sauer", "Falk", "Berg", "Voss", "Kraut"],
		"le": ["mann", "stein", "berger", "feld", "hauer", "mayer", "dorf", "ner", "bach", "ler", "au", "ling", "huber", "tal"],
	},
	"ita": {
		"fs": ["Lo", "Ma", "Fe", "Gi", "Ni", "Al", "Ric", "Em", "Fa", "Do", "Ste", "Cl", "Pa", "Vit"],
		"fe": ["renzo", "rco", "derico", "anluca", "colò", "essio", "cardo", "ilio", "bio", "menico", "fano", "audio", "olo", "torio"],
		"ls": ["Mon", "Cast", "Bor", "Val", "Por", "Lag", "Roc", "Fior", "Ven", "Bel", "Sar", "Ter", "Gal", "Cor"],
		"le": ["tanari", "ellani", "ghese", "cerro", "tovino", "nero", "cella", "entini", "tura", "lucci", "etti", "ardi", "olini", "ano"],
	},
	"fr": {
		"fs": ["Lu", "Ju", "Hu", "Th", "Ni", "Éti", "Ba", "Cl", "Ma", "Fa", "Ré", "Ol", "Pier", "Gas"],
		"fe": ["dovic", "lien", "go", "éo", "colas", "enne", "ptiste", "ément", "thieu", "bien", "my", "ivier", "rick", "pard"],
		"ls": ["Beau", "Mont", "Roche", "Val", "Lac", "Pont", "Clair", "Saint", "Du", "Fon", "Ler", "Mar", "Bel", "Chev"],
		"le": ["rivage", "clair", "blanc", "mont", "ourt", "rieux", "fontaine", "pré", "champ", "tier", "nier", "oux", "mond", "ault"],
	},
	"nl": {
		"fs": ["Ja", "Ste", "Ma", "Ru", "Ti", "Bas", "Lu", "Wou", "Ni", "Da", "Gi", "Ko", "Ev", "Mi"],
		"fe": ["ap", "ijn", "ttijs", "ben", "men", "tiaan", "uk", "ter", "ek", "an", "js", "enraad", "ert", "ces"],
		"ls": ["Van", "De", "Dijk", "Mol", "Veld", "Brink", "Linde", "Water", "Haven", "Zee", "Kamp", "Bos", "Hoek", "Smit"],
		"le": ["hoven", "kamp", "veen", "stad", "dorp", "rust", "man", "aar", "berg", "ink", "sma", "huis", "dal", "burg"],
	},
	"tr": {
		"fs": ["Em", "Ka", "Mu", "Ba", "Ser", "Tu", "Yi", "Os", "Ce", "Al", "Ber", "Ha", "Il", "Ke"],
		"fe": ["re", "an", "rat", "ris", "can", "ncay", "ğit", "man", "m", "p", "kay", "kan", "ker", "mal"],
		"ls": ["Kara", "Yeşil", "Altın", "Deniz", "Mavi", "Taş", "Güneş", "Kır", "Demir", "Ak", "Bay", "Çel", "Tun", "Er"],
		"le": ["oğlu", "dağ", "ova", "köy", "liman", "tepe", "kent", "ay", "han", "soy", "turk", "bulut", "gül", "yıldız"],
	},
	"jp": {
		"fs": ["Ha", "Ke", "Ry", "Sh", "Ta", "Yu", "Ko", "Na", "Ts", "Ai", "So", "Mi", "Dai", "Ren"],
		"fe": ["ruto", "nta", "uto", "ota", "kumi", "ki", "suke", "oki", "ubasa", "chi", "ra", "sato", "ki", "ji"],
		"ls": ["Asa", "Kita", "Shira", "Mina", "Aoki", "Fuji", "Saku", "Tsuki", "Naka", "Yama", "Hara", "Mori", "Take", "Oka"],
		"le": ["hara", "mori", "kawa", "toyama", "ta", "moto", "oka", "yama", "zawa", "shima", "da", "mura", "noue", "saki"],
	},
}

static func flavor(league: int) -> String:
	return FLAVOR_BY_LEAGUE[clampi(league, 0, FLAVOR_BY_LEAGUE.size() - 1)]

static func _pick(rng: RandomNumberGenerator, a: Array) -> String:
	return str(a[rng.randi() % a.size()])

## Retorna {"full": "Nome Sobrenome", "short": "N. Sobrenome"}
static func make(league: int, rng: RandomNumberGenerator) -> Dictionary:
	var t: Dictionary = T[flavor(league)]
	var first: String = _pick(rng, t.fs) + _pick(rng, t.fe)
	var last: String = _pick(rng, t.ls) + _pick(rng, t.le)
	first = first.substr(0, 1).to_upper() + first.substr(1)
	last = last.substr(0, 1).to_upper() + last.substr(1)
	return {"full": "%s %s" % [first, last], "short": "%s. %s" % [first.substr(0, 1), last]}
