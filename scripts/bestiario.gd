class_name Bestiario
extends RefCounted
## Bestiário e personagens do Diário (DEFINIDO): revela aos poucos. 1º encontro: nome, imagem e elemento;
## 3 vitórias: habilidades e fraquezas; vencer o Veterano e a Elite: uma frase da história cada.
## Os chefes de ato vão para a aba Personagens (com onde foram vistos pela primeira vez).
## PROVISÓRIO (meu): toda luta conta, inclusive tutorial, QR e Evento; "vitória" = cada inimigo da espécie
## derrotado; as frases da história ainda não existem (texto provisório BEST_FRASE_PENDENTE).

const CHEFES := ["mestre_calder", "semeadora_velada", "thessa_vurn", "ysmera"]
const VITORIAS_REVELA := 3

## Espécies do Bestiário, na ordem do jogo: [{id, chave do sprite de exibição, versões}]
static var _especies: Array = []

static func especies() -> Array:
	if not _especies.is_empty():
		return _especies
	var por_id := {}
	for chave: String in Artes.lista_inimigos():
		var f: Dictionary = Artes.dados_inimigos()["inimigos"][chave]
		var id := str(f["id"])
		if id in CHEFES:
			continue
		if not por_id.has(id):
			por_id[id] = {"id": id, "chave": chave, "versoes": {}}
			_especies.append(por_id[id])
		var v = f.get("versao")
		por_id[id]["versoes"][str(v) if v != null else "unica"] = chave
	return _especies

static func ficha(chave: String) -> Dictionary:
	return Artes.dados_inimigos()["inimigos"].get(chave, {})

static func dados() -> Dictionary:
	if not Jogo.dados.has("bestiario"):
		Jogo.dados["bestiario"] = {}
	return Jogo.dados["bestiario"]

static func personagens() -> Dictionary:
	if not Jogo.dados.has("personagens"):
		Jogo.dados["personagens"] = {}
	return Jogo.dados["personagens"]

static func registro(id: String) -> Dictionary:
	return dados().get(id, {})

static func vistas() -> int:
	return dados().size()

## Chamado no fim de toda luta. "onde" = "tutorial", "qr", "evento" ou o número da fase.
static func registrar(motor: Motor, onde: String, desde := 0) -> void:
	if motor == null:
		return
	var b := dados()
	var p := personagens()
	for l: Lutador in motor.vistos:
		var id := str(ficha(l.sprite).get("id", l.sprite))
		if l.categoria == "chefe" or id in CHEFES:
			if not p.has(id):
				p[id] = {"onde": onde, "novo": true}
			continue
		if not b.has(id):
			b[id] = {"vit": 0, "versoes": {}, "onde": onde, "novo": true}
	for l: Lutador in motor.derrotados.slice(desde):
		var id := str(ficha(l.sprite).get("id", l.sprite))
		if not b.has(id):
			continue
		var r: Dictionary = b[id]
		var antes := int(r["vit"])
		r["vit"] = antes + 1
		if antes < VITORIAS_REVELA and antes + 1 >= VITORIAS_REVELA:
			r["novo"] = true
		var vs: Dictionary = r["versoes"]
		if not vs.has(l.categoria) and l.categoria in ["veterano", "elite"]:
			r["novo"] = true
		vs[l.categoria] = int(vs.get(l.categoria, 0)) + 1

static func tem_novidade() -> bool:
	for r in dados().values():
		if bool(r.get("novo", false)):
			return true
	for r in personagens().values():
		if bool(r.get("novo", false)):
			return true
	return false

static func marcar_visto(id: String) -> void:
	var r: Dictionary = dados().get(id, personagens().get(id, {}))
	if bool(r.get("novo", false)):
		r["novo"] = false
		Jogo.salvar()

## Elementos que causam +25% contra este elemento.
static func fraquezas(elemento: String) -> Array:
	var r: Array = []
	if elemento == "":
		return r
	for el: String in Catalogo.VANTAGEM:
		if elemento in Catalogo.VANTAGEM[el]:
			r.append(el)
	return r

## Elementos que este elemento resiste (−25% de dano): os que ele vence.
static func resistencias(elemento: String) -> Array:
	return Catalogo.VANTAGEM.get(elemento, []).duplicate()

## Tipo do Catálogo para o sprite (mesma regra do Motor.criar_inimigo).
static func tipo_de(chave: String) -> String:
	if Catalogo.SUPREMAS.has(chave):
		return Catalogo.SUPREMAS[chave]
	if chave == "urso_de_barranco" or Catalogo.TIPOS.has(chave):
		return chave
	var tipo := chave
	for suf in ["_comum", "_veterano", "_elite"]:
		if tipo.ends_with(suf):
			tipo = tipo.substr(0, tipo.length() - suf.length())
	return Catalogo.tipo_do_sprite(tipo)

## Ataques da espécie com a versão a partir da qual aparecem (Comum usa 2, Veterano 3, Elite 4;
## versões únicas e Supremas usam os 4 desde o começo): [{id, desde}].
static func habilidades_de(chave: String) -> Array:
	var tipo := tipo_de(chave)
	if not Catalogo.TIPOS.has(tipo):
		return []
	var el = ficha(chave).get("elemento")
	var versao = ficha(chave).get("versao")
	var unica: bool = versao == null or str(versao) == "suprema" or tipo in ["urso_de_barranco", "besta_sem_nome"] or Catalogo.SUPREMAS.has(chave)
	var desde := ["comum", "comum", "veterano", "elite"]
	var r: Array = []
	var lista: Array = Catalogo.TIPOS[tipo]["hab"]
	for i in mini(lista.size(), 4):
		var h := str(lista[i])
		if h == "*lebre":
			h = str(Catalogo.HAB_LEBRE.get(str(el) if el != null else "", "golpe"))
		r.append({"id": h, "desde": "" if unica else str(desde[i])})
	if not r.any(func(x): return Catalogo.HAB[x["id"]].has("poder") and Catalogo.HAB[x["id"]]["cat"] == "comum"):
		r.append({"id": "golpe", "desde": ""})
	return r

## Novidades por aba do Diário.
static func novidade_bestiario() -> bool:
	for r in dados().values():
		if bool(r.get("novo", false)):
			return true
	return false

static func novidade_personagens() -> bool:
	for r in personagens().values():
		if bool(r.get("novo", false)):
			return true
	return false

## Habilidades da espécie (as da Elite, que tem mais).
static func habilidades(chave: String) -> Array:
	var tipo := chave
	if Catalogo.SUPREMAS.has(chave):
		tipo = Catalogo.SUPREMAS[chave]
	else:
		for suf in ["_comum", "_veterano", "_elite"]:
			if tipo.ends_with(suf):
				tipo = tipo.substr(0, tipo.length() - suf.length())
		tipo = Catalogo.tipo_do_sprite(tipo)
	if not Catalogo.TIPOS.has(tipo):
		return []
	var el = ficha(chave).get("elemento")
	var r: Array = []
	for h0: String in Catalogo.TIPOS[tipo]["hab"]:
		var h := h0
		if h == "*lebre":
			h = str(Catalogo.HAB_LEBRE.get(str(el) if el != null else "", "golpe"))
		r.append(Catalogo.nome_hab(h))
	return r

## Primeiro quadro da pose parada, para miniaturas.
static func miniatura(chave: String) -> Texture2D:
	var a := Artes.inimigo_acao(chave, "parado")
	if a.is_empty() or a["peca"].is_empty():
		return null
	var t := AtlasTexture.new()
	t.atlas = a["peca"]["tex"]
	var r: Rect2 = a["peca"]["rect"]
	t.region = Rect2(r.position, Vector2(int(a["largura"]), int(a["altura"])))
	return t
