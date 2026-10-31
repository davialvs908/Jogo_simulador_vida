extends RefCounted
## Copa simples (mata-mata de 8 clubes: quartas, semifinal, final) dentro da temporada.
## A partida da copa fica "pendente" depois das rodadas CUP_AT do campeonato; opponent_idx() passa a
## devolver o adversário da copa, então hub/match funcionam sem mudanças.

const STAGE_NAMES := ["Quartas de final", "Semifinal", "Final"]
const CUP_AT := [3, 7, 11]   # rodadas de liga concluídas antes de cada fase

static func init_cup(gs) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("cup_%d_%d_%d" % [gs.league_id, gs.season, gs.club_idx])
	var teams: Array = range(8)
	for i in range(teams.size() - 1, 0, -1):
		var j := int(rng.randi() % (i + 1))
		var tmp = teams[i]
		teams[i] = teams[j]
		teams[j] = tmp
	gs.cup_teams = teams
	gs.cup_stage = 0
	gs.cup_alive = true
	gs.cup_champion = -1
	gs.cup_log = []
	gs.cup_result = ""

static func ensure(gs) -> void:
	if gs.cup_teams.size() == 0 or (gs.cup_stage < 3 and gs.cup_teams.size() != 8 >> gs.cup_stage):
		init_cup(gs)

static func pending(gs) -> bool:
	ensure(gs)
	return gs.cup_alive and gs.cup_stage < 3 and gs.round_no >= CUP_AT[gs.cup_stage] and gs.cup_teams.has(gs.club_idx)

static func opponent(gs) -> int:
	var t: Array = gs.cup_teams
	var i := t.find(gs.club_idx)
	if i < 0:
		return (gs.club_idx + 1) % 8
	return int(t[i ^ 1])

static func stage_name(gs) -> String:
	return STAGE_NAMES[clampi(gs.cup_stage, 0, 2)]

static func _strength(gs, c: int) -> int:
	return Leagues.club_strength(gs.league_id, c)

static func _ai_match(gs, a: int, b: int) -> Array:
	var ga: int = gs._sim_goals(_strength(gs, a) + 1, _strength(gs, b))
	var gb: int = gs._sim_goals(_strength(gs, b), _strength(gs, a) + 1)
	var w: int
	if ga > gb:
		w = a
	elif gb > ga:
		w = b
	else:
		w = a if randf() < 0.5 + float(_strength(gs, a) - _strength(gs, b)) * 0.01 else b
	return [w, ga, gb]

static func _log(gs, stage: int, a: int, b: int, ga: int, gb: int, w: int, pens: bool) -> void:
	gs.cup_log.append("%s: %s %d x %d %s%s" % [STAGE_NAMES[stage], Leagues.club_name(gs.league_id, a), ga, gb,
		Leagues.club_name(gs.league_id, b), (" (pên. %s)" % Leagues.club_name(gs.league_id, w)) if pens else ""])

## Avança as fases que não dependem do usuário (já eliminado ou clube aposentado).
static func sync(gs) -> void:
	ensure(gs)
	while gs.cup_stage < 3 and gs.round_no >= CUP_AT[gs.cup_stage]:
		if gs.cup_alive and gs.cup_teams.has(gs.club_idx):
			return
		_play_stage(gs, -1, 0, 0)

## Joga a fase inteira. Se user_pair >= 0, o jogo do usuário usa o placar real (pg x og).
static func _play_stage(gs, user_pair: int, pg: int, og: int) -> int:
	var t: Array = gs.cup_teams
	var winners: Array = []
	var user_won := false
	for i in range(0, t.size(), 2):
		var a: int = t[i]
		var b: int = t[i + 1]
		if a == gs.club_idx or b == gs.club_idx:
			if user_pair < 0:
				# usuário não está jogando de verdade: simula como IA
				var r := _ai_match(gs, a, b)
				winners.append(r[0])
				_log(gs, gs.cup_stage, a, b, r[1], r[2], r[0], r[1] == r[2])
				continue
			var opp: int = b if a == gs.club_idx else a
			var w: int = gs.club_idx if pg > og else opp
			var pens := pg == og
			if pens:
				w = gs.club_idx if randf() < 0.5 else opp
			user_won = (w == gs.club_idx)
			winners.append(w)
			_log(gs, gs.cup_stage, gs.club_idx, opp, pg, og, w, pens)
		else:
			var r2 := _ai_match(gs, a, b)
			winners.append(r2[0])
			_log(gs, gs.cup_stage, a, b, r2[1], r2[2], r2[0], r2[1] == r2[2])
	gs.cup_teams = winners
	gs.cup_stage += 1
	if gs.cup_stage >= 3:
		gs.cup_champion = int(winners[0])
	return 1 if user_won else 0

## O usuário jogou a partida da copa. Retorna {"text", "won", "champion", "prize"}.
static func play_user(gs, pg: int, og: int) -> Dictionary:
	var stage: int = gs.cup_stage
	var opp := opponent(gs)
	var won := _play_stage(gs, 0, pg, og) == 1
	var prize := 0
	var txt := ""
	var champion := false
	var opp_name: String = Leagues.club_name(gs.league_id, opp)
	if won:
		prize = int((300 + stage * 300) * float(gs.league().pay))
		if stage == 2:
			champion = true
			prize = int(2500 * float(gs.league().pay))
			gs.cup_result = "Campeão"
			txt = "CAMPEÃO DA COPA! Final vencida contra %s (%d x %d%s)." % [opp_name, pg, og, ", nos pênaltis" if pg == og else ""]
		else:
			gs.cup_result = "Avançou em %s" % STAGE_NAMES[stage]
			txt = "%s: classificado após vencer %s (%d x %d%s)." % [STAGE_NAMES[stage], opp_name, pg, og, ", nos pênaltis" if pg == og else ""]
	else:
		gs.cup_alive = false
		gs.cup_result = "Eliminado: %s" % STAGE_NAMES[stage]
		txt = "%s: eliminado por %s (%d x %d%s)." % [STAGE_NAMES[stage], opp_name, pg, og, ", nos pênaltis" if pg == og else ""]
		if stage == 2:
			gs.cup_result = "Vice-campeão"
			prize = int(800 * float(gs.league().pay))
			txt = "Vice-campeão da copa: perdeu a final para %s (%d x %d)." % [opp_name, pg, og]
	if prize > 0:
		gs.money += prize
		txt += " Prêmio da copa: $%d." % prize
	return {"text": txt, "won": won, "champion": champion, "prize": prize}

static func status_text(gs) -> String:
	ensure(gs)
	var s := "Copa %s — " % gs.league().name
	if gs.cup_stage >= 3:
		var ch: int = gs.cup_champion
		s += "encerrada. Campeão: %s." % Leagues.club_name(gs.league_id, ch)
	elif not gs.cup_alive:
		s += "você foi eliminado. Em disputa: %s." % stage_name(gs)
	elif pending(gs):
		s += "%s pendente contra %s." % [stage_name(gs), Leagues.club_name(gs.league_id, opponent(gs))]
	else:
		s += "%s após a rodada %d do campeonato." % [stage_name(gs), CUP_AT[gs.cup_stage]]
	return s

static func log_text(gs) -> String:
	if gs.cup_log.is_empty():
		return "Nenhuma partida de copa disputada ainda."
	return "\n".join(PackedStringArray(gs.cup_log))
