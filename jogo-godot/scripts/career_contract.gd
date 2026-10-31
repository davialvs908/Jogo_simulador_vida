extends RefCounted
## Contratos, renovação e propostas de transferência.

static func wage_for(ovr: int, pay: float) -> int:
	var w: float = pow(maxf(float(ovr - 40), 1.0), 1.6) * 2.0 * pay
	return maxi(40, int(round(w / 5.0)) * 5)

## "Nível de mercado": overall + fama + imprensa + potencial (jovens).
static func market_level(gs) -> float:
	var lv: float = float(gs.overall()) + float(gs.total_fame()) / 10.0 + maxf(0.0, float(gs.press)) / 20.0
	if gs.age <= 22:
		lv += maxf(0.0, float(gs.potential - gs.overall())) * 0.25
	if gs.age >= 33:
		lv -= float(gs.age - 32) * 1.5
	if gs.injury_days > 10:
		lv -= 2.0
	return lv

static func make_contract(gs, league: int, club: int, years: int, mult := 1.0) -> Dictionary:
	var pay: float = float(Leagues.DATA[league].pay)
	var weekly: int = int(round(float(wage_for(gs.overall(), pay)) * mult / 5.0)) * 5
	return {
		"league": league, "club": club, "weekly": weekly, "years": years,
		"clause": weekly * (50 + int(gs.rng_int(0, 40))), "bonus": weekly * 3,
	}

static func apply_contract(gs, c: Dictionary) -> void:
	gs.contract_weekly = int(c.weekly)
	gs.contract_years = int(c.years)
	gs.contract_clause = int(c.clause)

static func renewal_chance(gs) -> float:
	var strength: int = Leagues.club_strength(gs.league_id, gs.club_idx)
	var avg: float = gs.season_avg_rating()
	var p: float = 0.55 + float(gs.overall() - strength) * 0.02 + (avg - 6.4) * 0.12 + float(gs.press) / 400.0
	if gs.age >= 33:
		p -= float(gs.age - 32) * 0.08
	return clampf(p, 0.08, 0.95)

static func try_renew(gs) -> String:
	if gs.retired:
		return "Você está aposentado."
	if gs.contract_years > 3:
		return "Seu contrato ainda é longo (%d temporadas). O clube só negocia com 3 ou menos restando." % gs.contract_years
	if gs.renew_tried_season == gs.season:
		return "A diretoria já respondeu nesta temporada. Tente de novo na próxima."
	gs.renew_tried_season = gs.season
	if randf() > renewal_chance(gs):
		gs.add_news("Diretoria do %s recusa aumento de %s" % [gs.club_name, gs.player_name], -2)
		return "A diretoria do %s recusou renovar nos seus termos (chance era %d%%). Tente na próxima temporada ou ouça outras propostas." % [
			gs.club_name, int(renewal_chance(gs) * 100.0)]
	var pay: float = float(gs.league().pay)
	var new_weekly: int = maxi(int(round(float(wage_for(gs.overall(), pay)) * gs.rng_float(1.0, 1.15) / 5.0)) * 5, int(float(gs.contract_weekly) * 1.05))
	var add_years: int = gs.rng_int(2, 4)
	var bonus: int = new_weekly * 3
	gs.contract_weekly = new_weekly
	gs.contract_years = mini(gs.contract_years + add_years, 5)
	gs.contract_clause = new_weekly * gs.rng_int(55, 90)
	gs.money += bonus
	gs.add_news("%s renova com o %s" % [gs.player_name, gs.club_name], 3)
	return "Renovado! Novo salário semanal $%d, contrato até %d temporada(s), multa $%d. Bônus de assinatura $%d." % [
		new_weekly, gs.contract_years, gs.contract_clause, bonus]

static func generate_offers(gs, max_offers := 3) -> Array:
	var offers: Array = []
	if gs.retired:
		return offers
	var level: float = market_level(gs)
	var cands: Array = []
	for lg in Leagues.count():
		for c in 8:
			if lg == gs.league_id and c == gs.club_idx:
				continue
			var s: int = Leagues.club_strength(lg, c)
			if float(s) <= level + 5.0 and float(s) >= level - 14.0:
				# prefere clubes mais próximos do nível (leve) e de ligas mais ricas
				var w: float = 1.0 + float(Leagues.DATA[lg].pay) + maxf(0.0, 1.0 - absf(float(s) - level) / 10.0)
				cands.append({"lg": lg, "c": c, "w": w})
	var picked := 0
	while picked < max_offers and cands.size() > 0:
		var tot := 0.0
		for x in cands:
			tot += float(x.w)
		var r := randf() * tot
		var idx := 0
		for i in cands.size():
			r -= float(cands[i].w)
			if r <= 0.0:
				idx = i
				break
		var cd: Dictionary = cands[idx]
		cands.remove_at(idx)
		# no máximo uma proposta por liga
		var dup := false
		for o in offers:
			if int(o.league) == int(cd.lg):
				dup = true
		if dup:
			continue
		var years: int = gs.rng_int(2, 4)
		var ct := make_contract(gs, int(cd.lg), int(cd.c), years, gs.rng_float(0.9, 1.25))
		ct["club_name"] = Leagues.club_name(int(cd.lg), int(cd.c))
		ct["league_name"] = str(Leagues.DATA[int(cd.lg)].name)
		ct["bonus"] = int(ct.weekly) * gs.rng_int(3, 6)
		offers.append(ct)
		picked += 1
	return offers

static func offer_line(o: Dictionary) -> String:
	return "%s (%s) — $%d/sem, %d temp., multa $%d, bônus de assinatura $%d" % [
		o.club_name, o.league_name, int(o.weekly), int(o.years), int(o.clause), int(o.bonus)]
