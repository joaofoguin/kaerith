extends Tela
## Diário (etapa 9). Abas por tipo (DEFINIDO): História, Missões, Personagens e Bestiário, num painel claro
## de pergaminho (kit aprovado). Bestiário revela aos poucos (regras em bestiario.gd).
## PROVISÓRIO (meu): a História guarda os textos já vistos (Prólogo, Campos de Auren, Despertar) e mostra os
## 4 capítulos da S1 com cadeado até os textos deles entrarem no jogo; Missões fica vazia até a etapa das
## missões; "A Voz" é o primeiro personagem (sem retrato ainda); selo "NOVO" some quando o jogador abre a ficha.

const ABAS := ["DIARIO_HISTORIA", "DIARIO_MISSOES", "DIARIO_PERSONAGENS", "DIARIO_BESTIARIO"]
const COR_TINTA := Color("#22160c")
const COR_TINTA_CLARA := Color("#5a4026")
const COLUNAS := 5
const CAPITULOS := ["DIARIO_CAP_1", "DIARIO_CAP_2", "DIARIO_CAP_3", "DIARIO_CAP_4"]
const HISTORIA := preload("res://scripts/historia.gd")

var aba := 0
var barra: BarraAbas
var lista: VBoxContainer
var rolagem: ScrollContainer
var popup: Control

func montar() -> void:
	Tema.fundo(self)
	Tema.cabecalho(self, "ABA_DIARIO", 300)

	var icones := ["historia", "missoes", "personagens", "bestiario"]
	var itens: Array = []
	for i in ABAS.size():
		itens.append([ABAS[i], "res://artes/interface/abas/%s.png" % icones[i]])
	barra = BarraAbas.criar(itens, 348)
	barra.position = Vector2(6, 52)
	barra.trocou.connect(_trocar_aba)
	add_child(barra)

	# caderno de anotações: folha pautada com margem vermelha e argolas à esquerda
	var caderno := Control.new()
	caderno.position = Vector2(6, 96)
	caderno.size = Vector2(348, 482)
	caderno.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caderno.draw.connect(_desenhar_caderno.bind(caderno))
	add_child(caderno)
	rolagem = ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	rolagem.position = Vector2(50, 110)      # 1ª linha da pauta em y 130 = 20 px dentro da lista
	rolagem.size = Vector2(296, 456)
	add_child(rolagem)
	lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 0)     # cada anotação ocupa linhas inteiras da pauta
	rolagem.add_child(lista)
	# caderno e lista vão até o fim da tela (celulares mais altos que 584)
	_caderno = caderno
	resized.connect(_ajustar_altura)
	_ajustar_altura.call_deferred()
	_trocar_aba(0)

var _caderno: Control
func _ajustar_altura() -> void:
	var h := maxf(584.0, size.y)
	_caderno.size = Vector2(348, h - 102.0)
	rolagem.size = Vector2(296, h - 128.0)
	_caderno.queue_redraw()

const PAPEL := Color("#f1e6cc")
const PAUTA := Color(0.42, 0.56, 0.72, 0.30)
const MARGEM := Color(0.75, 0.25, 0.22, 0.55)

func _desenhar_caderno(c: Control) -> void:
	var t := c.size
	c.draw_rect(Rect2(Vector2(3, 4), t), Color(0, 0, 0, 0.45))          # sombra
	c.draw_rect(Rect2(Vector2.ZERO, t), Color("#5a4026"))                 # capa por trás
	var folha := Rect2(4, 2, t.x - 6, t.y - 6)
	c.draw_rect(folha, PAPEL)
	# manchinhas do papel (fixas, sem sorteio a cada quadro)
	for k in 90:
		var x := fposmod(k * 73.0, folha.size.x - 4) + folha.position.x
		var y := fposmod(k * 131.0, folha.size.y - 4) + folha.position.y
		c.draw_rect(Rect2(floorf(x), floorf(y), 2, 1), Color(0.55, 0.42, 0.25, 0.10))
	c.draw_rect(Rect2(folha.position, Vector2(folha.size.x, 22)), Color(0.55, 0.42, 0.25, 0.10))
	var y0 := 34.0
	while y0 < folha.end.y - 4:
		c.draw_rect(Rect2(folha.position.x + 2, y0, folha.size.x - 4, 1), PAUTA)
		y0 += 20.0
	c.draw_rect(Rect2(38, folha.position.y, 1, folha.size.y), MARGEM)
	c.draw_rect(Rect2(40, folha.position.y, 1, folha.size.y), MARGEM)
	# argolas
	var yy := 24.0
	while yy < t.y - 16:
		c.draw_circle(Vector2(18, yy), 5.0, Color("#3a2a1a"))
		c.draw_circle(Vector2(18, yy), 3.0, Color("#0f101a"))
		c.draw_rect(Rect2(2, yy - 2, 16, 3), Color("#9aa0b4"))
		c.draw_rect(Rect2(2, yy - 2, 16, 1), Color("#d8dce8"))
		yy += 36.0
	# canto dobrado
	var p := folha.end
	c.draw_colored_polygon(PackedVector2Array([p, p + Vector2(-18, 0), p + Vector2(0, -18)]), Color("#5a4026"))
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(-18, 0), p + Vector2(0, -18), p + Vector2(-18, -18)]), Color("#d8c8a4"))

func _trocar_aba(i: int) -> void:
	aba = i
	if barra:
		barra.marcar(aba)
	lista.modulate.a = 0.0                       # a lista nova aparece suavemente
	create_tween().tween_property(lista, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	_montar_aba()

## Selo "!" nas abas que têm novidade (personagem ou espécie nova ainda não aberta).
func _atualizar_alertas() -> void:
	if barra:
		barra.alerta(1, HISTORIA.tem_para_coletar())
		barra.alerta(2, Bestiario.novidade_personagens())
		barra.alerta(3, Bestiario.novidade_bestiario())

func _montar_aba() -> void:
	_atualizar_alertas()
	for f in lista.get_children():
		f.queue_free()
	rolagem.scroll_vertical = 0
	match aba:
		0:
			_aba_historia()
		1:
			_aba_missoes()
		2:
			_aba_personagens()
		3:
			_aba_bestiario()

func atualizar_textos() -> void:
	if lista:
		_montar_aba()

# ------------------------------------------------------------ peças comuns
func _tinta(texto: String, tam := 12, clara := false) -> Label:
	var l := Tema.rotulo(texto, tam)
	l.add_theme_color_override("font_color", COR_TINTA_CLARA if clara else COR_TINTA)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _vazio(chave: String) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 160)
	lista.add_child(c)
	var l := _tinta(chave, 16, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(290, 0)
	lista.add_child(l)

## Linha tocável: ícone (ou nada), título, subtítulo e selo NOVO.
func _linha(icone: Texture2D, titulo: String, sub: String, bloqueada: bool, novo: bool, acao: Callable, tam_titulo := 16) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(290, 60)      # 3 linhas da pauta (20 px cada)
	var e := StyleBoxEmpty.new()
	var ep := StyleBoxFlat.new()                 # tocado: marca-texto amarelo
	ep.bg_color = Color(1.0, 0.86, 0.3, 0.35)
	ep.set_corner_radius_all(2)

	for s in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, e)
	b.add_theme_stylebox_override("pressed", ep)
	b.disabled = bloqueada
	if not bloqueada:
		b.pressed.connect(acao)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 2
	h.offset_right = -6
	h.add_theme_constant_override("separation", 8)
	h.offset_top = 20
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(44, 44)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.texture = load("res://artes/interface/icone16_cadeado.png") if bloqueada else icone
	if bloqueada:
		ic.modulate = Color(0.45, 0.35, 0.25)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.custom_minimum_size = Vector2(20, 44)
	h.add_child(ic)
	ic.visible = ic.texture != null              # anotação sem figura começa colada na margem
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_theme_constant_override("separation", 4)
	v.offset_top = 0
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := _tinta(titulo, tam_titulo, bloqueada)
	t.autowrap_mode = TextServer.AUTOWRAP_OFF
	t.clip_text = true
	v.add_child(t)
	if sub != "":
		var s := _tinta(sub, 12, true)
		s.autowrap_mode = TextServer.AUTOWRAP_OFF
		s.clip_text = true
		v.add_child(s)
	h.add_child(v)
	if novo:
		h.add_child(_selo_novo())
	return b

func _selo_novo(chave := "DIARIO_NOVO", cor := Color("#b8322a")) -> Control:
	var p := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = cor
	e.set_corner_radius_all(3)
	e.content_margin_left = 4
	e.content_margin_right = 4
	p.add_theme_stylebox_override("panel", e)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Tema.rotulo(chave, 8, true)
	l.add_theme_color_override("font_color", Color.WHITE)
	p.add_child(l)
	return p

func _fechar_popup() -> void:
	if popup is Janela:
		(popup as Janela).fechar()
	popup = null

func _abrir(j: Janela) -> void:
	_fechar_popup()
	popup = j
	add_child(j)

# ------------------------------------------------------------ História
## Capítulos já vividos, na ordem: [título, subtítulo, liberado, partes do texto]
func _capitulos() -> Array:
	var etapa := str(Jogo.dados.get("etapa", "prologo"))
	var depois_criacao := etapa in ["chegada", "tutorial1", "tutorial2", "pronto"]
	var depois_chegada := etapa in ["tutorial1", "tutorial2", "pronto"]
	var pronto := etapa == "pronto"
	var desp: Array = ["DESP_INTRO_1", "DESP_INTRO_2"]
	var el := str(Jogo.dados.get("elemento", ""))
	if el != "":
		desp.append("DESP_" + el.to_upper())
	desp.append("DESP_GUARDE")
	return [
		["DIARIO_CAP_PROLOGO", "DIARIO_SUB_PROLOGO", depois_criacao, range(1, 10).map(func(n): return "PROLOGO_%d" % n)],
		["CHEG_REGIAO", "DIARIO_SUB_CHEGADA", depois_chegada, range(1, 7).map(func(n): return "CHEG_%d" % n)],
		["DESP_TITULO", "DIARIO_SUB_DESPERTAR", pronto, desp],
	]

func _aba_historia() -> void:
	for c: Array in _capitulos():
		var liberado: bool = c[2]
		lista.add_child(_linha(null, tr(c[0]) if liberado else "???", tr(c[1]) if liberado else "", not liberado, false,
			_ler.bind(tr(c[0]), c[3])))
	var sep := _tinta("DIARIO_TEMPORADA_1", 12, true)
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	sep.custom_minimum_size = Vector2(0, 40)
	lista.add_child(sep)
	for i in CAPITULOS.size():
		var ato := i + 1
		var nome := tr("DIARIO_CAPITULO_N") % ato + " · " + tr(CAPITULOS[i])
		if not HISTORIA.capitulo_liberado(ato):
			lista.add_child(_linha(null, nome, "DIARIO_EM_BREVE", true, false, Callable()))
			continue
		# o capítulo cresce com o que o jogador já viveu: falas dos NPCs, da Voz, a cutscene e o fechamento
		var entradas: Array = HISTORIA.entradas_do_capitulo(ato)
		var sub := tr("REGIAO_%d" % ato)
		if not entradas.is_empty():
			sub += " · " + tr("DIARIO_SUB_CAPITULO") % entradas.size()
		lista.add_child(_linha(null, nome, sub, false, false,
			_ler.bind(nome, entradas if not entradas.is_empty() else ["DIARIO_CAP_VAZIO"])))

## Lê o capítulo na própria folha do caderno: título, um fio e os parágrafos com espaço entre eles.
func _ler(titulo: String, partes: Array) -> void:
	for f in lista.get_children():
		f.queue_free()
	rolagem.scroll_vertical = 0
	var voltar := Button.new()
	voltar.text = "DIARIO_VOLTAR"
	voltar.alignment = HORIZONTAL_ALIGNMENT_LEFT
	voltar.custom_minimum_size = Vector2(0, 28)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		voltar.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		voltar.add_theme_color_override(c, COR_TINTA_CLARA)
	voltar.add_theme_font_size_override("font_size", 12)
	voltar.pressed.connect(_montar_aba)
	lista.add_child(voltar)
	var t := _tinta(titulo, 24)
	t.custom_minimum_size = Vector2(290, 0)
	lista.add_child(t)
	var fio := ColorRect.new()
	fio.color = Color(0.36, 0.25, 0.15, 0.5)
	fio.custom_minimum_size = Vector2(120, 2)
	fio.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	lista.add_child(fio)
	for k: String in partes:
		var p := _tinta(tr(k), 14)
		p.custom_minimum_size = Vector2(290, 0)
		p.add_theme_constant_override("line_spacing", 4)
		lista.add_child(p)
		var esp := Control.new()
		esp.custom_minimum_size = Vector2(0, 6)
		lista.add_child(esp)
	lista.modulate.a = 0.0
	create_tween().tween_property(lista, "modulate:a", 1.0, 0.25)

# ------------------------------------------------------------ Personagens
func _aba_personagens() -> void:
	if str(Jogo.dados.get("etapa", "prologo")) != "prologo":
		lista.add_child(_linha(null, tr("DIARIO_VOZ"), tr("DIARIO_VISTO_EM") % tr("DIARIO_CAP_PROLOGO"), false, false,
			_ficha_personagem.bind("", tr("DIARIO_VOZ"), "", tr("DIARIO_CAP_PROLOGO"), tr("DIARIO_VOZ_DESC"))))
	for npc: String in HISTORIA.npcs_conhecidos():
		var onde_npc := HISTORIA.onde_npc(npc)
		lista.add_child(_linha(HISTORIA.retrato(npc), HISTORIA.nome_npc(npc),
			tr("DIARIO_VISTO_EM") % (tr("FASE_N") % onde_npc if onde_npc > 0 else "?"), false, false,
			_ficha_npc.bind(npc)))
	var p := Bestiario.personagens()
	for id: String in Bestiario.CHEFES:
		if not p.has(id):
			continue
		var r: Dictionary = p[id]
		var f := Bestiario.ficha(id)
		var onde := _onde(str(r.get("onde", "")))
		lista.add_child(_linha(Bestiario.miniatura(id), str(f.get("nome", id)), tr("DIARIO_VISTO_EM") % onde,
			false, bool(r.get("novo", false)), _ficha_personagem.bind(id, str(f.get("nome", id)), _el(f), onde, "")))
	if lista.get_child_count() == 0:
		_vazio("DIARIO_PERSONAGENS_VAZIO")

func _ficha_personagem(id: String, nome: String, el: String, onde: String, desc: String) -> void:
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 6)
	if id != "":
		caixa.add_child(_retrato(id, 128))
	var linhas: Array = []
	if el != "":
		linhas.append(tr("DIARIO_ELEMENTO") % el)
	linhas.append(tr("DIARIO_VISTO_EM") % onde)
	if desc != "":
		linhas.append("")
		linhas.append(desc)
	var l := Tema.rotulo("\n".join(linhas), 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	caixa.add_child(l)
	if id != "":
		Bestiario.marcar_visto(id)
	_abrir(Janela.criar(nome, [["FECHAR", _fechar_popup]], "", [caixa]))
	_montar_aba.call_deferred()

## Ficha do NPC: retrato grande, elemento, onde apareceu, quem é e o que já disse (cresce com a história).
func _ficha_npc(npc: String) -> void:
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 6)
	var tex := HISTORIA.retrato(npc)
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.custom_minimum_size = Vector2(260, 144)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		caixa.add_child(t)
	var onde := HISTORIA.onde_npc(npc)
	var linhas: Array = [
		tr("DIARIO_ELEMENTO") % tr("EL_" + str(HISTORIA.NPCS.get(npc, "")).to_upper()),
		tr("DIARIO_VISTO_EM") % (tr("FASE_N") % onde if onde > 0 else "?"),
		"", tr("NPC_%s_DESC" % npc.to_upper()), "", tr("DIARIO_FALAS").to_upper()]
	var falas: Array = HISTORIA.falas_do_npc(npc)
	if falas.is_empty():
		linhas.append(tr("DIARIO_NPC_NADA"))
	for f: String in falas:
		linhas.append("\"" + f + "\"")
	var l := Tema.rotulo("\n".join(linhas), 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	caixa.add_child(l)
	_abrir(Janela.criar(HISTORIA.nome_npc(npc), [["FECHAR", _fechar_popup]], "", [caixa]))

# ------------------------------------------------------------ Missões
## Missões (DEFINIDO): as que esperam a recompensa primeiro, depois as em andamento e, no fim, as concluídas.
func _aba_missoes() -> void:
	var recebidas: Array = HISTORIA.recebidas()
	if recebidas.is_empty():
		_vazio("DIARIO_MISSOES_VAZIO")
		return
	var abertas: Array = recebidas.filter(func(id): return HISTORIA.estado(id) == HISTORIA.ESTADO_CONCLUIDA)
	abertas.append_array(recebidas.filter(func(id): return HISTORIA.estado(id) == HISTORIA.ESTADO_ATIVA))
	var feitas: Array = recebidas.filter(func(id): return HISTORIA.estado(id) == HISTORIA.ESTADO_COLETADA)
	if not abertas.is_empty():
		lista.add_child(_separador("DIARIO_MIS_ANDAMENTO"))
		for id: String in abertas:
			lista.add_child(_linha_missao(id))
	if not feitas.is_empty():
		lista.add_child(_separador("DIARIO_MIS_CONCLUIDAS"))
		for id: String in feitas:
			lista.add_child(_linha_missao(id))

func _separador(chave: String) -> Label:
	var sep := _tinta(chave, 12, true)
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	sep.custom_minimum_size = Vector2(0, 40)
	return sep

func _linha_missao(id: String) -> Control:
	var m: Dictionary = HISTORIA.MISSOES[id]
	var npc := str(m["npc"])
	var est := HISTORIA.estado(id)
	var status: String = {HISTORIA.ESTADO_ATIVA: "MIS_ATIVA", HISTORIA.ESTADO_CONCLUIDA: "MIS_PRONTA"}.get(est, "MIS_FEITA")
	var b := _linha(HISTORIA.retrato(npc), tr("MIS_%s_OBJ" % id.substr(1)),
		HISTORIA.nome_npc(npc) + " · " + (HISTORIA.progresso_texto(id) if est == HISTORIA.ESTADO_ATIVA else tr(status)),
		false, false, _ficha_missao.bind(id), 14)
	if est == HISTORIA.ESTADO_CONCLUIDA:
		# selo "Coletar" no lugar do NOVO: a recompensa está esperando
		var h: Control = b.get_child(0)
		h.add_child(_selo_novo("MIS_COLETAR", Color("#2f7a3a")))
	elif est == HISTORIA.ESTADO_COLETADA:
		b.modulate = Color(1, 1, 1, 0.6)
	return b

func _ficha_missao(id: String) -> void:
	var m: Dictionary = HISTORIA.MISSOES[id]
	var npc := str(m["npc"])
	var est := HISTORIA.estado(id)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 6)
	var tex := HISTORIA.retrato(npc)
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.custom_minimum_size = Vector2(260, 96)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		caixa.add_child(t)
	var linhas: Array = [tr("MIS_DE") % HISTORIA.nome_npc(npc), "", "\"" + tr("MIS_%s_PEDIDO" % id.substr(1)) + "\"", "",
		HISTORIA.objetivo(id), tr({HISTORIA.ESTADO_ATIVA: "MIS_ATIVA", HISTORIA.ESTADO_CONCLUIDA: "MIS_PRONTA"}.get(est, "MIS_FEITA"))]
	if est >= HISTORIA.ESTADO_CONCLUIDA:
		linhas.append_array(["", "\"" + tr("MIS_%s_FIM" % id.substr(1)) + "\""])
	var l := Tema.rotulo("\n".join(linhas), 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	caixa.add_child(l)
	var botoes: Array = [["FECHAR", _fechar_popup]]
	if est == HISTORIA.ESTADO_CONCLUIDA:
		botoes = [["MIS_COLETAR", _coletar.bind(id)], ["FECHAR", _fechar_popup]]
	_abrir(Janela.criar(tr("MIS_TITULO_N") % (HISTORIA.recebidas().find(id) + 1), botoes, "", [caixa]))

## Coletar (DEFINIDO): a recompensa entra na hora e aparece no popup de recompensas do kit.
func _coletar(id: String) -> void:
	_fechar_popup()
	var linhas: Array = HISTORIA.coletar(id)
	if linhas.is_empty():
		return
	var r := PopupResultado.new()
	r.tipo = "presente"
	r.titulo = tr("MIS_CONCLUIDA_TITULO")
	r.subtitulo = HISTORIA.nome_npc(str(HISTORIA.MISSOES[id]["npc"])).to_upper()
	r.linhas = linhas
	r.botoes = [["OK", _fechar_resultado.bind(r), "primario"]]
	add_child(r)

func _fechar_resultado(r: Control) -> void:
	r.queue_free()
	_montar_aba()

# ------------------------------------------------------------ Bestiário
func _aba_bestiario() -> void:
	var esp := Bestiario.especies()
	var cont := _tinta(tr("DIARIO_DESCOBERTOS") % [Bestiario.vistas(), esp.size()], 14)
	cont.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lista.add_child(cont)
	var g := GridContainer.new()
	g.columns = COLUNAS
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	lista.add_child(g)
	for e: Dictionary in esp:
		g.add_child(_celula(e))

func _celula(e: Dictionary) -> Control:
	var id := str(e["id"])
	var r := Bestiario.registro(id)
	var visto := not r.is_empty()
	var b := Button.new()
	b.custom_minimum_size = Vector2(56, 56)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.36, 0.25, 0.15, 0.14 if visto else 0.30)
	st.border_color = Color(0.36, 0.25, 0.15, 0.5)
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, st)
	if visto:
		var ic := TextureRect.new()
		ic.texture = Bestiario.miniatura(str(e["chave"]))
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 3
		ic.offset_top = 3
		ic.offset_right = -3
		ic.offset_bottom = -3
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		if bool(r.get("novo", false)):
			var n := _selo_novo()
			n.position = Vector2(2, 2)
			b.add_child(n)
		b.pressed.connect(_ficha_inimigo.bind(e))
	else:
		b.text = "?"
		b.add_theme_font_override("font", Tema.fonte_numeros)
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", Color(0.36, 0.25, 0.15, 0.6))
		b.add_theme_color_override("font_disabled_color", Color(0.36, 0.25, 0.15, 0.6))
		b.disabled = true
	return b

## Ficha completa do Bestiário (componentes/popup_bestiario.gd).
func _ficha_inimigo(e: Dictionary) -> void:
	Bestiario.marcar_visto(str(e["id"]))
	var p = preload("res://scripts/componentes/popup_bestiario.gd").new()
	p.especie = e
	add_child(p)
	_montar_aba.call_deferred()

func _retrato(chave: String, altura: int) -> Control:
	var t := TextureRect.new()
	t.texture = Bestiario.miniatura(chave)
	t.custom_minimum_size = Vector2(260, altura)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t

func _el(f: Dictionary) -> String:
	var el = f.get("elemento")
	if el == null or str(el) == "":
		return ""
	return tr("EL_" + str(el).to_upper())

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
