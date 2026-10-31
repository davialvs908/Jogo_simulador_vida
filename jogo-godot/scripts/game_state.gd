extends Node
## Estado global: carreira (elenco, contrato, temporada, copa), economia e vida (Maya).
## Toda a lógica pesada está em scripts/career_*.gd (helpers estáticos que recebem este nó).

const CareerSquad = preload("res://scripts/career_squad.gd")
const CareerCup = preload("res://scripts/career_cup.gd")
const CareerContract = preload("res://scripts/career_contract.gd")
const CareerLife = preload("res://scripts/career_life.gd")

const SAVE_PATH := "user://jogo_save.json"
const SAVE_VERSION := 2
const ROUNDS := 14

const HOUSES := [
	{"id": 0, "name": "Quarto alugado", "price": 0, "rent": 40, "energy": 60, "desc": "Cama simples. Recupera pouca energia."},
	{"id": 1, "name": "Apartamento", "price": 1800, "rent": 0, "energy": 85, "desc": "Sala, cozinha e quarto. Bom descanso."},
	{"id": 2, "name": "Casa com quintal", "price": 6500, "rent": 0, "energy": 100, "desc": "Espaço para a namorada morar com você."},
	{"id": 3, "name": "Mansão com piscina", "price": 22000, "rent": 0, "energy": 100, "desc": "Fama máxima. Descanso total."},
]
const CARS := [
	{"id": "hatch", "name": "Street Hatch", "price": 500, "speed": 16.0, "color": Color(0.12, 0.35, 0.28)},
	{"id": "sedan", "name": "Sedan Executivo", "price": 2400, "speed": 20.0, "color": Color(0.15, 0.15, 0.2)},
	{"id": "sport", "name": "Esportivo GT", "price": 9000, "speed": 27.0, "color": Color(0.75, 0.1, 0.1)},
	{"id": "super", "name": "Supercarro X", "price": 30000, "speed": 34.0, "color": Color(0.95, 0.8, 0.1)},
]
const GIFTS := [
	{"id": "flowers", "name": "Flores", "price": 40, "bond": 6},
	{"id": "dress", "name": "Vestido", "price": 220, "bond": 14},
	{"id": "jewel", "name": "Joia", "price": 900, "bond": 30},
]
const CLOTHES := [
	{"id": 0, "name": "Roupa básica", "price": 0, "fame": 0},
	{"id": 1, "name": "Streetwear", "price": 300, "fame": 5},
	{"id": 2, "name": "Terno de grife", "price": 1500, "fame": 15},
]
# chaves de treino/atributo (as 3 primeiras são as antigas e continuam válidas)
const STAT_NAMES := {"pace": "Velocidade", "shoot": "Chute", "pass": "Passe",
	"dribble": "Drible", "defense": "Defesa", "physical": "Físico"}

# aparência (o hub/humanoid_builder pode ler estes arrays)
const LOOK_SKIN_NAMES := ["Clara", "Morena clara", "Parda", "Morena escura", "Negra"]
const LOOK_SKINS := [Color(0.96, 0.80, 0.69), Color(0.87, 0.69, 0.52), Color(0.74, 0.55, 0.38), Color(0.55, 0.38, 0.26), Color(0.36, 0.24, 0.17)]
const LOOK_HAIR_NAMES := ["Curto", "Raspado", "Médio", "Longo", "Coque", "Black power"]
const LOOK_HAIR_COLOR_NAMES := ["Preto", "Castanho", "Loiro", "Ruivo", "Grisalho", "Azul tingido"]
const LOOK_HAIR_COLORS := [Color(0.06, 0.05, 0.05), Color(0.30, 0.18, 0.09), Color(0.85, 0.72, 0.38), Color(0.62, 0.25, 0.10), Color(0.70, 0.70, 0.72), Color(0.15, 0.35, 0.85)]

# ---------------------------------------------------------------- estado (tudo isto é salvo)

var player_name := "Alex Rivera"
var club_name := "Harbor FC"
var money := 250
var day := 1
var hour := 9.0
var energy := 100.0
var fame := 0
var pace := 1            # níveis 1..10 derivados dos atributos (compatibilidade com match.gd)
var shoot := 1
var pass_skill := 1
var house_id := 0
var owned_cars: Array = []
var current_car := ""
var clothes_id := 0
var bond := 20
var gf_status := "none"      # none / dating / girlfriend
var gf_lives_with := false
var last_date_day := 0
var gifts := {}
var matches_played := 0
var wins := 0
var last_home := 0
var last_away := 0
var last_payout := 0
var tutorial_done := false

# Liga / temporada
var league_id := 0
var club_idx := 0
var season := 1
var round_no := 0
var table: Array = []     # por clube: [pontos, gols pró, gols contra, jogos, vitórias]
var last_opponent := ""

# Jogador
var player_pos := "ATA"
var age := 18
var potential := 85
var attrs := {"pace": 58, "shoot": 58, "pass": 50, "dribble": 58, "defense": 44, "physical": 50}
var look_skin := 1
var look_hair := 0
var look_hair_color := 0
var retired := false
var peak_ovr := 0

# Estatísticas
var career_goals := 0
var career_assists := 0
var career_apps := 0
var career_rating_sum := 0.0
var season_goals := 0
var season_assists := 0
var season_apps := 0
var season_rating_sum := 0.0
var form: Array = []              # últimas notas
var last_match := {}
var match_stats_open := false
var last_fixture_text := ""
var last_season_report := ""
var scorers := {}                 # "clube_slot" -> [gols, assistências] (IA, liga atual)
var trophies: Array = []
var history: Array = []
var transfers_log: Array = []

# Saúde
var injury_days := 0
var injury_name := ""
var injuries_total := 0

# Contrato
var contract_weekly := 0
var contract_years := 0           # temporadas restantes (incluindo a atual)
var contract_clause := 0
var contract_expired := false
var renew_tried_season := 0
var offers: Array = []

# Imprensa / avisos
var press := 0                    # -100..100
var news: Array = []
var notifications: Array = []
var last_interview_day := -10

# Finanças
var debt := 0
var sponsors: Array = []
var investments := {}
var bills_paid_total := 0
var last_weekly_text := ""
var last_bills_text := ""

# Maya
var maya_married := false
var marriage_day := 0
var children := 0
var pregnancy_due := 0
var maya_event := {}
var maya_reconcile_day := 0
var maya_last_fight_day := -10

# Copa
var cup_teams: Array = []
var cup_stage := 0
var cup_alive := true
var cup_champion := -1
var cup_log: Array = []
var cup_result := ""              # resultado do usuário na copa desta temporada

const PERSIST := [
	"player_name", "club_name", "money", "day", "hour", "energy", "fame", "house_id", "owned_cars", "current_car",
	"clothes_id", "bond", "gf_status", "gf_lives_with", "last_date_day", "gifts", "matches_played", "wins",
	"last_home", "last_away", "last_payout", "tutorial_done", "league_id", "club_idx", "season", "round_no", "table",
	"last_opponent",
	"player_pos", "age", "potential", "attrs", "look_skin", "look_hair", "look_hair_color", "retired", "peak_ovr",
	"career_goals", "career_assists", "career_apps", "career_rating_sum", "season_goals", "season_assists",
	"season_apps", "season_rating_sum", "form", "last_match", "match_stats_open", "last_fixture_text",
	"last_season_report", "scorers", "trophies", "history", "transfers_log",
	"injury_days", "injury_name", "injuries_total",
	"contract_weekly", "contract_years", "contract_clause", "contract_expired", "renew_tried_season", "offers",
	"press", "news", "notifications", "last_interview_day",
	"debt", "sponsors", "investments", "bills_paid_total", "last_weekly_text", "last_bills_text",
	"maya_married", "marriage_day", "children", "pregnancy_due", "maya_event", "maya_reconcile_day", "maya_last_fight_day",
	"cup_teams", "cup_stage", "cup_alive", "cup_champion", "cup_log", "cup_result",
]
# campos que pertencem só à carreira esportiva (zerados em start_career)
const CAREER_FIELDS := [
	"player_pos", "age", "potential", "attrs", "retired", "peak_ovr", "career_goals", "career_assists", "career_apps",
	"career_rating_sum", "season_goals", "season_assists", "season_apps", "season_rating_sum", "form", "last_match",
	"match_stats_open", "last_fixture_text", "last_season_report", "scorers", "trophies", "history", "transfers_log",
	"injury_days", "injury_name", "injuries_total", "contract_weekly", "contract_years", "contract_clause",
	"contract_expired", "renew_tried_season", "offers", "cup_teams", "cup_stage", "cup_alive", "cup_champion", "cup_log", "cup_result",
	"season", "round_no", "table",
]

var _defaults := {}
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()
	for n in PERSIST:
		var v: Variant = get(n)
		_defaults[n] = v.duplicate(true) if (typeof(v) == TYPE_ARRAY or typeof(v) == TYPE_DICTIONARY) else v

func _ready() -> void:
	load_game()

func rng_int(a: int, b: int) -> int:
	return rng.randi_range(a, b)

func rng_float(a: float, b: float) -> float:
	return rng.randf_range(a, b)

# ---------------------------------------------------------------- dados básicos

func house() -> Dictionary:
	return HOUSES[clampi(house_id, 0, HOUSES.size() - 1)]

func car_data(id: String) -> Dictionary:
	for c in CARS:
		if c.id == id:
			return c
	return {}

func has_car() -> bool:
	return owned_cars.size() > 0

func car_name() -> String:
	return str(car_data(current_car).get("name", ""))

func league() -> Dictionary:
	return Leagues.DATA[clampi(league_id, 0, Leagues.count() - 1)]

func has_save() -> bool:
	return tutorial_done

func skin_color() -> Color:
	return LOOK_SKINS[clampi(look_skin, 0, LOOK_SKINS.size() - 1)]

func hair_color() -> Color:
	return LOOK_HAIR_COLORS[clampi(look_hair_color, 0, LOOK_HAIR_COLORS.size() - 1)]

# ---------------------------------------------------------------- jogador

func overall() -> int:
	return CareerSquad.overall(player_pos, attrs)

func _level(v: int) -> int:
	return clampi(1 + int((v - 40) / 6.0), 1, 10)

func _sync_legacy() -> void:
	pace = _level(int(attrs.get("pace", 40)))
	shoot = _level(int(attrs.get("shoot", 40)))
	pass_skill = _level(int(attrs.get("pass", 40)))
	peak_ovr = maxi(peak_ovr, overall())

func attr_cap(key: String) -> int:
	var cap := potential
	if age >= 31 and (key == "pace" or key == "physical"):
		cap -= (age - 30) * 3
	return clampi(cap, 40, 99)

## Prévia determinística dos atributos iniciais (usada por club.gd e por start_career).
func preview_player(pos: String, pname: String) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash("player_%s_%s" % [pname, pos])
	var a: Dictionary = CareerSquad.starting_attrs(pos, r, 50)
	var pot := r.randi_range(76, 92)
	return {"attrs": a, "ovr": CareerSquad.overall(pos, a), "potential": pot}

func attrs_text() -> String:
	var s := "%s · %s · %d anos · Overall %d (potencial %d)\n" % [player_name, CareerSquad.POS_NAMES.get(player_pos, player_pos), age, overall(), potential]
	var parts: Array = []
	for k in CareerSquad.ATTR_KEYS:
		parts.append("%s %d/%d" % [CareerSquad.ATTR_NAMES[k], int(attrs.get(k, 40)), attr_cap(k)])
	return s + " · ".join(PackedStringArray(parts))

func train(stat: String) -> String:
	if retired:
		return "Você está aposentado."
	if not STAT_NAMES.has(stat):
		return "Treino desconhecido."
	if injury_days > 3:
		return "Você está lesionado (%s, %d dias). Faça fisioterapia." % [injury_name, injury_days]
	if energy < 25.0:
		return "Você está cansado demais. Descanse primeiro."
	var cur: int = int(attrs.get(stat, 40))
	var cap := attr_cap(stat)
	if cur >= cap:
		return "%s já está no limite do seu potencial (%d). Jogue bem e evolua." % [STAT_NAMES[stat], cap]
	if not spend(60):
		return "Sem dinheiro ($60)."
	var gain := 3 if cur < 70 else (2 if cur < 85 else 1)
	if age >= 30:
		gain = maxi(1, gain - 1)
	gain = mini(gain, cap - cur)
	var lv_before := _level(cur)
	attrs[stat] = cur + gain
	_sync_legacy()
	energy -= 20.0
	add_time(2.0)
	save_game()
	var extra := ""
	if _level(cur + gain) > lv_before:
		extra = " (nível %d)" % _level(cur + gain)
	return "%s subiu para %d%s! Overall %d." % [STAT_NAMES[stat], cur + gain, extra, overall()]

func energy_factor() -> float:
	return lerpf(0.7, 1.0, clampf(energy / 100.0, 0.0, 1.0))

func mood_factor() -> float:
	return 1.03 if (gf_status == "girlfriend" and bond >= 60) else 1.0

func injury_factor() -> float:
	return 0.88 if injury_days > 0 else 1.0

func speed_multiplier() -> float:
	return (1.0 + (pace - 1) * 0.035) * energy_factor() * mood_factor() * injury_factor()

func can_play() -> bool:
	return not retired

func season_avg_rating() -> float:
	return season_rating_sum / float(season_apps) if season_apps > 0 else 6.5

func career_avg_rating() -> float:
	return career_rating_sum / float(career_apps) if career_apps > 0 else 0.0

func add_fame(n: int) -> void:
	fame = maxi(0, fame + n)

# ---------------------------------------------------------------- imprensa / avisos

func add_news(text: String, press_delta := 0) -> void:
	news.append("D%d · %s" % [day, text])
	while news.size() > 12:
		news.pop_front()
	press = clampi(press + press_delta, -100, 100)
	if press_delta >= 5:
		add_fame(1)

func notify(text: String) -> void:
	notifications.append(text)
	while notifications.size() > 30:
		notifications.pop_front()

## Devolve e limpa as notificações pendentes (o hub pode exibir como toast).
func pop_notifications() -> Array:
	var out := notifications.duplicate()
	notifications.clear()
	return out

func press_label() -> String:
	if press >= 50: return "Queridinho da mídia"
	if press >= 20: return "Boa imagem"
	if press > -20: return "Neutra"
	if press > -50: return "Imagem arranhada"
	return "Vilão da imprensa"

func press_text() -> String:
	var s := "Imprensa: %s (%d)\n" % [press_label(), press]
	if news.is_empty():
		return s + "Sem manchetes ainda."
	var recent: Array = news.duplicate()
	recent.reverse()
	return s + "\n".join(PackedStringArray(recent.slice(0, 6)))

func give_interview() -> String:
	if retired:
		return "Ninguém procura entrevistas com ex-atletas aposentados... por enquanto."
	if day - last_interview_day < 3:
		return "Você já deu entrevista há pouco. A assessoria pede para esperar."
	last_interview_day = day
	var chance := clampf(0.55 + float(overall() - 60) * 0.005 + season_avg_rating() * 0.0 + (0.1 if form_avg() >= 7.0 else 0.0), 0.3, 0.85)
	if randf() < chance:
		add_news("%s fala bem em entrevista e cai nas graças da torcida" % player_name, 4)
		add_fame(1)
		return "Boa entrevista! Imprensa +4, fama +1."
	add_news("%s dá declaração polêmica após o treino" % player_name, -5)
	return "Você falou demais e a declaração virou polêmica. Imprensa -5."

func charity(amount := 300) -> String:
	if retired:
		return "Você está aposentado."
	if not spend(amount):
		return "Sem dinheiro ($%d)." % amount
	add_news("%s faz ação social e doa $%d" % [player_name, amount], 8)
	add_fame(1)
	return "Ação social realizada (-$%d). Imprensa +8, fama +1." % amount

func form_avg() -> float:
	if form.is_empty():
		return 0.0
	var s := 0.0
	for r in form:
		s += float(r)
	return s / float(form.size())

# ---------------------------------------------------------------- saúde

func injury_text() -> String:
	if injury_days <= 0:
		return "Saudável."
	return "Lesão: %s — faltam %d dia(s) (velocidade reduzida)." % [injury_name, injury_days]

func physio() -> String:
	if not spend(120):
		return "Fisioterapia custa $120."
	add_time(1.0)
	if injury_days > 0:
		injury_days = maxi(0, injury_days - 2)
		save_game()
		if injury_days == 0:
			return "Fisioterapia concluída: você está liberado!"
		return "Fisioterapia ajudou: faltam %d dia(s) de recuperação." % injury_days
	energy = minf(100.0, energy + 10.0)
	save_game()
	return "Sessão preventiva: energia +10."

func _roll_injury() -> void:
	if injury_days > 0:
		return
	var p := 0.035 + (1.0 - clampf(energy / 100.0, 0.0, 1.0)) * 0.05
	if int(attrs.get("physical", 50)) < 55:
		p += 0.015
	if randf() >= p:
		return
	var r := randf()
	var days := 0
	if r < 0.6:
		injury_name = "Entorse leve"
		days = rng_int(2, 4)
	elif r < 0.9:
		injury_name = "Estiramento muscular"
		days = rng_int(5, 9)
	else:
		injury_name = "Lesão no joelho"
		days = rng_int(14, 24)
	if age >= 32:
		days = int(days * 1.3)
	injury_days = days
	injuries_total += 1
	add_news("%s se lesiona: %s (%d dias)" % [player_name, injury_name, days], -1)
	notify("Lesão: %s, %d dias fora. Use a fisioterapia." % [injury_name, days])

# ---------------------------------------------------------------- liga / temporada

func start_career(lg: int, club: int, pos := "", look := {}, pname := "") -> void:
	for n in CAREER_FIELDS:
		var dv: Variant = _defaults[n]
		set(n, dv.duplicate(true) if (typeof(dv) == TYPE_ARRAY or typeof(dv) == TYPE_DICTIONARY) else dv)
	if pname != "":
		player_name = pname
	if pos != "" and CareerSquad.POSITIONS.has(pos):
		player_pos = pos
	look_skin = int(look.get("skin", look_skin))
	look_hair = int(look.get("hair", look_hair))
	look_hair_color = int(look.get("hair_color", look_hair_color))
	var pv := preview_player(player_pos, player_name)
	attrs = pv.attrs
	potential = int(pv.potential)
	age = 18
	league_id = lg
	club_idx = club
	club_name = Leagues.club_name(lg, club)
	season = 1
	round_no = 0
	reset_table()
	CareerCup.init_cup(self)
	_sync_legacy()
	var c: Dictionary = CareerContract.make_contract(self, lg, club, 3, 0.8)
	CareerContract.apply_contract(self, c)
	tutorial_done = true
	add_news("%s assina o primeiro contrato profissional com o %s" % [player_name, club_name], 2)
	save_game()

func reset_table() -> void:
	table = []
	for i in 8:
		table.append([0, 0, 0, 0, 0])

func _ensure_table() -> void:
	if table.size() != 8:
		reset_table()

func cup_pending() -> bool:
	return not retired and CareerCup.pending(self)

func opponent_idx() -> int:
	if cup_pending():
		return CareerCup.opponent(self)
	var sched := Leagues.schedule()
	var rp: Array = sched[mini(round_no, sched.size() - 1)]
	for pr in rp:
		if pr[0] == club_idx:
			return pr[1]
		if pr[1] == club_idx:
			return pr[0]
	return (club_idx + 1) % 8

func opponent_name() -> String:
	return Leagues.club_name(league_id, opponent_idx())

## Descrição da próxima partida (campeonato ou copa) para a UI.
func next_fixture_text() -> String:
	if retired:
		return "Aposentado."
	if season_over():
		return "Temporada encerrada: feche o balanço no estádio."
	if cup_pending():
		return "COPA — %s contra %s" % [CareerCup.stage_name(self), opponent_name()]
	return "Campeonato — rodada %d/%d contra %s" % [round_no + 1, ROUNDS, opponent_name()]

func season_over() -> bool:
	return round_no >= ROUNDS and not cup_pending()

func _apply(a: int, b: int, ga: int, gb: int) -> void:
	table[a][1] += ga; table[a][2] += gb; table[a][3] += 1
	table[b][1] += gb; table[b][2] += ga; table[b][3] += 1
	if ga > gb:
		table[a][0] += 3; table[a][4] += 1
	elif ga < gb:
		table[b][0] += 3; table[b][4] += 1
	else:
		table[a][0] += 1; table[b][0] += 1

func _sim_goals(strength: int, opp: int) -> int:
	var lam := 1.3 + (strength - opp) * 0.04
	lam = clampf(lam, 0.3, 3.2)
	var g := 0
	var l := exp(-lam)
	var p := 1.0
	while true:
		p *= randf()
		if p <= l:
			break
		g += 1
		if g > 7:
			break
	return g

## Distribui gols/assistências de um clube da IA entre os jogadores do elenco.
func _credit_team(club: int, goals: int) -> void:
	if goals <= 0:
		return
	var sq: Array = CareerSquad.squad(league_id, club, season)
	for i in goals:
		var gi: int = CareerSquad.weighted_pick(sq, false)
		var ks := "%d_%d" % [club, int(sq[gi].slot)]
		var arr: Array = scorers.get(ks, [0, 0])
		arr[0] = int(arr[0]) + 1
		scorers[ks] = arr
		if randf() < 0.7:
			var ai: int = CareerSquad.weighted_pick(sq, true, int(sq[gi].slot))
			var ka := "%d_%d" % [club, int(sq[ai].slot)]
			var arr2: Array = scorers.get(ka, [0, 0])
			arr2[1] = int(arr2[1]) + 1
			scorers[ka] = arr2

func _ai_round_pair(a: int, b: int) -> void:
	var sa := Leagues.club_strength(league_id, a) + 2
	var sb := Leagues.club_strength(league_id, b)
	var ga := _sim_goals(sa, sb)
	var gb := _sim_goals(sb, sa)
	_apply(a, b, ga, gb)
	_credit_team(a, ga)
	_credit_team(b, gb)

## Registra o resultado do jogador (ele joga como "casa" no 3D) e simula o resto da rodada.
## Se houver jogo de copa pendente, o resultado vale para a copa (a rodada de liga não avança).
## Também aplica notas, evolução, lesão e imprensa. Chame add_match_stats() DEPOIS para corrigir gols/assistências/nota.
func record_league_round(player_goals: int, opp_goals: int) -> void:
	_ensure_table()
	CareerCup.ensure(self)
	if season_over():
		return
	if retired:
		_record_retired_round()
		return
	if round_no >= 1 and not offers.is_empty():
		offers.clear()
	if round_no >= 1 and contract_expired:
		_auto_extend()
	if CareerCup.pending(self):
		var opp_c := CareerCup.opponent(self)
		last_opponent = Leagues.club_name(league_id, opp_c)
		var res: Dictionary = CareerCup.play_user(self, player_goals, opp_goals)
		last_fixture_text = str(res.text)
		_post_match("cup", player_goals, opp_goals, opp_c)
		if bool(res.champion):
			add_news("%s é campeão da copa com o %s!" % [player_name, club_name], 8)
			add_fame(5)
		notify(last_fixture_text)
		return
	var sched := Leagues.schedule()
	var opp := opponent_idx()
	last_opponent = Leagues.club_name(league_id, opp)
	_apply(club_idx, opp, player_goals, opp_goals)
	_credit_team(opp, opp_goals)
	var rd := round_no
	for pr in sched[rd]:
		if pr[0] == club_idx or pr[1] == club_idx:
			continue
		_ai_round_pair(pr[0], pr[1])
	round_no += 1
	last_fixture_text = "Rodada %d: %s %d x %d %s" % [rd + 1, club_name, player_goals, opp_goals, last_opponent]
	CareerCup.sync(self)
	_post_match("league", player_goals, opp_goals, opp)

func _record_retired_round() -> void:
	cup_alive = false
	var sched := Leagues.schedule()
	for pr in sched[round_no]:
		_ai_round_pair(pr[0], pr[1])
	round_no += 1
	CareerCup.sync(self)

func _auto_extend() -> void:
	contract_expired = false
	contract_weekly = int(float(contract_weekly) * 0.9 / 5.0) * 5
	contract_years = 1
	contract_clause = contract_weekly * 50
	notify("Sem outro acordo, o %s renovou por 1 temporada com salário reduzido ($%d/sem)." % [club_name, contract_weekly])

func _post_match(kind: String, pg: int, og: int, opp: int) -> void:
	var win := pg > og
	var loss := pg < og
	var ovr := overall()
	var f := pow(float(ovr) / 70.0, 2.0)
	var gsh := clampf(float(CareerSquad.GOAL_W.get(player_pos, 0.0)) * f / 26.0, 0.0, 0.5)
	var ash := clampf(float(CareerSquad.ASSIST_W.get(player_pos, 0.0)) * f / 22.0, 0.0, 0.5)
	var g := 0
	var a := 0
	for i in pg:
		if randf() < gsh:
			g += 1
		elif randf() < ash:
			a += 1
	if kind == "league":
		_credit_team(club_idx, pg - g)
	var opp_str := Leagues.club_strength(league_id, opp)
	var rt := 6.2 + (0.5 if win else (-0.4 if loss else 0.0)) + float(g) * 0.8 + float(a) * 0.5
	rt += float(ovr - opp_str) * 0.012 + rng.randfn(0.0, 0.45)
	if og == 0 and (player_pos == "GOL" or player_pos == "ZAG" or player_pos == "LAT" or player_pos == "VOL"):
		rt += 0.9 if player_pos == "GOL" else 0.6
	if energy < 25.0:
		rt -= 0.4
	if injury_days > 0:
		rt -= 0.6
	rt = snappedf(clampf(rt, 3.5, 10.0), 0.1)
	_register_match(kind, g, a, rt, pg, og, opp, true)
	_match_growth(rt)
	_roll_injury()
	if rt >= 8.5 or g >= 3:
		add_news("%s brilha contra %s: nota %.1f%s" % [player_name, last_opponent, rt, (" e %d gols" % g) if g >= 2 else ""], 3)
		add_fame(2 if g >= 3 else 1)
	elif rt <= 4.8:
		add_news("%s decepciona contra %s (nota %.1f)" % [player_name, last_opponent, rt], -3)

func _register_match(kind: String, g: int, a: int, rt: float, pg: int, og: int, opp: int, auto: bool) -> void:
	season_apps += 1
	career_apps += 1
	season_goals += g
	career_goals += g
	season_assists += a
	career_assists += a
	season_rating_sum += rt
	career_rating_sum += rt
	form.append(rt)
	while form.size() > 5:
		form.pop_front()
	match_stats_open = auto
	last_match = {"kind": kind, "goals": g, "assists": a, "rating": rt, "pg": pg, "og": og,
		"opp": Leagues.club_name(league_id, opp), "auto": auto, "day": day}

## O agente da partida chama DEPOIS de record_league_round() com os números reais do jogador.
## Substitui a estimativa automática daquela partida (gols limitados ao placar do time).
func add_match_stats(goals: int, assists: int, rating: float) -> String:
	if last_match.is_empty() or not match_stats_open:
		return "Nenhuma partida aguardando estatísticas."
	var g := clampi(goals, 0, int(last_match.get("pg", goals)))
	var a := clampi(assists, 0, maxi(0, int(last_match.get("pg", assists)) - g))
	var rt := snappedf(clampf(rating, 1.0, 10.0), 0.1)
	season_goals += g - int(last_match.goals)
	career_goals += g - int(last_match.goals)
	season_assists += a - int(last_match.assists)
	career_assists += a - int(last_match.assists)
	season_rating_sum += rt - float(last_match.rating)
	career_rating_sum += rt - float(last_match.rating)
	if form.size() > 0:
		form[form.size() - 1] = rt
	last_match["goals"] = g
	last_match["assists"] = a
	last_match["rating"] = rt
	last_match["auto"] = false
	match_stats_open = false
	if rt >= 8.5 or g >= 3:
		add_fame(1)
	return "Nota %.1f · %d gol(s) · %d assistência(s) registrados." % [rt, g, a]

func _match_growth(rt: float) -> void:
	var chance := 0.35 if rt >= 7.5 else (0.15 if rt >= 6.5 else 0.0)
	if age >= 30:
		chance *= 0.5
	if randf() >= chance:
		return
	var w: Array = CareerSquad.WEIGHTS[player_pos]
	var pool: Array = []
	for i in CareerSquad.ATTR_KEYS.size():
		if float(w[i]) >= 0.15:
			pool.append(CareerSquad.ATTR_KEYS[i])
	var k: String = pool[rng_int(0, pool.size() - 1)]
	if int(attrs[k]) < attr_cap(k):
		attrs[k] = int(attrs[k]) + 1
		_sync_legacy()
		notify("Boa atuação: %s subiu para %d (overall %d)." % [STAT_NAMES[k], int(attrs[k]), overall()])

func standings() -> Array:
	_ensure_table()
	var rows: Array = []
	for i in 8:
		rows.append({"idx": i, "pts": table[i][0], "gf": table[i][1], "ga": table[i][2], "pl": table[i][3], "w": table[i][4]})
	rows.sort_custom(func (a, b):
		if a.pts != b.pts:
			return a.pts > b.pts
		var da: int = a.gf - a.ga
		var db: int = b.gf - b.ga
		if da != db:
			return da > db
		return a.gf > b.gf)
	return rows

func position() -> int:
	var rows := standings()
	for i in rows.size():
		if rows[i].idx == club_idx:
			return i + 1
	return 8

func table_text() -> String:
	var out := "#  Clube                          J  V  SG  Pts\n"
	var rows := standings()
	for i in rows.size():
		var r: Dictionary = rows[i]
		var nm: String = Leagues.club_name(league_id, r.idx)
		var mark := ">" if r.idx == club_idx else " "
		out += "%s%d %-28s %2d %2d %3d %3d\n" % [mark, i + 1, nm, r.pl, r.w, r.gf - r.ga, r.pts]
	return out

# ---------------------------------------------------------------- elenco

func _me_entry() -> Dictionary:
	return {"slot": 99, "club": club_idx, "league": league_id, "name": player_name, "short": player_name,
		"pos": player_pos, "ovr": overall(), "age": age, "num": 10, "starter": true, "user": true}

## Elenco de um clube (20 jogadores; o clube do usuário inclui o jogador dele = 21).
func club_squad(lg: int, club: int) -> Array:
	if lg == league_id and club == club_idx and not retired:
		return CareerSquad.squad_with_user(lg, club, season, _me_entry())
	return CareerSquad.squad(lg, club, season)

func squad_text(lg := -1, club := -1) -> String:
	if lg < 0:
		lg = league_id
	if club < 0:
		club = club_idx
	var sq := club_squad(lg, club)
	var out := "%s — elenco (%d jogadores, força média %.1f)\n" % [Leagues.club_name(lg, club), sq.size(), CareerSquad.average_top(sq)]
	for p in sq:
		out += "%s#%-2d %-22s %s  OVR %d  %d anos%s\n" % [">" if p.user else " ", int(p.num), p.name, p.pos, int(p.ovr), int(p.age), "  (você)" if p.user else ""]
	return out

func squad_rank() -> int:
	var sq := club_squad(league_id, club_idx)
	var ahead := 0
	for p in sq:
		if not p.user and p.pos == player_pos and int(p.ovr) > overall():
			ahead += 1
	return ahead + 1

func top_scorers(n := 5) -> Array:
	var list: Array = []
	for k in scorers.keys():
		var parts: PackedStringArray = str(k).split("_")
		var c := int(parts[0])
		var sl := int(parts[1])
		var sq: Array = CareerSquad.squad(league_id, c, season)
		var p: Dictionary = sq[sl]
		list.append({"name": p.name, "club": Leagues.club_name(league_id, c), "club_idx": c, "goals": int(scorers[k][0]),
			"assists": int(scorers[k][1]), "ovr": int(p.ovr), "user": false})
	if season_apps > 0 and not retired:
		list.append({"name": player_name, "club": club_name, "club_idx": club_idx, "goals": season_goals, "assists": season_assists,
			"ovr": overall(), "user": true})
	list.sort_custom(func (a, b):
		if a.goals != b.goals:
			return a.goals > b.goals
		if a.assists != b.assists:
			return a.assists > b.assists
		return a.ovr > b.ovr)
	return list.slice(0, n)

func top_scorers_text(n := 5) -> String:
	var l := top_scorers(n)
	if l.is_empty():
		return "Artilharia: ninguém marcou ainda."
	var out := "Artilharia da temporada %d\n" % season
	for i in l.size():
		var e: Dictionary = l[i]
		out += "%s%d. %s (%s) — %d gols, %d assist.\n" % [">" if e.user else " ", i + 1, e.name, e.club, e.goals, e.assists]
	return out

func _best_player_of_season() -> Dictionary:
	var best := {}
	var best_s := -1.0
	var pts_of := {}
	for r in standings():
		pts_of[int(r.idx)] = int(r.pts)
	for k in scorers.keys():
		var parts: PackedStringArray = str(k).split("_")
		var c := int(parts[0])
		var sq: Array = CareerSquad.squad(league_id, c, season)
		var p: Dictionary = sq[int(parts[1])]
		var s := float(scorers[k][0]) * 2.0 + float(scorers[k][1]) * 1.5 + float(int(p.ovr) - 70) * 0.15 + float(pts_of.get(c, 0)) * 0.08
		if s > best_s:
			best_s = s
			best = {"name": p.name, "club": Leagues.club_name(league_id, c), "user": false}
	if season_apps >= 8 and not retired:
		var su := float(season_goals) * 2.0 + float(season_assists) * 1.5 + (season_avg_rating() - 6.0) * 6.0 + float(overall() - 70) * 0.15 + float(pts_of.get(club_idx, 0)) * 0.08
		if su > best_s:
			best = {"name": player_name, "club": club_name, "user": true}
	return best

## Fim de temporada: bônus pela posição, prêmios, histórico, envelhecimento, contrato e propostas.
## Retorna o bônus em dinheiro (compatível com o hub atual); o texto completo fica em last_season_report.
func finish_season() -> int:
	_ensure_table()
	CareerCup.ensure(self)
	if cup_alive and cup_stage < 3:
		cup_alive = false
	var saved_round := round_no
	round_no = maxi(round_no, ROUNDS)
	CareerCup.sync(self)
	round_no = saved_round
	var pos := position()
	var bonus: int = [3000, 1800, 1000, 500, 250, 120, 60, 0][pos - 1]
	bonus = int(bonus * float(league().pay))
	if retired:
		bonus = 0
	money += bonus
	var rep: Array = []
	var lname: String = league().name
	var champ_idx: int = int(standings()[0].idx)
	rep.append("%s %d: você terminou em %dº. Campeão: %s." % [lname, season, pos, Leagues.club_name(league_id, champ_idx)])
	var cup_res := cup_result if cup_result != "" else "Não disputou"
	var won_league := (pos == 1 and not retired)
	var won_cup := (cup_champion == club_idx and not retired)
	if won_league:
		add_fame(10)
		trophies.append("Temp. %d — Campeão da %s (%s)" % [season, lname, club_name])
		add_news("%s é campeão da %s!" % [club_name, lname], 10)
	if won_cup:
		trophies.append("Temp. %d — Campeão da Copa %s (%s)" % [season, str(league().region), club_name])
	rep.append("Copa: %s (campeão: %s)." % [cup_res, Leagues.club_name(league_id, cup_champion) if cup_champion >= 0 else "?"])
	# prêmios individuais
	var aw: Array = []
	if not retired:
		var ts := top_scorers(1)
		if not ts.is_empty():
			var t0: Dictionary = ts[0]
			rep.append("Artilheiro: %s (%s) com %d gols." % [t0.name, t0.club, t0.goals])
			if t0.user and t0.goals >= 3:
				aw.append("Artilheiro da %s" % lname)
		var bp := _best_player_of_season()
		if not bp.is_empty():
			rep.append("Melhor jogador: %s (%s)." % [bp.name, bp.club])
			if bp.user:
				aw.append("Melhor jogador da %s" % lname)
		for w in aw:
			trophies.append("Temp. %d — %s" % [season, w])
			var prize := int(1200 * float(league().pay))
			money += prize
			bonus += prize
			add_fame(8)
			add_news("%s é eleito: %s" % [player_name, w], 8)
			rep.append("Prêmio individual: %s (+$%d, +8 fama)." % [w, prize])
	history.append({
		"season": season, "age": age, "league": lname, "club": club_name, "pos": pos, "ovr": overall(),
		"apps": season_apps, "goals": season_goals, "assists": season_assists,
		"rating": snappedf(season_avg_rating(), 0.01), "cup": cup_res, "awards": aw,
		"champion": won_league, "cup_champion": won_cup,
	})
	if not retired:
		_develop_season()
		age += 1
		contract_years -= 1
		rep.append("Idade %d · Overall %d (potencial %d)." % [age, overall(), potential])
		CareerLife.expire_sponsors(self)
		_check_retirement(rep)
		if contract_years <= 0 and not retired:
			contract_expired = true
			rep.append("Seu contrato EXPIROU. Escolha uma proposta antes da primeira rodada, senão o clube renova com salário menor.")
	# nova temporada
	season += 1
	round_no = 0
	season_goals = 0
	season_assists = 0
	season_apps = 0
	season_rating_sum = 0.0
	scorers = {}
	reset_table()
	CareerCup.init_cup(self)
	if retired:
		cup_alive = false
	else:
		offers = _build_offers()
		if not offers.is_empty():
			rep.append("Propostas recebidas: %d (veja offers_text())." % offers.size())
		else:
			rep.append("Nenhum clube se interessou nesta janela.")
	_sync_legacy()
	last_season_report = "\n".join(PackedStringArray(rep))
	save_game()
	return bonus

func _develop_season() -> void:
	var w: Array = CareerSquad.WEIGHTS[player_pos]
	for i in CareerSquad.ATTR_KEYS.size():
		var k: String = CareerSquad.ATTR_KEYS[i]
		var cur := int(attrs[k])
		var delta := 0
		var key_attr := float(w[i]) >= 0.2
		if age <= 23:
			delta = rng_int(1, 3) + (1 if key_attr else 0)
		elif age <= 28:
			delta = rng_int(0, 1) + (1 if (key_attr and randf() < 0.3) else 0)
		elif age <= 31:
			delta = -rng_int(0, 1) if (k == "pace" or k == "physical") else 0
		else:
			delta = -rng_int(1, 3) if (k == "pace" or k == "physical") else -rng_int(0, 1)
		if delta > 0:
			delta = mini(delta, maxi(0, attr_cap(k) - cur))
		attrs[k] = clampi(cur + delta, 30, 99)
	_sync_legacy()

func can_retire() -> bool:
	return age >= 33 and not retired

func _check_retirement(rep: Array) -> void:
	if age >= 38 or (age >= 34 and overall() < 50):
		rep.append("Seu corpo não aguenta mais: aposentadoria encerra a carreira.")
		_do_retire()
	elif age >= 33:
		rep.append("Aos %d anos você pode se aposentar quando quiser (retire_player())." % age)

func _do_retire() -> void:
	retired = true
	cup_alive = false
	offers = []
	sponsors = []
	add_news("%s anuncia a aposentadoria aos %d anos" % [player_name, age], 5)

func retire_player() -> String:
	if retired:
		return retirement_summary()
	if age < 33:
		return "Você ainda é novo demais para pendurar as chuteiras (precisa de 33+)."
	_do_retire()
	save_game()
	return retirement_summary()

func retirement_summary() -> String:
	if not retired:
		return ""
	var champs := 0
	var cups := 0
	for h in history:
		if bool(h.get("champion", false)): champs += 1
		if bool(h.get("cup_champion", false)): cups += 1
	return "APOSENTADORIA — %s\nIdade: %d · Temporadas: %d · Overall máximo: %d\nPartidas: %d · Gols: %d · Assistências: %d · Nota média: %.2f\nTítulos de liga: %d · Copas: %d · Troféus e prêmios: %d\nClubes: %s\nFama: %d · Imprensa: %s · Patrimônio em caixa: $%d" % [
		player_name, age, history.size(), peak_ovr, career_apps, career_goals, career_assists, career_avg_rating(),
		champs, cups, trophies.size(), "; ".join(PackedStringArray(_club_list())), total_fame(), press_label(), money]

func _club_list() -> Array:
	var out: Array = []
	for h in history:
		var c := str(h.club)
		if out.is_empty() or out[out.size() - 1] != c:
			out.append(c)
	if out.is_empty():
		out.append(club_name)
	return out

func salary_for(home: int, away: int) -> int:
	if retired:
		return 0
	var base := 120
	if home > away:
		base = 400
	elif home == away:
		base = 220
	return int(base * float(league().pay) * 0.5) + total_fame() * 4 + int(float(contract_weekly) * 0.15)

func total_fame() -> int:
	return fame + int(CLOTHES[clampi(clothes_id, 0, CLOTHES.size() - 1)].fame) + house_id * 5

# ---------------------------------------------------------------- contrato / transferências

func contract_text() -> String:
	if retired:
		return "Aposentado. Pensão semanal: $%d." % int(float(contract_weekly) * 0.2)
	var s := "Contrato com %s: $%d/semana + prêmio por jogo, %d temporada(s) restante(s), multa de rescisão $%d." % [
		club_name, contract_weekly, contract_years, contract_clause]
	if contract_expired:
		s += "\nEXPIRADO — escolha uma proposta antes da rodada 1."
	s += "\nChance de renovação agora: %d%%." % int(CareerContract.renewal_chance(self) * 100.0)
	return s

func try_renew_contract() -> String:
	return CareerContract.try_renew(self)

func transfer_window_open() -> bool:
	return round_no == 0 and not retired

func _build_offers() -> Array:
	var list: Array = CareerContract.generate_offers(self, 3)
	if contract_years <= 0:
		# oferta de renovação do clube atual (um pouco abaixo do mercado)
		var own: Dictionary = CareerContract.make_contract(self, league_id, club_idx, rng_int(1, 2), 0.9)
		own["club_name"] = club_name
		own["league_name"] = league().name
		own["own"] = true
		list.push_front(own)
	return list

func offers_text() -> String:
	if retired:
		return "Aposentado: sem propostas."
	if offers.is_empty():
		return "Nenhuma proposta no momento.%s" % ("" if transfer_window_open() else " (Janela fechada: só no início da temporada.)")
	var out := "Propostas%s:\n" % ("" if transfer_window_open() else " (janela fechada)")
	for i in offers.size():
		var o: Dictionary = offers[i]
		out += "[%d] %s%s\n" % [i, CareerContract.offer_line(o), " (renovação)" if bool(o.get("own", false)) else ""]
	return out

func ask_agent_offers() -> String:
	if not transfer_window_open():
		return "A janela de transferências só abre no início da temporada (antes da rodada 1)."
	if not spend(200):
		return "O empresário cobra $200 para sondar o mercado."
	var extra: Array = CareerContract.generate_offers(self, 3)
	if extra.is_empty():
		return "O empresário não achou clubes interessados (overall %d, nível de mercado %.0f)." % [overall(), CareerContract.market_level(self)]
	offers = extra
	if contract_years <= 0:
		offers.push_front(_build_offers()[0])
	return "O empresário trouxe %d proposta(s):\n%s" % [extra.size(), offers_text()]

func reject_offer(i: int) -> String:
	if i < 0 or i >= offers.size():
		return "Proposta inválida."
	offers.remove_at(i)
	return "Proposta recusada."

func accept_offer(i: int) -> String:
	if retired:
		return "Você está aposentado."
	if i < 0 or i >= offers.size():
		return "Proposta inválida."
	if not transfer_window_open():
		return "A janela de transferências está fechada."
	var o: Dictionary = offers[i]
	var lg := int(o.league)
	var cl := int(o.club)
	var bonus := int(o.bonus)
	var weekly := int(o.weekly)
	var years := int(o.years)
	var clause := int(o.clause)
	var old_club := club_name
	var own := (lg == league_id and cl == club_idx)
	var left_early := contract_years > 1 and not contract_expired and not own
	contract_weekly = weekly
	contract_years = years
	contract_clause = clause
	contract_expired = false
	money += bonus
	offers = []
	if own:
		add_news("%s renova com o %s" % [player_name, club_name], 3)
		save_game()
		return "Renovação aceita: $%d/semana por %d temporada(s). Bônus $%d." % [weekly, years, bonus]
	if lg != league_id and gf_lives_with:
		bond = maxi(0, bond - 6)
	var new_name: String = Leagues.club_name(lg, cl)
	var lg_changed := lg != league_id
	league_id = lg
	club_idx = cl
	club_name = new_name
	round_no = 0
	reset_table()
	scorers = {}
	CareerCup.init_cup(self)
	transfers_log.append("Temp. %d: %s -> %s" % [season, old_club, new_name])
	add_news("%s deixa o %s e assina com o %s%s" % [player_name, old_club, new_name, " (%s)" % str(league().name) if lg_changed else ""], 3 if not left_early else -3)
	add_fame(2 if lg_changed else 1)
	save_game()
	return "Transferido para %s (%s)! $%d/semana, %d temporada(s), multa $%d. Bônus de assinatura $%d.%s" % [
		new_name, league().name, weekly, years, clause, bonus, " Maya sente a mudança (vínculo -6)." if (lg_changed and gf_lives_with) else ""]

# ---------------------------------------------------------------- relatórios para a UI

func stats_text() -> String:
	return "Temporada %d: %d jogos · %d gols · %d assist. · nota média %.2f\nCarreira: %d jogos · %d gols · %d assist. · nota média %.2f\nForma (últimas notas): %s" % [
		season, season_apps, season_goals, season_assists, season_avg_rating(), career_apps, career_goals, career_assists,
		career_avg_rating(), ", ".join(PackedStringArray(form.map(func (x): return "%.1f" % float(x)))) if not form.is_empty() else "—"]

func trophies_text() -> String:
	if trophies.is_empty():
		return "Sala de troféus vazia. Ainda."
	return "\n".join(PackedStringArray(trophies))

func history_text() -> String:
	if history.is_empty():
		return "Nenhuma temporada concluída."
	var out := ""
	for h in history:
		out += "Temp %d (%d anos) %s · %s: %dº lugar · %d jogos, %d gols, %d assist., nota %.2f · OVR %d · Copa: %s%s\n" % [
			int(h.season), int(h.age), h.club, h.league, int(h.pos), int(h.apps), int(h.goals), int(h.assists), float(h.rating), int(h.ovr),
			h.cup, (" · " + ", ".join(PackedStringArray(h.awards))) if not h.awards.is_empty() else ""]
	return out

func cup_text() -> String:
	return CareerCup.status_text(self) + "\n" + CareerCup.log_text(self)

func finance_text() -> String:
	return CareerLife.finance_text(self)

func sponsors_text() -> String:
	return CareerLife.sponsors_text(self)

func sign_sponsor(id: String) -> String:
	return CareerLife.sign_sponsor(self, id)

func drop_sponsor(id: String) -> String:
	return CareerLife.drop_sponsor(self, id)

func investments_text() -> String:
	return CareerLife.investments_text(self)

func buy_investment(id: String) -> String:
	return CareerLife.buy_investment(self, id)

func sell_investment(id: String) -> String:
	return CareerLife.sell_investment(self, id)

func maya_status_text() -> String:
	return CareerLife.maya_status_text(self)

func maya_event_text() -> String:
	return str(maya_event.get("text", ""))

## Lista de {"id","label"} do evento pendente da Maya (vazia se não houver).
func maya_event_options() -> Array:
	return CareerLife.maya_options(self)

func resolve_maya_event(choice: String) -> String:
	return CareerLife.resolve_maya_event(self, choice)

func propose_marriage() -> String:
	return CareerLife.propose_marriage(self)

func try_for_child() -> String:
	return CareerLife.try_for_child(self)

func career_summary_text() -> String:
	var lines: Array = []
	lines.append("%s · %s · %d anos · OVR %d (pot. %d)" % [player_name, CareerSquad.POS_NAMES.get(player_pos, player_pos), age, overall(), potential])
	if retired:
		lines.append("APOSENTADO · " + club_name)
		lines.append(retirement_summary())
		return "\n".join(PackedStringArray(lines))
	lines.append("%s (%s) · Temporada %d · Rodada %d/%d · %dº lugar" % [club_name, league().name, season, mini(round_no, ROUNDS), ROUNDS, position()])
	lines.append("Próximo: " + next_fixture_text())
	lines.append("Contrato: $%d/sem · %d temp. · multa $%d%s" % [contract_weekly, contract_years, contract_clause, " (EXPIRADO)" if contract_expired else ""])
	lines.append(stats_text().split("\n")[0])
	lines.append("Carreira: %d jogos · %d gols · %d assist. · troféus %d" % [career_apps, career_goals, career_assists, trophies.size()])
	lines.append("Fama %d · Imprensa %s · Caixa $%d%s" % [total_fame(), press_label(), money, (" · Dívida $%d" % debt) if debt > 0 else ""])
	lines.append(injury_text())
	if not offers.is_empty():
		lines.append("%d proposta(s) na mesa%s." % [offers.size(), "" if transfer_window_open() else " (janela fechada)"])
	lines.append(maya_status_text())
	return "\n".join(PackedStringArray(lines))

# ---------------------------------------------------------------- tempo / dias

func time_text() -> String:
	var h := int(hour) % 24
	var m := int((hour - floor(hour)) * 60.0)
	return "%02d:%02d" % [h, m]

func is_night() -> bool:
	return hour >= 19.0 or hour < 6.0

func add_time(hours: float) -> void:
	hour += hours
	while hour >= 24.0:
		hour -= 24.0
		_new_day()

## Cobra até o que tiver em caixa; o resto vira dívida. Retorna o valor efetivamente pago.
func charge(amount: int, _label := "") -> int:
	var paid := mini(money, amount)
	money -= paid
	debt += amount - paid
	return paid

func _new_day() -> void:
	day += 1
	if injury_days > 0:
		injury_days -= 2 if house_id >= 2 else 1
		injury_days = maxi(0, injury_days)
		if injury_days == 0:
			notify("Você se recuperou da lesão (%s)." % injury_name)
	if day % 3 == 0:
		press += -1 if press > 0 else (1 if press < 0 else 0)
	if day % 7 == 0:
		CareerLife.weekly(self)
	if day % CareerLife.BILL_CYCLE == 0:
		CareerLife.monthly(self)
	if gf_status != "none" and not gf_lives_with and day - last_date_day > 5:
		bond = maxi(0, bond - 6)
		if bond < 30 and gf_status == "girlfriend" and not maya_married:
			gf_status = "dating"
		if bond <= 0:
			gf_status = "none"
	CareerLife.daily_maya(self)

func sleep_at_home() -> void:
	energy = minf(100.0, energy + float(house().energy))
	var wake := 8.0
	var hrs := wake - hour if hour < wake else (24.0 - hour + wake)
	add_time(hrs)
	if gf_lives_with:
		bond = mini(100, bond + 4)
		last_date_day = day

func spend(amount: int) -> bool:
	if money < amount:
		return false
	money -= amount
	return true

func gift_count(id: String) -> int:
	return int(gifts.get(id, 0))

func relationship_label() -> String:
	if maya_married:
		return "Esposa"
	match gf_status:
		"girlfriend": return "Namorada"
		"dating": return "Saindo"
	return "Conhecida"

# ---------------------------------------------------------------- save / load

func save_game() -> void:
	_sync_legacy()
	var data := {"save_version": SAVE_VERSION, "pace": pace, "shoot": shoot, "pass_skill": pass_skill}
	for n in PERSIST:
		data[n] = get(n)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func _coerce(cur: Variant, v: Variant) -> Variant:
	match typeof(cur):
		TYPE_INT: return int(v) if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_BOOL) else cur
		TYPE_FLOAT: return float(v) if (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) else cur
		TYPE_BOOL: return bool(v)
		TYPE_STRING: return str(v)
		TYPE_ARRAY: return v if typeof(v) == TYPE_ARRAY else cur
		TYPE_DICTIONARY: return v if typeof(v) == TYPE_DICTIONARY else cur
	return v

func _reset_all() -> void:
	for n in PERSIST:
		var dv: Variant = _defaults[n]
		set(n, dv.duplicate(true) if (typeof(dv) == TYPE_ARRAY or typeof(dv) == TYPE_DICTIONARY) else dv)

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	_reset_all()
	for n in PERSIST:
		if d.has(n):
			set(n, _coerce(get(n), d[n]))
	# saves antigos
	if not d.has("bond") and d.has("relationship"):
		bond = int(d.get("relationship", 20))
	if bool(d.get("owns_car", false)) and owned_cars.is_empty():
		owned_cars = ["hatch"]
		current_car = "hatch"
	_normalize_loaded()
	if not d.has("attrs"):
		_migrate_old_player(d)
	if not d.has("contract_years"):
		var c: Dictionary = CareerContract.make_contract(self, league_id, club_idx, 3, 0.8)
		CareerContract.apply_contract(self, c)
	_sync_legacy()

func _normalize_loaded() -> void:
	var a2 := {}
	for k in CareerSquad.ATTR_KEYS:
		a2[k] = int(attrs.get(k, 50))
	attrs = a2
	if not CareerSquad.POSITIONS.has(player_pos):
		player_pos = "ATA"
	cup_teams = cup_teams.map(func (x): return int(x))
	for r in table:
		for i in r.size():
			r[i] = int(r[i])
	var s2 := {}
	for k in scorers.keys():
		s2[k] = [int(scorers[k][0]), int(scorers[k][1])]
	scorers = s2
	if table.size() != 0 and table.size() != 8:
		table = []
	league_id = clampi(league_id, 0, Leagues.count() - 1)
	club_idx = clampi(club_idx, 0, 7)
	house_id = clampi(house_id, 0, HOUSES.size() - 1)

func _migrate_old_player(d: Dictionary) -> void:
	# níveis 1..10 antigos viram atributos 40..94
	var p: int = int(d.get("pace", 1))
	var s: int = int(d.get("shoot", 1))
	var ps: int = int(d.get("pass_skill", 1))
	attrs = {
		"pace": 40 + (p - 1) * 6 + 3, "shoot": 40 + (s - 1) * 6 + 3, "pass": 40 + (ps - 1) * 6 + 3,
		"dribble": 40 + int((p + s + ps) / 3.0 - 1.0) * 6 + 2, "defense": 44, "physical": 50 + (p - 1) * 2,
	}
	player_pos = "ATA"
	age = 19 + int(maxi(0, int(d.get("season", 1)) - 1))
	potential = clampi(overall() + 18, 75, 92)

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_reset_all()
