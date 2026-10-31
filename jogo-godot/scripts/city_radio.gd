extends RefCounted
## Rádio do carro (estações fictícias, só texto) e geração procedural da buzina.

const STATIONS := [
	{"name": "Maré FM", "freq": "98.1", "tag": "Pop da Orla", "lines": [
		"Locutora: \"Bom dia, Porto! Abrindo a manhã com o hit do verão.\"",
		"♪ (batida solar com sintetizador de praia) ♪",
		"Locutor: \"Pedido do ouvinte Beto: dedicar essa pra quem está preso no semáforo.\"",
		"Locutora: \"São {time}, o céu está assim: {weather}.\"",
		"♪ (refrão assobiável, palmas ao fundo) ♪",
		"Locutor: \"Ligue e concorra a um ano de pastel grátis no mercado da orla!\"",
	]},
	{"name": "Onda Norte", "freq": "101.5", "tag": "Notícias e Trânsito", "lines": [
		"Repórter: \"Trânsito fluindo bem no Centro. Atenção aos semáforos da Av. da Praia.\"",
		"Repórter: \"A Guarda Municipal reforça a fiscalização de velocidade: limite de 65 km/h.\"",
		"Âncora: \"Tempo agora: {weather}. Dirija com cuidado.\"",
		"Âncora: \"Prefeitura anuncia nova ciclovia ligando o Subúrbio à Zona de Lojas.\"",
		"Repórter: \"Banco Orla mantém rendimento da poupança. Veja condições na agência.\"",
		"Âncora: \"Você ouve a Onda Norte, {time} em ponto.\"",
	]},
	{"name": "Gol de Placa AM", "freq": "89.9", "tag": "Esportes", "lines": [
		"Comentarista: \"A {league} está pegando fogo, e o {club} aparece em {pos}º lugar.\"",
		"Narrador: \"Rodada {round} na agenda! Quem leva os três pontos?\"",
		"Comentarista: \"Dizem que o camisa 10 do {club} anda treinando forte pela cidade.\"",
		"Narrador: \"Resenha esportiva: o clássico do bairro lota o estádio de novo.\"",
		"Comentarista: \"Tempo para o jogo: {weather}. Bola rolando!\"",
	]},
	{"name": "Lofi do Porto", "freq": "104.3", "tag": "Música ambiente", "lines": [
		"♪ (piano suave, chuva distante) ♪",
		"♪ (baixo macio, vinil rodando) ♪",
		"♪ (violão calmo e vibrafone) ♪",
		"Voz suave: \"Respire fundo. A estrada é longa, mas você não tem pressa.\"",
		"♪ (sintetizador sonhador) ♪",
	]},
]

var idx := -1           # -1 = desligado
var line_i := 0
var timer := 0.0

func is_on() -> bool:
	return idx >= 0

func next() -> void:
	idx += 1
	if idx >= STATIONS.size():
		idx = -1
	line_i = 0
	timer = 0.0

func set_index(i: int) -> void:
	idx = clampi(i, -1, STATIONS.size() - 1)

func update(delta: float) -> void:
	if idx < 0:
		return
	timer += delta
	if timer > 11.0:
		timer = 0.0
		var lines: Array = STATIONS[idx].lines
		line_i = (line_i + 1) % lines.size()

func title() -> String:
	if idx < 0:
		return "Rádio desligada (R)"
	var st: Dictionary = STATIONS[idx]
	return "%s %s · %s" % [st.name, st.freq, st.tag]

func current_text(weather_text: String) -> String:
	if idx < 0:
		return ""
	var lines: Array = STATIONS[idx].lines
	var s: String = lines[line_i % lines.size()]
	var g := GameState
	s = s.replace("{time}", g.time_text()).replace("{weather}", weather_text.to_lower())
	s = s.replace("{club}", g.club_name).replace("{league}", str(g.league().name))
	s = s.replace("{pos}", str(g.position())).replace("{round}", str(g.round_no + 1))
	return s

## Gera um beep curto (duas notas) como AudioStreamWAV.
static func make_horn(freq: float = 420.0, dur: float = 0.32) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for k in n:
		var t := float(k) / float(rate)
		var env := minf(1.0, t * 40.0) * minf(1.0, (dur - t) * 25.0)
		var v := (sin(TAU * freq * t) * 0.5 + sin(TAU * freq * 1.26 * t) * 0.35 + sin(TAU * freq * 2.0 * t) * 0.1) * env * 0.55
		data.encode_s16(k * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
