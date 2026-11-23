class_name TelaDespertar
extends Control
## O Despertar (no meio do 2º combate do tutorial, com a Vida em 25%). DEFINIDO: sem perguntas; uma
## animação apresenta os elementos (Morte e Luz aparecem só como silhuetas, sem nome e sem foco),
## o jogador escolhe livre, depois 1 de 3 habilidades e qual ataque comum ela substitui.
## Roteiro: a Voz interrompe a queda → os 6 elementos nascem da luz, um por vez, com a descrição
## embaixo → giram em órbita (falso 3D) → escolha → a Voz fecha o momento.

signal escolhido(elemento: String, habilidade: String, sai: String)
signal _tocou

const CENTRO := Vector2(180, 236)
const RAIO := Vector2(124, 66)
const COR_EL := {"fogo": Color("#ff7a3a"), "agua": Color("#4ab0ff"), "terra": Color("#c8964e"),
	"ar": Color("#6ee0b0"), "raio": Color("#ffe04a"), "gelo": Color("#a8e8ff")}
const ATRIBUTOS := ["forca", "percepcao", "agilidade", "resistencia", "ressonancia"]

var comuns: Array = []          # os ataques comuns atuais do jogador
var elemento := ""
var habilidade := ""
var fundo: ColorRect
var cosmos: CenaPintada
var orbita: Control
var icones := {}                # elemento → TextureButton
var angulo := {}                # elemento → ângulo na órbita
var giro := 0.0
var girando := false
var escolhendo := false
var ondas: Array = []           # anéis de luz: [posição, cor, tempo]
var painel: PanelContainer
var caixa: CaixaDialogo
var dica: Label
var silhuetas: Array = []
var nomes := {}                 # elemento → Label com o nome, embaixo do medalhão
var titulo: Label
var tempo := 0.0
var _espera_id := 0
var _escala_antes := 1.0       # velocidade do combate, devolvida no fim

func _ready() -> void:
	# quadro fixo de 360×640 centrado na vertical (celulares mais altos); o véu escuro cobre a tela toda
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_top = -320.0
	offset_bottom = 320.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_escala_antes = Engine.time_scale
	Engine.time_scale = 1.0            # a cena roda sempre na velocidade normal
	fundo = ColorRect.new()
	fundo.color = Color(0.02, 0.02, 0.05, 0.0)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.offset_top = -1000.0
	fundo.offset_bottom = 1000.0
	fundo.mouse_filter = Control.MOUSE_FILTER_PASS     # segura os toques fora do quadro (a luta embaixo não reage)
	add_child(fundo)
	cosmos = CenaPintada.new("silencio")
	cosmos.duracao = 60.0
	cosmos.modulate.a = 0.0
	add_child(cosmos)
	# Morte e Luz: duas silhuetas nas bordas, sem nome e fora de foco (duas cópias tremidas)
	for lado in [-1, 1]:
		for copia in 2:
			var s := HeroiFrente.new()
			s.escala = 3
			s.size = Vector2(144, 200)
			s.position = Vector2((-64 if lado < 0 else 280) + copia * 3, 250 + copia * 2)
			s.modulate = Color(0, 0, 0, 0) if lado < 0 else Color(1, 1, 1, 0)
			s.vestir(["corpo_2_Pele-1", "cabelo_longo_Preto"] if lado < 0 else ["corpo_1_Pele-1", "cabelo_curto_Platinado"])
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(s)
			silhuetas.append(s)
	orbita = Control.new()
	orbita.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	orbita.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orbita.draw.connect(_desenhar_orbita)
	add_child(orbita)
	titulo = Tema.rotulo("DESP_TITULO", 24)
	titulo.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	titulo.add_theme_constant_override("outline_size", 4)
	titulo.add_theme_color_override("font_outline_color", Color("#1a1030"))
	titulo.position = Vector2(0, 28)
	titulo.size = Vector2(360, 32)
	titulo.modulate.a = 0.0
	add_child(titulo)
	var fio := ColorRect.new()                              # filete dourado sob o título
	fio.color = Color(Tema.COR_OURO, 0.5)
	fio.position = Vector2(110, 36)
	fio.size = Vector2(140, 2)
	titulo.add_child(fio)
	dica = Tema.rotulo("DESP_TOQUE", 16)
	dica.position = Vector2(0, 600)
	dica.size = Vector2(360, 24)
	dica.modulate.a = 0.0
	add_child(dica)
	caixa = CaixaDialogo.new()
	caixa.position = Vector2(8, 500)
	caixa.size = Vector2(344, 128)
	caixa.visible = false
	add_child(caixa)
	_roteiro()

func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed:
		_tocou.emit()

## Espera um tempo, ou menos se o jogador tocar na tela.
func _esperar(s: float) -> void:
	_espera_id += 1
	get_tree().create_timer(s).timeout.connect(_fim_da_espera.bind(_espera_id))
	await _tocou

func _fim_da_espera(id: int) -> void:
	if id == _espera_id:
		_tocou.emit()

func _process(delta: float) -> void:
	tempo += delta
	if girando:
		giro += delta * 0.18
	for e in icones:
		_posicionar(e)
	for o in ondas:
		o[2] += delta
	ondas = ondas.filter(func(o): return o[2] < 1.2)
	for i in silhuetas.size():
		var s: Control = silhuetas[i]
		s.position.y = 250 + (i % 2) * 2 + sin(tempo * 0.7 + i) * 3
	orbita.queue_redraw()

func _posicionar(e: String) -> void:
	var b: TextureButton = icones[e]
	if b.has_meta("voando"):
		return
	var a: float = angulo[e] + giro
	var frente := (sin(a) + 1.0) / 2.0                   # 0 = atrás, 1 = na frente
	var p := CENTRO + Vector2(cos(a) * RAIO.x, sin(a) * RAIO.y)
	var esc := 0.9 + 0.3 * frente          # os de trás ainda com uns 36 px para o toque
	b.scale = Vector2(esc, esc)
	b.position = p - b.size * esc / 2.0
	var luz := 0.55 + 0.45 * frente
	if elemento != "" and e != elemento:
		luz *= 0.3
	b.modulate = Color(luz, luz, luz, b.modulate.a)
	b.z_index = int(frente * 10)
	var rn: Label = nomes.get(e)
	if rn:
		rn.position = p + Vector2(-45, 26.0 * esc)
		rn.z_index = b.z_index
		rn.modulate = Color(luz, luz, luz, rn.modulate.a)
		rn.scale = Vector2.ONE

func _desenhar_orbita() -> void:
	var a := clampf(cosmos.modulate.a * 1.6, 0.0, 1.0)
	# a luz do centro (a Voz), pulsando
	for i in 7:
		var r := 8.0 + i * 8.0 + 3.0 * sin(tempo * 2.0 + i)
		orbita.draw_circle(CENTRO, r, Color(1.0, 0.95, 0.85, 0.05 * a))
	orbita.draw_rect(Rect2(CENTRO - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1, a))
	# trilha da órbita em pontinhos (mais fortes na frente)
	if not icones.is_empty():
		for k in 48:
			var t := k * TAU / 48.0 + giro * 0.5
			var frente := (sin(t) + 1.0) / 2.0
			var p := CENTRO + Vector2(cos(t) * RAIO.x, sin(t) * RAIO.y)
			orbita.draw_rect(Rect2(p.floor(), Vector2(2, 2)), Color(0.8, 0.85, 1.0, (0.08 + 0.25 * frente) * a))
	# medalhão de cada elemento: halo, disco escuro e anel na cor dele (cada um bem separado)
	for e in icones:
		var b: TextureButton = icones[e]
		var c: Color = COR_EL[e]
		var centro := b.position + b.size * b.scale / 2.0
		var forte := 0.22 if e != elemento else 0.4 + 0.15 * sin(tempo * 4.0)
		var vis := b.modulate.a * b.modulate.r
		orbita.draw_circle(centro, 34.0 * b.scale.x, Color(c, forte * vis))
		orbita.draw_circle(centro, 27.0 * b.scale.x, Color(0.04, 0.04, 0.08, 0.95 * b.modulate.a))
		orbita.draw_arc(centro, 27.0 * b.scale.x, 0, TAU, 40, Color(c, vis), 2.0)
		orbita.draw_arc(centro, 23.0 * b.scale.x, 0, TAU, 40, Color(c, 0.35 * vis), 1.0)
	for o in ondas:
		var c: Color = o[1]
		var f: float = clampf(o[2] / 1.2, 0.0, 1.0)
		c.a = (1.0 - f) * 0.8
		orbita.draw_arc(o[0], 6.0 + f * 70.0, 0, TAU, 40, c, 2.0)

func _roteiro() -> void:
	var t := create_tween()
	t.tween_property(fundo, "color:a", 1.0, 0.9)             # a batalha some por completo
	t.tween_property(cosmos, "modulate:a", 0.3, 1.4)
	t.parallel().tween_property(titulo, "modulate:a", 1.0, 1.4)
	await t.finished
	caixa.mostrar(["DESP_INTRO_1", "DESP_INTRO_2"], "???")
	await caixa.terminou
	caixa.visible = false
	# os 6 elementos nascem da luz, um por vez, cada um com a sua descrição embaixo
	for i in Catalogo.ELEMENTOS.size():
		var e: String = Catalogo.ELEMENTOS[i]
		angulo[e] = PI / 2 - giro        # nasce sempre na frente; os anteriores já giraram
		var b := TextureButton.new()
		b.texture_normal = load("res://artes/combate/elem20_%s.png" % e)
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_SCALE
		b.size = Vector2(40, 40)
		b.position = CENTRO - Vector2(20, 20)
		b.scale = Vector2(0.1, 0.1)
		b.set_meta("voando", true)
		b.pressed.connect(_ver_elemento.bind(e))
		add_child(b)
		move_child(b, orbita.get_index() + 1)
		icones[e] = b
		var rn := Tema.rotulo("EL_" + e.to_upper(), 16)
		rn.add_theme_color_override("font_color", COR_EL[e])
		rn.add_theme_constant_override("outline_size", 4)
		rn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		rn.size = Vector2(90, 18)
		rn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rn.modulate.a = 0.0
		add_child(rn)
		nomes[e] = rn
		create_tween().tween_property(rn, "modulate:a", 1.0, 0.5).set_delay(0.5)
		ondas.append([CENTRO, COR_EL[e], 0.0])
		var alvo := CENTRO + Vector2(0, RAIO.y)
		var ti := create_tween().set_parallel(true)
		ti.tween_property(b, "position", alvo - Vector2(20, 20) * 1.15, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ti.tween_property(b, "scale", Vector2(1.15, 1.15), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ti.chain().tween_callback(_pousou.bind(e, alvo))
		_apresentar(e)
		await _esperar(2.8)
		if i < Catalogo.ELEMENTOS.size() - 1:
			# os já apresentados giram para abrir lugar ao próximo
			var tg := create_tween()
			tg.tween_property(self, "giro", giro + TAU / 6.0, 0.6).set_trans(Tween.TRANS_SINE)
			await tg.finished
	_limpar_painel()
	# Morte e Luz: só silhuetas, sem nome, quase invisíveis
	var ts := create_tween().set_parallel(true)
	for i in silhuetas.size():
		ts.tween_property(silhuetas[i], "modulate:a", (0.16 if i < 2 else 0.08) / (1 + i % 2), 1.2)
	girando = true
	caixa.mostrar(["DESP_ESCOLHA"], "???")
	await caixa.terminou
	caixa.visible = false
	escolhendo = true
	create_tween().tween_property(dica, "modulate:a", 1.0, 0.4)

func _pousou(e: String, onde: Vector2) -> void:
	icones[e].remove_meta("voando")
	ondas.append([onde, COR_EL[e], 0.0])

## Painel de baixo com nome, função e atributos do elemento.
func _apresentar(e: String, com_botao := false) -> void:
	var c := _novo_painel()
	var t := Tema.rotulo("EL_" + e.to_upper(), 24)
	t.add_theme_color_override("font_color", COR_EL[e])
	t.add_theme_constant_override("outline_size", 2)
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	c.add_child(t)
	var f := Tema.rotulo(Catalogo.funcao_elemento(e), 16)
	f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	f.custom_minimum_size = Vector2(300, 0)
	c.add_child(f)
	var m: Array = Catalogo.MODELO_JOGADOR[e]
	var atr := HBoxContainer.new()
	atr.alignment = BoxContainer.ALIGNMENT_CENTER
	atr.add_theme_constant_override("separation", 10)
	for i in 5:
		var par := HBoxContainer.new()
		par.add_theme_constant_override("separation", 2)
		var ic := TextureRect.new()
		ic.texture = load("res://artes/interface/icone16_%s.png" % ATRIBUTOS[i])
		par.add_child(ic)
		par.add_child(Tema.rotulo(str(m[i]), 8, true))
		atr.add_child(par)
	c.add_child(atr)
	if com_botao:
		var b := Button.new()
		b.text = "DESP_ESCOLHER"
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(_escolher_elemento.bind(e))
		c.add_child(b)
	_ancorar()

func _limpar_painel() -> void:
	if painel:
		var p := painel
		var t := create_tween()
		t.tween_property(p, "modulate:a", 0.0, 0.15)
		t.tween_callback(p.queue_free)
		painel = null

func _novo_painel() -> VBoxContainer:
	_limpar_painel()
	painel = PanelContainer.new()
	painel.custom_minimum_size = Vector2(336, 0)
	painel.position = Vector2(12, 700)
	painel.modulate.a = 0.0
	painel.z_index = 20
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 6)
	painel.add_child(c)
	add_child(painel)
	return c

## Encosta o painel embaixo da tela depois de medir a altura (nunca passa da tela) e o faz subir.
func _ancorar() -> void:
	var p := painel
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	p.reset_size()
	var y := maxf(8.0, 640.0 - p.size.y - 12.0)
	p.position = Vector2(12, y + 16)
	var t := create_tween().set_parallel(true)
	t.tween_property(p, "modulate:a", 1.0, 0.25)
	t.tween_property(p, "position:y", y, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# ---------------- 1. elemento
func _ver_elemento(e: String) -> void:
	if not escolhendo or habilidade != "" or elemento != "":
		return
	dica.modulate.a = 0.0
	var b: TextureButton = icones[e]
	ondas.append([b.position + b.size * b.scale / 2.0, COR_EL[e], 0.0])
	_apresentar(e, true)

func _escolher_elemento(e: String) -> void:
	elemento = e
	escolhendo = false
	for x in icones:
		icones[x].disabled = true
	# a órbita para com o escolhido na frente
	girando = false
	var alvo: float = PI / 2 - float(angulo[e])
	while alvo - giro > PI:
		alvo -= TAU
	while giro - alvo > PI:
		alvo += TAU
	var t := create_tween()
	t.tween_property(self, "giro", alvo, 0.8).set_trans(Tween.TRANS_SINE)
	ondas.append([CENTRO, COR_EL[e], 0.0])
	_ver_habilidades()

# ---------------- 2. habilidade (1 de 3)
## Pedido do João (2026-11-22): cartões mais agradáveis, na cor do elemento, com ícone, nome, tipo/usos e o efeito.
func _ver_habilidades() -> void:
	habilidade = ""
	var c := _novo_painel()
	var t := Tema.rotulo("DESP_HAB", 16)
	t.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(300, 0)
	c.add_child(t)
	for h in Catalogo.DESPERTAR[elemento]:
		var b := _cartao_hab(h, 312.0, true)
		b.pressed.connect(_escolher_hab.bind(h))
		c.add_child(b)
	_ancorar()

## Cartão da habilidade: medalhão com o ícone, nome na cor do elemento, selo com tipo e usos e o efeito embaixo.
## botao = true devolve um Button (toque escolhe); false, só o quadro (a "nova habilidade" no topo da troca).
func _cartao_hab(h: String, largura: float, botao: bool) -> Control:
	var H: Dictionary = Catalogo.HAB[h]
	var el := str(H.get("el", ""))
	var cor: Color = COR_EL.get(el, Tema.COR_OURO_CLARO)
	var util := largura - 64.0
	var linhas := Tema._quebrar(Catalogo.descrever(h), Tema.fonte_pequena, 12, util, 4)
	if linhas.is_empty():
		linhas = PackedStringArray([Catalogo.descrever(h)])
	var alto := maxf(56.0, 48.0 + 14.0 * linhas.size() + 6.0)
	var q: Control
	if botao:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		for est in ["normal", "disabled"]:
			b.add_theme_stylebox_override(est, _caixa_cartao(cor, 0.0))
		for est in ["hover", "focus"]:
			b.add_theme_stylebox_override(est, _caixa_cartao(cor, 0.12))
		for est in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(est, _caixa_cartao(cor, 0.22))
		q = b
	else:
		var p := Panel.new()
		p.add_theme_stylebox_override("panel", _caixa_cartao(cor, 0.08))
		q = p
	q.custom_minimum_size = Vector2(largura, alto)
	# medalhão do elemento
	var med := Control.new()
	med.position = Vector2(10, 10)
	med.size = Vector2(36, 36)
	med.mouse_filter = Control.MOUSE_FILTER_IGNORE
	med.draw.connect(func():
		med.draw_circle(Vector2(18, 18), 18, Color(cor, 0.25))
		med.draw_circle(Vector2(18, 18), 15, Color(0.04, 0.04, 0.08))
		med.draw_arc(Vector2(18, 18), 15, 0, TAU, 32, cor, 2.0))
	q.add_child(med)
	var ic := TextureRect.new()
	ic.texture = load("res://artes/combate/elem20_%s.png" % (el if el != "" else "comum"))
	ic.position = Vector2(18, 18)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.add_child(ic)
	var nome := Label.new()
	nome.text = str(H["nome"]).to_upper()
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nome.position = Vector2(54, 6)
	nome.size = Vector2(largura - 80, 22)
	nome.add_theme_font_size_override("font_size", 16)
	nome.add_theme_color_override("font_color", cor.lightened(0.25))
	nome.add_theme_constant_override("outline_size", 4)
	nome.add_theme_color_override("font_outline_color", Color("#0c0d16"))
	nome.set_meta("fonte_fixa", true)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q.add_child(nome)
	Tema.caber(nome, largura - 80, 22, 1)
	# selo com o tipo e os usos por luta, logo abaixo do nome
	var cat := str(H["cat"])
	var usos := tr("HAB_INFO_SEM_LIMITE").trim_suffix(".") if cat == "comum" else tr("DESP_USOS") % int(Catalogo.USOS.get(cat, 0))
	var selo := PanelContainer.new()
	var es := StyleBoxFlat.new()
	es.bg_color = Color("#0c0d16")
	es.border_color = Color(cor, 0.7)
	es.set_border_width_all(1)
	es.set_corner_radius_all(3)
	es.content_margin_left = 5
	es.content_margin_right = 5
	es.content_margin_top = 1
	es.content_margin_bottom = 1
	selo.add_theme_stylebox_override("panel", es)
	selo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := Label.new()
	rs.text = (tr("HAB_INFO_CAT_" + cat.to_upper()) + " · " + usos).to_upper()
	rs.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rs.add_theme_font_override("font", Tema.fonte_10)
	rs.add_theme_font_size_override("font_size", 10)
	rs.add_theme_color_override("font_color", cor.lightened(0.35))
	rs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selo.add_child(rs)
	q.add_child(selo)
	selo.position = Vector2(54, 28)
	# efeito, linha a linha (a quebra é feita à mão, como nos balões)
	for k in linhas.size():
		var l := Label.new()
		l.text = linhas[k].strip_edges()
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.position = Vector2(54, 46 + 14 * k)
		l.add_theme_font_override("font", Tema.fonte_pequena)
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color("#dfe2ee"))
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q.add_child(l)
	if botao:
		# setinha em pixels à direita (toque para escolher)
		var seta := Control.new()
		seta.position = Vector2(largura - 16, floorf(alto / 2.0) - 5)
		seta.size = Vector2(6, 10)
		seta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seta.draw.connect(func():
			for k2 in 5:
				seta.draw_rect(Rect2(k2, k2, 1, 10 - 2 * k2), cor))
		q.add_child(seta)
	return q

## Fundo do cartão: escuro tingido pela cor do elemento, borda de 2 px e faixa clara no alto.
func _caixa_cartao(cor: Color, luz: float) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = Color("#141626").lerp(cor, 0.14 + luz)
	e.border_color = cor if luz > 0.0 else Color(cor, 0.75)
	e.set_border_width_all(2)
	e.border_width_top = 3
	e.set_corner_radius_all(4)
	e.shadow_color = Color(0, 0, 0, 0.45)
	e.shadow_size = 2
	e.shadow_offset = Vector2(0, 2)
	return e

## Troca: a nova habilidade fica numa caixa no topo (nome e efeito); embaixo, os 4 ataques comuns.
## Segurar um ataque mostra o balão com o que ele faz (como no combate); tocar escolhe qual sai.
func _escolher_hab(h: String) -> void:
	habilidade = h
	var c := _novo_painel()
	var topo := Tema.rotulo("DESP_NOVA", 12)
	topo.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	c.add_child(topo)
	c.add_child(_cartao_hab(h, 312.0, false))
	var q := Tema.rotulo("DESP_TROCAR", 16)
	q.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size = Vector2(300, 0)
	c.add_child(q)
	var dica_troca := Tema.rotulo("DESP_SEGURE", 12)
	dica_troca.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	dica_troca.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica_troca.custom_minimum_size = Vector2(300, 0)
	c.add_child(dica_troca)
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 8)
	for x in comuns:
		grade.add_child(_botao_comum(str(x)))
	var centro := CenterContainer.new()
	centro.add_child(grade)
	c.add_child(centro)
	var voltar := Button.new()
	voltar.text = "DESP_VOLTAR"
	voltar.custom_minimum_size = Vector2(0, 30)
	voltar.add_theme_font_size_override("font_size", 12)
	Tema.estilo_botao(voltar, "secundario")
	voltar.pressed.connect(_ver_habilidades)
	c.add_child(voltar)
	_ancorar()

## Botão de ataque comum no estilo dos botões do combate (moldura do kit, encaixe com o ícone e o nome).
func _botao_comum(x: String) -> Button:
	var H: Dictionary = Catalogo.HAB[x]
	var b := Button.new()
	b.custom_minimum_size = Vector2(152, 48)
	b.focus_mode = Control.FOCUS_NONE
	Tema.estilo_botao(b, "secundario")
	b.pressed.connect(_fim.bind(x))
	Tema.ao_segurar(b, _balao_comum.bind(x, b))
	var encaixe := TextureRect.new()
	encaixe.texture = load("res://artes/combate/encaixe26.png")
	encaixe.position = Vector2(6, 11)
	encaixe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(encaixe)
	var ic := TextureRect.new()
	ic.texture = load("res://artes/combate/elem20_comum.png")
	ic.position = Vector2(9, 14)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var nome := Label.new()
	nome.text = str(H["nome"]).to_upper()
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nome.position = Vector2(38, 4)
	nome.size = Vector2(108, 40)
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override("font_size", 16)
	nome.add_theme_constant_override("line_spacing", -4)
	nome.add_theme_constant_override("outline_size", 4)
	nome.add_theme_color_override("font_outline_color", Color("#12131c"))
	nome.set_meta("fonte_fixa", true)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nome)
	Tema.caber(nome, 108.0, 40.0)
	b.text = ""
	return b

## Balão do ataque comum (segurar): tipo, usos e o efeito.
func _balao_comum(x: String, b: Control) -> void:
	var H: Dictionary = Catalogo.HAB[x]
	var linhas: Array = [[tr("HAB_INFO_CAT_COMUM") + " · " + tr("HAB_INFO_SEM_LIMITE"), Balao.TINTA_CLARA], Catalogo.descrever(x)]
	Balao.mostrar(self, b.get_global_rect(), str(H["nome"]), Balao.TINTA, linhas)

# ---------------- 3. a Voz fecha o momento
func _fim(sai: String) -> void:
	_limpar_painel()
	for x in icones:
		create_tween().tween_property(nomes[x], "modulate:a", 0.0, 0.4)
		if x != elemento:
			create_tween().tween_property(icones[x], "modulate:a", 0.0, 0.5)
	# o elemento escolhido vai para a luz do centro e explode na cor dele
	var b: TextureButton = icones[elemento]
	b.set_meta("voando", true)
	var t := create_tween().set_parallel(true)
	t.tween_property(b, "position", CENTRO - Vector2(20, 20) * 1.6, 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(b, "scale", Vector2(1.6, 1.6), 0.6)
	await t.finished
	for k in 3:
		ondas.append([CENTRO, COR_EL[elemento], -0.15 * k])
	var flash := ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(COR_EL[elemento], 0.0)
	add_child(flash)
	var tf := create_tween()
	tf.tween_property(flash, "color:a", 0.55, 0.2)
	tf.tween_property(flash, "color:a", 0.0, 0.8)
	move_child(caixa, -1)
	caixa.mostrar(["DESP_OUVIU", "DESP_" + elemento.to_upper(), "DESP_GUARDE"], "???")
	await caixa.terminou
	var tx := create_tween()
	tx.tween_property(self, "modulate:a", 0.0, 0.6)
	await tx.finished
	Engine.time_scale = _escala_antes
	escolhido.emit(elemento, habilidade, sai)
	queue_free()
