extends Control
## Popup ilustrado de UMA promoção, no estilo dos jogos de celular: cena desenhada (santuário dos ecos ou
## forja do elemento), faixa com o nome por cima, itens grandes nos pedestais (balançando, com brilho),
## quantidades em letra grande, selo girando "1 por conta", botão verde com o preço, relógio e "1/1".
## O mesmo popup abre pelo botão lateral do Início e pela vitrine da Loja.
## Uso: var p = preload("res://scripts/componentes/popup_promocao.gd").new(); p.promo = "bolsa"; add_child(p)
## Desde 2026-11-22 `promo` é o id da promoção no Firebase (ConfigRemota). O "modelo" (bolsa ou conjunto) diz qual
## arte e conteúdo usar; nome, descrição, preço, prazo e quantidades vêm de lá.
## PROVISÓRIO (meu): a oferta acaba junto com o ato em curso; o Conjunto mostra as peças do elemento do
## jogador (Fogo se ainda não houver); a compra real só chega com as lojas oficiais (LOJA_REAL_DEPOIS).
## Artes: artes/promocao/ (ferramentas/montar_promocoes.py).
## Modelo "livre" (2026-11-22): cena e ícone podem vir da pasta promocoes/ do site (ConfigRemota.arte) e os itens
## dos pedestais vêm do campo "conteudo" (até 3: cristais, fragmentos, moedas, vidas, poção ou peça).

const TEMPORADA := preload("res://scripts/temporada.gd")
const PASTA := "res://artes/promocao/"
const ESCALA := 2.0
const CARTAO := Rect2(16, 76, 328, 520)
const ELEMENTOS := ["fogo", "agua", "terra", "ar", "raio", "gelo"]
const COR_EL := {"fogo": "#ff8a3a", "agua": "#5ab4ff", "terra": "#d0a048", "ar": "#5cd6a6", "raio": "#f4d23a", "gelo": "#96d4f6"}
const FAIXA_EL := {"fogo": "#b02a14", "agua": "#1e5ab0", "terra": "#8a5a22", "ar": "#1e7a5a", "raio": "#6a3aa8", "gelo": "#2e6aa8"}

var promo := "bolsa"
var _modelo := "bolsa"

var _dados: Dictionary
var _el := "fogo"
var _cor := Color("#5ee0c0")        # destaque do tema (raios, brilhos)
var _cor_faixa := Color("#6e3f9e")  # faixa do título
var _tempo := 0.0
var _itens: Array = []               # [TextureRect, y_base, fase]
var _raios: Control
var _atras: Control
var _frente: Control
var _selo: Control
var _relogio: Label
var _janela: Janela
var _particulas: Array = []

static func dados_promo(id: String) -> Dictionary:
	var p := ConfigRemota.promocao(id)
	if not p.is_empty():
		return p
	for q in Loja.PROMOS:            # a promoção acabou ou foi desligada com o popup abrindo: mostra o modelo
		if str(q["id"]) == id:
			return {"id": id, "modelo": id, "nome": TranslationServer.translate(q["nome"]), "desc": TranslationServer.translate(q["desc"]), "preco": q["preco"],
				"fim": 0, "cristais": 50, "fragmentos": 100}
	return {"id": id, "modelo": "bolsa", "nome": TranslationServer.translate(Loja.PROMOS[0]["nome"]), "desc": TranslationServer.translate(Loja.PROMOS[0]["desc"]),
		"preco": Loja.PROMOS[0]["preco"], "fim": 0, "cristais": 50, "fragmentos": 100}

## Elemento mostrado no Conjunto (o do jogador; Fogo antes da escolha).
static func elemento_conjunto() -> String:
	var el := str(Jogo.dados.get("elemento", ""))
	return el if el in ELEMENTOS else "fogo"

## Ícone do botão do Início: a arte nova da promoção (campo "icone") ou a do modelo.
static func icone_da(p: Dictionary) -> Texture2D:
	var t := ConfigRemota.arte(str(p.get("icone", "")))
	return t if t else icone(str(p.get("modelo", "bolsa")))

## Ícone do botão do Início pelo modelo ("bolsa" ou "conjunto").
static func icone(id: String) -> Texture2D:
	if id == "conjunto":
		return load(PASTA + "icone_conjunto_%s.png" % elemento_conjunto())
	return load(PASTA + "icone_bolsa.png")

func _ready() -> void:
	_dados = dados_promo(promo)
	_modelo = str(_dados["modelo"])
	_el = elemento_conjunto()
	if _modelo == "conjunto":
		_cor = Color(COR_EL[_el])
		_cor_faixa = Color(FAIXA_EL[_el])
	var cor := str(_dados.get("cor", ""))
	if Color.html_is_valid(cor):
		_cor = Color.html(cor).lightened(0.2)
		_cor_faixa = Color.html(cor)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Tema.elevar(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 18:
		_particulas.append(Vector3(rng.randf_range(0, CARTAO.size.x), rng.randf_range(0, CARTAO.size.y), rng.randf_range(0.5, 1.0)))

	var veu := ColorRect.new()
	veu.color = Color(0.02, 0.02, 0.05, 0.82)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)
	_raios = _camada(_desenhar_raios)

	# cartão: a cena desenhada ×2
	var cena := TextureRect.new()
	cena.texture = ConfigRemota.arte(str(_dados.get("cena", "")))
	if cena.texture == null:
		cena.texture = load(PASTA + ("cena_conjunto_%s.png" % _el if _modelo == "conjunto" else "cena_bolsa.png"))
	cena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cena.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cena.position = CARTAO.position
	cena.size = CARTAO.size
	cena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cena)
	_atras = _camada(_desenhar_brilhos_atras)

	# itens nos pedestais (na cena: pedestais em x 34 / 82 / 130, topo 168 / 150 / 168)
	var texturas: Array = []
	if _modelo == "livre":
		for item: Dictionary in _conteudo():
			texturas.append(textura_item(item))
	elif _modelo == "bolsa":
		for a in ["monte_fragmentos.png", "bolsa.png", "monte_cristais.png"]:
			texturas.append(load(PASTA + a))
	else:
		for a in ["conjunto_%s_arma.png" % _el, "conjunto_%s_armadura.png" % _el, "conjunto_%s_cabeca.png" % _el]:
			texturas.append(load(PASTA + a))
	var lugares := _lugares(texturas.size())
	for i in texturas.size():
		if texturas[i] == null:
			continue
		var t := TextureRect.new()
		t.texture = texturas[i]
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var esc := ESCALA * (2.0 if t.texture.get_width() <= 16 else 1.0)     # ícone 16 (vida) fica do tamanho dos outros
		t.size = Vector2(t.texture.get_width(), t.texture.get_height()) * esc
		var base: Vector2 = CARTAO.position + lugares[i] * ESCALA
		t.position = Vector2(floorf(base.x - t.size.x / 2.0), base.y - t.size.y)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(t)
		_itens.append([t, t.position.y, i * 1.7])

	_frente = _camada(_desenhar_frente)
	_montar_textos()
	_selo = _camada(_desenhar_selo)

	var x := Tema.botao_x()
	x.position = Vector2(CARTAO.end.x - 26, CARTAO.position.y - 12)
	x.pressed.connect(fechar)
	add_child(x)

	# tudo (menos o véu) num quadro de 360×640 centrado na vertical: em celular mais alto o cartão
	# fica no meio da tela, não grudado em cima
	var quadro := Control.new()
	quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quadro.anchor_right = 1.0
	quadro.anchor_top = 0.5
	quadro.anchor_bottom = 0.5
	quadro.offset_top = -320.0
	quadro.offset_bottom = 320.0
	var filhos := get_children()
	add_child(quadro)
	for f: Node in filhos:
		if f != veu:
			f.reparent(quadro, false)

	# entrada com "pop"
	modulate.a = 0.0
	pivot_offset = Vector2(180, 330)
	scale = Vector2(0.88, 0.88)
	var tw := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_property(self, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _camada(f: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(f.bind(c))
	add_child(c)
	return c

func _rotulo(texto: String, tam: int, numeros := false, contorno := 6) -> Label:
	var l := Tema.rotulo(texto, tam, numeros)
	l.add_theme_constant_override("outline_size", contorno)
	l.add_theme_color_override("font_outline_color", Color("#12081a"))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Rótulo centrado num ponto: vai dentro de uma caixa de largura fixa (o Godot só centra e quebra a
## linha direito com o rótulo dentro de um container; solto, ele cresce para a direita).
func _rotulo_em(l: Label, centro_x: float, y: float, largura: float, quebrar := false) -> void:
	var caixa := VBoxContainer.new()
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.position = Vector2(floorf(centro_x - largura / 2.0), y)
	caixa.custom_minimum_size = Vector2(largura, 0)
	caixa.size = Vector2(largura, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_FILL
	if quebrar:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(l)
	add_child(caixa)

func _montar_textos() -> void:
	# nome na faixa e a descrição embaixo dela
	var nome := _rotulo(tr(_dados["nome"]), 24)
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nome.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	_rotulo_em(nome, 180, 46, 264)
	# descrição: quebrada por mim, uma linha por rótulo (cada linha centrada de verdade)
	var linhas := Tema._quebrar(tr(_dados["desc"]), Tema.fonte_texto, 12, 236.0, 3)
	for k in linhas.size():
		var d := _rotulo(linhas[k].strip_edges(), 12, false, 4)
		d.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		d.add_theme_color_override("font_color", Color("#f2ecff"))
		_rotulo_em(d, 180, 100 + k * 16, 300)

	# quantidades / nomes embaixo dos pedestais
	var esq := CARTAO.position.x + 34 * ESCALA
	var dir := CARTAO.position.x + 130 * ESCALA
	if _modelo == "livre":
		var itens := _conteudo()
		var lugares := _lugares(itens.size())
		for i in itens.size():
			var cx: float = CARTAO.position.x + lugares[i].x * ESCALA
			var q := _rotulo("x%d" % int(itens[i]["qtd"]), 24, true)
			q.add_theme_color_override("font_color", Color("#ffe9a8"))
			_rotulo_em(q, cx, 448, 104)
			var n := _rotulo(nome_item(itens[i]), 12, false, 4)
			n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			n.add_theme_color_override("font_color", Color("#f2ecff"))
			_rotulo_em(n, cx, 476, 104)
	elif _modelo == "bolsa":
		var q1 := _rotulo("x%d" % int(_dados["fragmentos"]), 24, true)
		q1.add_theme_color_override("font_color", Color("#8af0d4"))
		_rotulo_em(q1, esq, 448, 110)
		var q2 := _rotulo("x%d" % int(_dados["cristais"]), 24, true)
		q2.add_theme_color_override("font_color", Color("#ff9ad0"))
		_rotulo_em(q2, dir, 448, 110)
		# os 6 elementos que podem ser escolhidos para os fragmentos
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 1)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for el in ELEMENTOS:
			var ic := TextureRect.new()
			ic.texture = load("res://artes/combate/elem16_%s.png" % el)
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(ic)
		h.position = Vector2(floorf(esq - 50), 478)
		add_child(h)
		var cr := _rotulo("PROMO_ITEM_CRISTAIS", 12, false, 4)
		cr.add_theme_color_override("font_color", Color("#ffd0e8"))
		_rotulo_em(cr, dir, 478, 120)
	else:
		var ids := _pecas_ids()
		if not ids.is_empty():
			var conj := _rotulo(Equipamento.conjunto_de(ids[0]), 16, false, 6)
			conj.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			conj.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
			_rotulo_em(conj, 180, 452, 300)
		var ep := _rotulo(tr("PROMO_EPICAS_DO") % tr("EL_" + _el.to_upper()), 12, false, 4)
		ep.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		ep.add_theme_color_override("font_color", _cor.lightened(0.3))
		_rotulo_em(ep, 180, 476, 300)

	# botão verde com o preço
	var comprar := Button.new()
	comprar.text = str(_dados["preco"])
	comprar.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	comprar.position = Vector2(70, 500)
	comprar.size = Vector2(220, 52)
	comprar.add_theme_font_size_override("font_size", 24)
	Tema.estilo_botao(comprar, "confirmar")
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		comprar.add_theme_color_override(c, Color.WHITE)
	comprar.add_theme_constant_override("outline_size", 6)
	comprar.add_theme_color_override("font_outline_color", Color("#1e5a24"))
	if not Loja.PAGOS_LIBERADOS:
		# dinheiro real bloqueado (pedido do João, 2026-11-22): cadeado e "Bloqueado"; o toque explica
		Tema.estilo_botao(comprar, "secundario")
		comprar.text = tr("LOJA_BLOQUEADO")
		comprar.icon = load("res://artes/interface/icone16_cadeado.png")
		comprar.add_theme_font_size_override("font_size", 16)
		comprar.add_theme_color_override("font_outline_color", Color("#12131c"))
	comprar.pressed.connect(_comprar)
	add_child(comprar)
	# relógio e quantas restam
	_relogio = _rotulo("", 16, true, 4)
	_relogio.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_relogio.add_theme_color_override("font_color", Color.WHITE)
	_rotulo_em(_relogio, 192, 554, 140)
	var resta := _rotulo(tr("PROMO_DISPONIVEL") % [1, 1], 12, false, 4)
	resta.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	resta.add_theme_color_override("font_color", Color("#d8dae6"))
	_rotulo_em(resta, 180, 574, 200)
	_atualizar_relogio()

func _conteudo() -> Array:
	return _dados.get("conteudo", [])

## Pedestais da cena usados por N itens: 1 no meio, 2 nas pontas, 3 em todos.
func _lugares(n: int) -> Array:
	var todos := [Vector2(34, 170), Vector2(82, 152), Vector2(130, 170)]
	if n == 1:
		return [todos[1]]
	if n == 2:
		return [todos[0], todos[2]]
	return todos.slice(0, n)

## Desenho de um item do conteúdo (as artes do jogo; poção e peça usam o ícone 32 ampliado).
static func textura_item(item: Dictionary) -> Texture2D:
	match str(item["tipo"]):
		"cristais":
			return load(PASTA + "monte_cristais.png")
		"fragmentos":
			return load(PASTA + "monte_fragmentos.png")
		"moedas":
			return load("res://artes/loja/moedas_3.png")
		"vidas":
			return load("res://artes/interface/icone16_vida.png")
		"pocao":
			return _icone_atlas("pocao32_" + str(item["id"]))
		"peca":
			return Equipamento.icone(str(item["id"]))
	return null

static func _icone_atlas(chave: String) -> Texture2D:
	var pc := Artes.icone(chave)
	if pc.is_empty():
		return null
	var at := AtlasTexture.new()
	at.atlas = pc["tex"]
	var r: Rect2 = pc["rect"]
	at.region = Rect2(r.position, Vector2(32, 32))
	return at

static func nome_item(item: Dictionary) -> String:
	match str(item["tipo"]):
		"cristais":
			return TranslationServer.translate("PROMO_ITEM_CRISTAIS")
		"fragmentos":
			return TranslationServer.translate("PROMO_ITEM_FRAGMENTOS")
		"moedas":
			return TranslationServer.translate("RES_L_MOEDAS")
		"vidas":
			return TranslationServer.translate("VIDAS_TITULO")
		"pocao":
			return str(Loja.consumiveis().get(str(item["id"]), {}).get("nome", item["id"]))
		"peca":
			return str(Equipamento.ficha(str(item["id"])).get("nome", item["id"]))
	return str(item["id"])

## Arma, armadura e cabeça Épicas do elemento, de preferência do mesmo conjunto.
func _pecas_ids() -> Array:
	var por_conj := {}
	for id_peca: String in Equipamento.todos_ids():
		if Equipamento.raridade_de(id_peca) != "epico" or Equipamento.elemento_de(id_peca) != _el:
			continue
		var t := Equipamento.tipo_de(id_peca)
		if not t in ["arma", "armadura", "cabeca"]:
			continue
		var c := Equipamento.conjunto_de(id_peca)
		if not por_conj.has(c):
			por_conj[c] = {}
		por_conj[c][t] = id_peca
	for c in por_conj:
		if por_conj[c].size() == 3:
			return [por_conj[c]["arma"], por_conj[c]["armadura"], por_conj[c]["cabeca"]]
	return []

# ------------------------------------------------------------ desenho
func _desenhar_raios(c: Control) -> void:
	var centro := CARTAO.get_center() + Vector2(0, -40)
	for i in 20:
		var a := _tempo * 0.18 + i * TAU / 20.0
		c.draw_colored_polygon(PackedVector2Array([centro, centro + Vector2.from_angle(a - 0.07) * 620.0,
			centro + Vector2.from_angle(a + 0.07) * 620.0]), Color(_cor, 0.07))

## Brilho redondo atrás de cada item (pulsando) e partículas subindo dentro do cartão.
func _desenhar_brilhos_atras(c: Control) -> void:
	for k in _itens.size():
		var t: TextureRect = _itens[k][0]
		var centro := t.position + t.size / 2.0
		var p := 0.5 + 0.5 * sin(_tempo * 2.2 + k)
		for r in 4:
			c.draw_circle(centro, t.size.x * (0.62 - r * 0.12), Color(_cor, 0.05 + 0.03 * r + 0.03 * p))
	for q: Vector3 in _particulas:
		var y := fmod(q.y - _tempo * 18.0 * q.z, CARTAO.size.y)
		if y < 0:
			y += CARTAO.size.y
		var pos := CARTAO.position + Vector2(q.x + sin(_tempo + q.x) * 4.0, y)
		var a := 0.35 + 0.5 * q.z
		c.draw_rect(Rect2(pos.floor(), Vector2(2, 2)), Color(_cor.lightened(0.4), a))
		if int(q.x) % 3 == 0:
			c.draw_rect(Rect2(pos.floor() + Vector2(-1, 0), Vector2(4, 1)), Color(_cor.lightened(0.6), a * 0.6))

## Moldura do cartão (escura, clara grossa, filete), faixa do título e o reloginho.
func _desenhar_frente(c: Control) -> void:
	var r := CARTAO
	c.draw_rect(r.grow(4), Color("#12081a"), false, 3.0)
	c.draw_rect(r.grow(1), Color("#f4ead2"), false, 4.0)
	c.draw_rect(r.grow(-2), Color("#c8b88a"), false, 1.0)
	c.draw_rect(r.grow(-3), Color(0, 0, 0, 0.35), false, 1.0)
	# faixa do título com as pontas dobradas para trás
	var y0 := 40.0
	var alt := 46.0
	var esc := _cor_faixa.darkened(0.45)
	for lado: int in [-1, 1]:
		var x_borda := 180.0 + lado * 156.0
		var x_dentro := 180.0 + lado * 126.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(x_dentro, y0 + 10), Vector2(x_borda, y0 + 10),
			Vector2(x_borda - lado * 10, y0 + 10 + alt / 2.0), Vector2(x_borda, y0 + 10 + alt), Vector2(x_dentro, y0 + 10 + alt)]), esc)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x_dentro, y0 + 10 + alt), Vector2(180.0 + lado * 134.0, y0 + alt),
			Vector2(x_dentro, y0 + alt)]), Color("#12081a"))
	var faixa := Rect2(46, y0, 268, alt)
	c.draw_rect(faixa.grow(2), Color("#12081a"))
	c.draw_rect(faixa, _cor_faixa)
	c.draw_rect(Rect2(faixa.position, Vector2(faixa.size.x, 6)), _cor_faixa.lightened(0.25))
	c.draw_rect(Rect2(faixa.position + Vector2(0, faixa.size.y - 6), Vector2(faixa.size.x, 6)), _cor_faixa.darkened(0.25))
	c.draw_rect(Rect2(faixa.position + Vector2(0, 3), Vector2(faixa.size.x, 1)), Tema.COR_OURO_CLARO)
	c.draw_rect(Rect2(faixa.position + Vector2(0, faixa.size.y - 4), Vector2(faixa.size.x, 1)), Tema.COR_OURO)
	for k in 3:
		if int(_tempo * 4.0 + k * 3) % 5 == 0:
			var p := faixa.position + Vector2(30 + k * 100, 6)
			c.draw_rect(Rect2(p + Vector2(-3, 0), Vector2(7, 1)), Color.WHITE)
			c.draw_rect(Rect2(p + Vector2(0, -3), Vector2(1, 7)), Color.WHITE)
	# reloginho ao lado do tempo
	var w := 60.0
	if _relogio:
		w = Tema.fonte_numeros.get_string_size(_relogio.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var rc := Vector2(floorf(192.0 - w / 2.0 - 16.0), 564)
	c.draw_circle(rc, 9, Color("#12081a"))
	c.draw_circle(rc, 8, Tema.COR_OURO)
	c.draw_circle(rc, 6, Color("#fff4dc"))
	c.draw_rect(Rect2(rc + Vector2(-2, -12), Vector2(5, 3)), Tema.COR_OURO)
	c.draw_line(rc, rc + Vector2.from_angle(_tempo * 2.0) * 4.0, Color("#12081a"), 1.0)
	c.draw_line(rc, rc + Vector2(0, -4), Color("#12081a"), 1.0)

## Selo "1 por conta" em estrela girando devagar, no canto da cena (como os selos de oferta).
func _desenhar_selo(c: Control) -> void:
	var centro := Vector2(CARTAO.end.x - 34, CARTAO.position.y + 150)
	var fora := PackedVector2Array()
	var dentro := PackedVector2Array()
	for i in 24:
		var a := _tempo * 0.4 + i * TAU / 24.0
		var r := 34.0 if i % 2 == 0 else 28.0
		fora.append(centro + Vector2.from_angle(a) * (r + 2.0))
		dentro.append(centro + Vector2.from_angle(a) * r)
	c.draw_colored_polygon(fora, Color("#12081a"))
	c.draw_colored_polygon(dentro, Color("#d8394a"))
	c.draw_circle(centro, 22, Color("#b82434"))
	c.draw_arc(centro, 22, 0, TAU, 32, Tema.COR_OURO, 1.0)
	var f := Tema.fonte_numeros
	var l1 := "1"
	var l2 := tr("PROMO_POR_CONTA").to_upper()
	var w1 := f.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var w2 := f.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	c.draw_string_outline(f, Vector2(floorf(centro.x - w1 / 2.0), centro.y + 2), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color("#12081a"))
	c.draw_string(f, Vector2(floorf(centro.x - w1 / 2.0), centro.y + 2), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Tema.COR_OURO_CLARO)
	c.draw_string(f, Vector2(floorf(centro.x - w2 / 2.0), centro.y + 13), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)

func _process(delta: float) -> void:
	var antes := int(_tempo * 8.0)
	_tempo += delta / maxf(Engine.time_scale, 0.01)
	for it in _itens:
		var t: TextureRect = it[0]
		t.position.y = float(it[1]) + roundf(sin(_tempo * 2.0 + float(it[2])) * 2.0)
	for camada in [_raios, _atras, _frente, _selo]:
		if camada:
			camada.queue_redraw()
	if int(_tempo * 8.0) != antes:
		_atualizar_relogio()

func _atualizar_relogio() -> void:
	if _relogio:
		_relogio.text = TEMPORADA.texto_tempo(maxi(0, int(_dados["fim"]) - ConfigRemota.agora()))

func _comprar() -> void:
	if _janela and is_instance_valid(_janela):
		_janela.fechar()
	_janela = Janela.criar(tr(_dados["nome"]), [["OK", func():
		if _janela and is_instance_valid(_janela):
			_janela.fechar()
		_janela = null]], tr("LOJA_PAGO_BLOQUEADO") if not Loja.PAGOS_LIBERADOS else tr("LOJA_REAL_DEPOIS") % str(_dados["preco"]))
	add_child(_janela)

func fechar() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)
