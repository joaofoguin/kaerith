extends "res://scripts/componentes/popup_vitrine.gd"
## Ficha do Bestiário (pedido do João e dos amigos, 2026-11-13): retrato num palco na cor do elemento,
## versões da espécie (Comum/Veterano/Elite) para alternar, informações, atributos, ataques com descrição,
## fraquezas e resistências e as anotações da história.
## Revelação (DEFINIDA): 1º encontro mostra nome, imagem e elemento; 3 vitórias revelam habilidades e
## fraquezas; vencer o Veterano e a Elite revela uma frase da história cada.
## PROVISÓRIO (meu): os atributos (do modelo do papel) e o papel entram junto com as habilidades, depois
## das 3 vitórias; versão ainda não vencida aparece como silhueta.
## Uso: var p = POPUP_BEST.new(); p.especie = e  (dicionário de Bestiario.especies()); add_child(p)

const COR_EL := {"fogo": Color("#ff7a3a"), "agua": Color("#4ab0ff"), "terra": Color("#c8964e"),
	"ar": Color("#6ee0b0"), "raio": Color("#ffe04a"), "gelo": Color("#a8e8ff")}
const COR_CAT := {"comum": Color("#6a7090"), "veterano": Color("#5aa0e0"), "elite": Color("#b07ae8"),
	"suprema": Color("#e8b33a"), "unica": Color("#e8b33a")}
const ORDEM := ["comum", "veterano", "elite", "suprema", "unica"]
const TEXTO := Color("#d8dae6")
const CINZA := Color("#8088a8")
const VERDE := Color("#7ee08a")
const VERMELHO := Color("#ff7a6b")
const ATRIBUTOS := ["ATR_FORCA", "ATR_PERCEPCAO", "ATR_AGILIDADE", "ATR_RESISTENCIA", "ATR_RESSONANCIA"]

var especie: Dictionary = {}
var versao := ""             # versão mostrada; vazio = a mais forte já vencida (ou a 1ª)
var _col: VBoxContainer

func _ready() -> void:
	if versao == "":
		versao = _versao_inicial()
	_cores()
	super._ready()

func _cores() -> void:
	var el := _el()
	if COR_EL.has(el):
		var c: Color = COR_EL[el]
		cor_acento = c
		cor_claro = c.lightened(0.35)
		cor_fundo = Color(c.darkened(0.86), 1.0)
		cor_escuro = Color(c.darkened(0.9), 1.0)
	else:
		cor_acento = Tema.COR_OURO
		cor_claro = Tema.COR_OURO_CLARO
		cor_fundo = Color("#181a28")
		cor_escuro = Color("#0e0f18")

func _versoes() -> Array:
	var vs: Dictionary = especie.get("versoes", {})
	var r: Array = []
	for v in ORDEM:
		if vs.has(v):
			r.append(v)
	return r

func _vencidas() -> Dictionary:
	return Bestiario.registro(str(especie["id"])).get("versoes", {})

## A versão aparece por inteiro depois de vencida; a comum (ou única) aparece desde o 1º encontro.
func _liberada(v: String) -> bool:
	return v == _versoes()[0] or int(_vencidas().get(v, 0)) > 0

func _versao_inicial() -> String:
	var r := str(_versoes()[0])
	for v in _versoes():
		if _liberada(str(v)):
			r = str(v)
	return r

func _chave() -> String:
	return str(especie["versoes"].get(versao, especie["chave"]))

func _el() -> String:
	var el = Bestiario.ficha(_chave()).get("elemento")
	return str(el) if el != null else ""

# ------------------------------------------------------------ montagem
func _montar(col: VBoxContainer) -> void:
	_col = col
	var chave := _chave()
	var f := Bestiario.ficha(chave)
	var id := str(especie["id"])
	var r := Bestiario.registro(id)
	var vit := int(r.get("vit", 0))
	var revelado := vit >= Bestiario.VITORIAS_REVELA
	var el := _el()

	# nome e selos
	var nome := Tema.rotulo(str(f.get("nome", id)), 20)
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nome.add_theme_color_override("font_color", cor_claro)
	nome.add_theme_constant_override("outline_size", 4)
	nome.add_theme_color_override("font_outline_color", cor_escuro)
	Tema.caber(nome, LARGURA - 40.0, 28.0, 1, [20, 16, 14])
	col.add_child(nome)
	var selos := HBoxContainer.new()
	selos.alignment = BoxContainer.ALIGNMENT_CENTER
	selos.add_theme_constant_override("separation", 4)
	var cc: Color = COR_CAT.get(versao, CINZA)
	selos.add_child(selo(tr("INIM_" + ("SUPREMA" if versao in ["suprema", "unica"] else versao.to_upper())), Color.WHITE, Color(cc.darkened(0.7), 1.0), cc))
	if el != "":
		selos.add_child(selo(tr("EL_" + el.to_upper()), cor_claro, Color("#0e0f18"), cor_acento, load("res://artes/combate/elem16_%s.png" % el)))
	else:
		selos.add_child(selo(tr("INIM_SEM_ELEMENTO"), CINZA, Color("#0e0f18"), Color("#3c4058")))
	selos.add_child(selo(str(f.get("familia", "")), TEXTO, Color("#0e0f18"), Color("#3c4058")))
	col.add_child(selos)

	col.add_child(_palco(chave))
	if _versoes().size() > 1:
		col.add_child(_seletor())

	# o resto rola (a ficha completa passa da altura da tela)
	var rol := ScrollContainer.new()
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rol.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var corpo := VBoxContainer.new()
	corpo.add_theme_constant_override("separation", 6)
	corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rol.add_child(corpo)
	col.add_child(rol)
	corpo.resized.connect(func():
		var limite := maxf(140.0, get_viewport_rect().size.y - 360.0)
		rol.custom_minimum_size = Vector2(0, minf(corpo.size.y, limite)))

	# informações
	corpo.add_child(secao("BEST_INFO"))
	var t: Dictionary = Catalogo.TIPOS.get(_tipo(chave), {})
	corpo.add_child(_dado("BEST_PRIMEIRO", _onde(str(r.get("onde", "")))))
	corpo.add_child(_dado("BEST_VITORIAS", str(vit)))
	if revelado and not t.is_empty():
		corpo.add_child(_dado("BEST_PAPEL", tr("BEST_PAPEL_" + str(t["papel"]).to_upper())))
		corpo.add_child(secao("BEST_ATRIBUTOS"))
		var modelo: Array = Catalogo.MODELO_PAPEL.get(str(t["papel"]), [])
		for i in mini(modelo.size(), ATRIBUTOS.size()):
			corpo.add_child(_atributo(ATRIBUTOS[i], int(modelo[i])))

	# ataques
	corpo.add_child(secao("BEST_ATAQUES"))
	if revelado:
		for a: Dictionary in Bestiario.habilidades_de(chave):
			corpo.add_child(_ataque(str(a["id"]), str(a["desde"])))
	else:
		corpo.add_child(_cadeado(tr("DIARIO_REVELA_3") % (Bestiario.VITORIAS_REVELA - vit)))

	# elementos
	corpo.add_child(secao("BEST_ELEMENTOS"))
	if revelado:
		corpo.add_child(_linha_elementos("BEST_FRACO", Bestiario.fraquezas(el), VERDE))
		corpo.add_child(_linha_elementos("BEST_RESISTE", Bestiario.resistencias(el), VERMELHO))
	else:
		corpo.add_child(_cadeado(tr("DIARIO_REVELA_3") % (Bestiario.VITORIAS_REVELA - vit)))

	# anotações da história (uma por Veterano e uma por Elite vencidos)
	var anot: Array = []
	for v: String in ["veterano", "elite"]:
		if especie["versoes"].has(v):
			anot.append(v)
	if not anot.is_empty():
		corpo.add_child(secao("BEST_ANOTACOES"))
		for v: String in anot:
			if int(_vencidas().get(v, 0)) > 0:
				var fv := Bestiario.ficha(str(especie["versoes"][v]))
				corpo.add_child(paragrafo(str(fv.get("nome", "")) + ": " + tr("BEST_FRASE_PENDENTE"), TEXTO))
			else:
				corpo.add_child(_cadeado(tr("DIARIO_REVELA_" + v.to_upper())))

	var ok := Button.new()
	ok.text = "FECHAR"
	ok.custom_minimum_size = Vector2(0, 38)
	Tema.estilo_botao(ok, "secundario")
	ok.pressed.connect(fechar)
	col.add_child(ok)

func _tipo(chave: String) -> String:
	return Bestiario.tipo_de(chave)

# ------------------------------------------------------------ peças
## Palco do retrato: céu em faixas na cor do elemento, chão com sombra e o inimigo em pixel art.
func _palco(chave: String) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 128)
	c.draw.connect(func():
		var s := c.size
		var faixas := 6
		for i in faixas:
			var y0 := floorf(s.y * i / faixas)
			var y1 := floorf(s.y * (i + 1) / faixas)
			c.draw_rect(Rect2(0, y0, s.x, y1 - y0), cor_escuro.lerp(cor_acento, 0.06 + 0.05 * i))
		var chao := s.y - 22.0
		c.draw_rect(Rect2(0, chao, s.x, s.y - chao), Color(cor_escuro, 1.0))
		c.draw_rect(Rect2(0, chao, s.x, 1), Color(cor_acento, 0.5))
		var meio := s.x / 2.0
		for k in 3:
			var w := 70.0 - k * 18.0
			c.draw_rect(Rect2(floorf(meio - w / 2.0), chao + 2 + k, floorf(w), 3), Color(0, 0, 0, 0.25 + k * 0.1))
		c.draw_rect(Rect2(Vector2.ZERO, s), Color(cor_acento, 0.6), false, 1.0))
	var t := TextureRect.new()
	t.texture = Bestiario.miniatura(chave)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.offset_top = 6
	t.offset_bottom = -10
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(t)
	return c

## Fileira com as versões da espécie: toque para trocar; as não vencidas ficam como silhueta.
func _seletor() -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	for v: String in _versoes():
		var livre := _liberada(v)
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 52)
		var cc: Color = COR_CAT.get(v, CINZA)
		var e := StyleBoxFlat.new()
		e.bg_color = Color("#0e0f18") if v != versao else Color(cc.darkened(0.6), 1.0)
		e.border_color = cc if v == versao else Color(cc, 0.45)
		e.set_border_width_all(2 if v == versao else 1)
		e.set_corner_radius_all(3)
		for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(s, e)
		var ic := TextureRect.new()
		ic.texture = Bestiario.miniatura(str(especie["versoes"][v]))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.position = Vector2(4, 2)
		ic.size = Vector2(56, 36)
		ic.modulate = Color.WHITE if livre else Color(0, 0, 0, 0.75)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		var l := Tema.rotulo(tr("INIM_" + ("SUPREMA" if v in ["suprema", "unica"] else v.to_upper())) if livre else "?", 8, true)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_color_override("font_color", Color.WHITE if v == versao else CINZA)
		l.position = Vector2(0, 38)
		l.size = Vector2(64, 12)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(l)
		b.disabled = not livre
		b.pressed.connect(_trocar_versao.bind(v))
		h.add_child(b)
	return h

func _trocar_versao(v: String) -> void:
	if v == versao:
		return
	versao = v
	_cores()
	_cartao.add_theme_stylebox_override("panel", _estilo_cartao())
	for n in _col.get_children():
		n.queue_free()
	_montar(_col)

func _dado(chave: String, valor: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var a := Tema.rotulo(chave, 12)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	a.add_theme_color_override("font_color", CINZA)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var b := Tema.rotulo(valor, 12)
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_color_override("font_color", TEXTO)
	h.add_child(b)
	return h

## Barra do atributo (o modelo dos inimigos vai de 4 a 16 pontos).
func _atributo(chave: String, valor: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var a := Tema.rotulo(chave, 12)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	a.custom_minimum_size = Vector2(110, 0)
	a.add_theme_color_override("font_color", CINZA)
	h.add_child(a)
	var b := barra(valor / 16.0, cor_acento, 8.0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	var n := Tema.rotulo(str(valor), 8, true)
	n.custom_minimum_size = Vector2(18, 0)
	n.add_theme_color_override("font_color", cor_claro)
	h.add_child(n)
	return h

## Cartão do ataque: ícone, nome, tipo, a partir de qual versão e a descrição.
func _ataque(h: String, desde: String) -> Control:
	var H: Dictionary = Catalogo.HAB[h]
	var el := str(H.get("el", ""))
	var p := PanelContainer.new()
	var est := StyleBoxFlat.new()
	est.bg_color = Color("#12131e")
	est.border_color = Color(COR_EL.get(el, Color("#b8bccc")), 0.6)
	est.set_border_width_all(1)
	est.border_width_left = 3
	est.set_corner_radius_all(3)
	est.content_margin_left = 8
	est.content_margin_right = 6
	est.content_margin_top = 4
	est.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", est)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 6)
	var ic := TextureRect.new()
	ic.texture = load("res://artes/combate/elem16_%s.png" % (el if el != "" else "comum"))
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	topo.add_child(ic)
	var n := Tema.rotulo(str(H["nome"]), 12)
	n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.add_theme_color_override("font_color", Color.WHITE)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(n)
	if desde != "" and desde != _versoes()[0]:
		var d := Tema.rotulo(tr("BEST_DESDE") % tr("INIM_" + desde.to_upper()), 8, true)
		d.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		d.add_theme_color_override("font_color", COR_CAT.get(desde, CINZA))
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		topo.add_child(d)
	v.add_child(topo)
	var desc := Catalogo.descrever(h)
	var quebradas := Tema._quebrar(desc, Tema.fonte_texto, 12, LARGURA - 50.0, 4)
	if quebradas.is_empty():
		quebradas = PackedStringArray([desc])
	for linha in quebradas:
		var l := Tema.rotulo(linha.strip_edges(), 12)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.add_theme_color_override("font_color", Color("#c8ccd8"))
		v.add_child(l)
	p.add_child(v)
	return p

func _linha_elementos(chave: String, els: Array, cor: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var a := Tema.rotulo(chave, 12)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	a.custom_minimum_size = Vector2(110, 0)
	a.add_theme_color_override("font_color", cor)
	h.add_child(a)
	if els.is_empty():
		var n := Tema.rotulo("BEST_NENHUM", 12)
		n.add_theme_color_override("font_color", CINZA)
		h.add_child(n)
	for e in els:
		var c: Color = COR_EL.get(str(e), CINZA)
		h.add_child(selo(tr("EL_" + str(e).to_upper()), c.lightened(0.3), Color("#0e0f18"), c, load("res://artes/combate/elem16_%s.png" % str(e))))
	return h

func _cadeado(texto: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(9, 11)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.draw.connect(func():
		ic.draw_rect(Rect2(2, 0, 5, 1), CINZA)
		ic.draw_rect(Rect2(1, 1, 1, 4), CINZA)
		ic.draw_rect(Rect2(7, 1, 1, 4), CINZA)
		ic.draw_rect(Rect2(0, 5, 9, 6), CINZA)
		ic.draw_rect(Rect2(4, 7, 1, 2), Color("#0e0f18")))
	h.add_child(ic)
	var linhas := Tema._quebrar(texto, Tema.fonte_texto, 12, LARGURA - 50.0, 3)
	if linhas.is_empty():
		linhas = PackedStringArray([texto])
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	for linha in linhas:
		var l := Tema.rotulo(linha.strip_edges(), 12)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.add_theme_color_override("font_color", CINZA)
		v.add_child(l)
	h.add_child(v)
	return h

func _onde(o: String) -> String:
	match o:
		"tutorial":
			return tr("CHEG_REGIAO")
		"qr":
			return tr("DIARIO_ONDE_QR")
		"evento":
			return tr("DIARIO_ONDE_EVENTO")
		"":
			return "?"
	return tr("FASE_N") % int(o)
