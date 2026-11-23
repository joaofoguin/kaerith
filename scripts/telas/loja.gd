extends Tela
## Loja (kit aprovado, 3ª leva): tela corrida com toldo e lampiões, Promoções (vitrine em falso 3D),
## Itens do dia (8, 1 grátis), Equipamentos do dia (3), Cristais (6 pacotes) e Moedas (6 trocas).
## Regras em scripts/loja.gd. Compras com dinheiro real ficam para a etapa 10 (lojas oficiais).

const FUNDO := Color("#1a1826")
const TABUA := Color("#201e2e")
const ALTURA_TOPO := 76.0

var rolagem: ScrollContainer
var lista: VBoxContainer
var toldo: TextureRect
var toldo_quadros: Array = []
var vitrines: Array = []          # [TextureRect, tema]
var vitrine_quadros := {}
var relogios: Array = []          # Labels "RENOVA EM"
var pilula_moedas: Label
var pilula_cristais: Label
var popup: Control = null
var _t := 0.0
var _versao_promos := -1          # ConfigRemota.versao quando a vitrine foi montada
var _q := 0

func montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var piso := Control.new()
	piso.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	piso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	piso.draw.connect(func():
		for y in range(0, int(piso.size.y) + 16, 16):
			piso.draw_line(Vector2(0, y), Vector2(piso.size.x, y), TABUA)
			var x0 := (y / 16) % 2 * 40
			for x in range(x0, int(piso.size.x), 80):
				piso.draw_line(Vector2(x, y), Vector2(x, y + 15), TABUA))
	piso.resized.connect(piso.queue_redraw)
	add_child(piso)
	for q in 8:
		toldo_quadros.append(load("res://artes/loja/toldo_q%d.png" % q))
	for tema in ["bolsa", "conjunto"]:
		var qs: Array = []
		for q in 8:
			qs.append(load("res://artes/loja/vitrine_%s_q%d.png" % [tema, q]))
		vitrine_quadros[tema] = qs

	rolagem = ScrollContainer.new()
	rolagem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rolagem.offset_top = ALTURA_TOPO          # o topo (toldo, nome e saldo) fica parado em cima
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(rolagem)
	lista = VBoxContainer.new()
	lista.custom_minimum_size = Vector2(360, 0)
	lista.add_theme_constant_override("separation", 8)
	rolagem.add_child(lista)
	var topo := _cabecalho()
	topo.position = Vector2.ZERO
	topo.size = Vector2(360, ALTURA_TOPO)
	add_child(topo)
	if not Loja.liberada():
		_bloqueada()
		return
	_montar_tudo()

func _bloqueada() -> void:
	var caixa := VBoxContainer.new()
	caixa.custom_minimum_size = Vector2(360, 300)
	caixa.alignment = BoxContainer.ALIGNMENT_CENTER
	var cad := TextureRect.new()
	cad.texture = load("res://artes/interface/icone16_cadeado.png")
	cad.custom_minimum_size = Vector2(48, 48)
	cad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cad.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	caixa.add_child(cad)
	var t := Tema.rotulo("LOJA_BLOQUEADA", 16)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(300, 0)
	caixa.add_child(t)
	var teste := Button.new()
	teste.text = "LOJA_ABRIR_TESTE"
	teste.add_theme_font_size_override("font_size", 12)
	Tema.estilo_botao(teste, "secundario")
	teste.pressed.connect(func():
		Jogo.dados["loja_teste"] = true
		Jogo.salvar()
		principal.abrir_aba("loja"))
	var centro := CenterContainer.new()
	centro.add_child(teste)
	if Jogo.adm():                   # botão de teste só na versão ADM
		caixa.add_child(centro)
	else:
		teste.queue_free()
		centro.queue_free()
	lista.add_child(caixa)

func _montar_tudo() -> void:
	var v := Loja.vitrine()
	var folga := Control.new()
	folga.custom_minimum_size = Vector2(0, 4)
	lista.add_child(folga)
	# Promoções: vêm do Firebase (ConfigRemota); sem nenhuma no ar, a faixa some
	var promos := ConfigRemota.promocoes()
	_versao_promos = ConfigRemota.versao
	if not promos.is_empty():
		lista.add_child(_faixa("LOJA_PROMOCOES", "LOJA_SO_ENQUANTO", "res://artes/interface/icone24_bau.png"))
	for p in promos:
		lista.add_child(_banner(p))
	# Itens do dia
	lista.add_child(_faixa("LOJA_ITENS_DIA", "", "", true))
	var grade := GridContainer.new()
	grade.columns = 4
	grade.add_theme_constant_override("h_separation", 5)
	grade.add_theme_constant_override("v_separation", 6)
	var itens: Array = v["itens"]
	var pocoes := Loja.consumiveis()
	for i in itens.size():
		var e: Dictionary = itens[i]
		var it: Dictionary = pocoes.get(e["id"], {})
		var p := Loja.preco_item(str(e["id"]))
		grade.add_child(_cartao(_icone_item(str(it.get("icone", ""))), str(it.get("nome", e["id"])), str(it.get("raridade", "comum")),
			int(p[0]), str(p[1]), bool(e["gratis"]), bool(e["vendido"]), 80, _pedir_item.bind(i)))
	lista.add_child(_margem(grade))
	# Equipamentos do dia
	lista.add_child(_faixa("LOJA_EQUIP_DIA", "", "", true))
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 4)
	var equips: Array = v["equips"]
	for i in equips.size():
		var e: Dictionary = equips[i]
		var id := str(e["id"])
		linha.add_child(_cartao(Equipamento.icone(id), str(Equipamento.ficha(id)["nome"]), Equipamento.raridade_de(id),
			Loja.preco_equip(id), "moeda", false, bool(e["vendido"]), 110, _pedir_equip.bind(i), _selo_elemento(id)))
	lista.add_child(_margem(linha))
	# Cristais (dinheiro real: etapa 10)
	lista.add_child(_faixa("LOJA_CRISTAIS", "LOJA_DOBRO" if Loja.PAGOS_LIBERADOS else "LOJA_EM_BREVE", "res://artes/interface/icone16_cristal.png"))
	var gc := GridContainer.new()
	gc.columns = 3
	gc.add_theme_constant_override("h_separation", 4)
	gc.add_theme_constant_override("v_separation", 6)
	for k in Loja.CRISTAIS.size():
		gc.add_child(_pacote("cristais", k + 1, _num(int(Loja.CRISTAIS[k][0])), str(Loja.CRISTAIS[k][1]), "", _pedir_real.bind(tr("LOJA_PACOTE_CRISTAIS") % int(Loja.CRISTAIS[k][0]), str(Loja.CRISTAIS[k][1])), not Loja.PAGOS_LIBERADOS))
	lista.add_child(_margem(gc))
	# Moedas (troca por cristais)
	lista.add_child(_faixa("LOJA_MOEDAS", "LOJA_TROCA", "res://artes/interface/icone16_moeda.png"))
	var gm := GridContainer.new()
	gm.columns = 3
	gm.add_theme_constant_override("h_separation", 4)
	gm.add_theme_constant_override("v_separation", 6)
	for k in Loja.MOEDAS.size():
		gm.add_child(_pacote("moedas", k + 1, _num(Loja.moedas_do_pacote(k)), str(Loja.MOEDAS[k][0]), "cristal", _pedir_moedas.bind(k)))
	lista.add_child(_margem(gm))
	var fim := Control.new()
	fim.custom_minimum_size = Vector2(0, 16)
	lista.add_child(fim)

# ------------------------------------------------------------ peças visuais
func _cabecalho() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(360, ALTURA_TOPO)
	var base := ColorRect.new()
	base.color = FUNDO
	base.size = Vector2(360, ALTURA_TOPO)
	c.add_child(base)
	var sombra := ColorRect.new()
	sombra.color = Color(0, 0, 0, 0.45)
	sombra.position = Vector2(0, ALTURA_TOPO - 2)
	sombra.size = Vector2(360, 2)
	c.add_child(sombra)
	toldo = TextureRect.new()
	toldo.texture = toldo_quadros[0]
	toldo.size = Vector2(360, 70)
	toldo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.add_child(toldo)
	var placa := PanelContainer.new()
	var t := Tema.rotulo("ABA_LOJA", 24)
	t.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	t.add_theme_constant_override("outline_size", 4)
	t.add_theme_color_override("font_outline_color", Color("#3a1020"))
	t.custom_minimum_size = Vector2(110, 0)
	placa.add_child(t)
	placa.position = Vector2(118, 18)
	c.add_child(placa)
	# saldo em pílulas, nos cantos de baixo do toldo
	pilula_moedas = _pilula(c, "res://artes/interface/icone16_moeda.png", Vector2(6, 50))
	pilula_cristais = _pilula(c, "res://artes/interface/icone16_cristal.png", Vector2(255, 50))
	atualizar_textos()
	return c

func _pilula(pai: Control, icone: String, pos: Vector2) -> Label:
	var p := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = Color("#12131c")
	e.border_color = Color("#545a74")
	e.set_border_width_all(1)
	e.set_corner_radius_all(9)
	e.content_margin_left = 4
	e.content_margin_right = 8
	p.add_theme_stylebox_override("panel", e)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	var ic := TextureRect.new()
	ic.texture = load(icone)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	h.add_child(ic)
	var l := Tema.rotulo("0", 12, true)
	l.set_meta("fonte_fixa", true)       # moedas e cristais na fonte original (pedido do João)
	l.custom_minimum_size = Vector2(68, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	h.add_child(l)
	p.add_child(h)
	p.position = pos
	pai.add_child(p)
	return l

func _faixa(chave: String, direita: String, icone: String, relogio := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(360, 36)
	var f := TextureRect.new()
	f.texture = load("res://artes/loja/faixa_secao.png")
	f.position = Vector2(12, 0)
	f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	c.add_child(f)
	var x := 20.0
	if icone == "" and relogio:
		icone = "res://artes/interface/icone16_relogio.png"
	if icone != "":
		var ic := TextureRect.new()
		ic.texture = load(icone)
		ic.position = Vector2(20, 7)
		ic.size = Vector2(20, 20)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.add_child(ic)
		x = 46.0
	var t := Tema.rotulo(chave, 16)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.position = Vector2(x, 6)
	t.size = Vector2(200, 22)
	t.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	t.add_theme_constant_override("outline_size", 3)
	t.add_theme_color_override("font_outline_color", Color("#3a1020"))
	c.add_child(t)
	if direita != "" or relogio:
		var d := Tema.rotulo(direita, 8, true)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		d.position = Vector2(176, 12)
		d.size = Vector2(150, 12)
		d.add_theme_color_override("font_color", Color("#c8ccd8"))
		c.add_child(d)
		if relogio:
			relogios.append(d)
	return c

func _margem(filho: Control) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_child(filho)
	return m

func _banner(p: Dictionary) -> Control:
	var c := PanelContainer.new()
	c.custom_minimum_size = Vector2(336, 176)
	var dentro := Control.new()
	dentro.custom_minimum_size = Vector2(320, 160)
	dentro.clip_contents = true
	dentro.mouse_filter = Control.MOUSE_FILTER_PASS     # o toque passa para o quadro (abre o popup)
	c.add_child(dentro)
	var tex := TextureRect.new()
	var tema: String = p["modelo"] if vitrine_quadros.has(p["modelo"]) else "bolsa"
	var nova := ConfigRemota.arte(str(p.get("vitrine", "")))     # arte nova do site (campo "vitrine"), parada
	tex.texture = nova if nova else vitrine_quadros[tema][0]
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.size = Vector2(320, 160)
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.mouse_filter = Control.MOUSE_FILTER_PASS
	dentro.add_child(tex)
	if nova == null:
		vitrines.append([tex, tema])
	var nome := Tema.rotulo(p["nome"], 24)
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED   # o nome já vem no idioma certo
	nome.position = Vector2(0, 122)
	nome.size = Vector2(320, 32)
	nome.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	nome.add_theme_constant_override("outline_size", 6)
	nome.add_theme_color_override("font_outline_color", Color("#3a1020"))
	dentro.add_child(nome)
	var toque := Tema.rotulo("LOJA_TOQUE_VER", 8, true)
	toque.position = Vector2(206, 6)
	toque.size = Vector2(108, 12)
	toque.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	toque.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	dentro.add_child(toque)
	if not Loja.PAGOS_LIBERADOS:
		dentro.add_child(_selo_bloqueado())
	# só abre com um toque de verdade: passar o dedo para rolar a Loja não conta
	Tema.ao_tocar(c, func(_pos: Vector2): _pedir_promo(p))
	return _margem(c)

func _icone_item(chave: String) -> Texture2D:
	var pc := Artes.icone(chave)
	if pc.is_empty():
		return null
	var at := AtlasTexture.new()
	at.atlas = pc["tex"]
	var r: Rect2 = pc["rect"]
	at.region = Rect2(r.position, Vector2(32, 32))
	return at

func _cor(rar: String) -> Color:
	return Equipamento.COR_RARIDADE.get(rar, Color.WHITE)

## Cartão de item: brilho da raridade no topo, ícone na moldura, nome em caixa alta, raridade e preço.
## Linha do cartão do equipamento: ícone do elemento e o que ele melhora (pedido do João, 2026-11-13).
func _selo_elemento(id: String) -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 3)
	var el := Equipamento.elemento_de(id)
	var rar := Equipamento.raridade_de(id)
	var ic := TextureRect.new()
	ic.texture = load("res://artes/combate/elem16_%s.png" % (el if el != "" else "comum"))
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	h.add_child(ic)
	var t := ""
	if el != "" and Equipamento.HAB_EL.has(rar):
		t = tr("LOJA_EL_CURTO") % [int(Equipamento.HAB_EL[rar]), tr("EL_" + el.to_upper())]
	else:
		t = tr("LOJA_ATR_CURTO") % [int(Equipamento.PONTOS.get(rar, 0)), tr("ATR_" + Equipamento.atributo_de(id).to_upper())]
	var r := Tema.rotulo(t, 8, true)
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.add_theme_color_override("font_color", Color("#c8ccd8"))
	h.add_child(r)
	return h

## O que a peça dá, para o popup de compra: atributo principal, elemento e conjunto.
func _descricao_equip(id: String) -> String:
	var rar := Equipamento.raridade_de(id)
	var linhas: Array = [tr("LOJA_EQ_ATRIBUTO") % [int(Equipamento.PONTOS.get(rar, 0)), tr("ATR_" + Equipamento.atributo_de(id).to_upper())]]
	var el := Equipamento.elemento_de(id)
	if el != "" and Equipamento.HAB_EL.has(rar):
		var nome_el := tr("EL_" + el.to_upper())
		linhas.append(tr("LOJA_EQ_ELEMENTO") % [nome_el, int(Equipamento.HAB_EL[rar]), nome_el])
	else:
		linhas.append(tr("LOJA_EQ_SEM_ELEMENTO"))
	if Equipamento.conjunto_de(id) != "":
		linhas.append(tr("LOJA_EQ_CONJUNTO") % Equipamento.conjunto_de(id))
	return "\n".join(linhas)

func _cartao(icone: Texture2D, nome: String, rar: String, valor: int, moeda: String, gratis: bool, vendido: bool, largura: int, acao: Callable, extra: Control = null) -> Control:
	var c := PanelContainer.new()
	c.custom_minimum_size = Vector2(largura, 124)
	var e := StyleBoxFlat.new()
	e.bg_color = Color("#181a28")
	e.border_color = _cor(rar).darkened(0.35)
	e.set_border_width_all(2)
	e.set_corner_radius_all(4)
	e.content_margin_left = 4
	e.content_margin_right = 4
	e.content_margin_top = 4
	e.content_margin_bottom = 4
	c.add_theme_stylebox_override("panel", e)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var topo := Control.new()
	topo.custom_minimum_size = Vector2(0, 44)
	var brilho := ColorRect.new()
	brilho.color = Color(_cor(rar), 0.18)
	brilho.size = Vector2(largura - 8, 24)
	topo.add_child(brilho)
	var mold := TextureRect.new()
	mold.texture = load("res://artes/interface/moldura_%s.png" % rar)
	mold.size = Vector2(40, 40)
	mold.position = Vector2((largura - 8 - 40) / 2.0, 2)
	topo.add_child(mold)
	var ic := TextureRect.new()
	ic.texture = icone
	ic.size = Vector2(32, 32)
	ic.position = mold.position + Vector2(4, 4)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	topo.add_child(ic)
	v.add_child(topo)
	var n := Tema.rotulo(nome.to_upper(), 8, true)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(largura - 10, 22)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(n)
	var r := Tema.rotulo("RAR_" + rar.to_upper(), 8, true)
	r.add_theme_color_override("font_color", _cor(rar))
	v.add_child(r)
	if extra != null:
		v.add_child(extra)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 28)
	b.add_theme_font_override("font", Tema.fonte_numeros)
	b.add_theme_font_size_override("font_size", 12)
	if gratis:
		b.text = "LOJA_GRATIS"
		Tema.estilo_botao(b, "confirmar")
	else:
		b.text = _num(valor)
		b.icon = load("res://artes/interface/icone16_%s.png" % moeda)
		b.set_meta("fonte_fixa", true)   # preço na fonte original mesmo se o botão diminuir o texto
	b.pressed.connect(acao)
	v.add_child(b)
	c.add_child(v)
	if vendido:
		c.modulate = Color(0.45, 0.45, 0.5)
		b.disabled = true
		b.text = "LOJA_VENDIDO"
		b.icon = null
	return c

func _pacote(tipo: String, k: int, quantia: String, preco: String, moeda: String, acao: Callable, trancado := false) -> Control:
	var c := PanelContainer.new()
	c.custom_minimum_size = Vector2(108, 112)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var pilha := TextureRect.new()
	pilha.texture = load("res://artes/loja/%s_%d.png" % [tipo, k])
	pilha.custom_minimum_size = Vector2(0, 40)
	pilha.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	pilha.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.add_child(pilha)
	var q := Tema.rotulo(quantia, 16, true)
	q.add_theme_color_override("font_color", Tema.COR_OURO_CLARO if tipo == "moedas" else Color("#9fe8ff"))
	v.add_child(q)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 26)
	b.add_theme_font_size_override("font_size", 12)
	b.text = preco
	if moeda != "":
		b.icon = load("res://artes/interface/icone16_%s.png" % moeda)
		b.add_theme_font_override("font", Tema.fonte_numeros)
		b.add_theme_font_size_override("font_size", 12)
		b.set_meta("fonte_fixa", true)
	elif trancado:
		# dinheiro real bloqueado: cadeado e "Bloqueado" no lugar do preço; o toque explica
		Tema.estilo_botao(b, "secundario")
		b.text = "LOJA_BLOQUEADO"
		b.icon = load("res://artes/interface/icone16_cadeado.png")
		b.add_theme_font_size_override("font_size", 12)
		b.modulate = Color(1, 1, 1, 0.8)
		pilha.modulate = Color(0.55, 0.55, 0.6, 1)
		q.modulate = Color(0.7, 0.7, 0.75, 1)
	else:
		Tema.estilo_botao(b, "confirmar")
	b.pressed.connect(acao)
	v.add_child(b)
	c.add_child(v)
	return c

## 1500 → "1.500" (Silkscreen, que não confunde o 5 com S).
func _num(n: int) -> String:
	var s := str(n)
	var r := ""
	var k := 0
	for i in range(s.length() - 1, -1, -1):
		r = s[i] + r
		k += 1
		if k % 3 == 0 and i > 0:
			r = "." + r
	return r

# ------------------------------------------------------------ animação e textos
func _process(delta: float) -> void:
	_t += delta
	if _t < 0.125:
		return
	_t = 0.0
	_q = (_q + 1) % 8
	if toldo:
		toldo.texture = toldo_quadros[_q]
	for par in vitrines:
		par[0].texture = vitrine_quadros[par[1]][_q]
	if _q == 0:
		for r in relogios:
			r.text = tr("LOJA_RENOVA") % Loja.texto_renova()
		if str(Jogo.dados.get("loja", {}).get("dia", "")) != Loja.hoje() and Loja.liberada():
			principal.abrir_aba("loja")        # virou o dia: vitrine nova
		elif _versao_promos >= 0 and ConfigRemota.versao != _versao_promos and popup == null:
			principal.abrir_aba("loja")        # promoções novas do Firebase

func atualizar_textos() -> void:
	if pilula_moedas:
		pilula_moedas.text = _num(int(Jogo.dados["moedas"]))
		pilula_cristais.text = _num(int(Jogo.dados["cristais"]))
	for r in relogios:
		r.text = tr("LOJA_RENOVA") % Loja.texto_renova()

# ------------------------------------------------------------ compras
func _fechar_popup() -> void:
	if popup is Janela:
		(popup as Janela).fechar()
	popup = null

## Confirmação: o item grande no centro, nome, preço e Comprar / Cancelar.
func _confirmar(icone: Texture2D, nome: String, rar: String, preco_txt: String, moeda: String, acao: Callable, texto := "") -> void:
	_fechar_popup()
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 6)
	var topo := Control.new()
	topo.custom_minimum_size = Vector2(80, 84)
	var mold := TextureRect.new()
	mold.texture = load("res://artes/interface/moldura_%s.png" % rar)
	mold.size = Vector2(80, 80)
	mold.position = Vector2(90, 0)
	mold.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mold.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	topo.add_child(mold)
	var ic := TextureRect.new()
	ic.texture = icone
	ic.size = Vector2(64, 64)
	ic.position = Vector2(98, 8)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	topo.add_child(ic)
	caixa.add_child(topo)
	var n := Tema.rotulo(nome, 16)
	n.add_theme_color_override("font_color", _cor(rar).lightened(0.2))
	caixa.add_child(n)
	if texto != "":
		var d := Tema.rotulo(texto, 12)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(260, 0)
		d.add_theme_color_override("font_color", Color("#c8ccd8"))
		caixa.add_child(d)
	var p := HBoxContainer.new()
	p.alignment = BoxContainer.ALIGNMENT_CENTER
	if moeda != "":
		var im := TextureRect.new()
		im.texture = load("res://artes/interface/icone16_%s.png" % moeda)
		im.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		p.add_child(im)
	var pt := Tema.rotulo(preco_txt, 16, true)
	pt.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	p.add_child(pt)
	caixa.add_child(p)
	var j := Janela.criar(tr("LOJA_CONFIRMAR"), [["LOJA_COMPRAR", acao]], "", [caixa])
	j.destaque = false
	j.fechar_x = _fechar_popup
	popup = j
	add_child(j)

func _pedir_item(i: int) -> void:
	var e: Dictionary = Loja.vitrine()["itens"][i]
	var it: Dictionary = Loja.consumiveis().get(e["id"], {})
	var p := Loja.preco_item(str(e["id"]))
	var preco_txt := tr("LOJA_GRATIS") if bool(e["gratis"]) else _num(int(p[0]))
	var moeda := "" if bool(e["gratis"]) else str(p[1])
	_confirmar(_icone_item(str(it.get("icone", ""))), str(it.get("nome", "")), str(it.get("raridade", "comum")), preco_txt, moeda,
		_feito.bind(func(): return Loja.comprar_item(i)), str(it.get("efeito", "")).split(" · ")[-1])

func _pedir_equip(i: int) -> void:
	var id := str(Loja.vitrine()["equips"][i]["id"])
	var desc := _descricao_equip(id)
	_confirmar(Equipamento.icone(id), str(Equipamento.ficha(id)["nome"]), Equipamento.raridade_de(id), _num(Loja.preco_equip(id)), "moeda",
		_feito.bind(func(): return Loja.comprar_equip(i)), desc)

func _pedir_moedas(k: int) -> void:
	_confirmar(load("res://artes/loja/moedas_%d.png" % (k + 1)), tr("LOJA_PACOTE_MOEDAS") % _num(Loja.moedas_do_pacote(k)), "raro",
		_num(int(Loja.MOEDAS[k][0])), "cristal", _feito.bind(func(): return Loja.trocar_moedas(k)))

## Selo "cadeado + EM BREVE" no canto da promoção enquanto o dinheiro real está bloqueado.
func _selo_bloqueado() -> Control:
	var s := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = Color("#12131c", 0.92)
	e.border_color = Tema.COR_OURO
	e.set_border_width_all(1)
	e.set_corner_radius_all(3)
	e.content_margin_left = 5
	e.content_margin_right = 6
	e.content_margin_top = 2
	e.content_margin_bottom = 2
	s.add_theme_stylebox_override("panel", e)
	s.position = Vector2(6, 6)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cad := TextureRect.new()
	cad.texture = load("res://artes/interface/icone16_cadeado.png")
	cad.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	cad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(cad)
	var r := Tema.rotulo("LOJA_EM_BREVE", 12)
	r.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(r)
	s.add_child(h)
	return s

## Compra com dinheiro real: bloqueada por enquanto (Loja.PAGOS_LIBERADOS); chega com as lojas oficiais.
func _pedir_real(nome: String, preco: String) -> void:
	_fechar_popup()
	var j := Janela.criar(nome, [["OK", _fechar_popup]], tr("LOJA_PAGO_BLOQUEADO") if not Loja.PAGOS_LIBERADOS else tr("LOJA_REAL_DEPOIS") % preco)
	popup = j
	add_child(j)

func _pedir_promo(p: Dictionary) -> void:
	_fechar_popup()
	var pp = preload("res://scripts/componentes/popup_promocao.gd").new()
	pp.promo = str(p["id"])
	add_child(pp)

func _feito(compra: Callable) -> void:
	var erro: String = compra.call()
	_fechar_popup()
	if erro != "":
		var j := Janela.criar(tr(erro), [["OK", _fechar_popup]])
		popup = j
		add_child(j)
		return
	# monta de novo para mostrar "VENDIDO" e o saldo novo, na mesma posição da rolagem
	var y := rolagem.scroll_vertical
	for f in lista.get_children():
		f.queue_free()
	vitrines.clear()
	relogios.clear()
	await get_tree().process_frame
	_montar_tudo()
	await get_tree().process_frame
	rolagem.scroll_vertical = y
	var t := create_tween()
	pilula_moedas.pivot_offset = Vector2(20, 5)
	t.tween_property(pilula_moedas, "scale", Vector2(1.4, 1.4), 0.1)
	t.tween_property(pilula_moedas, "scale", Vector2.ONE, 0.15)
