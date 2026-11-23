extends RefCounted
## Orbes de cada elemento: nível, evolução com fragmentos, Orbes novos e as escolhas de habilidade.
## Uso por preload (sem class_name, para o editor não precisar reescanear):
##   const ORBES := preload("res://scripts/orbes.gd")
## Regras (Mobile · Progressão):
##   - o Orbe do próprio elemento vem no Despertar (nível 1);
##   - evoluir do nível n−1 ao n custa CUSTO_NIVEL[n] fragmentos DAQUELE elemento e pede o nível
##     nivel_minimo_para(n) do jogador; nível máximo 10;
##   - Orbe novo: CUSTO_NOVO fragmentos do elemento dele, na ordem em que são obtidos (pede NIVEL_NOVO);
##     depois evolui da mesma forma que o do elemento base;
##   - cada nível de Orbe: +2 pontos base de Ressonância e +1 uso nas habilidades daquele elemento;
##   - a cada nível escolhe UMA: melhorar uma habilidade daquele elemento (+20% no efeito, acumula)
##     ou aprender uma nova; ao obter um Orbe novo já escolhe 1 habilidade dele.
##
## Revisão de 2026-11-22 (pedido do João: "mais viável desbloquear e evoluir"). PROVISÓRIO (meus números):
##   - custos de evolução ~40% dos antigos (300/500/800/1200/1700/2300/3000/3800/4700);
##   - nível do jogador para o nível n do Orbe: 5 + 5×(n−2) (era 15 + 10×(n−2)), porque o jogo agora
##     começa no nível 1 e a S1 termina perto do nível 23;
##   - Orbes novos: 60/100/160/240/340 fragmentos (eram 150/250/400/600/850) nos níveis 5/10/15/20/25
##     (eram 10/20/30/40/50);
##   - fragmentos das fases (FRAG_* abaixo) também subiram.
## Com isso a meta da S1 (Orbe base no nível 3–4 e 2 Orbes novos) fica ao alcance sem repetir fases demais.

const MAX_NIVEL := 10
## índice = nível que vai alcançar
const CUSTO_NIVEL := [0, 0, 120, 200, 320, 480, 680, 920, 1200, 1520, 1880]
const CUSTO_NOVO := [60, 100, 160, 240, 340]
const NIVEL_NOVO := [5, 10, 15, 20, 25]
const NIVEL_ORBE_BASE := 5         # nível do jogador para o Orbe chegar ao nível 2
const NIVEL_ORBE_PASSO := 5        # e mais 5 a cada nível seguinte do Orbe

## Fragmentos por vitória nas fases do mapa (PROVISÓRIO, revisão de 2026-11-22). Antes: 40% (50% com bandido
## de elemento) de 1–3 em toda fase; Elite e Suprema 5–10; chefe 15–25.
const FRAG_CHANCE := 0.6           # chance de fragmentos em qualquer fase
const FRAG_CHANCE_ELEMENTAL := 0.75   # com bandido de elemento na luta
const FRAG_SORTE := [2, 4]         # quantos, quando sai
const FRAG_FIXO := {"elite": [8, 14], "suprema": [12, 18], "chefe": [25, 35]}
const MELHORIA := 0.20

## {elemento: nível}. Cria o do elemento base para saves antigos.
static func todos() -> Dictionary:
	if not Jogo.dados.has("orbes") or typeof(Jogo.dados["orbes"]) != TYPE_DICTIONARY:
		Jogo.dados["orbes"] = {}
	var o: Dictionary = Jogo.dados["orbes"]
	var base := str(Jogo.dados.get("elemento", ""))
	if base != "" and not o.has(base):
		o[base] = 1
	return o

static func base() -> String:
	return str(Jogo.dados.get("elemento", ""))

static func nivel(el: String) -> int:
	return int(todos().get(el, 0))

static func fragmentos(el: String) -> int:
	var f: Dictionary = Jogo.dados["fragmentos"]
	return int(f.get(el, 0))

## Quantos Orbes novos (fora o do elemento base) o jogador já tem.
static func novos() -> int:
	var n := 0
	for el in todos():
		if str(el) != base():
			n += 1
	return n

static func nivel_minimo_para(n: int) -> int:
	return NIVEL_ORBE_BASE + NIVEL_ORBE_PASSO * (n - 2)

## Tudo que o popup precisa: {"tem", "nivel", "maximo", "acao" ("evoluir"/"obter"/""), "custo",
## "nivel_req", "falta_frag", "falta_nivel", "pode"}.
static func estado(el: String) -> Dictionary:
	var r := {"tem": false, "nivel": nivel(el), "maximo": false, "acao": "", "custo": 0, "nivel_req": 0}
	var jog := int(Jogo.dados["nivel"])
	if base() == "":
		r["pode"] = false
		return r
	if r["nivel"] > 0:
		r["tem"] = true
		if int(r["nivel"]) >= MAX_NIVEL:
			r["maximo"] = true
			r["pode"] = false
			return r
		var alvo := int(r["nivel"]) + 1
		r["acao"] = "evoluir"
		r["custo"] = CUSTO_NIVEL[alvo]
		r["nivel_req"] = nivel_minimo_para(alvo)
	else:
		var k := novos()
		if k >= CUSTO_NOVO.size():
			r["pode"] = false
			return r
		r["acao"] = "obter"
		r["custo"] = CUSTO_NOVO[k]
		r["nivel_req"] = NIVEL_NOVO[k]
	r["falta_frag"] = maxi(0, int(r["custo"]) - fragmentos(el))
	r["falta_nivel"] = jog < int(r["nivel_req"])
	r["pode"] = int(r["falta_frag"]) == 0 and not r["falta_nivel"] and pendente() == ""
	return r

## Paga e sobe (ou obtém) o Orbe. Deixa a escolha de habilidade pendente até o jogador escolher.
static func avancar(el: String) -> bool:
	var e := estado(el)
	if not e["pode"]:
		return false
	var f: Dictionary = Jogo.dados["fragmentos"]
	f[el] = fragmentos(el) - int(e["custo"])
	var o := todos()
	o[el] = int(e["nivel"]) + 1
	Jogo.dados["orbe_pendente"] = el
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	return true

## Elemento com escolha de habilidade em aberto ("" = nenhum).
static func pendente() -> String:
	return str(Jogo.dados.get("orbe_pendente", ""))

# ------------------------------------------------------------ habilidades
## As 6 habilidades do elemento (3 do Despertar + 3 dos Orbes), na ordem do catálogo.
static func habilidades_do(el: String) -> Array:
	var r: Array = []
	for h in Catalogo.HAB:
		var H: Dictionary = Catalogo.HAB[h]
		if str(H.get("el", "")) == el and str(H.get("cat", "")) in ["ofensiva", "defensiva", "utilitaria"]:
			r.append(h)
	return r

static func conhece(h: String) -> bool:
	return Jogo.habilidades_conhecidas().has(h)

static func melhorias() -> Dictionary:
	if not Jogo.dados.has("melhorias") or typeof(Jogo.dados["melhorias"]) != TYPE_DICTIONARY:
		Jogo.dados["melhorias"] = {}
	return Jogo.dados["melhorias"]

static func vezes_melhorada(h: String) -> int:
	return int(melhorias().get(h, 0))

## PROVISÓRIO (meu): só dá para melhorar habilidade com número (dano, escudo ou cura); as que só põem
## condição não teriam o que aumentar.
static func melhoravel(h: String) -> bool:
	var H: Dictionary = Catalogo.HAB.get(h, {})
	return H.has("poder") or H.has("escudo") or H.has("cura")

## Opções da escolha pendente: {"aprender": [...], "melhorar": [...]}.
## No Orbe recém-obtido (nível 1) só há "aprender".
static func opcoes(el: String) -> Dictionary:
	var aprender: Array = []
	var melhorar: Array = []
	for h in habilidades_do(el):
		if conhece(h):
			if melhoravel(h):
				melhorar.append(h)
		else:
			aprender.append(h)
	if nivel(el) <= 1:
		melhorar = []
	return {"aprender": aprender, "melhorar": melhorar}

static func aprender(h: String) -> void:
	var g: Array = Jogo.dados.get("hab_guardadas", [])
	if not g.has(h) and not Jogo.habilidades().has(h):
		g.append(h)
	Jogo.dados["hab_guardadas"] = g
	_fechar_escolha()

static func melhorar(h: String) -> void:
	var m := melhorias()
	m[h] = int(m.get(h, 0)) + 1
	_fechar_escolha()

## Sem nada para escolher (tudo aprendido e nada melhorável): a escolha some sozinha.
static func pular_escolha() -> void:
	_fechar_escolha()

static func _fechar_escolha() -> void:
	Jogo.dados["orbe_pendente"] = ""
	Jogo.salvar()
	Jogo.progresso_mudou.emit()

# ------------------------------------------------------------ efeito no combate
## Pontos base de Ressonância vindos dos Orbes: +2 por nível; o nível 1 do Orbe base já é o começo.
static func pontos_ressonancia() -> int:
	var soma := 0
	var o := todos()
	for el in o:
		soma += int(o[el])
	return maxi(0, 2 * (soma - 1)) if base() != "" else 0

## Usos a mais de uma habilidade: +1 por nível acima do 1 do Orbe do elemento dela.
static func usos_extras(h: String) -> int:
	var el := str(Catalogo.HAB.get(h, {}).get("el", ""))
	if el == "":
		return 0
	return maxi(0, nivel(el) - 1)

## Multiplicador do efeito (dano, escudo, cura) de uma habilidade melhorada.
static func fator(h: String) -> float:
	return 1.0 + MELHORIA * vezes_melhorada(h)

# ------------------------------------------------------------ testes (só na versão ADM)
## Botão "Acumular Orbes (teste)": +1 nível em todos os Orbes que o jogador já tem e obtém os que faltam
## (nível 1), sem gastar fragmentos e sem pedir nível. As habilidades novas não são escolhidas aqui.
static func acumular_teste() -> void:
	if base() == "":
		return
	var o := todos()
	for el: String in Catalogo.ELEMENTOS:
		o[el] = mini(MAX_NIVEL, int(o.get(el, 0)) + 1)
	Jogo.salvar()
	Jogo.progresso_mudou.emit()

## Botão do popup do Orbe: evolui/obtém AGORA, sem custo e sem pedir nível, e abre a escolha de habilidade.
static func avancar_teste(el: String) -> bool:
	var e := estado(el)
	if base() == "" or e["maximo"] or pendente() != "":
		return false
	var o := todos()
	o[el] = int(e["nivel"]) + 1
	Jogo.dados["orbe_pendente"] = el
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	return true
