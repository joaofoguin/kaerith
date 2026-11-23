class_name FichaPeca
extends Control
## Ficha de uma peça do inventário. Faixa no topo na cor da raridade, a peça grande girando devagar
## sobre raios de luz, nome, raridade/elemento, atributos com ícone, comparação com a peça do mesmo
## espaço (▲ verde / ▼ vermelho), progresso do conjunto e os botões. Nunca passa da tela.
## Sinal `escolheu(acao)`: "equipar", "tirar", "vender", "excluir" ou "fechar".

signal escolheu(acao: String)

const LARGURA := 320.0
const ICONE_ATR := {"forca": "icone16_forca.png", "percepcao": "icone16_percepcao.png", "agilidade": "icone16_agilidade.png",
	"resistencia": "icone16_resistencia.png", "ressonancia": "icone16_ressonancia.png", "vida": "icone16_vida.png", "critico": "icone16_mais.png"}

var uid := -1
var _id := ""
var _cor := Color.WHITE
var _painel: PanelContainer
var _raios: Control
var _peca: Control
var _tempo := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Tema.elevar(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var p := Equipamento.peca(uid)
	_id = str(p.get("id", ""))
	var rar := Equipamento.raridade_de(_id)
	_cor = Equipamento.COR_RARIDADE.get(rar, Color.WHITE)
	var veu := ColorRect.new()
	veu.color = Color(0.02, 0.02, 0.05, 0.7)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.gui_input.connect(_toque_fora)
	add_child(veu)

	_painel = PanelContainer.new()
	_painel.custom_minimum_size = Vector2(LARGURA, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#151726")
	estilo.border_color = _cor.darkened(0.25)
	estilo.set_border_width_all(2)
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = 12
	estilo.content_margin_right = 12
	estilo.content_margin_top = 0
	estilo.content_margin_bottom = 12
	estilo.shadow_color = Color(_cor, 0.25)
	estilo.shadow_size = 10
	_painel.add_theme_stylebox_override("panel", estilo)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	_painel.add_child(c)
	add_child(_painel)

	# --- topo: faixa na cor da raridade com a peça grande e os raios atrás
	var topo := Control.new()
	topo.custom_minimum_size = Vector2(LARGURA - 24, 112)
	_raios = Control.new()
	_raios.position = Vector2(-12, 0)
	_raios.size = Vector2(LARGURA, 112)
	_raios.clip_contents = true
	_raios.draw.connect(_desenhar_topo)
	topo.add_child(_raios)
	_peca = Control.new()
	_peca.position = Vector2((LARGURA - 24) / 2.0 - 40, 16)
	_peca.size = Vector2(80, 80)
	_peca.pivot_offset = Vector2(40, 40)
	var m := TextureRect.new()
	m.texture = Equipamento.moldura(_id)
	m.size = Vector2(40, 40)
	m.scale = Vector2(2, 2)
	m.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_peca.add_child(m)
	var ic := TextureRect.new()
	ic.texture = Equipamento.icone(_id)
	ic.position = Vector2(8, 8)
	ic.size = Vector2(32, 32)
	ic.scale = Vector2(2, 2)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_peca.add_child(ic)
	topo.add_child(_peca)
	var fechar := Tema.botao_x()             # mesmo X vermelho dos outros popups
	fechar.position = Vector2(LARGURA - 24 - 30, 8)
	fechar.pressed.connect(_emitir.bind("fechar"))
	topo.add_child(fechar)
	c.add_child(topo)

	# --- nome, raridade · elemento, espaço · conjunto
	var nome := Tema.rotulo(str(Equipamento.ficha(_id).get("nome", "")), 24)
	nome.add_theme_color_override("font_color", _cor.lightened(0.15))
	nome.add_theme_constant_override("outline_size", 4)
	nome.add_theme_color_override("font_outline_color", Color("#0c0d16"))
	c.add_child(nome)
	Tema.caber(nome, LARGURA - 24, 30, 1, [24, 16])
	# losangos da raridade (1 a 5), como nas células do inventário
	var nivel := 5 - int(Equipamento.ORDEM_RARIDADE.get(rar, 4))
	var estrelas := Control.new()
	estrelas.custom_minimum_size = Vector2(LARGURA - 24, 8)
	estrelas.draw.connect(func():
		var x0 := (LARGURA - 24) / 2.0 - (nivel * 10 - 4) / 2.0
		for k in nivel:
			var q := Vector2(floorf(x0 + k * 10 + 3), 4)
			estrelas.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -4), q + Vector2(4, 0), q + Vector2(0, 4), q + Vector2(-4, 0)]), _cor.darkened(0.4))
			estrelas.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -3), q + Vector2(3, 0), q + Vector2(0, 3), q + Vector2(-3, 0)]), _cor.lightened(0.2)))
	c.add_child(estrelas)
	var el := Equipamento.elemento_de(_id)
	var linha_chips := HBoxContainer.new()
	linha_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	linha_chips.add_theme_constant_override("separation", 6)
	linha_chips.add_child(_chip(tr("RAR_" + rar.to_upper()), _cor))
	if el != "":
		var chip_el := _chip(tr("EL_" + el.to_upper()), Color("#c8ccd8"))
		var ie := TextureRect.new()
		ie.texture = load("res://artes/combate/elem20_%s.png" % el)
		ie.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ie.custom_minimum_size = Vector2(20, 20)
		linha_chips.add_child(ie)
		linha_chips.add_child(chip_el)
	linha_chips.add_child(_chip(tr("EQ_" + Equipamento.tipo_de(_id).to_upper()), Color("#9a9fb8")))
	c.add_child(linha_chips)

	# --- atributos da peça (com a diferença para a peça do mesmo espaço)
	var caixa := PanelContainer.new()
	var ec := StyleBoxFlat.new()
	ec.bg_color = Color("#0e0f18")
	ec.set_corner_radius_all(3)
	ec.content_margin_left = 8
	ec.content_margin_right = 8
	ec.content_margin_top = 6
	ec.content_margin_bottom = 6
	caixa.add_theme_stylebox_override("panel", ec)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 4)
	caixa.add_child(lista)
	var meu := _contribuicao(p)
	var outro := {}
	var onde := Equipamento.espaco_de_uid(uid)
	var comparar := onde == "" and Equipamento.tipo_de(_id) != "acessorio"
	if comparar:
		outro = _contribuicao(Equipamento.em(Equipamento.espacos_para(_id)[0]))
	var atr := Equipamento.atributo_de(_id)
	lista.add_child(_linha(ICONE_ATR[atr], tr("ATR_" + atr.to_upper()), "+%d" % int(Equipamento.PONTOS[rar]), ""))
	for x in p.get("extras", []):
		var t := str(x["tipo"])
		lista.add_child(_linha(ICONE_ATR.get(t, "icone16_mais.png"), tr("EQ_EXTRA"), Equipamento.texto_extra(x), ""))
	if el != "" and Equipamento.HAB_EL.has(rar):
		lista.add_child(_linha("icone16_ressonancia.png", tr("EQ_HAB_EL") % tr("EL_" + el.to_upper()), "+%d%%" % int(Equipamento.HAB_EL[rar]), ""))
	c.add_child(caixa)
	if comparar:
		c.add_child(_comparacao(meu, outro))
	elif Equipamento.tipo_de(_id) == "acessorio" and onde == "":
		var a1 := Equipamento.em("acessorio1")
		var a2 := Equipamento.em("acessorio2")
		var txt := tr("EQ_ACESS_AGORA") % [_nome_ou_vazio(a1), _nome_ou_vazio(a2)]
		c.add_child(_nota(txt))

	# --- conjunto
	var conj := Equipamento.conjunto_de(_id)
	if conj != "":
		var n := int(Equipamento.bonus()["conjuntos"].get(conj, 0))
		var txt := "%s · %d/5" % [conj, n]
		var bar := _barra_conjunto(n)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 3)
		var r := Tema.rotulo(txt, 12)
		r.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
		vb.add_child(r)
		vb.add_child(bar)
		vb.add_child(_nota(tr("EQ_CONJ_REGRA")))
		c.add_child(vb)

	# --- botões
	var principal := Button.new()
	principal.custom_minimum_size = Vector2(0, 46)
	principal.add_theme_font_size_override("font_size", 24)
	if onde != "":
		principal.text = "EQ_TIRAR"
		Tema.estilo_botao(principal, "secundario")
		principal.pressed.connect(_emitir.bind("tirar"))
	else:
		principal.text = "EQ_EQUIPAR"
		Tema.estilo_botao(principal, "confirmar")
		principal.pressed.connect(_emitir.bind("equipar"))
	c.add_child(principal)
	var baixo := HBoxContainer.new()
	baixo.add_theme_constant_override("separation", 8)
	var vender := Button.new()
	vender.text = tr("EQ_VENDER") % Equipamento.preco_venda(_id)
	vender.icon = load("res://artes/interface/icone16_moeda.png")
	vender.custom_minimum_size = Vector2(0, 40)
	vender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vender.add_theme_font_size_override("font_size", 12)
	Tema.estilo_botao(vender, "secundario")
	vender.pressed.connect(_emitir.bind("vender"))
	baixo.add_child(vender)
	var excluir := Button.new()
	excluir.text = "EQ_EXCLUIR"
	excluir.custom_minimum_size = Vector2(96, 40)
	excluir.add_theme_font_size_override("font_size", 12)
	Tema.estilo_botao(excluir, "perigo")
	excluir.pressed.connect(_emitir.bind("excluir"))
	baixo.add_child(excluir)
	c.add_child(baixo)

	_painel.modulate.a = 0.0
	_encaixar.call_deferred()

func _encaixar() -> void:
	await get_tree().process_frame
	var tela := size if size.y > 0.0 else get_viewport_rect().size
	_painel.reset_size()
	var alto := tela.y - 24.0
	if _painel.size.y > alto:
		var c: Control = _painel.get_child(0)
		_painel.remove_child(c)
		var rol := ScrollContainer.new()
		rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		rol.custom_minimum_size = Vector2(LARGURA - 24, alto - 16)
		rol.add_child(c)
		_painel.add_child(rol)
		_painel.reset_size()
	_painel.size = Vector2(LARGURA, minf(_painel.size.y, alto))
	_painel.position = ((tela - _painel.size) / 2.0).floor()
	_painel.pivot_offset = _painel.size / 2.0
	_painel.scale = Vector2(0.9, 0.9)
	Tema.manter_centrado(_painel, alto)
	Tema.ajustar_depois(self)
	var t := create_tween().set_parallel(true)
	t.tween_property(_painel, "modulate:a", 1.0, 0.18)
	t.tween_property(_painel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_peca.scale = Vector2(0.4, 0.4)
	var tp := create_tween()
	tp.tween_property(_peca, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)

func _process(delta: float) -> void:
	_tempo += delta
	if _raios:
		_raios.queue_redraw()
	if _peca:
		_peca.position.y = 16.0 + roundf(sin(_tempo * 2.0) * 2.0)

## Faixa de cima: degradê na cor da raridade, raios girando e brilhos.
func _desenhar_topo() -> void:
	var s := _raios.size
	for i in 14:
		var f := float(i) / 14.0
		_raios.draw_rect(Rect2(0, i * 8, s.x, 8), Color(_cor.darkened(0.55), 0.85 - f * 0.6))
	var centro := Vector2(s.x / 2.0, 56)
	for i in 12:
		var a := _tempo * 0.4 + i * TAU / 12.0
		var p1 := centro + Vector2.from_angle(a - 0.08) * 220.0
		var p2 := centro + Vector2.from_angle(a + 0.08) * 220.0
		_raios.draw_colored_polygon(PackedVector2Array([centro, p1, p2]), Color(_cor, 0.1))
	for k in 4:
		_raios.draw_circle(centro, 30.0 + k * 10.0, Color(_cor, 0.06))
	var q := int(_tempo * 5.0)
	var pontos := [Vector2(60, 24), Vector2(236, 30), Vector2(84, 86), Vector2(220, 84), Vector2(40, 60), Vector2(262, 62)]
	for k in pontos.size():
		if (q + k) % 3 == 0:
			continue
		var p: Vector2 = pontos[k]
		_raios.draw_rect(Rect2(p - Vector2(3, 0), Vector2(8, 2)), Color(_cor.lightened(0.4), 0.8))
		_raios.draw_rect(Rect2(p - Vector2(0, 3), Vector2(2, 8)), Color(_cor.lightened(0.4), 0.8))
	_raios.draw_rect(Rect2(0, s.y - 2, s.x, 2), Color(_cor, 0.6))

func _chip(texto: String, cor: Color) -> Control:
	var p := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = Color(cor, 0.14)
	e.border_color = Color(cor, 0.6)
	e.set_border_width_all(1)
	e.set_corner_radius_all(8)
	e.content_margin_left = 6
	e.content_margin_right = 6
	e.content_margin_top = 1
	e.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", e)
	var r := Tema.rotulo(texto, 12)
	r.add_theme_color_override("font_color", cor)
	p.add_child(r)
	return p

func _linha(icone: String, nome: String, valor: String, delta: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var ic := TextureRect.new()
	ic.texture = load("res://artes/interface/" + icone)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.custom_minimum_size = Vector2(16, 20)
	h.add_child(ic)
	var n := Tema.rotulo(nome, 16)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	h.add_child(n)
	var v := Tema.rotulo(valor, 16)
	v.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	h.add_child(v)
	if delta != "":
		h.add_child(Tema.rotulo(delta, 12))
	return h

func _nota(texto: String) -> Label:
	var r := Tema.rotulo(texto, 12)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(LARGURA - 24, 0)
	r.add_theme_color_override("font_color", Color("#9a9fb8"))
	return r

func _nome_ou_vazio(p: Dictionary) -> String:
	if p.is_empty():
		return tr("EQ_VAZIO_CURTO")
	return str(Equipamento.ficha(str(p["id"])).get("nome", ""))

## Pontos que a peça soma por tipo (atributo principal + extras).
func _contribuicao(p: Dictionary) -> Dictionary:
	var r := {}
	if p.is_empty():
		return r
	var id := str(p["id"])
	var a := Equipamento.atributo_de(id)
	r[a] = int(r.get(a, 0)) + int(Equipamento.PONTOS[Equipamento.raridade_de(id)])
	for x in p.get("extras", []):
		var t := str(x["tipo"])
		r[t] = int(r.get(t, 0)) + int(x["valor"])
	return r

## "Trocando pela peça equipada": ▲ verde no que sobe, ▼ vermelho no que desce.
func _comparacao(meu: Dictionary, outro: Dictionary) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	var atual := Equipamento.em(Equipamento.espacos_para(_id)[0])
	vb.add_child(_nota(tr("EQ_TROCANDO") % _nome_ou_vazio(atual) if not atual.is_empty() else tr("EQ_ESPACO_VAZIO")))
	var tipos: Array = []
	for k in meu:
		tipos.append(k)
	for k in outro:
		if not k in tipos:
			tipos.append(k)
	var linha := HFlowContainer.new()
	linha.add_theme_constant_override("h_separation", 10)
	for k in tipos:
		var d := int(meu.get(k, 0)) - int(outro.get(k, 0))
		if d == 0:
			continue
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		var ic := TextureRect.new()
		ic.texture = load("res://artes/interface/" + ICONE_ATR.get(k, "icone16_mais.png"))
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(ic)
		var sufixo := "%" if k in ["vida", "critico"] else ""
		var r := Tema.rotulo(("+%d%s" if d > 0 else "%d%s") % [d, sufixo], 12)
		r.add_theme_color_override("font_color", Color("#7fd07a") if d > 0 else Color("#ff6a5a"))
		h.add_child(r)
		linha.add_child(h)
	if linha.get_child_count() > 0:
		vb.add_child(linha)
	return vb

func _barra_conjunto(n: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	for i in 5:
		var q := ColorRect.new()
		q.custom_minimum_size = Vector2(54, 6)
		q.color = Tema.COR_OURO if i < n else Color("#2a2c3c")
		if i == 2 or i == 4:
			q.color = Tema.COR_OURO_CLARO if i < n else Color("#4a4458")
		h.add_child(q)
	return h

func _toque_fora(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		_emitir("fechar")

func _emitir(acao: String) -> void:
	escolheu.emit(acao)

func fechar() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)
