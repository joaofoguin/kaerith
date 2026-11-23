class_name Artes
extends RefCounted
## (Classe estática, sem autoload: funciona mesmo com o editor aberto enquanto os arquivos mudam.)
## Lê as folhas-atlas (artes/atlas) e os catálogos (dados/*.json) gerados por ferramentas/montar_artes.py.
## Cada imagem é devolvida como {"tex": página, "rect": Rect2} para desenhar com draw_texture_rect_region.

static var heroi := {}
static var inimigos := {}
static var itens := {}
static var _paginas := {}
static var _pronto := false

static func _garantir() -> void:
	if _pronto:
		return
	_pronto = true
	heroi = _ler("res://dados/heroi.json")
	inimigos = _ler("res://dados/inimigos.json")
	itens = _ler("res://dados/itens.json")

static func dados_heroi() -> Dictionary:
	_garantir()
	return heroi

static func dados_inimigos() -> Dictionary:
	_garantir()
	return inimigos

static func dados_itens() -> Dictionary:
	_garantir()
	return itens

static func _ler(caminho: String) -> Dictionary:
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		push_error("Não achei " + caminho)
		return {}
	return JSON.parse_string(f.get_as_text())

static func _pagina(grupo: String, i: int) -> Texture2D:
	var chave := "%s_%d" % [grupo, i]
	if not _paginas.has(chave):
		_paginas[chave] = load("res://artes/atlas/%s.png" % chave)
	return _paginas[chave]

static func _peca(grupo: String, indice: Dictionary, nome: String) -> Dictionary:
	_garantir()
	if not indice.has(nome):
		push_warning("Imagem não encontrada: %s/%s" % [grupo, nome])
		return {}
	var r: Array = indice[nome]
	return {"tex": _pagina(grupo, int(r[0])), "rect": Rect2(r[1], r[2], r[3], r[4])}

## Camada do herói de costas (tira de 15 quadros 80×64).
## "camada@id" é uma peça equipada (dados/equipado.json, ferramentas/montar_equipado.py).
static func heroi_costas(nome: String) -> Dictionary:
	_garantir()
	return _heroi("costas", nome)

## Camada do herói de frente (1 quadro 48×64).
static func heroi_frente(nome: String) -> Dictionary:
	_garantir()
	return _heroi("frente", nome)

static func _heroi(lado: String, nome: String) -> Dictionary:
	var chave := nome
	if "@" in nome:
		var partes := nome.split("@")
		chave = partes[1] + "_" + partes[0]
	elif heroi[lado]["imagens"].has(nome):
		return _peca("heroi_" + lado, heroi[lado]["imagens"], nome)
	var eq := Equipamento.dados_visuais()
	if eq.is_empty():
		return {}
	return _peca("equip_" + lado, eq[lado]["imagens"], chave)

## Ícone 32×32 (ou tira animada 4×32) de item/poção.
static func icone(nome: String) -> Dictionary:
	_garantir()
	return _peca("itens", itens["atlas"]["imagens"], nome)

## Ação de um inimigo: {"peca", "quadros", "largura", "altura", "fps"}.
static func inimigo_acao(chave: String, acao: String) -> Dictionary:
	_garantir()
	var ficha: Dictionary = inimigos["inimigos"].get(chave, {})
	var a: Dictionary = ficha.get("acoes", {}).get(acao, {})
	if a.is_empty():
		return {}
	var r := a.duplicate()
	r["peca"] = _peca("inimigos", inimigos["atlas"]["imagens"], a["imagem"])
	return r

static func lista_inimigos() -> Array:
	_garantir()
	return inimigos["inimigos"].keys()
