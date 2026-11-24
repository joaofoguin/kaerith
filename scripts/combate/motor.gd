class_name Motor
extends RefCounted
## Regras do combate por turnos, sem desenho. Cada rodada devolve uma lista de eventos que a tela anima.
## Fórmulas (DEFINIDAS em Mobile · Números): poder % × Força/Ressonância → redução da Resistência
## Res/(Res+50×fator do atacante), teto 75% → ±25% elemental → crítico ×1,5.

var jogador: Lutador
var inimigos: Array = []          # onda atual (os caídos ficam com vida 0)
var ondas: Array = []
var onda_atual := 0
var rodada := 1
var guarda_rodada1 := false       # desfaz o traço Território das feras locais
var derrotados: Array = []
var vistos: Array = []            # todos os inimigos que entraram na luta (Bestiário)
var fim := ""                     # "", "vitoria" ou "derrota"
var pocoes := {}                  # referência ao inventário de poções (id → quantidade)
var usos_max := {}
var rng := RandomNumberGenerator.new()
var _ev: Array = []
var _prox_id := 1
const ORBES := preload("res://scripts/orbes.gd")

## Rebalanceamento (pedido do João, 2026-11-13, medido no simulador ferramentas/simulador_combate).
## Vida e dano de cada categoria ficam em Catalogo.MULT. PROVISÓRIOS (delegação de números):
const CURA_INIMIGO := 0.4         # curas e drenos dos inimigos
const REGENERACAO := 0.05         # Regeneração por rodada (era 8%)
const TERRITORIO := 1.1           # feras locais nas 2 primeiras rodadas (era +20%)
## Usos das habilidades de elemento dos inimigos (os ataques comuns continuam sem limite).
const USOS_INIMIGO := {
	"comum": {"ofensiva": 1, "defensiva": 1, "utilitaria": 1},
	"veterano": {"ofensiva": 1, "defensiva": 1, "utilitaria": 1},
	"elite": {"ofensiva": 1, "defensiva": 1, "utilitaria": 1},
	"suprema": {"ofensiva": 2, "defensiva": 1, "utilitaria": 1},
}

## PROVISÓRIO (delegação): em grupo, cada inimigo Comum/Veterano tem Vida e dano reduzidos,
## para o combate comum continuar em 4–6 turnos com 2 ou 3 inimigos (com Vida 120 cheia, 2 já venceriam).
const GRUPO := {2: 0.6, 3: 0.45}

## Pedido do João (2026-11-13): as 10 primeiras fases ficam como estão; dali em diante os inimigos sobem,
## porque o jogador já tem equipamentos e moedas para poções. PROVISÓRIO (medido no simulador, t13.py):
## Vida e dano × 1,10 na fase 11, subindo em linha até × 1,25 na fase 40 e parado nisso depois.
## Vale só para as fases do mapa (QR e Evento ficam como estão).
const DIFICULDADE_INICIO := 10
const DIFICULDADE_MIN := 1.10
const DIFICULDADE_MAX := 1.35
const DIFICULDADE_TETO := 40
var dificuldade := 1.0

## Rebalanceamento de 2026-11-24 (pedido do João: "muito fácil avançar sem comprar itens e equipamentos"). PROVISÓRIO:
## depois da fase 40 a dificuldade continua subindo um pouco por fase, porque as peças que caem (Rara na Suprema,
## Épica no chefe) e os Orbes deixavam o herói forte demais sem comprar nada. Fase 75 ≈ ×1,46, 150 ≈ ×1,68, 300 ≈ ×2,13. Início em ×1,10 na fase 11 (era 1,20).
const DIFICULDADE_POR_FASE := 0.003

static func dificuldade_da_fase(fase: int) -> float:
	if fase <= DIFICULDADE_INICIO:
		return 1.0
	var t := clampf(float(fase - DIFICULDADE_INICIO - 1) / float(DIFICULDADE_TETO - DIFICULDADE_INICIO - 1), 0.0, 1.0)
	return lerpf(DIFICULDADE_MIN, DIFICULDADE_MAX, t) + DIFICULDADE_POR_FASE * maxf(0.0, float(fase - DIFICULDADE_TETO))

## Tutorial 2: o herói não cai antes do Despertar (piso de Vida 1) e o último inimigo de pé também não; o dano dos inimigos não
## é reduzido pelo grupo (só a Vida), para o jogador chegar logo aos 25%.
var piso_jogador := 0
var piso_inimigos := 0
var sem_grupo := false
## Tutorial 2: quando o herói chega ao piso (a tela mostra Vida zero), a rodada para e o Despertar acontece.
var despertar_pendente := false

## Pedido do João (2026-11-22): no tutorial 2 os inimigos podem cair antes do Despertar; só o ÚLTIMO de pé
## fica com o piso, para a luta continuar até o herói cair e o Despertar acontecer.
func _piso(l: Lutador) -> int:
	if l.eh_jogador:
		return piso_jogador
	if piso_inimigos > 0 and vivos().filter(func(o): return o != l).is_empty():
		return piso_inimigos
	return 0

func _init(encontro: Dictionary, elemento: String, nivel: int, habilidades: Array, inventario_pocoes: Dictionary) -> void:
	rng.randomize()
	ondas = encontro["ondas"]
	dificuldade = dificuldade_da_fase(int(encontro.get("fase", 0)))
	pocoes = inventario_pocoes
	jogador = Lutador.new()
	jogador.id = 0
	jogador.eh_jogador = true
	jogador.nome = "HEROI_NOME"
	jogador.elemento = elemento
	jogador.nivel = nivel
	jogador.definir_atributos(Catalogo.MODELO_JOGADOR[elemento])
	jogador.vida_max = int(round(120 * jogador.fator))
	jogador.vida = jogador.vida_max
	Equipamento.aplicar(jogador)
	jogador.habilidades = habilidades.duplicate()
	jogador.preparar_usos()
	# Orbes: +1 uso por nível acima do 1 nas habilidades do elemento do Orbe
	for h: String in jogador.usos:
		if int(jogador.usos[h]) >= 0:
			jogador.usos[h] = int(jogador.usos[h]) + ORBES.usos_extras(h)
	usos_max = jogador.usos.duplicate()

# ------------------------------------------------------------ montagem
func criar_inimigo(spec: Dictionary) -> Lutador:
	var l := Lutador.new()
	l.id = _prox_id
	_prox_id += 1
	l.sprite = spec["sprite"]
	l.categoria = spec["categoria"]
	l.nivel = int(spec["nivel"])
	var ficha: Dictionary = Artes.dados_inimigos()["inimigos"].get(l.sprite, {})
	l.nome = ficha.get("nome", l.sprite)
	l.elemento = ficha.get("elemento", "") if ficha.get("elemento") != null else ""
	l.tamanho = int(ficha.get("tamanho", 48))
	var tipo := l.sprite
	if l.categoria == "suprema":
		tipo = Catalogo.SUPREMAS[l.sprite]
	elif l.categoria != "chefe" and l.sprite != "urso_de_barranco":
		for suf in ["_comum", "_veterano", "_elite"]:
			if tipo.ends_with(suf):
				tipo = tipo.substr(0, tipo.length() - suf.length())
		tipo = Catalogo.tipo_do_sprite(tipo)
	l.tipo = tipo
	var t: Dictionary = Catalogo.TIPOS[tipo]
	l.familia = t["fam"]
	var n: int = {"comum": 2, "veterano": 3, "elite": 4, "suprema": 4, "chefe": 99}[l.categoria]
	if tipo in ["urso_de_barranco", "besta_sem_nome"]:
		n = 4
	for h in t["hab"].slice(0, n):
		l.habilidades.append(Catalogo.HAB_LEBRE.get(l.elemento, "golpe") if h == "*lebre" else h)
	if not l.habilidades.any(func(h): return Catalogo.HAB[h].has("poder") and Catalogo.HAB[h]["cat"] == "comum"):
		l.habilidades.append("golpe")      # sempre tem um ataque sem limite de usos
	l.definir_atributos(Catalogo.MODELO_PAPEL[t["papel"]])
	var m: Array = Catalogo.MULT[l.categoria]
	l.vida_max = int(round(120 * l.fator * m[0]))
	l.vida = l.vida_max
	l.mult_dano = m[1]
	if spec.get("reforcado", false):
		# QR raro: a Elite vem reforçada como Elite Suprema (Vida e dano da Suprema)
		var ms: Array = Catalogo.MULT["suprema"]
		l.vida_max = int(round(120 * l.fator * ms[0]))
		l.vida = l.vida_max
		l.mult_dano = ms[1]
	if dificuldade != 1.0:
		l.vida_max = int(round(l.vida_max * dificuldade))
		l.vida = l.vida_max
		l.mult_dano *= dificuldade
	l.rodada_entrada = rodada
	l.preparar_usos()
	if USOS_INIMIGO.has(l.categoria):
		var u: Dictionary = USOS_INIMIGO[l.categoria]
		for h: String in l.usos:
			var cat := str(Catalogo.HAB[h]["cat"])
			if u.has(cat):
				l.usos[h] = int(u[cat])
	vistos.append(l)
	return l

func iniciar() -> Array:
	_ev = []
	_entrar_onda(0)
	return _ev

func _entrar_onda(i: int) -> void:
	onda_atual = i
	inimigos = []
	_emitir({"t": "onda", "n": i + 1, "total": ondas.size()})
	var n: int = ondas[i].size()
	for spec in ondas[i]:
		var l := criar_inimigo(spec)
		if l.categoria in ["comum", "veterano"] and GRUPO.has(n):
			l.vida_max = int(round(l.vida_max * GRUPO[n]))
			l.vida = l.vida_max
			if not sem_grupo:
				l.mult_dano *= GRUPO[n]
		inimigos.append(l)
		_emitir({"t": "entra", "l": l})

## Guarda o evento junto com as condições de cada lutador NAQUELE momento, para a tela mostrar os ícones
## no tempo certo (o Motor resolve a rodada inteira antes da animação).
func _emitir(e: Dictionary) -> void:
	var foto := {}
	var todos: Array = [jogador]
	todos.append_array(inimigos)
	for l: Lutador in todos:
		if l != null:
			foto[l] = l.icones_condicao()
	e["conds"] = foto
	_ev.append(e)

func vivos() -> Array:
	return inimigos.filter(func(l): return l.vivo())

func _oponentes(l: Lutador) -> Array:
	return vivos() if l.eh_jogador else ([jogador] if jogador.vivo() else [])

func _aliados(l: Lutador) -> Array:
	return [jogador] if l.eh_jogador else vivos()

# ------------------------------------------------------------ rodada
## acao do jogador: {"hab": id, "alvo": Lutador} ou {"pocao": id}
func jogar_rodada(acao: Dictionary) -> Array:
	_ev = []
	var lista: Array = []
	var a := acao.duplicate()
	a["ator"] = jogador
	a["prio"] = acao.has("pocao") or (acao.has("hab") and Catalogo.HAB[acao["hab"]].get("prio", false))
	lista.append(a)
	for ini in vivos():
		var esc := _escolher(ini)
		esc["ator"] = ini
		esc["prio"] = Catalogo.HAB[esc["hab"]].get("prio", false)
		lista.append(esc)
	for x in lista:
		x["ator"].agiu = false
		x["ator"].perde_acao = false
	lista.sort_custom(_antes)
	for x in lista:
		if fim != "" or not jogador.vivo() or vivos().is_empty() or despertar_pendente:
			break
		_executar(x)
	if despertar_pendente:
		rodada += 1             # o herói caiu: nada de queimadura nem fim de rodada até o Despertar
	else:
		_fim_da_rodada()
	return _ev

func _antes(a: Dictionary, b: Dictionary) -> bool:
	if a["prio"] != b["prio"]:
		return a["prio"]
	var ag_a: float = a["ator"].agilidade_efetiva()
	var ag_b: float = b["ator"].agilidade_efetiva()
	if not is_equal_approx(ag_a, ag_b):
		return ag_a > ag_b
	return a["ator"].id < b["ator"].id      # empate: o jogador (id 0) age primeiro

## Ordem prevista da próxima rodada (para a fila "VEZ" no topo da tela).
func ordem_prevista() -> Array:
	var todos: Array = [jogador]
	todos.append_array(vivos())
	todos.sort_custom(_mais_rapido)
	return todos

func _mais_rapido(a: Lutador, b: Lutador) -> bool:
	if not is_equal_approx(a.agilidade_efetiva(), b.agilidade_efetiva()):
		return a.agilidade_efetiva() > b.agilidade_efetiva()
	return a.id < b.id

func _executar(x: Dictionary) -> void:
	var ator: Lutador = x["ator"]
	if not ator.vivo():
		return
	ator.guarda = false
	ator.exposto = false
	ator.contragolpe = false
	if ator.perde_acao:
		_emitir({"t": "msg", "k": "MSG_INTERROMPIDO", "a": [ator]})
		ator.agiu = true
		return
	if ator.tem("atordoado") and rng.randf() < 0.30:
		_emitir({"t": "msg", "k": "MSG_ATORDOADO", "a": [ator]})
		ator.agiu = true
		return
	if x.has("pocao"):
		_usar_pocao(x["pocao"])
		ator.agiu = true
		return
	_realizar(ator, x["hab"], x.get("alvo"))

## Faz a habilidade acontecer (sem checar atordoamento: usado também nas reações dos chefes).
func _realizar(ator: Lutador, hab: String, alvo_escolhido) -> void:
	if not ator.pode_usar(hab):
		hab = "golpe"
	if ator.usos_de(hab) > 0:
		ator.usos[hab] -= 1
	var h: Dictionary = Catalogo.HAB[hab]
	_emitir({"t": "acao", "l": ator, "hab": hab})
	var alvos: Array = []
	match h["alvo"]:
		"inimigo":
			var opo := _oponentes(ator)
			var alvo = alvo_escolhido
			if alvo == null or not (alvo in opo):
				alvo = opo[0] if not opo.is_empty() else null
			if alvo != null:
				alvos = [alvo]
		"inimigos":
			alvos = _oponentes(ator)
		"si":
			alvos = [ator]
		"aliado":
			var al = alvo_escolhido
			alvos = [al if al != null and al.vivo() else ator]
		"aliados":
			alvos = _aliados(ator)
	if h.has("poder"):
		var extra: String = h.get("extra", "")
		var acertou_principal := false
		for alvo in alvos:
			var golpes := int(h.get("golpes", 1))
			var acertou_alvo := false
			for g in golpes:
				if not alvo.vivo():
					break
				var acertou := _golpe(ator, alvo, hab, float(h["poder"]))
				acertou_alvo = acertou_alvo or acertou
				if acertou and alvo.vivo():
					_efeitos_do_acerto(ator, alvo, h)
			if alvo == alvos[0]:
				acertou_principal = acertou_alvo
			# só consome a condição (ex.: Detonação → Queimadura) se o golpe acertou
			if acertou_alvo and h.has("consome") and alvo.conds.has(h["consome"]):
				alvo.conds.erase(h["consome"])
				_emitir({"t": "atualiza"})
		# a corrente só salta para os outros se acertou o primeiro alvo
		if extra == "cadeia" and acertou_principal and ator.vivo():
			var outros := _oponentes(ator).filter(func(o): return o != alvos[0])
			for o in outros.slice(0, 2):
				_golpe(ator, o, hab, 90.0)
		if extra == "exposto":
			ator.exposto = true
	else:
		for alvo in alvos:
			if h.has("cond"):
				_aplicar(alvo, h["cond"], ator)
			if h.has("escudo"):
				var esc: float = h["escudo"] / 100.0 * ator.ressonancia_efetiva() * (ORBES.fator(hab) if ator.eh_jogador else 1.0)
				_aplicar(alvo, "escudo", ator, {"valor": esc, "reflexo": h.get("reflexo", "")})
			if h.has("cura"):
				var cura: float = alvo.vida_max * h["cura"] / 100.0 * (ORBES.fator(hab) if ator.eh_jogador else 1.0)
				_curar(alvo, int(round(cura)))
			if h.get("extra", "") == "purifica1" and not alvo.negativas().is_empty():
				alvo.conds.erase(alvo.negativas()[0])
				_emitir({"t": "atualiza"})
			if h.has("cond_si"):
				var dados: Dictionary = {"esquiva": 0.15} if h.get("extra", "") == "pluma" else {}
				_aplicar(alvo, h["cond_si"], ator, dados)
			if h.has("cond_si2"):
				_aplicar(alvo, h["cond_si2"], ator)
		match h.get("extra", ""):
			"guarda":
				ator.guarda = true
				if ator.eh_jogador and rodada == 1:
					guarda_rodada1 = true
				_emitir({"t": "atualiza"})
			"contragolpe":
				ator.contragolpe = true
				_emitir({"t": "atualiza"})
			"devolve_uso":
				_devolver_usos(ator, 1)
			"invoca":
				if vivos().size() < 3:
					var l := criar_inimigo({"sprite": h["invoca"], "categoria": "comum", "nivel": ator.nivel})
					inimigos.append(l)
					_emitir({"t": "entra", "l": l})
	ator.agiu = true

func _efeitos_do_acerto(ator: Lutador, alvo: Lutador, h: Dictionary) -> void:
	if h.has("cond"):
		_aplicar(alvo, h["cond"], ator)
	match h.get("extra", ""):
		"tira_positivo":
			if not alvo.positivas().is_empty():
				alvo.conds.erase(alvo.positivas()[0])
				_emitir({"t": "atualiza"})
		"interrompe":
			if not alvo.agiu:
				alvo.perde_acao = true

## Parte fixa do dano (sem erro, crítico nem escudo): [valor, multiplicador do elemento].
## Usada pelo golpe de verdade e pela previsão mostrada ao jogador.
func _calcular_dano(ator: Lutador, alvo: Lutador, hab: String, poder: float) -> Array:
	var h: Dictionary = Catalogo.HAB[hab]
	var atributo: float = ator.forca if h.get("base", "F") == "F" else ator.ressonancia_efetiva()
	var bruto := poder / 100.0 * atributo
	if ator.eh_jogador:
		bruto *= ORBES.fator(hab)       # habilidade melhorada pelo Orbe (+20% por melhoria)
	if h.get("extra", "") == "sentenca":
		bruto += ator.resistencia_efetiva()
	var mult := ator.mult_dano
	if ator.tem("furia"):
		mult *= 1.3
	if ator.tem("p_sangue"):
		mult *= 1.3
	if ator.tem("enfraquecido"):
		mult *= 0.75
	var maior_bonus := 0.0
	for c in h.get("bonus", {}):
		if alvo.tem(c):
			maior_bonus = max(maior_bonus, float(h["bonus"][c]))
	mult *= 1.0 + maior_bonus / 100.0
	if ator.eh_jogador and h.get("el", "") != "":
		mult *= 1.0 + float(ator.bonus_el.get(h["el"], 0)) / 100.0
	if h.get("extra", "") == "punho" and (ator.tem("escudo") or ator.tem("fortificado")):
		mult *= 1.2
	if ator.familia == "bandidos":
		var outros := vivos().filter(func(o): return o != ator and o.familia == "bandidos").size()
		mult *= 1.0 + 0.1 * min(outros, 2)
	if ator.familia == "locais" and rodada - ator.rodada_entrada < 2 and not guarda_rodada1:
		mult *= TERRITORIO
	var res := alvo.resistencia_efetiva()
	var reducao: float = min(0.75, res / (res + 50.0 * ator.fator))
	var v := bruto * mult * (1.0 - reducao)
	# DEFINIDO (João, 2026-11-13): só habilidade de elemento tem vantagem/resistência (±25%), pelo elemento
	# da habilidade; ataques comuns (sem elemento) batem sempre normal
	var el_hab := str(h.get("el", ""))
	var el := Catalogo.vantagem(el_hab, alvo.elemento) if el_hab != "" else 1.0
	v *= el
	if alvo.guarda:
		v *= 0.5
	if alvo.exposto:
		v *= 1.2
	if alvo.tem("campo"):
		v *= 0.8
	if alvo.familia == "soldados" and alvo.tipo != "escudeiro_gelo":
		if _aliados(alvo).any(func(o): return o.tipo == "escudeiro_gelo" and o != alvo):
			v *= 0.85
	return [v, el]

## Previsão do dano de uma habilidade do jogador num alvo (sem crítico; por golpe e total).
## Pedido do João (2026-11-13): a caixinha do ataque mostra o dano final no inimigo.
func prever_dano(ator: Lutador, alvo: Lutador, hab: String) -> Dictionary:
	var h: Dictionary = Catalogo.HAB.get(hab, {})
	if not h.has("poder") or alvo == null:
		return {}
	var calc := _calcular_dano(ator, alvo, hab, float(h["poder"]))
	var um: int = max(1, int(round(float(calc[0]))))
	var golpes := int(h.get("golpes", 1))
	var chance: float = min(0.5, 0.05 + 0.01 * ator.base(ator.percepcao)) + float(h.get("crit", 0.0))
	if ator.tem("p_falcao"):
		chance += 0.15
	if ator.tem("sobrecarga"):
		chance = 1.0
	# bônus que já entraram na conta (para o jogador ver de onde vem o número)
	var mods: Array = []
	if ator.eh_jogador and ORBES.vezes_melhorada(hab) > 0:
		mods.append(["orbe", int(round((ORBES.fator(hab) - 1.0) * 100.0))])
	if ator.eh_jogador and h.get("el", "") != "" and int(ator.bonus_el.get(h["el"], 0)) > 0:
		mods.append(["equip", int(ator.bonus_el.get(h["el"], 0))])
	for c in ["furia", "p_sangue", "p_ressonancia", "enfraquecido"]:
		if ator.tem(c):
			mods.append([c, 0])
	return {"golpe": um, "golpes": golpes, "total": um * golpes, "ef": calc[1], "mods": mods,
		"critico": max(1, int(round(float(calc[0]) * ator.mult_crit))) * golpes, "chance": int(round(minf(1.0, chance) * 100.0))}

## Um golpe: erro/esquiva, dano, escudo, crítico, reações. Devolve se acertou.
func _golpe(ator: Lutador, alvo: Lutador, hab: String, poder: float) -> bool:
	var h: Dictionary = Catalogo.HAB[hab]
	if not h.get("certeiro", false):
		var erro: float = max(0.0, 0.08 - 0.004 * ator.base(ator.percepcao))
		var esquiva: float = 0.002 * alvo.base(alvo.agilidade)
		if alvo.tem("impeto"):
			esquiva += float(alvo.conds["impeto"].get("esquiva", 0.0))
		if rng.randf() < erro + esquiva:
			_emitir({"t": "erro", "l": alvo})
			return false
	var calc := _calcular_dano(ator, alvo, hab, poder)
	var v: float = calc[0]
	var el: float = calc[1]
	var chance: float = min(0.5, 0.05 + 0.01 * ator.base(ator.percepcao)) + float(h.get("crit", 0.0))
	if ator.tem("p_falcao"):
		chance += 0.15
	var critico := rng.randf() < chance
	if ator.tem("sobrecarga"):
		critico = true
		ator.conds.erase("sobrecarga")
	if ator.tipo == "thessa_vurn" and alvo.tem("marcado"):
		critico = true
		alvo.conds.erase("marcado")
	if critico:
		v *= ator.mult_crit
	var dano: int = max(1, int(round(v)))
	var absorvido := 0
	if alvo.tem("escudo"):
		var e: Dictionary = alvo.conds["escudo"]
		absorvido = min(dano, int(e["valor"]))
		e["valor"] = float(e["valor"]) - absorvido
		dano -= absorvido
		if e.get("reflexo", "") != "":
			var fonte = e.get("fonte")
			var r_fonte: float = fonte.ressonancia_efetiva() if fonte != null else 0.0
			_aplicar(ator, e["reflexo"], fonte, {"valor": 0.4 * r_fonte})
		if float(e["valor"]) <= 0.0:
			alvo.conds.erase("escudo")
	alvo.vida = max(_piso(alvo), alvo.vida - dano)
	if alvo.eh_jogador and piso_jogador > 0 and alvo.vida <= piso_jogador:
		despertar_pendente = true
	_emitir({"t": "dano", "l": alvo, "v": dano, "abs": absorvido, "crit": critico, "ef": el, "fonte": ator, "vida": alvo.vida})
	if h.get("extra", "") == "crit_atordoa" and critico and alvo.vivo():
		_aplicar(alvo, "atordoado", ator)
	if alvo.vivo() and alvo.tem("campo") and rng.randf() < 0.30:
		_aplicar(ator, "atordoado", alvo)
	if h.has("dreno") and dano > 0:
		_curar(ator, int(round(dano * float(h["dreno"]))))
	if alvo.contragolpe and alvo.vivo() and ator.vivo():
		alvo.contragolpe = false
		_emitir({"t": "msg", "k": "MSG_CONTRAGOLPE", "a": [alvo]})
		_golpe(alvo, ator, "golpe", 150.0)
	_depois_do_dano(alvo, ator)
	return true

func _depois_do_dano(alvo: Lutador, ator) -> void:
	if not alvo.vivo():
		_emitir({"t": "queda", "l": alvo})
		if not alvo.eh_jogador:
			derrotados.append(alvo)
			# Herança da Geada (criados de gelo): Fortificado num aliado, exceto golpe final de Fogo
			if alvo.familia in ["glaciais", "soldados"] and (ator == null or ator.elemento != "fogo"):
				var al := vivos()
				if not al.is_empty():
					_aplicar(al[rng.randi_range(0, al.size() - 1)], "fortificado", alvo)
		return
	var metade := alvo.vida * 2 <= alvo.vida_max
	if metade and alvo.familia == "anomalas" and not alvo.frenesi_usado:
		alvo.frenesi_usado = true
		_emitir({"t": "msg", "k": "MSG_FRENESI", "a": [alvo]})
		_aplicar(alvo, "furia", alvo)
	if metade and alvo.categoria == "chefe" and not alvo.fase2:
		alvo.fase2 = true
		_emitir({"t": "msg", "k": "MSG_FASE2", "a": [alvo]})
		var t: Dictionary = Catalogo.TIPOS[alvo.tipo]
		for h in t.get("fase2", []):
			if not (h in alvo.habilidades):
				alvo.habilidades.append(h)
				var cat: String = Catalogo.HAB[h]["cat"]
				alvo.usos[h] = Catalogo.USOS.get(cat, -1)
		match alvo.tipo:
			"semeadora_velada":
				_aplicar(alvo, "furia", alvo)
			"thessa_vurn":
				_realizar(alvo, "chamar_atirador", null)
			"ysmera":
				_realizar(alvo, "silencio_absoluto", null)

func _aplicar(alvo: Lutador, c: String, fonte, dados := {}) -> void:
	var d := dados.duplicate()
	d["fonte"] = fonte
	if c == "queimadura" and not d.has("valor"):
		d["valor"] = 0.4 * (fonte.ressonancia_efetiva() if fonte != null else 0.0)
		if fonte != null and not fonte.eh_jogador:
			d["valor"] = float(d["valor"]) * fonte.mult_dano
	if alvo.aplicar(c, d):
		_emitir({"t": "cond", "l": alvo, "c": c})

func _curar(alvo: Lutador, valor: int) -> void:
	if not alvo.eh_jogador:
		valor = int(round(valor * CURA_INIMIGO))
	var antes := alvo.vida
	alvo.vida = min(alvo.vida_max, alvo.vida + valor)
	if alvo.vida > antes:
		_emitir({"t": "cura", "l": alvo, "v": alvo.vida - antes, "vida": alvo.vida})

func _devolver_usos(l: Lutador, quantos: int) -> void:
	# devolve à habilidade de elemento mais gasta
	var melhor := ""
	var falta := 0
	for h in l.usos:
		var maxu := int(usos_max.get(h, -1)) if l.eh_jogador else -1
		if maxu > 0 and maxu - int(l.usos[h]) > falta:
			falta = maxu - int(l.usos[h])
			melhor = h
	if melhor != "":
		l.usos[melhor] = min(int(usos_max[melhor]), int(l.usos[melhor]) + quantos)
		_emitir({"t": "atualiza"})

# ------------------------------------------------------------ poções (Mobile · Poções)
const POCAO_TEMPORARIA := {"tonico_de_reflexo": "p_reflexo", "sangue_quente": "p_sangue", "elixir_de_granito": "p_granito",
	"olho_de_falcao": "p_falcao", "elixir_de_ressonancia": "p_ressonancia"}

func pocao_serve(id: String) -> bool:
	if int(pocoes.get(id, 0)) <= 0:
		return false
	if POCAO_TEMPORARIA.has(id):
		return not jogador.tem(POCAO_TEMPORARIA[id]) and jogador.contar(true) < 2
	match id:
		"elixir_purificador":
			return not jogador.negativas().is_empty()
		"essencia_de_eco", "frasco_de_ressonancia":
			return usos_max.keys().any(func(h): return int(usos_max[h]) > 0 and int(jogador.usos[h]) < int(usos_max[h]))
	return true

func _usar_pocao(id: String) -> void:
	pocoes[id] = int(pocoes.get(id, 0)) - 1
	if int(pocoes[id]) <= 0:
		pocoes.erase(id)
	_emitir({"t": "pocao", "l": jogador, "id": id})
	var j := jogador
	match id:
		"pocao_de_vida_i":
			_curar(j, int(round(j.vida_max * 0.25)))
		"pocao_de_vida_ii":
			_curar(j, int(round(j.vida_max * 0.40)))
		"pocao_de_vida_iii":
			_curar(j, int(round(j.vida_max * 0.60)))
		"remedio_de_estrada":
			_curar(j, int(round(j.vida_max * 0.20)))
			if not j.negativas().is_empty():
				j.conds.erase(j.negativas()[0])
		"elixir_purificador":
			for c in j.negativas():
				j.conds.erase(c)
		"essencia_de_eco":
			_devolver_usos(j, 99)
		"frasco_de_ressonancia":
			for h in usos_max:
				if int(usos_max[h]) > 0:
					j.usos[h] = usos_max[h]
		_:
			if POCAO_TEMPORARIA.has(id):
				_aplicar(j, POCAO_TEMPORARIA[id], j)
	_emitir({"t": "atualiza"})

# ------------------------------------------------------------ fim da rodada
func _fim_da_rodada() -> void:
	var todos: Array = [jogador]
	todos.append_array(vivos())
	for l in todos:
		# acabou a luta (todos os inimigos caíram ou o herói caiu): nada de efeitos de fim de rodada
		if not jogador.vivo() or vivos().is_empty():
			break
		if not l.vivo():
			continue
		if l.tem("queimadura"):
			var d: int = max(1, int(round(float(l.conds["queimadura"].get("valor", 1.0)))))
			l.vida = max(_piso(l), l.vida - d)
			_emitir({"t": "dano", "l": l, "v": d, "abs": 0, "crit": false, "ef": 1.0, "fonte": null, "queimadura": true, "vida": l.vida})
			_depois_do_dano(l, l.conds["queimadura"].get("fonte"))
		if l.vivo() and l.tem("regeneracao"):
			_curar(l, int(round(l.vida_max * REGENERACAO)))
		if l.vivo() and l.tipo == "semeadora_velada" and vivos().any(func(o): return o.tipo == "brotado"):
			_curar(l, int(round(l.vida_max * 0.05)))
	for l in todos:
		for c in l.conds.keys():
			l.conds[c]["turnos"] -= 1
			if l.conds[c]["turnos"] <= 0:
				l.conds.erase(c)
	_emitir({"t": "atualiza"})
	rodada += 1
	if not jogador.vivo():
		fim = "derrota"
		_emitir({"t": "fim", "vitoria": false})
	elif vivos().is_empty():
		if onda_atual + 1 < ondas.size():
			_entrar_onda(onda_atual + 1)
		else:
			fim = "vitoria"
			_emitir({"t": "fim", "vitoria": true})

# ------------------------------------------------------------ inteligência dos inimigos
func _escolher(ini: Lutador) -> Dictionary:
	var t: Dictionary = Catalogo.TIPOS[ini.tipo]
	if t.has("propria"):
		ini.vez_propria += 1
		if ini.vez_propria % int(t["a_cada"]) == 0:
			var p: String = t["propria"]
			var serve := true
			if Catalogo.HAB[p].get("extra", "") == "invoca":
				serve = vivos().size() < 3
			if p == "marca_de_caca":
				serve = not jogador.tem("marcado")
			if serve:
				return {"hab": p, "alvo": jogador}
	var opcoes: Array = []
	var pesos: Array = []
	var aliados := vivos()
	for h in ini.habilidades:
		if not ini.pode_usar(h):
			continue
		var H: Dictionary = Catalogo.HAB[h]
		var w := 1.0
		if not H.has("poder"):
			if H.has("cura"):
				w = 4.0 if aliados.any(func(a): return a.vida < a.vida_max * 0.5) else 0.0
			elif H.has("escudo"):
				w = 0.0 if ini.tem("escudo") or ini.contar(true) >= 2 else 1.2
			elif H.get("extra", "") == "purifica1":
				w = 3.0 if aliados.any(func(a): return not a.negativas().is_empty()) else 0.0
			elif H.has("cond_si"):
				w = 0.0 if ini.tem(H["cond_si"]) or ini.contar(true) >= 2 else 1.0
			elif H.get("extra", "") == "guarda":
				w = 0.5
			elif H.get("extra", "") == "contragolpe":
				w = 0.7
			elif H.has("cond"):
				w = 0.0 if jogador.tem(H["cond"]) or jogador.contar(false) >= 2 or jogador.tem("firmeza") else 1.5
			else:
				w = 0.3
		else:
			w = 2.0 if H["cat"] != "comum" else 1.0
		if w > 0.0:
			opcoes.append(h)
			pesos.append(w)
	if opcoes.is_empty():
		return {"hab": "golpe", "alvo": jogador}
	var soma := 0.0
	for p in pesos:
		soma += p
	var r := rng.randf() * soma
	var escolha: String = opcoes[-1]
	for i in opcoes.size():
		r -= pesos[i]
		if r <= 0.0:
			escolha = opcoes[i]
			break
	var alvo = jogador
	if Catalogo.HAB[escolha]["alvo"] == "aliado":
		alvo = ini
		for a in aliados:
			if not a.negativas().is_empty():
				alvo = a
				break
	return {"hab": escolha, "alvo": alvo}

## Escolha automática do jogador (combate automático ao rejogar fases vencidas).
func escolher_automatico() -> Dictionary:
	if jogador.vida < jogador.vida_max * 0.3 and pocao_serve("pocao_de_vida_i"):
		return {"pocao": "pocao_de_vida_i"}
	var melhor := "golpe"
	var maior := 0.0
	for h in jogador.habilidades:
		var H: Dictionary = Catalogo.HAB[h]
		if jogador.pode_usar(h) and H.has("poder"):
			var p := float(H["poder"]) * (jogador.ressonancia if H.get("base", "F") == "R" else jogador.forca) * int(H.get("golpes", 1))
			if H["alvo"] == "inimigos":
				p *= vivos().size()
			if p > maior:
				maior = p
				melhor = h
	var alvo = vivos().reduce(func(a, b): return a if a.vida <= b.vida else b) if not vivos().is_empty() else null
	return {"hab": melhor, "alvo": alvo}

## O Despertar no meio do tutorial: elemento, modelo de atributos e a nova habilidade no lugar de um comum.
func despertar(elemento: String, nova: String, sai: String) -> void:
	var j := jogador
	j.elemento = elemento
	j.definir_atributos(Catalogo.MODELO_JOGADOR[elemento])
	Equipamento.aplicar(j, false)
	var i := j.habilidades.find(sai)
	if i < 0:
		i = j.habilidades.size() - 1
	j.habilidades[i] = nova
	j.usos.erase(sai)
	j.usos[nova] = Catalogo.USOS[Catalogo.HAB[nova]["cat"]]
	usos_max = j.usos.duplicate()
	j.vida = j.vida_max             # PROVISÓRIO: o Despertar devolve a Vida cheia, para a nova habilidade decidir a luta
	piso_jogador = 0
	piso_inimigos = 0
	despertar_pendente = false

## Continuar com vídeo (DEFINIDO): o herói volta com 50% da Vida e os usos de habilidade como estavam.
func reviver(fracao: float) -> void:
	jogador.vida = maxi(1, int(round(jogador.vida_max * fracao)))
	fim = ""
