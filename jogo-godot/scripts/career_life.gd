extends RefCounted
## Economia da vida real (patrocínios, investimentos, contas) e eventos da Maya.

const SPONSORS := [
	{"id": "bike", "name": "Bike Sol", "min_fame": 5, "weekly": 80},
	{"id": "drink", "name": "Energético Raio", "min_fame": 15, "weekly": 220},
	{"id": "boots", "name": "Chuteiras Vórtice", "min_fame": 30, "weekly": 500},
	{"id": "bank", "name": "Banco Horizonte", "min_fame": 50, "weekly": 900},
	{"id": "watch", "name": "Relógios Aurum", "min_fame": 80, "weekly": 1600},
	{"id": "car", "name": "Motores Titan", "min_fame": 120, "weekly": 2800},
]
const MAX_SPONSORS := 3

const INVESTMENTS := [
	{"id": "kiosk", "name": "Quiosque de lanches", "price": 1200, "weekly": 38, "risk": 0.35, "max": 3, "bill": 0},
	{"id": "shop", "name": "Loja de roupas", "price": 4000, "weekly": 135, "risk": 0.30, "max": 3, "bill": 30},
	{"id": "flat", "name": "Apartamento para alugar", "price": 8000, "weekly": 240, "risk": 0.0, "max": 4, "bill": 40},
	{"id": "gymbiz", "name": "Academia de bairro", "price": 15000, "weekly": 490, "risk": 0.20, "max": 2, "bill": 60},
]

const MAYA_BDAY := 20          # aniversário da Maya: dia % 60 == 20
const BIRTHDAY_CYCLE := 60
const BILL_CYCLE := 30
const PREGNANCY_DAYS := 30
const EVENT_DEADLINE := 3      # dias para responder a um evento

# ---------------------------------------------------------------- patrocínios

static func sponsor_data(id: String) -> Dictionary:
	for s in SPONSORS:
		if s.id == id:
			return s
	return {}

static func sponsor_weekly(gs, id: String) -> int:
	var s := sponsor_data(id)
	if s.is_empty():
		return 0
	var mult: float = clampf(1.0 + float(gs.press) / 200.0, 0.5, 1.5)
	return int(float(s.weekly) * mult)

static func sponsor_active(gs, id: String) -> bool:
	for a in gs.sponsors:
		if a.get("id", "") == id:
			return true
	return false

static func sign_sponsor(gs, id: String) -> String:
	if gs.retired:
		return "Você está aposentado."
	var s := sponsor_data(id)
	if s.is_empty():
		return "Patrocinador desconhecido."
	if sponsor_active(gs, id):
		return "Você já tem contrato com %s." % s.name
	if gs.sponsors.size() >= MAX_SPONSORS:
		return "Você já tem %d patrocinadores (máximo). Cancele um antes." % MAX_SPONSORS
	if gs.total_fame() < int(s.min_fame):
		return "%s só fecha com fama %d (a sua é %d)." % [s.name, int(s.min_fame), gs.total_fame()]
	var bonus: int = int(sponsor_weekly(gs, id)) * 2
	gs.sponsors.append({"id": id, "until": gs.season + 1})
	gs.money += bonus
	gs.add_news("%s fecha patrocínio com %s" % [gs.player_name, s.name], 2)
	return "Contrato com %s assinado: $%d por semana até o fim da temporada %d. Bônus de assinatura $%d." % [
		s.name, sponsor_weekly(gs, id), gs.season + 1, bonus]

static func drop_sponsor(gs, id: String) -> String:
	for i in gs.sponsors.size():
		if gs.sponsors[i].get("id", "") == id:
			gs.sponsors.remove_at(i)
			gs.add_news("%s rompe com patrocinador" % gs.player_name, -2)
			return "Contrato rompido. A imprensa notou."
	return "Você não tem esse patrocinador."

static func sponsors_text(gs) -> String:
	var out := "Patrocínios (fama %d, imprensa %d) — máx. %d ativos\n" % [gs.total_fame(), gs.press, MAX_SPONSORS]
	for s in SPONSORS:
		var st := ""
		if sponsor_active(gs, s.id):
			var until := 0
			for a in gs.sponsors:
				if a.get("id", "") == s.id:
					until = int(a.get("until", 0))
			st = "ATIVO até temporada %d" % until
		elif gs.total_fame() >= int(s.min_fame):
			st = "disponível"
		else:
			st = "exige fama %d" % int(s.min_fame)
		out += "- %s [%s]: $%d/sem — %s\n" % [s.name, s.id, sponsor_weekly(gs, s.id), st]
	return out

static func expire_sponsors(gs) -> void:
	var keep: Array = []
	for a in gs.sponsors:
		if int(a.get("until", 0)) >= gs.season:
			keep.append(a)
		else:
			gs.notify("Contrato de patrocínio com %s terminou." % sponsor_data(str(a.get("id", ""))).get("name", "?"))
	gs.sponsors = keep

# ---------------------------------------------------------------- investimentos

static func inv_data(id: String) -> Dictionary:
	for s in INVESTMENTS:
		if s.id == id:
			return s
	return {}

static func inv_count(gs, id: String) -> int:
	return int(gs.investments.get(id, 0))

static func inv_price(gs, id: String) -> int:
	var d := inv_data(id)
	return int(float(d.price) * (1.0 + 0.25 * float(inv_count(gs, id))))

static func buy_investment(gs, id: String) -> String:
	var d := inv_data(id)
	if d.is_empty():
		return "Investimento desconhecido."
	if inv_count(gs, id) >= int(d.max):
		return "Você já tem o máximo de %s (%d)." % [d.name, int(d.max)]
	var p := inv_price(gs, id)
	if not gs.spend(p):
		return "Sem dinheiro ($%d)." % p
	gs.investments[id] = inv_count(gs, id) + 1
	gs.save_game()
	return "Comprou: %s por $%d. Rende cerca de $%d por semana." % [d.name, p, int(d.weekly)]

static func sell_investment(gs, id: String) -> String:
	var d := inv_data(id)
	if d.is_empty() or inv_count(gs, id) <= 0:
		return "Você não tem esse negócio."
	var back := int(float(d.price) * (1.0 + 0.25 * float(inv_count(gs, id) - 1)) * 0.7)
	gs.investments[id] = inv_count(gs, id) - 1
	gs.money += back
	gs.save_game()
	return "Vendeu %s por $%d." % [d.name, back]

static func investments_text(gs) -> String:
	var out := "Investimentos\n"
	for d in INVESTMENTS:
		out += "- %s [%s]: tem %d/%d · preço $%d · rende ~$%d/sem\n" % [d.name, d.id, inv_count(gs, d.id), int(d.max), inv_price(gs, d.id), int(d.weekly)]
	return out

# ---------------------------------------------------------------- semana / mês

static func weekly(gs) -> String:
	var lines: Array = []
	var inc := 0
	if not gs.retired:
		inc += gs.contract_weekly
		lines.append("Salário +$%d" % gs.contract_weekly)
		for a in gs.sponsors:
			var v := sponsor_weekly(gs, str(a.get("id", "")))
			inc += v
			lines.append("%s +$%d" % [sponsor_data(str(a.get("id", ""))).get("name", "Patrocínio"), v])
	elif gs.contract_weekly > 0:
		var pen := int(float(gs.contract_weekly) * 0.2)
		inc += pen
		lines.append("Pensão de ex-atleta +$%d" % pen)
	for d in INVESTMENTS:
		var n := inv_count(gs, d.id)
		for i in n:
			var v2 := int(float(d.weekly) * (1.0 + gs.rng_float(-1.0, 1.0) * float(d.risk)))
			inc += v2
		if n > 0:
			lines.append("%s x%d +$%d" % [d.name, n, int(float(d.weekly) * n)])
	gs.money += inc
	if gs.house_id == 0:
		var paid: int = gs.charge(int(gs.HOUSES[0].rent), "aluguel")
		lines.append("Aluguel -$%d" % paid)
	if gs.debt > 0:
		var interest := int(float(gs.debt) * 0.03)
		gs.debt += interest
		var pay := mini(gs.money, gs.debt)
		if pay > 0:
			gs.money -= pay
			gs.debt -= pay
			lines.append("Dívida paga -$%d (resta $%d)" % [pay, gs.debt])
	# imprensa
	if gs.total_fame() >= 15 and not gs.retired:
		var r := randf()
		if r < 0.05:
			gs.add_news("Flagra: %s em balada na véspera de jogo" % gs.player_name, -8)
			if gs.gf_status != "none":
				gs.bond = maxi(0, gs.bond - 4)
		elif r < 0.12:
			gs.add_news("%s visita hospital infantil e vira exemplo" % gs.player_name, 5)
	var txt := "Semana (dia %d): %s" % [gs.day, ", ".join(PackedStringArray(lines))]
	gs.last_weekly_text = txt
	return txt

static func monthly(gs) -> String:
	var items: Array = []
	var total := 0
	var util: int = 40 + 30 * gs.house_id
	items.append(["Luz/água/internet", util])
	if gs.house_id > 0:
		items.append(["IPTU da casa", int(float(gs.HOUSES[gs.house_id].price) * 0.012)])
	for d in INVESTMENTS:
		if int(d.bill) > 0 and inv_count(gs, d.id) > 0:
			items.append(["Taxas: %s" % d.name, int(d.bill) * inv_count(gs, d.id)])
	for cid in gs.owned_cars:
		var cd: Dictionary = gs.car_data(str(cid))
		if not cd.is_empty():
			items.append(["Seguro %s" % cd.name, int(float(cd.price) * 0.012)])
	if gs.children > 0:
		items.append(["Filhos (%d)" % gs.children, 90 * gs.children])
	if gs.gf_lives_with:
		items.append(["Mercado da casa", 60 + (80 if gs.maya_married else 0)])
	var parts: Array = []
	var unpaid := 0
	for it in items:
		var due: int = it[1]
		var paid: int = gs.charge(due, str(it[0]))
		total += due
		unpaid += due - paid
		parts.append("%s $%d" % [it[0], due])
	gs.bills_paid_total += total - unpaid
	if unpaid > 0 and gs.debt > 400:
		gs.add_news("%s com contas atrasadas" % gs.player_name, -4)
	var txt := "Contas do mês (dia %d): %s. Total $%d%s" % [gs.day, ", ".join(PackedStringArray(parts)), total,
		(" — faltou $%d (dívida)" % unpaid) if unpaid > 0 else ""]
	gs.last_bills_text = txt
	return txt

static func finance_text(gs) -> String:
	var weekly_in: int = 0 if gs.retired else gs.contract_weekly
	var sp := 0
	for a in gs.sponsors:
		sp += sponsor_weekly(gs, str(a.get("id", "")))
	var inv := 0
	for d in INVESTMENTS:
		inv += int(d.weekly) * inv_count(gs, d.id)
	return "Caixa $%d · Dívida $%d\nRenda semanal: salário $%d + patrocínios $%d + negócios ~$%d\n%s\n%s" % [
		gs.money, gs.debt, weekly_in, sp, inv, gs.last_weekly_text, gs.last_bills_text]

# ---------------------------------------------------------------- Maya

static func maya_options(gs) -> Array:
	var t: String = str(gs.maya_event.get("type", ""))
	match t:
		"birthday":
			return [{"id": "gift", "label": "Dar um presente (do inventário)"}, {"id": "dinner", "label": "Jantar romântico ($150)"}, {"id": "ignore", "label": "Esquecer"}]
		"fight":
			return [{"id": "apologize", "label": "Pedir desculpas"}, {"id": "gift", "label": "Dar um presente (do inventário)"}, {"id": "ignore", "label": "Ignorar"}]
		"reconcile":
			return [{"id": "talk", "label": "Conversar com calma"}, {"id": "dinner", "label": "Jantar para fazer as pazes ($150)"}, {"id": "ignore", "label": "Deixar para lá"}]
	return []

static func _best_gift(gs) -> String:
	for id in ["jewel", "dress", "flowers"]:
		if gs.gift_count(id) > 0:
			return id
	return ""

static func _use_gift(gs) -> int:
	var id := _best_gift(gs)
	if id == "":
		return -1
	gs.gifts[id] = gs.gift_count(id) - 1
	for g in gs.GIFTS:
		if g.id == id:
			return int(g.bond)
	return 0

static func _bond(gs, delta: int) -> void:
	gs.bond = clampi(gs.bond + delta, 0, 100)

static func resolve_maya_event(gs, choice: String) -> String:
	if gs.maya_event.is_empty():
		return "Nenhum evento pendente com a Maya."
	var t: String = str(gs.maya_event.get("type", ""))
	var out := ""
	match t:
		"birthday":
			match choice:
				"gift":
					var gb := _use_gift(gs)
					if gb < 0:
						return "Você não tem nenhum presente no inventário (compre no shopping)."
					_bond(gs, 12 + gb)
					out = "Maya adorou o presente de aniversário! Vínculo +%d." % (12 + gb)
				"dinner":
					if not gs.spend(150):
						return "Sem dinheiro ($150)."
					_bond(gs, 16)
					gs.last_date_day = gs.day
					out = "Jantar de aniversário inesquecível. Vínculo +16."
				_:
					_bond(gs, -18)
					gs.maya_reconcile_day = gs.day + 3
					out = "Você esqueceu o aniversário da Maya. Ela ficou magoada (vínculo -18)."
		"fight":
			match choice:
				"apologize":
					if randf() < 0.65:
						_bond(gs, 6)
						out = "Você pediu desculpas e a Maya aceitou. Vínculo +6."
					else:
						_bond(gs, -4)
						gs.maya_reconcile_day = gs.day + 3
						out = "As desculpas não bastaram agora (vínculo -4). Dê um tempo e converse depois."
				"gift":
					var gb2 := _use_gift(gs)
					if gb2 < 0:
						return "Você não tem nenhum presente no inventário."
					_bond(gs, 4 + gb2)
					out = "O presente amoleceu a discussão. Vínculo +%d." % (4 + gb2)
				_:
					_bond(gs, -12)
					gs.maya_reconcile_day = gs.day + 4
					out = "Você ignorou a briga (vínculo -12). Ela espera uma conversa."
		"reconcile":
			match choice:
				"talk":
					_bond(gs, 10)
					gs.last_date_day = gs.day
					out = "Vocês conversaram e fizeram as pazes. Vínculo +10."
				"dinner":
					if not gs.spend(150):
						return "Sem dinheiro ($150)."
					_bond(gs, 14)
					gs.last_date_day = gs.day
					out = "Jantar da reconciliação. Vínculo +14."
				_:
					_bond(gs, -8)
					out = "Você deixou para lá (vínculo -8)."
	gs.maya_event = {}
	check_bond(gs)
	gs.save_game()
	return out

static func check_bond(gs) -> void:
	if gs.gf_status == "none":
		return
	if gs.bond <= 0:
		if gs.maya_married:
			gs.maya_married = false
			var loss := int(float(gs.money) * 0.3)
			gs.money -= loss
			gs.add_news("%s e Maya se divorciam" % gs.player_name, -10)
			gs.notify("Divórcio. Você perdeu $%d no acordo." % loss)
		else:
			gs.notify("A Maya terminou com você.")
		gs.gf_status = "none"
		gs.gf_lives_with = false
	elif gs.bond < 30 and gs.gf_status == "girlfriend" and not gs.maya_married:
		gs.gf_status = "dating"

static func _start_event(gs, type: String, text: String) -> void:
	gs.maya_event = {"type": type, "text": text, "expires": gs.day + EVENT_DEADLINE}
	gs.notify("Maya: " + text)

static func daily_maya(gs) -> void:
	if gs.gf_status == "none":
		return
	# resolução automática de evento ignorado
	if not gs.maya_event.is_empty() and gs.day > int(gs.maya_event.get("expires", 0)):
		var t: String = str(gs.maya_event.get("type", ""))
		gs.maya_event["type"] = t
		resolve_maya_event(gs, "ignore")
		if gs.gf_status == "none":
			return
	# gravidez
	if gs.pregnancy_due > 0 and gs.day >= gs.pregnancy_due:
		gs.pregnancy_due = 0
		gs.children += 1
		_bond(gs, 8)
		gs.add_news("%s e Maya têm um filho!" % gs.player_name, 4)
		gs.notify("Nasceu o seu filho/filha! Agora são %d criança(s). Custos mensais +$90." % gs.children)
	if gs.maya_married and (gs.day - gs.marriage_day) > 0 and (gs.day - gs.marriage_day) % BIRTHDAY_CYCLE == 0:
		_bond(gs, 3)
		gs.notify("Aniversário de casamento com a Maya. Vínculo +3.")
	if not gs.maya_event.is_empty():
		return
	if gs.maya_reconcile_day > 0 and gs.day >= gs.maya_reconcile_day:
		gs.maya_reconcile_day = 0
		_start_event(gs, "reconcile", "Maya quer conversar sobre a última discussão.")
		return
	if gs.day % BIRTHDAY_CYCLE == MAYA_BDAY:
		_start_event(gs, "birthday", "Hoje é o aniversário da Maya!")
		return
	var gap: int = gs.day - gs.last_date_day
	var p := 0.0
	if not gs.gf_lives_with and gap > 4:
		p = 0.06 + float(gap - 4) * 0.01
	elif gs.gf_lives_with and gs.bond < 60:
		p = 0.04
	if gs.press <= -30:
		p += 0.03
	if gs.day - gs.maya_last_fight_day < 8:
		p = 0.0
	if randf() < p:
		gs.maya_last_fight_day = gs.day
		_start_event(gs, "fight", "Maya está chateada: reclama que você anda ausente.")

static func propose_marriage(gs) -> String:
	if gs.maya_married:
		return "Vocês já são casados."
	if gs.gf_status != "girlfriend":
		return "A Maya precisa ser sua namorada primeiro."
	if not gs.gf_lives_with:
		return "Vocês precisam morar juntos antes do casamento."
	if gs.bond < 80:
		return "O vínculo precisa estar em 80 ou mais (agora %d)." % gs.bond
	if not gs.spend(2500):
		return "Anel e cerimônia custam $2500."
	var chance := clampf(0.5 + float(gs.bond - 80) * 0.02, 0.5, 0.95)
	if randf() > chance:
		gs.bond = maxi(0, gs.bond - 10)
		return "A Maya pediu mais tempo (vínculo -10). O anel ficou guardado; você perdeu $2500 na festa."
	gs.maya_married = true
	gs.marriage_day = gs.day
	gs.bond = 100
	gs.add_news("%s e Maya se casam!" % gs.player_name, 6)
	gs.add_fame(3)
	gs.save_game()
	return "Ela disse sim! Casamento realizado (-$2500). Vínculo 100."

static func try_for_child(gs) -> String:
	if not gs.maya_married:
		return "Só depois do casamento."
	if gs.pregnancy_due > 0:
		return "A Maya já está grávida (nascimento previsto no dia %d)." % gs.pregnancy_due
	if gs.children >= 3:
		return "Vocês já têm 3 filhos."
	if gs.bond < 70:
		return "O vínculo precisa estar em 70 ou mais."
	if gs.house_id < 2:
		return "Vocês precisam de pelo menos a casa com quintal."
	gs.pregnancy_due = gs.day + PREGNANCY_DAYS
	gs.save_game()
	return "A Maya está grávida! Nascimento previsto no dia %d." % gs.pregnancy_due

static func maya_status_text(gs) -> String:
	var s := "%s · vínculo %d/100" % [gs.relationship_label(), gs.bond]
	if gs.gf_status == "none":
		return "Maya: conhecida (vínculo %d/100)." % gs.bond
	if gs.gf_lives_with:
		s += " · mora com você"
	if gs.maya_married:
		s += " · casados desde o dia %d" % gs.marriage_day
	if gs.pregnancy_due > 0:
		s += " · grávida (previsto dia %d)" % gs.pregnancy_due
	if gs.children > 0:
		s += " · %d filho(s)" % gs.children
	if not gs.maya_event.is_empty():
		s += "\nPendente: " + str(gs.maya_event.get("text", ""))
	else:
		var d: int = BIRTHDAY_CYCLE - ((gs.day - MAYA_BDAY) % BIRTHDAY_CYCLE + BIRTHDAY_CYCLE) % BIRTHDAY_CYCLE
		if d == BIRTHDAY_CYCLE:
			d = 0
		s += "\nPróximo aniversário dela em %d dia(s)." % d
	return "Maya: " + s
