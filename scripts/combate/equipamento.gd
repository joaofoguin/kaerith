class_name Equipamento
extends RefCounted
## Equipamentos (etapa 6). Regras em Mobile · Progressão / Economia / Equipamentos:
## 5 espaços (arma, armadura, cabeça e 2 acessórios); atributo principal fixo pelo papel da peça,
## +2/+3/+5/+7/+10 pontos base por raridade; extras sorteados (Raro 1×+2, Épico 2×+2, Lendário 2×+3:
## atributo, +5% de Vida ou +10% no multiplicador de crítico); do Raro em diante a peça melhora as
## habilidades do seu elemento em +5%/+8%/+12%; conjunto com 3 peças +10% de Ressonância, com 5 +20%.
## Inventário sem limite; vender devolve 25% do preço; consumíveis não se vendem nem se excluem.
## Cada peça no save é uma instância: {"uid", "id", "extras": [{"tipo", "valor"}], "novo"}.

const ESPACOS := ["cabeca", "arma", "acessorio1", "armadura", "acessorio2"]
const PONTOS := {"comum": 2, "incomum": 3, "raro": 5, "epico": 7, "lendario": 10}
const EXTRAS := {"raro": [1, 2], "epico": [2, 2], "lendario": [2, 3]}        # quantidade, pontos
const HAB_EL := {"raro": 5, "epico": 8, "lendario": 12}
## Preço base (Loja: Comum 300, Incomum 600, Raro 1.500). Épico e Lendário não são vendidos na Loja;
## PROVISÓRIO meu: 3.000 e 6.000 só para calcular a venda (25%).
const PRECO := {"comum": 300, "incomum": 600, "raro": 1500, "epico": 3000, "lendario": 6000}
const ORDEM_RARIDADE := {"lendario": 0, "epico": 1, "raro": 2, "incomum": 3, "comum": 4}
const ATR := {"Força": "forca", "Percepção": "percepcao", "Agilidade": "agilidade", "Resistência": "resistencia", "Ressonância": "ressonancia"}
const ATRIBUTOS := ["forca", "percepcao", "agilidade", "resistencia", "ressonancia"]
const EL := {"Fogo": "fogo", "Água": "agua", "Terra": "terra", "Ar": "ar", "Raio": "raio", "Gelo": "gelo"}
const COR_RARIDADE := {"comum": Color("#b8b0a0"), "incomum": Color("#7fd07a"), "raro": Color("#5aa8ff"), "epico": Color("#c07cff"), "lendario": Color("#ffc24a")}

static var _fichas := {}
static var _visual := {}

static func _garantir() -> void:
	if not _fichas.is_empty():
		return
	for it in Artes.dados_itens()["itens"]:
		if str(it["papel"]) != "Poção":
			_fichas[it["id"]] = it
	var f := FileAccess.open("res://dados/equipado.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY:
			_visual = d

static func ficha(id: String) -> Dictionary:
	_garantir()
	return _fichas.get(id, {})

static func todos_ids() -> Array:
	_garantir()
	return _fichas.keys()

static func dados_visuais() -> Dictionary:
	_garantir()
	return _visual

## "arma", "armadura", "cabeca" ou "acessorio".
static func tipo_de(id: String) -> String:
	var p := str(ficha(id).get("papel", "")).split(" · ")[0]
	match p:
		"Arma":
			return "arma"
		"Armadura":
			return "armadura"
		"Cabeça":
			return "cabeca"
	return "acessorio"

static func atributo_de(id: String) -> String:
	var partes := str(ficha(id).get("papel", "")).split(" · ")
	return ATR.get(partes[1] if partes.size() > 1 else "", "forca")

static func elemento_de(id: String) -> String:
	var e = ficha(id).get("elemento")
	return EL.get(str(e), "") if e != null else ""

static func raridade_de(id: String) -> String:
	return str(ficha(id).get("raridade", "comum"))

static func conjunto_de(id: String) -> String:
	var c = ficha(id).get("conjunto")
	return str(c) if c != null else ""

static func preco_venda(id: String) -> int:
	return int(PRECO.get(raridade_de(id), 300) * 0.25)

## Ícone 32×32 como textura (recorte do atlas de itens).
static func icone(id: String) -> Texture2D:
	var p := Artes.icone(str(ficha(id).get("icone", "")))
	if p.is_empty():
		return null
	var at := AtlasTexture.new()
	at.atlas = p["tex"]
	var r: Rect2 = p["rect"]
	at.region = Rect2(r.position, Vector2(32, 32))
	return at

static func moldura(id: String) -> Texture2D:
	return load("res://artes/interface/moldura_%s.png" % raridade_de(id))

# ------------------------------------------------------------ inventário no save
static func _lista() -> Array:
	if not Jogo.dados.has("equipamentos"):
		Jogo.dados["equipamentos"] = []
	return Jogo.dados["equipamentos"]

static func _equipado() -> Dictionary:
	if not Jogo.dados.has("equipado") or typeof(Jogo.dados["equipado"]) != TYPE_DICTIONARY:
		Jogo.dados["equipado"] = {}
	return Jogo.dados["equipado"]

static func lista() -> Array:
	return _lista()

## Cria a peça com os extras sorteados e põe no inventário.
static func dar(id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rar := raridade_de(id)
	var extras: Array = []
	if EXTRAS.has(rar):
		var qtd: int = EXTRAS[rar][0]
		var pts: int = EXTRAS[rar][1]
		var opcoes: Array = ATRIBUTOS.duplicate()
		opcoes.append_array(["vida", "critico"])
		opcoes.shuffle()
		for i in qtd:
			var t: String = opcoes[i]
			var valor := pts
			if t == "vida":
				valor = 5
			elif t == "critico":
				valor = 10
			extras.append({"tipo": t, "valor": valor})
	var uid := int(Jogo.dados.get("prox_uid", 1))
	Jogo.dados["prox_uid"] = uid + 1
	var peca := {"uid": uid, "id": id, "extras": extras, "novo": true}
	_lista().append(peca)
	return peca

## Peça aleatória de uma raridade (e elemento, do Raro em diante). Vazio = qualquer.
static func sortear(raridade: String, elemento := "") -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var candidatos: Array = []
	for id in todos_ids():
		if raridade_de(id) != raridade:
			continue
		if elemento != "" and elemento_de(id) != "" and elemento_de(id) != elemento:
			continue
		candidatos.append(id)
	if candidatos.is_empty():
		return ""
	return candidatos[rng.randi_range(0, candidatos.size() - 1)]

static func peca(uid: int) -> Dictionary:
	for p in _lista():
		if int(p["uid"]) == uid:
			return p
	return {}

static func uid_em(espaco: String) -> int:
	return int(_equipado().get(espaco, -1))

static func em(espaco: String) -> Dictionary:
	var u := uid_em(espaco)
	return peca(u) if u >= 0 else {}

static func espaco_de_uid(uid: int) -> String:
	var eq := _equipado()
	for e in eq:
		if int(eq[e]) == uid:
			return str(e)
	return ""

## Espaços onde a peça pode entrar.
static func espacos_para(id: String) -> Array:
	var t := tipo_de(id)
	if t == "acessorio":
		return ["acessorio1", "acessorio2"]
	return [t]

static func equipar(uid: int, espaco: String) -> void:
	var eq := _equipado()
	var antigo := espaco_de_uid(uid)
	if antigo != "":
		eq.erase(antigo)
	eq[espaco] = uid
	var p := peca(uid)
	if not p.is_empty():
		p["novo"] = false

static func desequipar(espaco: String) -> void:
	_equipado().erase(espaco)

static func remover(uid: int) -> void:
	var e := espaco_de_uid(uid)
	if e != "":
		desequipar(e)
	var l := _lista()
	for i in l.size():
		if int(l[i]["uid"]) == uid:
			l.remove_at(i)
			return

static func vender(uid: int) -> int:
	var p := peca(uid)
	if p.is_empty():
		return 0
	var v := preco_venda(str(p["id"]))
	remover(uid)
	Jogo.dados["moedas"] = int(Jogo.dados["moedas"]) + v
	return v

# ------------------------------------------------------------ bônus
## Soma de tudo que está equipado: pontos base por atributo, % de Vida, crítico, bônus por elemento
## das habilidades e % de Ressonância dos conjuntos.
static func bonus() -> Dictionary:
	var pontos := {"forca": 0, "percepcao": 0, "agilidade": 0, "resistencia": 0, "ressonancia": 0}
	var vida := 0
	var critico := 0
	var hab_el := {}
	var conjuntos := {}
	for e in ESPACOS:
		var p := em(e)
		if p.is_empty():
			continue
		var id := str(p["id"])
		var rar := raridade_de(id)
		pontos[atributo_de(id)] += int(PONTOS.get(rar, 2))
		for x in p.get("extras", []):
			var t := str(x["tipo"])
			if t == "vida":
				vida += int(x["valor"])
			elif t == "critico":
				critico += int(x["valor"])
			elif pontos.has(t):
				pontos[t] += int(x["valor"])
		var el := elemento_de(id)
		if el != "" and HAB_EL.has(rar):
			hab_el[el] = int(hab_el.get(el, 0)) + int(HAB_EL[rar])
		var c := conjunto_de(id)
		if c != "":
			conjuntos[c] = int(conjuntos.get(c, 0)) + 1
	# Orbes: +2 pontos base de Ressonância por nível (entra junto com os pontos das peças)
	pontos["ressonancia"] += preload("res://scripts/orbes.gd").pontos_ressonancia()
	var ress := 0
	for c in conjuntos:
		if int(conjuntos[c]) >= 5:
			ress = maxi(ress, 20)
		elif int(conjuntos[c]) >= 3:
			ress = maxi(ress, 10)
	return {"pontos": pontos, "vida": vida, "critico": critico, "hab_el": hab_el, "ressonancia": ress, "conjuntos": conjuntos}

## Põe os bônus no herói da luta (depois de definir os atributos pelo nível).
static func aplicar(l: Lutador, com_vida := true) -> void:
	var b := bonus()
	var pts: Dictionary = b["pontos"]
	l.forca += pts["forca"] * l.fator
	l.percepcao += pts["percepcao"] * l.fator
	l.agilidade += pts["agilidade"] * l.fator
	l.resistencia += pts["resistencia"] * l.fator
	l.ressonancia = (l.ressonancia + pts["ressonancia"] * l.fator) * (1.0 + int(b["ressonancia"]) / 100.0)
	l.mult_crit = minf(2.5, 1.5 + int(b["critico"]) / 100.0)
	l.bonus_el = b["hab_el"]
	if com_vida:
		l.vida_max = int(round(l.vida_max * (1.0 + int(b["vida"]) / 100.0)))
		l.vida = l.vida_max

## Atributos que a ficha do personagem mostra (modelo do elemento × nível + equipamentos).
static func atributos_finais(modelo: Array, fator: float) -> Dictionary:
	var b := bonus()
	var pts: Dictionary = b["pontos"]
	var r := {}
	for i in ATRIBUTOS.size():
		var a: String = ATRIBUTOS[i]
		r[a] = (float(modelo[i]) + float(pts[a])) * fator
	r["ressonancia"] = r["ressonancia"] * (1.0 + int(b["ressonancia"]) / 100.0)
	r["vida"] = 120.0 * fator * (1.0 + int(b["vida"]) / 100.0)
	return r

## Camadas do herói para o que está equipado: {"arma": id, "armadura": id, "cabeca": id,
## "esconde_cabelo": bool, "corta_cabelo": bool}. Acessórios não aparecem no herói.
static func visual() -> Dictionary:
	var pecas: Dictionary = dados_visuais().get("pecas", {})
	var r := {"esconde_cabelo": false, "corta_cabelo": false}
	for e in ["arma", "armadura", "cabeca"]:
		var p := em(e)
		if p.is_empty() or not pecas.has(str(p["id"])):
			continue
		r[e] = str(p["id"])
		if e == "cabeca":
			var v: Dictionary = pecas[str(p["id"])]
			r["esconde_cabelo"] = bool(v.get("esconde_cabelo", false))
			r["corta_cabelo"] = bool(v.get("corta_cabelo", false))
	return r

## Texto curto de um extra ("+2 Força", "+5% Vida", "+10% crítico").
static func texto_extra(x: Dictionary) -> String:
	var t := str(x["tipo"])
	if t == "vida":
		return TranslationServer.translate("EQ_EXTRA_VIDA") % int(x["valor"])
	if t == "critico":
		return TranslationServer.translate("EQ_EXTRA_CRIT") % int(x["valor"])
	return "+%d %s" % [int(x["valor"]), TranslationServer.translate("ATR_" + t.to_upper())]
