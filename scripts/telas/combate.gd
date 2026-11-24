extends Tela
## Tela de combate (layout aprovado no kit: tela_combate). Arena 360×360 em cima, mensagens,
## abas Luta / Inventário e os 4 botões de habilidade. As regras ficam no Motor; aqui só se anima.

const SLOT_X := [104, 184, 268]
const SLOT_Y := [196, 184, 200]       # base dos pés de cada lugar na arena (coordenadas da arena)
const ARENA_Y := 48
const COR_CRITICO := Color("#ffe04f")
const COR_CURA := Color("#8dd678")
const COR_EFICAZ := Color("#f08a3c")
const COR_RESISTE := Color("#4fa3eb")
const COR_CONTORNO := Color("#12131c")
## Velocidade normal das animações (pedido do João: a velocidade anterior virou o ×2).
const VELOCIDADE_NORMAL := 0.5
const ORBES_R := preload("res://scripts/orbes.gd")
const HISTORIA := preload("res://scripts/historia.gd")
const DIALOGO := preload("res://scripts/componentes/dialogo_historia.gd")

var fase := 1
var rejogando := false
var qr := {}                      # luta do QR Inimigo (encontro pronto, de CodigoQR.encontro_inimigo)
var evento_etapa := 0             # 1–5 = fase do Evento do QR (caminho lateral do mapa)
var tutorial := 0                 # 1 ou 2 = combates guiados da criação (sem vidas; o 2º tem o Despertar)
var despertou := false
var continuou := false            # já usou o vídeo de continuar nesta tentativa
var desistiu := false
var _best_desde := 0              # inimigos derrotados já contados no Bestiário (continuar não conta de novo)
var _mis_desde := 0               # o mesmo para as missões de "derrotar" (scripts/historia.gd)
var _pocoes_usadas := 0           # para as missões de desafio ("sem usar poções")
var _perda_derrota := 0
var _resultado_derrota: Array = []
var heroi_caido := false          # travado no último quadro da queda (morte ou espera do Despertar)
var icone_el: TextureRect
var encontro := {}
var motor: Motor

var arena: TextureRect
var arena_quadros: Array = []
var arena_tempo := 0.0
var arena_q := 0
var palco: Control
var numeros: Control
var heroi: SpriteCamadas
var _habs_vistas := {}      # id do inimigo → habilidades que ele já usou nesta luta
var visuais := {}          # id do lutador → {"spr", "placa", "barra", "conds", "slot", "l"}
var alvo: Lutador

var lbl_onda: Label
var fila_vez: HBoxContainer
var barra_jog: Barra
var lbl_vida_jog: Label
var lbl_nivel_jog: Label
var conds_jog: HBoxContainer
var msg1: Label
var msg2: Label
var aba_luta: Button
var aba_inv: Button
var grade_luta: Control
var grade_inv: GridContainer
var botoes_hab: Array = []
var bt_vel: Button
var bt_auto: Button
var popup: Janela

var ocupado := true
var vida_vista := {}       # Lutador → Vida mostrada agora (o Motor já sabe o fim da rodada; a tela vai golpe a golpe)
var automatico := false

## Barra de Vida desenhada (rampa do kit: escuro, base, claro).
## Ao perder Vida, a barra cai rápido e um rastro claro escorre logo depois (mostra quanto saiu).
class Barra extends Control:
	var frac := 1.0:
		set(v):
			frac = v
			queue_redraw()
	var rastro := 1.0:
		set(v):
			rastro = v
			queue_redraw()
	var cores := [Color("#5c1a2b"), Color("#d8394a"), Color("#ff7a6b")]
	var _tw: Tween
	func mostrar(f: float) -> void:
		f = clampf(f, 0.0, 1.0)
		if absf(f - frac) < 0.0005:
			return
		if _tw:
			_tw.kill()
		_tw = create_tween()
		if f < frac:
			rastro = maxf(rastro, frac)
			_tw.tween_property(self, "frac", f, 0.18)
			_tw.tween_interval(0.25)
			_tw.tween_property(self, "rastro", f, 0.4).set_ease(Tween.EASE_IN)
		else:
			rastro = f
			_tw.tween_property(self, "frac", f, 0.35).set_ease(Tween.EASE_OUT)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#12131c"))
		draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color("#2a2c3c"))
		var wr := floorf((size.x - 2) * clampf(rastro, 0.0, 1.0))
		if wr > 0:
			draw_rect(Rect2(Vector2(1, 1), Vector2(wr, size.y - 2)), Color("#f4e6c8"))
		var w := floorf((size.x - 2) * clampf(frac, 0.0, 1.0))
		if w > 0:
			draw_rect(Rect2(Vector2(1, 1), Vector2(w, size.y - 2)), cores[1])
			draw_rect(Rect2(Vector2(1, 1), Vector2(w, 1)), cores[2])
			draw_rect(Rect2(Vector2(1, size.y - 2), Vector2(w, 1)), cores[0])

func montar() -> void:
	Engine.time_scale = 1.0 if bool(Jogo.dados.get("velocidade_x2", false)) else VELOCIDADE_NORMAL
	if tutorial > 0:
		# Tutorial (DEFINIDO): 1º contra 1 Batedor; 2º contra 2 Batedores, com 1 Poção de Vida I só nesta luta.
		# Pedido do João (2026-11-22): do 2º combate em diante os inimigos têm pelo menos nível 2.
		var grupo: Array = []
		for i in tutorial:
			grupo.append({"sprite": "batedor_comum", "categoria": "comum", "nivel": 1 if tutorial == 1 else Encontros.NIVEL_MINIMO})
		encontro = {"fase": 0, "ato": 1, "tipo": "tutorial", "arena": 0, "ondas": [grupo]}
		var pocoes: Dictionary = {"pocao_de_vida_i": 1} if tutorial == 2 else {}
		# antes do Despertar o herói só tem os 4 ataques comuns (DEFINIDO)
		motor = Motor.new(encontro, "", int(Jogo.dados["nivel"]), Jogo.COMUNS_INICIAIS.duplicate(), pocoes)
		if tutorial == 2:
			motor.sem_grupo = true
			motor.piso_jogador = 1
			motor.piso_inimigos = 1
	else:
		if not qr.is_empty():
			encontro = qr
		elif evento_etapa > 0:
			encontro = CodigoQR.encontro_evento(evento_etapa)
		else:
			encontro = Encontros.gerar(fase)
			rejogando = fase < int(Jogo.dados["fase_atual"])
			# fase "jogada" (o popup da fase passa a mostrar os inimigos): conta ao entrar, vencendo ou não
			var jg: Dictionary = Jogo.dados.get("jogadas", {})
			jg[str(fase)] = int(jg.get(str(fase), 0)) + 1
			Jogo.dados["jogadas"] = jg
		motor = Motor.new(encontro, Jogo.dados["elemento"], int(Jogo.dados["nivel"]), Jogo.habilidades(), Jogo.dados["pocoes"])

	# música da luta (scripts/som.gd): chefe de ato tem a própria
	add_to_group("som_chefe" if str(encontro.get("tipo", "")) == "chefe" else "som_combate")
	var fundo := ColorRect.new()
	fundo.color = Tema.COR_FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var n0 := get_child_count()
	_montar_arena()
	var n1 := get_child_count()
	_montar_topo()
	var n2 := get_child_count()
	_montar_painel_jogador()
	_montar_baixo()
	# celular mais alto que 640: tudo abaixo da barra de cima desce junto e o céu da arena se estende
	# para cima (a 1ª linha da pintura é uma cor só); a barra de cima fica parada
	for i in range(n0, get_child_count()):
		if i >= n1 and i < n2:
			continue
		var c := get_child(i) as Control
		if c:
			c.set_meta("y0", c.position.y)
			_corpo.append(c)
	_ceu = TextureRect.new()
	var linha_ceu := AtlasTexture.new()
	linha_ceu.atlas = arena_quadros[0]
	linha_ceu.region = Rect2(0, 0, arena_quadros[0].get_width(), 1)
	_ceu.texture = linha_ceu
	_ceu.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ceu.stretch_mode = TextureRect.STRETCH_SCALE
	_ceu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ceu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ceu.position = Vector2(0, ARENA_Y)
	_ceu.size = Vector2(360, 0)
	add_child(_ceu)
	move_child(_ceu, n0)
	resized.connect(_ajustar_altura)
	_ajustar_altura.call_deferred()
	_atualizar_tudo()
	_comecar()

var _corpo: Array = []
var _ceu: TextureRect
var _dy := 0.0

func _ajustar_altura() -> void:
	_dy = maxf(0.0, floorf(size.y - 640.0))
	for c: Control in _corpo:
		if is_instance_valid(c):
			c.position.y = float(c.get_meta("y0")) + _dy
	_ceu.size = Vector2(maxf(360.0, size.x), _dy + 1)

func _process(delta: float) -> void:
	if _mira:
		_mira_pulo = maxf(0.0, _mira_pulo - delta * 5.0)
		var ver := _mira_visivel()
		_mira.visible = ver
		_anel.visible = ver
		if ver:
			_mira.queue_redraw()
			_anel.queue_redraw()
	arena_tempo += delta
	if arena_tempo >= 0.125:
		arena_tempo = 0.0
		arena_q = (arena_q + 1) % arena_quadros.size()
		arena.texture = arena_quadros[arena_q]

func _exit_tree() -> void:
	Engine.time_scale = 1.0

# ------------------------------------------------------------ montagem
func _montar_arena() -> void:
	for q in 4:
		arena_quadros.append(load("res://artes/arenas/ato%d_%d_q%d.png" % [encontro["ato"], encontro["arena"], q]))
	arena = TextureRect.new()
	arena.texture = arena_quadros[0]
	arena.position = Vector2(0, ARENA_Y)
	arena.size = Vector2(360, 360)
	arena.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(arena)
	palco = Control.new()
	palco.position = Vector2(0, ARENA_Y)
	palco.size = Vector2(360, 360)
	palco.clip_contents = true
	add_child(palco)
	heroi = SpriteCamadas.new()
	var meta := Artes.dados_heroi()
	heroi.largura_quadro = int(meta["quadro"][0])
	heroi.ancora_x = float(meta.get("desenho_x", 0)) + 24.0
	heroi.camadas = Jogo.camadas_heroi().map(func(n): return Artes.heroi_costas(n))
	heroi.size = Vector2(160, 140)
	heroi.position = Vector2(100 - 80, 348 - 140)
	heroi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heroi.terminou.connect(_heroi_terminou)
	palco.add_child(heroi)
	_anim_heroi("parado")
	numeros = Control.new()
	numeros.size = Vector2(360, 360)
	numeros.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palco.add_child(numeros)

func _montar_topo() -> void:
	var barra := ColorRect.new()
	barra.color = Color("#181a28")
	barra.size = Vector2(360, 48)
	add_child(barra)
	var linha := ColorRect.new()
	linha.color = Color("#7a5a34")
	linha.position = Vector2(0, 47)
	linha.size = Vector2(360, 1)
	add_child(linha)
	var pausa := Button.new()
	pausa.text = "II"
	pausa.position = Vector2(4, 2)
	pausa.custom_minimum_size = Vector2(44, 44)
	pausa.size = Vector2(44, 44)
	pausa.pressed.connect(pedir_saida)
	_estilo(pausa, "secundario")
	add_child(pausa)
	lbl_onda = Tema.rotulo("", 16)
	lbl_onda.position = Vector2(52, 14)
	lbl_onda.size = Vector2(70, 20)
	lbl_onda.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(lbl_onda)
	fila_vez = HBoxContainer.new()
	fila_vez.position = Vector2(122, 8)
	fila_vez.add_theme_constant_override("separation", 3)
	add_child(fila_vez)
	bt_vel = Button.new()
	bt_vel.text = "×2"
	bt_vel.toggle_mode = true
	bt_vel.position = Vector2(312, 2)
	bt_vel.size = Vector2(44, 44)
	bt_vel.button_pressed = bool(Jogo.dados.get("velocidade_x2", false))
	bt_vel.toggled.connect(_trocar_velocidade)
	_estilo_ligar(bt_vel)
	add_child(bt_vel)
	if rejogando:
		bt_auto = Button.new()
		bt_auto.text = "AUTO"
		bt_auto.toggle_mode = true
		bt_auto.position = Vector2(262, 2)
		bt_auto.size = Vector2(48, 44)
		bt_auto.add_theme_font_size_override("font_size", 16)
		bt_auto.toggled.connect(_ligar_auto)
		_estilo_ligar(bt_auto)
		add_child(bt_auto)

## Botões de ligar/desligar (×2 e Auto): azul quando desligado; verde, afundado e com luzinha acesa
## quando ligado (pedido do João: antes não dava para ver que estavam ligados).
func _estilo_ligar(b: Button) -> void:
	var desl := _caixa("res://artes/interface/botao_secundario_normal_9fatias_borda6.png")
	var lig := _caixa("res://artes/interface/botao_confirmar_pressionado_9fatias_borda6.png")
	for est in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(est, desl)
	for est in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(est, lig)
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color("#aeb4cc"))
	for c in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_outline_color", COR_CONTORNO)
	b.add_theme_constant_override("outline_size", 4)
	var luz := Control.new()
	luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	luz.position = Vector2(b.size.x - 9, 4)
	luz.size = Vector2(5, 5)
	luz.draw.connect(func():
		var on := b.button_pressed
		luz.draw_rect(Rect2(0, 0, 5, 5), COR_CONTORNO)
		luz.draw_rect(Rect2(1, 1, 3, 3), Color("#b8ffb0") if on else Color("#2a3048")))
	b.add_child(luz)
	b.toggled.connect(func(_on: bool): luz.queue_redraw())

## O ×2 fica lembrado para as próximas lutas.
func _trocar_velocidade(on: bool) -> void:
	Engine.time_scale = 1.0 if on else VELOCIDADE_NORMAL
	Jogo.dados["velocidade_x2"] = on
	Jogo.salvar()

func _montar_painel_jogador() -> void:
	var p := Panel.new()
	p.position = Vector2(184, ARENA_Y + 278)
	p.size = Vector2(168, 62)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	# nome e nível lado a lado: nome comprido diminui e, se preciso, é cortado antes do nível
	var nome := Tema.rotulo(Jogo.nome_heroi(), 16)
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nome.position = Vector2(10, 4)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nome.clip_text = true
	var fr := Tema.fonte_real(Tema.fonte_texto, 16)
	var larg_nome := minf(80.0, (fr[0] as Font).get_string_size(nome.text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fr[1])).x + 1.0)
	nome.size = Vector2(larg_nome, 20)
	p.add_child(nome)
	lbl_nivel_jog = Tema.rotulo("", 8, true)
	lbl_nivel_jog.position = Vector2(10 + larg_nome + 6, 8)
	lbl_nivel_jog.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	p.add_child(lbl_nivel_jog)
	icone_el = TextureRect.new()
	icone_el.position = Vector2(142, 8)
	p.add_child(icone_el)
	_icone_elemento()
	barra_jog = Barra.new()
	barra_jog.position = Vector2(10, 28)
	barra_jog.size = Vector2(148, 10)
	p.add_child(barra_jog)
	lbl_vida_jog = Tema.rotulo("", 8, true)
	lbl_vida_jog.set_meta("fonte_fixa", true)      # números de Vida na fonte original (pedido do João)
	lbl_vida_jog.position = Vector2(88, 42)
	lbl_vida_jog.size = Vector2(70, 12)
	lbl_vida_jog.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(lbl_vida_jog)
	conds_jog = HBoxContainer.new()
	conds_jog.position = Vector2(10, 40)
	conds_jog.add_theme_constant_override("separation", 2)
	p.add_child(conds_jog)

func _icone_elemento() -> void:
	var e: String = motor.jogador.elemento
	icone_el.texture = load("res://artes/combate/elem16_%s.png" % (e if e != "" else "comum"))

func _montar_baixo() -> void:
	var caixa := Panel.new()
	caixa.position = Vector2(8, 412)
	caixa.size = Vector2(344, 46)
	add_child(caixa)
	_caixa_msg = caixa
	msg1 = Label.new()
	msg1.position = Vector2(12, 5)
	msg1.size = Vector2(324, 18)
	msg1.clip_text = true
	caixa.add_child(msg1)
	msg2 = Label.new()
	msg2.position = Vector2(12, 22)
	msg2.size = Vector2(324, 18)
	msg2.clip_text = true
	msg2.add_theme_color_override("font_color", Color("#c8ccd8"))
	caixa.add_child(msg2)
	aba_luta = _aba("LUTA", Vector2(8, 462))
	aba_inv = _aba("INVENTARIO", Vector2(182, 462))
	aba_luta.pressed.connect(_mostrar_aba.bind(true))
	aba_inv.pressed.connect(_mostrar_aba.bind(false))
	grade_luta = Control.new()
	grade_luta.position = Vector2(8, 510)
	grade_luta.size = Vector2(344, 118)
	add_child(grade_luta)
	var habs: Array = motor.jogador.habilidades
	for i in habs.size():
		var b := _botao_hab(habs[i])
		b.position = Vector2((i % 2) * 176, (i / 2) * 62)
		grade_luta.add_child(b)
		botoes_hab.append(b)
	var rolagem := ScrollContainer.new()
	rolagem.position = Vector2(8, 510)
	rolagem.size = Vector2(344, 124)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.name = "rolagem_inv"
	add_child(rolagem)
	grade_inv = GridContainer.new()
	grade_inv.columns = 4
	grade_inv.add_theme_constant_override("h_separation", 4)
	grade_inv.add_theme_constant_override("v_separation", 4)
	rolagem.add_child(grade_inv)
	_mostrar_aba(true)

func _aba(chave: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = chave
	b.toggle_mode = true
	b.position = pos
	b.size = Vector2(170, 44)
	add_child(b)
	return b

## Botão com as 9 fatias do kit (tipo: primario/secundario/perigo...) ou de um elemento (artes/combate/botao_<el>_*).
func _estilo(b: Button, tipo: String) -> void:
	var pasta := "res://artes/combate/" if tipo in Catalogo.ELEMENTOS else "res://artes/interface/"
	var normal := _caixa(pasta + "botao_%s_normal_9fatias_borda6.png" % tipo)
	var apertado := _caixa(pasta + "botao_%s_pressionado_9fatias_borda6.png" % tipo)
	for est in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(est, normal)
	for est in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(est, apertado)
	Tema.cor_texto_botao(b, tipo)

## Diminui a fonte até o nome caber no quadro (quebra própria, em até `linhas` linhas; nunca passa da borda).
func _caber(r: Label, largura: float, altura: float, linhas := 2) -> void:
	Tema.caber(r, largura, altura, linhas)

## Nome da habilidade em destaque sobre a arena (na cor do elemento; dourado nas comuns).
func _faixa_hab(H: Dictionary, do_jogador: bool) -> void:
	var cores := {"fogo": Color("#ff7a3a"), "agua": Color("#4ab0ff"), "terra": Color("#c8964e"),
		"ar": Color("#6ee0b0"), "raio": Color("#ffe04a"), "gelo": Color("#a8e8ff")}
	var r := Label.new()
	r.text = str(H["nome"]).to_upper()
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_theme_font_size_override("font_size", 24)
	r.add_theme_color_override("font_color", cores.get(str(H.get("el", "")), Tema.COR_OURO_CLARO))
	r.add_theme_constant_override("outline_size", 6)
	r.add_theme_color_override("font_outline_color", COR_CONTORNO)
	r.position = Vector2(0, ARENA_Y + _dy + (230 if do_jogador else 70))
	r.size = Vector2(360, 30)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = 0.0
	r.pivot_offset = Vector2(180, 15)
	r.scale = Vector2(0.8, 0.8)
	add_child(r)
	var t := create_tween()
	t.tween_property(r, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(r, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.55)
	t.tween_property(r, "modulate:a", 0.0, 0.25)
	t.tween_callback(r.queue_free)

func _caixa(caminho: String) -> StyleBoxTexture:
	var c := StyleBoxTexture.new()
	c.texture = load(caminho)
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		c.set_texture_margin(lado, 6)
	c.content_margin_left = 8
	c.content_margin_right = 8
	c.content_margin_top = 4
	c.content_margin_bottom = 4
	return c

func _botao_hab(h: String) -> Button:
	var H: Dictionary = Catalogo.HAB[h]
	var b := Button.new()
	b.size = Vector2(168, 56)
	_estilo(b, "secundario" if H["el"] == "" else H["el"])
	b.pressed.connect(_escolheu_hab.bind(h))
	Tema.ao_segurar(b, _ficha_hab.bind(h, b))
	var encaixe := TextureRect.new()
	encaixe.texture = load("res://artes/combate/encaixe26.png")
	encaixe.position = Vector2(5, 13)
	encaixe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(encaixe)
	var ic := TextureRect.new()
	ic.texture = load("res://artes/combate/elem20_%s.png" % ("comum" if H["el"] == "" else H["el"]))
	ic.position = Vector2(8, 16)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var nome := Label.new()
	nome.text = H["nome"].to_upper()
	nome.position = Vector2(34, 5)
	nome.size = Vector2(86, 46)
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override("font_size", 16)
	nome.add_theme_constant_override("line_spacing", -4)
	nome.add_theme_color_override("font_outline_color", COR_CONTORNO)
	nome.add_theme_constant_override("outline_size", 4)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nome.set_meta("fonte_fixa", true)       # como definido no início: fonte original mesmo nos nomes longos
	_caber(nome, 86.0, 46.0)
	b.add_child(nome)
	var selo := ColorRect.new()
	selo.color = Color("#0e0f18")
	selo.position = Vector2(124, 16)
	selo.size = Vector2(38, 22)
	selo.name = "selo"
	selo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(selo)
	var inf := TextureRect.new()
	inf.texture = load("res://artes/combate/infinito.png")
	inf.position = Vector2(8, 5)
	inf.name = "inf"
	selo.add_child(inf)
	var usos := Tema.rotulo("", 16, true)
	usos.position = Vector2(0, 1)
	usos.size = Vector2(38, 20)
	usos.name = "usos"
	selo.add_child(usos)
	b.set_meta("hab", h)
	return b

## Segurar o botão da habilidade abre a caixinha dela: tipo, usos, efeito e o dano previsto no alvo mirado.
func _ficha_hab(h: String, b: Control) -> void:
	var H: Dictionary = Catalogo.HAB[h]
	var j: Lutador = motor.jogador
	var linhas: Array = []
	var cat := str(H["cat"])
	var u := j.usos_de(h)
	var usos := tr("HAB_INFO_SEM_LIMITE") if u < 0 else tr("BALAO_USOS") % [u, int(motor.usos_max.get(h, u))]
	linhas.append([tr("HAB_INFO_CAT_" + cat.to_upper()) + " · " + usos, Balao.TINTA_CLARA])
	linhas.append(Catalogo.descrever(h))
	if H.has("poder"):
		var alvos: Array = []
		if str(H["alvo"]) == "inimigos":
			alvos = motor.vivos()
		else:
			var a: Lutador = alvo if alvo != null and alvo.vivo() else (motor.vivos()[0] if not motor.vivos().is_empty() else null)
			if a != null:
				alvos = [a]
		for a: Lutador in alvos:
			var p := motor.prever_dano(j, a, h)
			if p.is_empty():
				continue
			var txt := tr("BALAO_DANO") % [a.nome, int(p["total"])]
			if int(p["golpes"]) > 1:
				txt = tr("BALAO_DANO_GOLPES") % [a.nome, int(p["golpes"]), int(p["golpe"]), int(p["total"])]
			var cor := Color("#7a1e14")
			if float(p["ef"]) > 1.0:
				txt += " " + tr("BALAO_EFICAZ")
				cor = Color("#1e6a2a")
			elif float(p["ef"]) < 1.0:
				txt += " " + tr("BALAO_POUCO_EFICAZ")
			linhas.append([txt, cor])
			linhas.append([tr("BALAO_CRITICO") % [int(p["critico"]), int(p["chance"])], Balao.TINTA_CLARA])
			if a == alvos[-1]:
				var nomes: Array = []
				for md: Array in p["mods"]:
					match str(md[0]):
						"orbe":
							nomes.append(tr("BALAO_MOD_ORBE") % int(md[1]))
						"equip":
							nomes.append(tr("BALAO_MOD_EQUIP") % int(md[1]))
						_:
							nomes.append(tr("COND_" + str(md[0]).to_upper()))
				linhas.append([tr("BALAO_INCLUI") % (", ".join(nomes) if not nomes.is_empty() else tr("BALAO_INCLUI_BASE")), Balao.TINTA_CLARA])
	var el := str(H.get("el", ""))
	Balao.mostrar(self, b.get_global_rect(), str(H["nome"]), COR_EL_BALAO.get(el, Balao.TINTA), linhas)

const COR_EL_BALAO := {"fogo": Color("#b8401a"), "agua": Color("#1e6aa8"), "terra": Color("#7a5420"),
	"ar": Color("#1e7a56"), "raio": Color("#8a6a00"), "gelo": Color("#2a7a98")}

## Tocar num ícone de efeito: o que ele faz e quantas rodadas faltam.
func _balao_cond(c: String, l: Lutador, ic: Control) -> void:
	var pos: bool = Catalogo.CONDICOES.get(c, {}).get("pos", true)
	var linhas: Array = [tr("COND_" + c.to_upper() + "_DESC")]
	if l.conds.has(c):
		var d: Dictionary = l.conds[c]
		if c == "escudo":
			linhas.append([tr("BALAO_ESCUDO_RESTA") % int(round(float(d.get("valor", 0.0)))), Balao.TINTA_CLARA])
		if c == "queimadura":
			linhas.append([tr("BALAO_QUEIMA_VALOR") % max(1, int(round(float(d.get("valor", 1.0))))), Balao.TINTA_CLARA])
		linhas.append([tr("BALAO_RODADAS") % maxi(1, int(d.get("turnos", 1)) - 1), Balao.TINTA_CLARA])
	else:
		linhas.append([tr("BALAO_ATE_PROXIMO"), Balao.TINTA_CLARA])
	Balao.mostrar(self, ic.get_global_rect(), tr("COND_" + c.to_upper()), Color("#1e6a2a") if pos else Color("#9a2a1a"), linhas)

## Segurar a placa do inimigo: ataques conhecidos (com usos nesta luta) e fraquezas.
## Conhecidos = os que ele já usou nesta luta, ou todos depois das 3 vitórias contra a espécie (Bestiário).
func _balao_inimigo(l: Lutador, placa: Control) -> void:
	var id := str(Bestiario.ficha(l.sprite).get("id", l.sprite))
	var revelado := int(Bestiario.registro(id).get("vit", 0)) >= Bestiario.VITORIAS_REVELA and l.categoria != "chefe"
	var vistas: Array = _habs_vistas.get(l.id, [])
	var linhas: Array = []
	var cat := tr("INIM_" + l.categoria.to_upper()) + " · " + (tr("NIVEL_N") % l.nivel)
	if l.elemento != "":
		cat += " · " + tr("EL_" + l.elemento.to_upper())
	linhas.append([cat, Balao.TINTA_CLARA])
	var conhecidas: Array = l.habilidades.filter(func(x): return revelado or vistas.has(x))
	if conhecidas.is_empty():
		linhas.append([tr("BALAO_ATAQUES_DESCONHECIDOS"), Balao.TINTA_CLARA])
	for h: String in conhecidas:
		var u := l.usos_de(h)
		var usos := "∞" if u < 0 else str(u)
		linhas.append([tr("BALAO_ATAQUE_INIMIGO") % [Catalogo.nome_hab(h), usos], Balao.TINTA])
		linhas.append(["  " + Catalogo.descrever(h), Balao.TINTA_CLARA])
	var faltam := l.habilidades.size() - conhecidas.size()
	if faltam > 0 and not conhecidas.is_empty():
		linhas.append([tr("BALAO_OUTROS_ATAQUES") % faltam, Balao.TINTA_CLARA])
	if revelado:
		var fr: Array = Bestiario.fraquezas(l.elemento)
		var nomes: Array = fr.map(func(x): return tr("EL_" + str(x).to_upper()))
		linhas.append([tr("DIARIO_FRAQUEZAS") % (", ".join(nomes) if not nomes.is_empty() else tr("DIARIO_SEM_FRAQUEZA")), Color("#1e6a2a")])
	else:
		linhas.append([tr("BALAO_FRAQUEZA_OCULTA") % (Bestiario.VITORIAS_REVELA - int(Bestiario.registro(id).get("vit", 0))), Balao.TINTA_CLARA])
	Balao.mostrar(self, placa.get_global_rect(), l.nome, Color("#9a2a1a"), linhas)

func _mostrar_aba(luta: bool) -> void:
	aba_luta.set_pressed_no_signal(false)
	aba_inv.set_pressed_no_signal(false)
	for par in [[aba_luta, luta], [aba_inv, not luta]]:
		var b: Button = par[0]
		var ativa: bool = par[1]
		_estilo(b, "primario" if ativa else "secundario")
		b.add_theme_color_override("font_color", Tema.COR_TEXTO_ESCURO if ativa else Tema.COR_TEXTO_APAGADO)
		b.add_theme_color_override("font_hover_color", Tema.COR_TEXTO_ESCURO if ativa else Tema.COR_TEXTO_APAGADO)
	grade_luta.visible = luta
	get_node("rolagem_inv").visible = not luta
	if not luta:
		_montar_inventario()

func _montar_inventario() -> void:
	for f in grade_inv.get_children():
		f.queue_free()
	var itens := {}
	for it in Artes.dados_itens()["itens"]:
		itens[it["id"]] = it
	var tem := false
	for id in motor.pocoes:
		if int(motor.pocoes[id]) <= 0 or not itens.has(id):
			continue
		tem = true
		var it: Dictionary = itens[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(82, 58)
		_estilo(b, "secundario")
		b.disabled = ocupado or not motor.pocao_serve(id)
		b.modulate.a = 0.5 if b.disabled else 1.0
		b.pressed.connect(_confirmar_pocao.bind(id, it["nome"]))
		Tema.ao_segurar(b, _balao_item.bind(it, int(motor.pocoes[id]), b))
		var ic := SpriteCamadas.new()
		ic.escala = 1
		ic.largura_quadro = 32
		ic.altura_quadro = 32
		ic.camadas = [Artes.icone(it["icone"])]
		ic.position = Vector2(6, 10)
		ic.size = Vector2(32, 32)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
		var q := Tema.rotulo("x%d" % int(motor.pocoes[id]), 16, true)
		q.position = Vector2(40, 18)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(q)
		grade_inv.add_child(b)
	if not tem:
		var vazio := Tema.rotulo("SEM_POCOES", 16)
		vazio.custom_minimum_size = Vector2(340, 40)
		grade_inv.add_child(vazio)

## Segurar a poção no Inventário da batalha: o que ela faz (pedido do João, 2026-11-13).
func _balao_item(it: Dictionary, qtd: int, b: Control) -> void:
	var efeito := str(it.get("efeito", ""))
	var partes := efeito.split(" · ")
	var linhas: Array = []
	if partes.size() > 1:
		linhas.append([partes[0], Balao.TINTA_CLARA])
	linhas.append(partes[-1])
	# poções de Vida: quanto recuperam agora
	var m := RegEx.create_from_string("recupera (\\d+)% da Vida").search(efeito)
	if m != null:
		linhas.append([tr("BALAO_POCAO_CURA") % int(round(motor.jogador.vida_max * int(m.get_string(1)) / 100.0)), Color("#1e6a2a")])
	linhas.append([tr("BALAO_POCAO_TURNO") % qtd, Balao.TINTA_CLARA])
	Balao.mostrar(self, b.get_global_rect(), str(it.get("nome", "")), Balao.TINTA, linhas)

# ------------------------------------------------------------ inimigos na arena
func _lugar_livre(l: Lutador) -> int:
	var usados := []
	for id in visuais:
		if visuais[id]["l"].vivo():
			usados.append(visuais[id]["slot"])
	if l.tamanho >= 80:
		return 1
	for s in [1, 0, 2] if usados.is_empty() else [0, 2, 1]:
		if not (s in usados):
			return s
	return 0

func _criar_visual(l: Lutador, n_da_onda: int, i_da_onda: int) -> void:
	var slot := 1
	if n_da_onda == 2:
		slot = [0, 2][i_da_onda]
	elif n_da_onda == 3:
		slot = i_da_onda
	if n_da_onda == 0 or l.tamanho >= 80:
		slot = _lugar_livre(l)
	var grande := l.tamanho >= 80
	var pe: float = SLOT_Y[slot] + (40 if l.tamanho >= 96 else (16 if grande else 0))
	var spr := SpriteCamadas.new()
	spr.escala = 2
	spr.size = Vector2(240 if grande else 120, 260 if grande else 140)
	spr.position = Vector2(SLOT_X[slot] - spr.size.x / 2, pe - spr.size.y)
	spr.mouse_filter = Control.MOUSE_FILTER_STOP
	spr.gui_input.connect(_tocou_inimigo.bind(l))
	spr.terminou.connect(_inimigo_terminou.bind(l))
	palco.add_child(spr)
	palco.move_child(numeros, -1)
	# placa numa coluna fixa por lugar (não se sobrepõem): nome em cima, nível à direita, barra embaixo
	var largura := 168 if grande else 112
	var placa := Control.new()
	placa.size = Vector2(largura, 48)
	var x0: float = 6.0 + slot * 118.0 if not grande else (360.0 - largura) / 2.0
	placa.position = Vector2(clampf(x0, 2, 358 - largura), 4)
	placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tarja := Panel.new()
	var fundo_placa := StyleBoxFlat.new()
	fundo_placa.bg_color = Color(0.07, 0.07, 0.11, 0.88)
	fundo_placa.border_color = Color("#545a74")
	fundo_placa.set_border_width_all(1)
	tarja.add_theme_stylebox_override("panel", fundo_placa)
	tarja.size = Vector2(largura, 54)
	tarja.mouse_filter = Control.MOUSE_FILTER_STOP
	tarja.gui_input.connect(_tocou_inimigo.bind(l))
	Tema.ao_segurar(tarja, _balao_inimigo.bind(l, tarja))
	placa.add_child(tarja)
	# linha 1: só o nome (largura toda); linha 2: selo do nível + barra. Os dois nunca dividem a mesma linha.
	var nome := Label.new()
	nome.text = l.nome
	nome.position = Vector2(5, 1)
	nome.size = Vector2(largura - 10, 26)
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nome.add_theme_constant_override("outline_size", 2)
	nome.add_theme_color_override("font_outline_color", COR_CONTORNO)
	# nome comprido (ex.: Curandeiro Clandestino) quebra em duas linhas menores dentro da placa
	nome.add_theme_constant_override("line_spacing", -3)
	Tema.caber(nome, largura - 10.0, 26.0, 2, [14, 12, 10])
	placa.add_child(nome)
	# selo do nível medido pelo texto (NV3, NV12, NV100 cabem sempre dentro da placa)
	var txt_nv := "NV%d" % l.nivel
	var fonte_nv: Font = Tema.fonte_numeros
	var fr_nv := Tema.fonte_real(fonte_nv, 8)
	var w_nv := ceilf((fr_nv[0] as Font).get_string_size(txt_nv, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fr_nv[1])).x) + 6.0
	var h_nv := maxf(13.0, ceilf(Tema.altura_texto(8)) + 1.0)     # alto o bastante para o texto ficar dentro do selo
	var selo_nv := Panel.new()
	var est_nv := StyleBoxFlat.new()
	est_nv.bg_color = Color("#2a2140")
	est_nv.border_color = Color("#6a5a2a")
	est_nv.set_border_width_all(1)
	selo_nv.add_theme_stylebox_override("panel", est_nv)
	selo_nv.position = Vector2(4, 28)
	selo_nv.size = Vector2(w_nv, h_nv)
	selo_nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placa.add_child(selo_nv)
	var nv := Label.new()
	nv.text = txt_nv
	nv.add_theme_font_override("font", fonte_nv)
	nv.add_theme_font_size_override("font_size", 8)
	nv.add_theme_constant_override("line_spacing", 0)
	nv.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	nv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selo_nv.add_child(nv)
	# pedido do João (2026-11-13): inimigo elemental mostra o ícone do elemento ao lado do nível
	var w_el := 0.0
	if l.elemento != "":
		var ic_el := TextureRect.new()
		ic_el.texture = load("res://artes/combate/elem16_%s.png" % l.elemento)
		ic_el.position = Vector2(6 + w_nv, 28 + floorf((h_nv - 16.0) / 2.0))
		ic_el.size = Vector2(16, 16)
		ic_el.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placa.add_child(ic_el)
		w_el = 18.0
	var barra := Barra.new()
	barra.position = Vector2(8 + w_nv + w_el, 28 + floorf((h_nv - 9.0) / 2.0))
	barra.size = Vector2(largura - 13 - w_nv - w_el, 9)
	placa.add_child(barra)
	# Vida em números embaixo da barra (pedido do João: saber quanto falta)
	var vida_txt := Tema.rotulo("", 8, true)
	vida_txt.set_meta("fonte_fixa", true)
	vida_txt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	vida_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vida_txt.position = Vector2(4, 40)
	vida_txt.size = Vector2(largura - 9, 12)
	vida_txt.add_theme_color_override("font_color", Color("#d8dae6"))
	vida_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	placa.add_child(vida_txt)
	var conds := HBoxContainer.new()
	conds.position = Vector2(2, 56)
	conds.add_theme_constant_override("separation", 1)
	placa.add_child(conds)
	# --- realce do alvo escolhido: seta dourada que balança sobre a cabeça, anel pulsando no chão
	# e a placa com borda dourada (assim fica claro em quem o golpe vai cair)
	var topo_spr := pe - l.tamanho * 2.0 - 20.0        # logo acima da cabeça (o desenho é dobrado)
	palco.add_child(placa)
	visuais[l.id] = {"spr": spr, "placa": placa, "barra": barra, "conds": conds, "vida_txt": vida_txt, "slot": slot, "l": l,
		"fundo_placa": fundo_placa, "mira_x": float(SLOT_X[slot]), "mira_topo": maxf(topo_spr, 76.0),
		"mira_pe": pe - 3.0, "mira_raio": clampf(l.tamanho * 0.7, 30.0, 70.0)}
	_anim_inimigo(l, "parado")

func _anim_inimigo(l: Lutador, acao: String) -> void:
	var v: Dictionary = visuais.get(l.id, {})
	if v.is_empty():
		return
	var a := Artes.inimigo_acao(l.sprite, acao)
	if a.is_empty():
		a = Artes.inimigo_acao(l.sprite, "ataque" if acao == "ataque2" else "parado")
	var spr: SpriteCamadas = v["spr"]
	spr.camadas = [a["peca"]]
	spr.largura_quadro = int(a["largura"])
	spr.altura_quadro = int(a["altura"])
	spr.tocar(range(int(a["quadros"])), float(a["fps"]), acao == "parado")

## Volta ao "parado" enquanto a Vida MOSTRADA for maior que zero; só some depois da animação de derrota
## (antes, um golpe anterior da rodada já sabia que o inimigo ia morrer e ele sumia cedo demais).
func _inimigo_terminou(l: Lutador) -> void:
	if not visuais.has(l.id):
		return
	if not visuais[l.id].get("caiu", false):
		_anim_inimigo(l, "parado")
	else:
		var spr: SpriteCamadas = visuais[l.id]["spr"]
		var t := create_tween()
		t.tween_property(spr, "modulate:a", 0.0, 0.3)

func _anim_heroi(nome: String) -> void:
	var meta := Artes.dados_heroi()
	heroi.tocar(meta["animacoes"][nome], float(meta["fps"]) * (1.5 if nome == "ataque" else 1.0), nome == "parado")

func _heroi_terminou() -> void:
	if not heroi_caido:
		_anim_heroi("parado")

func _tocou_inimigo(evento: InputEvent, l: Lutador) -> void:
	if evento is InputEventMouseButton and evento.pressed and l.vivo():
		alvo = l
		_atualizar_tudo()
		_mira_pulo = 1.0

# ------------------------------------------------------------ fluxo
func _comecar() -> void:
	ocupado = true
	var inicio := tr("MSG_INICIO") % fase
	if tutorial > 0:
		inicio = tr("TUT%d_INICIO" % tutorial)
	elif not qr.is_empty():
		inicio = tr("MSG_INICIO_QR")
	elif evento_etapa > 0:
		inicio = tr("MSG_INICIO_EVENTO") % evento_etapa
	_mensagem(inicio, "")
	await _tocar(motor.iniciar())
	_liberar()

func _liberar() -> void:
	if motor.fim != "":
		return
	ocupado = false
	if alvo == null or not alvo.vivo():
		var v := motor.vivos()
		alvo = v[0] if not v.is_empty() else null
	_mensagem(tr("MSG_SUA_VEZ"), _dica())
	_atualizar_tudo()
	if automatico:
		await get_tree().create_timer(0.3).timeout
		if automatico and not ocupado:
			_jogar(motor.escolher_automatico())

func _ligar_auto(on: bool) -> void:
	automatico = on
	if on and not ocupado:
		_jogar(motor.escolher_automatico())

func _escolheu_hab(h: String) -> void:
	if ocupado:
		return
	Input.vibrate_handheld(15)
	_jogar({"hab": h, "alvo": alvo})

func _confirmar_pocao(id: String, nome: String) -> void:
	if ocupado:
		return
	_abrir_popup(tr("USAR_POCAO") % nome, [["SIM", _usar_pocao.bind(id)], ["NAO", _fechar_popup]])

func _usar_pocao(id: String) -> void:
	_fechar_popup()
	_mostrar_aba(true)
	_jogar({"pocao": id})

func _jogar(acao: Dictionary) -> void:
	ocupado = true
	_atualizar_tudo()
	await _tocar(motor.jogar_rodada(acao))
	if tutorial == 2 and not despertou and motor.despertar_pendente:
		await _cair_e_despertar()
	_liberar()

## Dicas do tutorial (Golpe, Guarda e ordem de ação no 1º; Golpe Rápido, Varredura e poção no 2º).
func _dica() -> String:
	if tutorial == 0 or motor.rodada > 3:
		return ""
	return tr("TUT%d_%d" % [tutorial, motor.rodada])

## Tutorial 2: a Vida do herói chega a zero, ele cai e fica caído; o Despertar abre por cima e,
## depois da escolha do elemento, ele se levanta com a Vida cheia.
func _cair_e_despertar() -> void:
	vida_vista[motor.jogador] = 0
	_atualizar_tudo()
	await _esperar(0.35)
	heroi_caido = true
	_anim_heroi("queda")
	_mensagem(tr("MSG_VOCE_CAIU"), "")
	await _esperar(1.4)
	await _despertar()
	heroi_caido = false
	_anim_heroi("parado")
	var t := create_tween()
	heroi.modulate = Color(2.0, 2.0, 1.6)
	t.tween_property(heroi, "modulate", Color.WHITE, 0.6)

func _despertar() -> void:
	despertou = true
	var d := TelaDespertar.new()
	d.comuns = motor.jogador.habilidades.duplicate()
	add_child(d)
	var r: Array = await d.escolhido
	motor.despertar(r[0], r[1], r[2])
	_sincronizar_vida()
	Jogo.dados["elemento"] = r[0]
	var habs: Array = motor.jogador.habilidades.duplicate()
	Jogo.dados["habilidades"] = habs
	Jogo.salvar()
	_refazer_botoes()
	_icone_elemento()
	_atualizar_tudo()
	_mensagem(tr("TUT_DESPERTOU"), "")
	await _esperar(0.8)

func _refazer_botoes() -> void:
	for b in botoes_hab:
		b.queue_free()
	botoes_hab.clear()
	var habs: Array = motor.jogador.habilidades
	for i in habs.size():
		var b := _botao_hab(habs[i])
		b.position = Vector2((i % 2) * 176, (i / 2) * 62)
		grade_luta.add_child(b)
		botoes_hab.append(b)

func _tocar(eventos: Array) -> void:
	var onda_n := 0
	var onda_total := 0
	var entram: Array = []
	for i in eventos.size():
		var e: Dictionary = eventos[i]
		_conds_vistas = e.get("conds", {})
		match e["t"]:
			"onda":
				lbl_onda.text = tr("ONDA_N") % [e["n"], e["total"]]
				if e["n"] > 1:
					_limpar_caidos()
					_som("onda")
					_mensagem(tr("MSG_ONDA") % [e["n"], e["total"]], "")
					await _esperar(0.7)
				entram = []
				for j in range(i + 1, eventos.size()):
					if eventos[j]["t"] != "entra":
						break
					entram.append(eventos[j]["l"])
				onda_total = entram.size()
				onda_n = 0
			"entra":
				var l: Lutador = e["l"]
				vida_vista[l] = l.vida_max
				if l in entram:
					_criar_visual(l, onda_total, onda_n)
					onda_n += 1
				else:
					_criar_visual(l, 0, 0)
					_mensagem(tr("MSG_CHEGOU") % l.nome, "")
					await _esperar(0.5)
				_atualizar_tudo()
				await _esperar(0.12)
				if l.categoria == "chefe" and _na_historia():
					await _falar_chefe(l, "entra")
			"acao":
				var l: Lutador = e["l"]
				var H: Dictionary = Catalogo.HAB[e["hab"]]
				if not l.eh_jogador:
					var vh: Array = _habs_vistas.get(l.id, [])
					if not vh.has(e["hab"]):
						vh.append(e["hab"])
					_habs_vistas[l.id] = vh
				_mensagem(tr("MSG_USOU") % [_nome(l), H["nome"]], "")
				_faixa_hab(H, l.eh_jogador)
				if H.has("poder"):
					_som("ataque" if str(H.get("cat", "comum")) == "comum" else "magia")
				else:
					_som("condicao")
				if l.eh_jogador:
					_anim_heroi("ataque" if H.has("poder") else "parado")
				else:
					var especial: bool = l.categoria == "chefe" and H["cat"] != "comum"
					_anim_inimigo(l, "ataque2" if especial else "ataque")
				# o golpe só "chega" depois do avanço da animação; o dano vem no próximo evento
				await _esperar(0.5 if H.has("poder") else 0.35)
			"dano":
				var l: Lutador = e["l"]
				if e.get("queimadura", false):
					_mensagem(_txt1, tr("MSG_QUEIMA") % [_nome(l), e["v"]])
				elif l.eh_jogador:
					_mensagem(_txt1, tr("MSG_VOCE_RECEBEU") % e["v"])
				else:
					_mensagem(_txt1, tr("MSG_RECEBEU") % [l.nome, e["v"]])
				if e["crit"]:
					_som("critico")
				elif e.get("queimadura", false):
					_som("dano", 1.3)
				else:
					_som("dano_heroi" if l.eh_jogador else "dano")
				if l.eh_jogador:
					_anim_heroi("dano")
				else:
					_anim_inimigo(l, "dano")
				_tremer(l, e["crit"])
				if e["crit"]:
					_numero(l, "-%d!" % e["v"], COR_CRITICO, 24, Color("#c23b2e"))
				else:
					_numero(l, "-%d" % e["v"], Color.WHITE, 24)
				if float(e["ef"]) > 1.0:
					_numero(l, tr("EFICAZ"), COR_EFICAZ, 16, COR_CONTORNO, -26)
				elif float(e["ef"]) < 1.0:
					_numero(l, tr("RESISTE"), COR_RESISTE, 16, COR_CONTORNO, -26)
				if int(e["abs"]) > 0:
					_numero(l, tr("ESCUDO_ABS") % e["abs"], Color("#c8ccd8"), 16, COR_CONTORNO, -42)
				await _esperar(0.08)          # 1º o impacto e o número, depois a barra desce
				vida_vista[l] = int(e.get("vida", maxi(0, _vida(l) - int(e["v"]))))
				if l.eh_jogador and motor.despertar_pendente and not despertou:
					vida_vista[l] = 0           # no tutorial 2 o herói "cai" com Vida zero e o Despertar o levanta
				_atualizar_tudo()
				if l.eh_jogador or e["crit"]:
					Input.vibrate_handheld(70 if e["crit"] else 35)      # retorno no celular
				await _esperar(0.5)
			"erro":
				_som("errou")
				_numero(e["l"], tr("ERROU"), Color("#c8ccd8"), 16)
				_mensagem(_txt1, tr("MSG_ERROU"))
				await _esperar(0.35)
			"cura":
				_som("cura")
				_numero(e["l"], "+%d" % e["v"], COR_CURA, 24)
				vida_vista[e["l"]] = int(e.get("vida", _vida(e["l"]) + int(e["v"])))
				_atualizar_tudo()
				await _esperar(0.3)
			"cond":
				_mensagem(_txt1, tr("MSG_COND") % [_nome(e["l"]), tr("COND_" + e["c"].to_upper())])
				_atualizar_tudo()
				await _esperar(0.3)
			"msg":
				var nomes: Array = e["a"].map(func(x): return _nome(x))
				_mensagem(tr(e["k"]) % nomes, "")
				await _esperar(0.6)
				if e["k"] == "MSG_FASE2" and _na_historia():
					await _falar_chefe(e["a"][0], "fase2")
			"pocao":
				_pocoes_usadas += 1
				_som("pocao")
				_mensagem(tr("MSG_POCAO"), "")
				await _esperar(0.3)
			"queda":
				var l: Lutador = e["l"]
				await _esperar(0.35)          # deixa a barra terminar de esvaziar antes da queda
				_som("queda_heroi" if l.eh_jogador else "queda")
				if l.eh_jogador:
					heroi_caido = true
					_anim_heroi("queda")
					_mensagem(tr("MSG_VOCE_CAIU"), "")
				else:
					visuais[l.id]["caiu"] = true
					_anim_inimigo(l, "derrota")
					var placa: Control = visuais[l.id]["placa"]
					var tp := create_tween()
					tp.tween_property(placa, "modulate:a", 0.0, 0.3)
					_mensagem(tr("MSG_CAIU") % l.nome, "")
				await _esperar(0.6)
				if not l.eh_jogador and l.categoria == "chefe" and _na_historia():
					await _falar_chefe(l, "cai")
			"atualiza":
				_atualizar_tudo()
			"fim":
				await _esperar(0.6)
				_terminar(e["vitoria"])
	_conds_vistas = {}
	_sincronizar_vida()
	_atualizar_tudo()

## Efeito sonoro da luta (scripts/som.gd).
func _som(nome: String, tom := 1.0) -> void:
	if Jogo.som != null:
		Jogo.som.efeito(nome, tom)

## Fim da rodada: a Vida mostrada volta a bater com a do Motor.
func _sincronizar_vida() -> void:
	vida_vista[motor.jogador] = 0 if (motor.despertar_pendente and not despertou) else motor.jogador.vida
	for id in visuais:
		var l: Lutador = visuais[id]["l"]
		vida_vista[l] = l.vida

func _vida(l: Lutador) -> int:
	return int(vida_vista.get(l, l.vida))

## Tranco no alvo ao levar o golpe (mais forte no crítico) e um lampejo vermelho.
func _tremer(l: Lutador, forte: bool) -> void:
	var alvo_no: Control = null
	if l.eh_jogador:
		alvo_no = heroi
	elif visuais.has(l.id):
		alvo_no = visuais[l.id]["spr"]
	if alvo_no == null:
		return
	if not alvo_no.has_meta("x0"):
		alvo_no.set_meta("x0", alvo_no.position.x)
	var x0: float = alvo_no.get_meta("x0")
	var d := 6.0 if forte else 3.0
	var t := create_tween()
	t.tween_property(alvo_no, "position:x", x0 + d, 0.04)
	t.tween_property(alvo_no, "position:x", x0 - d, 0.06)
	t.tween_property(alvo_no, "position:x", x0, 0.05)
	var c := create_tween()
	alvo_no.self_modulate = Color(1.6, 0.7, 0.7)
	c.tween_property(alvo_no, "self_modulate", Color.WHITE, 0.25)

func _limpar_caidos() -> void:
	for id in visuais.keys():
		if not visuais[id]["l"].vivo():
			visuais[id]["spr"].queue_free()
			visuais[id]["placa"].queue_free()
			visuais.erase(id)
	_atualizar_mira()

func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _nome(l) -> String:
	return tr("VOCE") if l.eh_jogador else l.nome

## Mensagens da caixa de baixo. Texto comprido não é mais cortado (pedido do João): diminui para 10 e,
## se ainda não couber, quebra em duas linhas; a caixa cresce para cima, por cima do pé da arena.
var _txt1 := ""
var _txt2 := ""
var _caixa_msg: Panel
const LARGURA_MSG := 324.0

func _mensagem(a: String, b: String) -> void:
	_txt1 = a
	_txt2 = b
	var escolha: Array = []
	for tam: int in [12, 10]:
		var l1 := _linhas_msg(a, tam, 1)
		var l2 := _linhas_msg(b, tam, 1)
		if not l1.is_empty() and not l2.is_empty():
			escolha = [tam, l1, l2]
			break
	if escolha.is_empty():
		var t1 := _linhas_msg(a, 10, 2)
		var t2 := _linhas_msg(b, 10, 2)
		if t1.is_empty():
			t1 = PackedStringArray([a])
		if t2.is_empty():
			t2 = PackedStringArray([b])
		escolha = [10, t1, t2]
	var tam: int = escolha[0]
	var p1: PackedStringArray = escolha[1]
	var p2: PackedStringArray = escolha[2]
	var lh := ceilf(Tema.altura_texto(tam))
	msg1.add_theme_font_size_override("font_size", tam)
	msg2.add_theme_font_size_override("font_size", tam)
	msg1.text = "\n".join(p1)
	msg2.text = "\n".join(p2)
	var n1 := p1.size() if a != "" else 1
	msg1.position = Vector2(12, 5)
	msg1.size = Vector2(LARGURA_MSG, n1 * lh)
	msg2.position = Vector2(12, 5 + n1 * lh)
	msg2.size = Vector2(LARGURA_MSG, p2.size() * lh)
	var alto := maxf(46.0, 10.0 + (n1 + p2.size()) * lh)
	if _caixa_msg:
		_caixa_msg.size.y = alto
		_caixa_msg.position.y = float(_caixa_msg.get_meta("y0", 412.0)) + _dy - (alto - 46.0)

## Quebra a mensagem em até `max_linhas` linhas no tamanho `tam`; vazio se não couber.
func _linhas_msg(texto: String, tam: int, max_linhas: int) -> PackedStringArray:
	if texto == "":
		return PackedStringArray([""])
	return Tema._quebrar(texto, Tema.fonte_texto, tam, LARGURA_MSG, max_linhas)

func _numero(l: Lutador, texto: String, cor: Color, tam: int, contorno := COR_CONTORNO, dy := 0) -> void:
	var r := Label.new()
	r.text = texto
	r.add_theme_font_size_override("font_size", tam)
	r.add_theme_color_override("font_color", cor)
	r.add_theme_color_override("font_outline_color", contorno)
	r.add_theme_constant_override("outline_size", 6)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.size = Vector2(120, 30)
	var p := Vector2(100, 200)
	if not l.eh_jogador and visuais.has(l.id):
		var v: Dictionary = visuais[l.id]
		p = Vector2(SLOT_X[v["slot"]], SLOT_Y[v["slot"]] - min(l.tamanho, 64) * 2 + 10)
	r.position = p - Vector2(60, 15) + Vector2(0, dy)
	numeros.add_child(r)
	var t := create_tween()
	t.tween_property(r, "position:y", r.position.y - 22, 0.7)
	t.parallel().tween_property(r, "modulate:a", 0.0, 0.7).set_delay(0.35)
	t.tween_callback(r.queue_free)

# ------------------------------------------------------------ atualização do HUD
## Realce do alvo, em duas camadas do palco:
##  - _anel: atrás de todos os bonecos, então o anel fica no chão, embaixo dos pés, sem cobrir o inimigo;
##  - _mira: por cima de tudo, com a seta dourada balançando sobre a cabeça.
var _mira: Control
var _anel: Control
var _mira_pulo := 0.0

func _camada(desenho: Callable) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.draw.connect(desenho)
	palco.add_child(c)
	return c

func _atualizar_mira() -> void:
	if _mira == null:
		_anel = _camada(_desenhar_anel)
		_mira = _camada(_desenhar_seta)
	palco.move_child(_anel, 0)
	palco.move_child(_mira, -1)
	var ver := _mira_visivel()
	_anel.visible = ver
	_mira.visible = ver
	_anel.queue_redraw()
	_mira.queue_redraw()

func _mira_visivel() -> bool:
	return alvo != null and alvo.vivo() and not ocupado and visuais.has(alvo.id)

func _desenhar_anel() -> void:
	if not _mira_visivel():
		return
	var v: Dictionary = visuais[alvo.id]
	var t := Time.get_ticks_msec() / 1000.0
	var raio: float = v["mira_raio"] * (1.0 + 0.4 * _mira_pulo)
	var a := 0.8 + 0.2 * sin(t * 6.0)
	_anel.draw_set_transform(Vector2(v["mira_x"], v["mira_pe"]), 0, Vector2(1, 0.32))
	_anel.draw_circle(Vector2.ZERO, raio, Color(1.0, 0.84, 0.42, 0.22 * a))
	_anel.draw_arc(Vector2.ZERO, raio + 1, 0, TAU, 40, Color(COR_CONTORNO, 0.8), 6.0)
	_anel.draw_arc(Vector2.ZERO, raio, 0, TAU, 40, Color(Tema.COR_OURO_CLARO, a), 3.0)
	_anel.draw_arc(Vector2.ZERO, raio + 5, 0, TAU, 40, Color(1.0, 0.93, 0.7, 0.5 * a), 2.0)

func _desenhar_seta() -> void:
	if not _mira_visivel():
		return
	var v: Dictionary = visuais[alvo.id]
	var t := Time.get_ticks_msec() / 1000.0
	var x: float = v["mira_x"]
	var y: float = v["mira_topo"] + 4.0 * sin(t * 7.0)
	var s := 1.0 + 0.4 * _mira_pulo
	_mira.draw_colored_polygon(PackedVector2Array([Vector2(x - 12 * s, y - 2), Vector2(x + 12 * s, y - 2), Vector2(x, y + 14 * s)]), COR_CONTORNO)
	_mira.draw_colored_polygon(PackedVector2Array([Vector2(x - 9 * s, y), Vector2(x + 9 * s, y), Vector2(x, y + 10 * s)]), Tema.COR_OURO_CLARO)
	_mira.draw_colored_polygon(PackedVector2Array([Vector2(x - 6 * s, y + 1), Vector2(x, y + 1), Vector2(x - 1, y + 6 * s)]), Color(1, 1, 1, 0.6))

func _atualizar_tudo() -> void:
	var j := motor.jogador
	barra_jog.mostrar(float(_vida(j)) / j.vida_max)
	lbl_vida_jog.text = "%d/%d" % [_vida(j), j.vida_max]
	lbl_nivel_jog.text = tr("NIVEL_N") % j.nivel
	_icones(conds_jog, j)
	for id in visuais:
		var v: Dictionary = visuais[id]
		var l: Lutador = v["l"]
		v["barra"].mostrar(float(_vida(l)) / l.vida_max)
		(v["vida_txt"] as Label).text = "%d/%d" % [maxi(0, _vida(l)), l.vida_max]
		_icones(v["conds"], l)
		var mirado := l == alvo and l.vivo() and not ocupado
		var fp: StyleBoxFlat = v["fundo_placa"]
		fp.border_color = Tema.COR_OURO_CLARO if mirado else Color("#545a74")
		fp.set_border_width_all(2 if mirado else 1)
	_atualizar_mira()
	for b in botoes_hab:
		var h: String = b.get_meta("hab")
		var u := j.usos_de(h)
		var selo: Control = b.get_node("selo")
		selo.get_node("inf").visible = u < 0
		var lu: Label = selo.get_node("usos")
		lu.visible = u >= 0
		lu.text = "%d/%d" % [u, int(motor.usos_max.get(h, 0))] if u >= 0 else ""
		lu.add_theme_color_override("font_color", Tema.COR_OURO_CLARO if u != 0 else Color("#ff7a6b"))
		b.disabled = ocupado or not j.pode_usar(h)
		b.modulate.a = 0.55 if (not j.pode_usar(h)) else 1.0
	_atualizar_fila()

## Ícones de condição do momento do evento que está tocando (vazio = estado atual do Motor).
var _conds_vistas: Dictionary = {}

func _icones(caixa: HBoxContainer, l: Lutador) -> void:
	for f in caixa.get_children():
		f.queue_free()
	var lista: Array = _conds_vistas[l] if _conds_vistas.has(l) else l.icones_condicao()
	for c in lista:
		var ic := TextureRect.new()
		ic.texture = load(Catalogo.CONDICOES[c]["icone"] if Catalogo.CONDICOES.has(c) else "res://artes/combate/condicao16_guarda.png")
		ic.mouse_filter = Control.MOUSE_FILTER_STOP
		Tema.ao_tocar(ic, func(_p: Vector2): _balao_cond(str(c), l, ic))
		caixa.add_child(ic)

## Ordem de ação com mini-retratos (o primeiro, que age agora, tem moldura dourada).
func _atualizar_fila() -> void:
	for f in fila_vez.get_children():
		f.queue_free()
	var lista: Array = motor.ordem_prevista().slice(0, 4)
	for i in lista.size():
		var l: Lutador = lista[i]
		var q := Panel.new()
		q.custom_minimum_size = Vector2(30, 30)
		var est := StyleBoxFlat.new()
		est.bg_color = Color("#0e0f18")
		est.border_color = Tema.COR_OURO if i == 0 else (Color("#6cc4ff") if l.eh_jogador else Color("#545a74"))
		est.set_border_width_all(2 if i == 0 else 1)
		q.add_theme_stylebox_override("panel", est)
		var r := TextureRect.new()
		r.position = Vector2(2, 2)
		r.size = Vector2(26, 26)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture = _retrato(l)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		q.add_child(r)
		fila_vez.add_child(q)

## Rosto do lutador para a fila: recorte do 1º quadro parado (inimigo) ou o ícone do elemento (herói).
func _retrato(l: Lutador) -> Texture2D:
	if l.eh_jogador:
		return load("res://artes/combate/elem20_%s.png" % (l.elemento if l.elemento != "" else "comum"))
	var a := Artes.inimigo_acao(l.sprite, "parado")
	if a.is_empty():
		return null
	var peca: Dictionary = a["peca"]
	var rq: Rect2 = peca["rect"]
	var w := float(a["largura"])
	var h := float(a["altura"])
	var lado := minf(w, h) * 0.62
	var at := AtlasTexture.new()
	at.atlas = peca["tex"]
	at.region = Rect2(rq.position + Vector2((w - lado) / 2.0, h * 0.08), Vector2(lado, lado))
	return at

# ------------------------------------------------------------ saída, vitória e derrota
## Pausa (botão II ou voltar do Android): continuar ou desistir (conta como derrota).
func pedir_saida() -> void:
	if motor.fim != "":
		return
	_abrir_popup(tr("PAUSA_TEXTO"), [["CONTINUAR", _fechar_popup], ["DESISTIR", _desistir]])

func _desistir() -> void:
	desistiu = true
	_fechar_popup()
	_terminar(false)

func _terminar(vitoria: bool) -> void:
	if popup and popup.has_meta("resultado"):
		return
	if has_meta("resultado"):
		return
	set_meta("resultado", true)
	Bestiario.registrar(motor, _onde(), _best_desde)
	_best_desde = motor.derrotados.size()
	motor.fim = "vitoria" if vitoria else "derrota"
	ocupado = true
	automatico = false
	Engine.time_scale = 1.0
	if tutorial > 0:
		_terminar_tutorial(vitoria)
		return
	if not qr.is_empty() or evento_etapa > 0:
		_terminar_qr(vitoria)
		return
	var linhas: Array = []
	var fat := Lutador.fator_de(Encontros.nivel_da_fase(fase))
	var ato := clampi(int((fase - 1) / 75) + 1, 1, 4)
	var sub := (tr("FASE_N") % fase + " · " + tr("ATO_N") % ato).to_upper()
	# missões de "derrotar": contam na vitória e na derrota (só os que ainda não foram contados)
	var mis_desde := _mis_desde
	_mis_desde = motor.derrotados.size()
	var falas_derrota: Array = []
	if not vitoria:
		falas_derrota = HISTORIA.falas_de_conclusao(HISTORIA.contar(motor.derrotados.slice(mis_desde)))
	if vitoria:
		var primeira_vez := int(Jogo.dados["vitorias"].get(str(fase), 0)) == 0
		var falas: Array = HISTORIA.vitoria(fase, {"primeira": primeira_vez, "pocoes": _pocoes_usadas,
			"rodadas": motor.rodada, "vida": int(100.0 * motor.jogador.vida / maxf(1.0, motor.jogador.vida_max)),
			"derrotados": motor.derrotados.slice(mis_desde)})
		var xp := 0.0
		var moedas := 0.0
		var frasco := false
		for l in motor.derrotados:
			xp += Catalogo.xp_de(l.categoria, l.fator, l.nivel, int(Jogo.dados["nivel"]))   # menos XP se o herói estiver bem acima (2026-11-24)
			moedas += Catalogo.MOEDAS[l.categoria] * l.fator
			if l.familia == "bandidos" and l.elemento != "":
				frasco = true
		# pedido do João (2026-11-13): rejogar dá a MESMA recompensa da 1ª vez (antes era metade)
		var mult := 1.0
		# DEFINIDO (João, 2026-11-13): ao rejogar, cada fase dá XP, fragmentos e peças até 20 vezes por dia;
		# depois disso só moedas (rejogar outras fases continua dando)
		var rep := _contar_repeticao() if rejogando else 0
		var com_premio := rep <= LIMITE_REPETICOES
		if not com_premio:
			xp = 0.0
		var xp_i := int(round(xp * mult))
		var moedas_i := int(round(moedas * mult))
		var barra := _ganhar_xp_com_barra(xp_i)
		Jogo.dados["moedas"] = int(Jogo.dados["moedas"]) + moedas_i
		linhas.append({"icone": PopupResultado.icone("xp"), "nome": tr("RES_L_XP"), "valor": xp_i})
		linhas.append({"icone": PopupResultado.icone("moeda"), "nome": tr("RES_L_MOEDAS"), "valor": moedas_i})
		var frag := 0
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if not com_premio:
			pass
		elif rng.randf() < (ORBES_R.FRAG_CHANCE_ELEMENTAL if frasco else ORBES_R.FRAG_CHANCE):
			frag += rng.randi_range(ORBES_R.FRAG_SORTE[0], ORBES_R.FRAG_SORTE[1])
		# fragmentos garantidos de Elite, Suprema e chefe (revisão dos Orbes, 2026-11-22, em orbes.gd)
		var fixo: Array = ORBES_R.FRAG_FIXO.get(str(encontro["tipo"]), []) if com_premio else []
		if not fixo.is_empty():
			frag += int(rng.randi_range(int(fixo[0]), int(fixo[1])) * mult)
		if frag > 0:
			# PROVISÓRIO (meu): 50% de chance de vir do elemento base do herói; senão, qualquer um dos 6
			var el: String = Catalogo.ELEMENTOS[rng.randi_range(0, 5)]
			if str(Jogo.dados["elemento"]) != "" and rng.randf() < 0.5:
				el = str(Jogo.dados["elemento"])
			var f: Dictionary = Jogo.dados["fragmentos"]
			f[el] = int(f.get(el, 0)) + frag
			linhas.append({"icone": PopupResultado.icone("fragmento"), "nome": tr("RES_L_FRAG") % tr("EL_" + el.to_upper()), "valor": frag})
		var v: Dictionary = Jogo.dados["vitorias"]
		# recompensas únicas da 1ª vitória (Mobile · Mapa, DEFINIDO): Elite 20% de peça Incomum,
		# Elite Suprema 1 peça Rara do elemento dela, chefe de ato 1 peça Épica do elemento + 50 cristais
		# pedido do João (2026-11-13): as peças também saem ao rejogar; só os 50 cristais do chefe ficam na 1ª vitória (PROVISÓRIO)
		var primeira := int(v.get(str(fase), 0)) == 0
		if rejogando:
			linhas.append({"icone": PopupResultado.icone("xp"), "nome": tr("RES_L_REPETICOES"), "texto": "%d/%d" % [mini(rep, LIMITE_REPETICOES), LIMITE_REPETICOES]})
		if com_premio:
			var nova := ""
			match str(encontro["tipo"]):
				"elite":
					if rng.randf() < 0.2:
						nova = Equipamento.sortear("incomum")
				"suprema", "chefe":
					# pedido do João (2026-11-24): a peça garantida (Rara na Suprema, Épica no chefe) só na 1ª vitória;
					# ao rejogar, sorteio com pouca chance dela e mais chance de Comum/Incomum (Catalogo.PECA_REJOGAR)
					var rar := str(Catalogo.PECA_1A_VEZ[str(encontro["tipo"])])
					if not primeira:
						rar = Catalogo.sortear_raridade(Catalogo.PECA_REJOGAR[str(encontro["tipo"])], rng)
					nova = Equipamento.sortear(rar, _elemento_do_lider() if rar in ["raro", "epico"] else "")
					if str(encontro["tipo"]) == "chefe" and primeira:
						Jogo.dados["cristais"] = int(Jogo.dados["cristais"]) + 50
						linhas.append({"icone": PopupResultado.icone("cristal"), "nome": tr("RES_L_CRISTAIS"), "valor": 50})
			if nova != "":
				Equipamento.dar(nova)
				linhas.append({"icone": Equipamento.icone(nova), "nome": str(Equipamento.ficha(nova)["nome"]), "texto": tr("RAR_" + Equipamento.raridade_de(nova).to_upper())})
		v[str(fase)] = int(v.get(str(fase), 0)) + 1
		if fase >= int(Jogo.dados["fase_atual"]):
			Jogo.dados["fase_atual"] = min(fase + 1, 300)
		Historico.registrar("fase", fase, true, xp_i, moedas_i)     # histórico no servidor (fila local)
		Jogo.salvar()
		Jogo.progresso_mudou.emit()
		# história e missões (falas do NPC, da Voz e o fechamento do capítulo) antes das recompensas
		if not falas.is_empty():
			await _falar(falas)
		# Sem "Próxima" (pedido do João): um toque sem querer abriria outra fase e sair dela custaria
		# uma vida. Ficam a casa (Início) e o Voltar ao mapa.
		var botoes: Array = [_botao_casa(), ["RES_VOLTAR_MAPA", _voltar_ao_mapa, "primario"]]
		_abrir_resultado("vitoria", tr("VITORIA"), sub, linhas, barra, botoes)
	else:
		var perda: int = min(int(round(int(Jogo.dados["moedas"]) * 0.05)), int(500 * fat))
		Vidas.gastar()
		Jogo.dados["moedas"] = int(Jogo.dados["moedas"]) - perda
		linhas.append({"icone": PopupResultado.icone("vida"), "nome": tr("RES_L_VIDA"), "valor": 1, "pre": "-"})
		if perda > 0:
			linhas.append({"icone": PopupResultado.icone("moeda"), "nome": tr("RES_L_MOEDAS"), "valor": perda, "pre": "-"})
		Historico.registrar("fase", fase, false, 0, -perda)
		Jogo.salvar()
		Jogo.progresso_mudou.emit()
		if not falas_derrota.is_empty():
			await _falar(falas_derrota)       # a missão pode fechar mesmo numa derrota (os inimigos caíram)
		_perda_derrota = perda
		# pedido do João: "Jogar novamente" embaixo do continuar com vídeo (só se ainda houver vida)
		var de_novo := Vidas.qtd() > 0
		var botoes: Array = [_botao_casa(), ["RES_VOLTAR_MAPA", _voltar_ao_mapa, "secundario" if _pode_continuar() else "primario"]]
		if de_novo:
			botoes.push_front(["RES_JOGAR_NOVAMENTE", _jogar_novamente, "secundario" if _pode_continuar() else "primario"])
		if _pode_continuar():
			botoes.push_front(["RES_CONTINUAR_VIDEO", _continuar_video, "video"])
		_resultado_derrota = ["derrota", tr("DERROTA"), sub, linhas, {}, botoes, "RES_PERDAS"]
		_abrir_resultado("derrota", tr("DERROTA"), sub, linhas, {}, botoes, "RES_PERDAS")

## Fim da luta do QR Inimigo ou de uma fase do Evento do QR. Derrota gasta vida como no mapa.
func _terminar_qr(vitoria: bool) -> void:
	var linhas: Array = []
	var fat := Lutador.fator_de(int(Jogo.dados["nivel"]))
	var sub := ""
	var botao: Array = ["QR_VOLTAR_INICIO", _voltar_inicio, "primario"]
	if evento_etapa > 0:
		sub = (tr("EVENTO_FASE") % evento_etapa).to_upper()
		botao = ["MAPA", _voltar_ao_mapa, "primario"]
	else:
		sub = (tr("QR_N") % int(qr["qr"])).to_upper()
		fat = Lutador.fator_de(int(qr["ondas"][0][0]["nivel"]))
	if not vitoria:
		var perda: int = min(int(round(int(Jogo.dados["moedas"]) * 0.05)), int(500 * fat))
		Vidas.gastar()
		Jogo.dados["moedas"] = int(Jogo.dados["moedas"]) - perda
		linhas.append({"icone": PopupResultado.icone("vida"), "nome": tr("RES_L_VIDA"), "valor": 1, "pre": "-"})
		if perda > 0:
			linhas.append({"icone": PopupResultado.icone("moeda"), "nome": tr("RES_L_MOEDAS"), "valor": perda, "pre": "-"})
		Historico.registrar("evento" if evento_etapa > 0 else "qr", evento_etapa if evento_etapa > 0 else int(qr["qr"]), false, 0, -perda)
		Jogo.salvar()
		Jogo.progresso_mudou.emit()
		_abrir_resultado("derrota", tr("DERROTA"), sub, linhas, {}, [botao], "RES_PERDAS")
		return
	# recompensa normal dos inimigos derrotados; QR raro (Elite Suprema) vale o dobro
	var mult := 2.0 if (not qr.is_empty() and bool(qr.get("raro", false))) else 1.0
	var xp := 0.0
	var moedas := 0.0
	for l in motor.derrotados:
		xp += Catalogo.xp_de(l.categoria, l.fator, l.nivel, int(Jogo.dados["nivel"]))
		moedas += Catalogo.MOEDAS[l.categoria] * l.fator
	var xp_i := int(round(xp * mult))
	var moedas_i := int(round(moedas * mult))
	var barra := _ganhar_xp_com_barra(xp_i)
	Jogo.dados["moedas"] = int(Jogo.dados["moedas"]) + moedas_i
	linhas.append({"icone": PopupResultado.icone("xp"), "nome": tr("RES_L_XP"), "valor": xp_i})
	linhas.append({"icone": PopupResultado.icone("moeda"), "nome": tr("RES_L_MOEDAS"), "valor": moedas_i})
	var titulo := tr("VITORIA")
	if not qr.is_empty():
		# Elite do bloco: 5–10 fragmentos (dobro no raro)
		var frag := int(randi_range(5, 10) * mult)
		var el: String = Catalogo.ELEMENTOS[randi() % 6]
		var f: Dictionary = Jogo.dados["fragmentos"]
		f[el] = int(f.get(el, 0)) + frag
		linhas.append({"icone": PopupResultado.icone("fragmento"), "nome": tr("RES_L_FRAG") % tr("EL_" + el.to_upper()), "valor": frag})
		CodigoQR.registrar_vitoria(int(qr["qr"]))
		Online.registrar_qr(int(qr["qr"]))
	else:
		var e: Dictionary = Jogo.dados["evento_qr"]
		if int(e["vencidas"]) < evento_etapa:
			e["vencidas"] = evento_etapa
			if evento_etapa >= 5:
				linhas.append_array(CodigoQR.dar_premio_evento())
				titulo = tr("EVENTO_CONCLUIDO")
	Historico.registrar("evento" if evento_etapa > 0 else "qr", evento_etapa if evento_etapa > 0 else int(qr["qr"]), true, xp_i, moedas_i)
	# missões também contam nas lutas do QR (2026-11-24: a do Tobin não fechava com o QR 301)
	var falas: Array = HISTORIA.vitoria_qr(motor.derrotados.slice(_mis_desde))
	_mis_desde = motor.derrotados.size()
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	if not falas.is_empty():
		await _falar(falas)
	_abrir_resultado("vitoria", titulo, sub, linhas, barra, [botao])

func _voltar_inicio() -> void:
	principal.fechar_tela_cheia()

## Elemento do inimigo mais forte derrotado (Suprema/chefe); sem elemento, um ao acaso.
func _elemento_do_lider() -> String:
	var melhor: Lutador = null
	for l in motor.derrotados:
		if melhor == null or l.vida_max > melhor.vida_max:
			melhor = l
	if melhor != null and melhor.elemento != "":
		return melhor.elemento
	return Catalogo.ELEMENTOS[randi() % 6]

const LIMITE_REPETICOES := 20

## Conta mais uma vitória repetida desta fase hoje (data local) e devolve quantas já foram.
func _contar_repeticao() -> int:
	var hoje := Time.get_date_string_from_system()
	var r: Dictionary = Jogo.dados.get("repeticoes", {})
	if str(r.get("dia", "")) != hoje:
		r = {"dia": hoje, "fases": {}}
	var fases: Dictionary = r["fases"]
	var n := int(fases.get(str(fase), 0)) + 1
	fases[str(fase)] = n
	Jogo.dados["repeticoes"] = r
	return n

## Soma o XP e devolve os dados da barra do popup (antes, depois e quantos níveis subiu).
func _ganhar_xp_com_barra(qtd: int) -> Dictionary:
	var de := float(Jogo.dados["xp"]) / maxf(1.0, float(Jogo.xp_para(int(Jogo.dados["nivel"]))))
	var subiu := Jogo.ganhar_xp(qtd)
	var para := float(Jogo.dados["xp"]) / maxf(1.0, float(Jogo.xp_para(int(Jogo.dados["nivel"]))))
	return {"nivel": int(Jogo.dados["nivel"]), "de": de, "para": para, "subiu": subiu}

func _abrir_resultado(tipo: String, titulo: String, sub: String, linhas: Array, barra: Dictionary, botoes: Array, secao := "RES_RECOMPENSAS", texto := "") -> void:
	_fechar_popup()
	var r := PopupResultado.new()
	r.tipo = tipo
	r.titulo = titulo
	r.subtitulo = sub
	r.linhas = linhas
	r.xp = barra
	r.botoes = botoes
	r.secao = secao
	r.texto = texto
	add_child(r)

## Tutorial: derrota não gasta vida e repete na hora; vitória segue a criação.
## O fim do 2º fecha a introdução com um popup próprio; o presente de boas-vindas fica para o Início.
func _terminar_tutorial(vitoria: bool) -> void:
	if not vitoria:
		_abrir_resultado("derrota", tr("DERROTA"), "", [], {}, [["TENTAR_DE_NOVO", _repetir_tutorial, "primario"]], "", tr("TUT_DERROTA"))
		return
	var xp := 0
	var moedas := 0
	for l in motor.derrotados:
		xp += int(round(Catalogo.XP[l.categoria] * l.fator))
		moedas += int(round(Catalogo.MOEDAS[l.categoria] * l.fator))
	var barra := _ganhar_xp_com_barra(xp)
	Jogo.dados["moedas"] = int(Jogo.dados["moedas"]) + moedas
	var linhas: Array = [
		{"icone": PopupResultado.icone("xp"), "nome": tr("RES_L_XP"), "valor": xp},
		{"icone": PopupResultado.icone("moeda"), "nome": tr("RES_L_MOEDAS"), "valor": moedas},
	]
	if tutorial == 1:
		Jogo.dados["etapa"] = "tutorial2"
		Jogo.salvar()
		Jogo.progresso_mudou.emit()
		_abrir_resultado("vitoria", tr("VITORIA"), tr("INTRO_BATALHA_1").to_upper(), linhas, barra, [["CONTINUAR", _seguir, "primario"]])
		return
	Jogo.dados["etapa"] = "pronto"
	Jogo.dados["presente_pendente"] = true
	preload("res://scripts/novidades.gd").marcar_visto()     # herói novo: não precisa do aviso das novidades
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	var el := str(Jogo.dados.get("elemento", ""))
	if el != "":
		linhas.append({"icone": load("res://artes/combate/elem20_%s.png" % el), "nome": tr("INTRO_ELEMENTO"), "texto": tr("EL_" + el.to_upper())})
	_abrir_resultado("intro", tr("INTRO_FIM"), tr("INTRO_SUB").to_upper(), linhas, barra,
		[["INTRO_SEGUIR", _seguir, "primario"]], "RES_RECOMPENSAS", tr("INTRO_TEXTO") % Jogo.nome_heroi())

func _seguir() -> void:
	principal.seguir_criacao()

## Botão quadrado com a casinha da barra de baixo: fecha a luta e volta para a aba Início.
func _botao_casa() -> Array:
	return ["", _ir_ao_inicio, "secundario", "res://artes/interface/barra_inicio_selecionado.png"]

func _ir_ao_inicio() -> void:
	if _abrir_cena_pendente("inicio"):
		return
	principal.abrir_aba("inicio")
	principal.fechar_tela_cheia()

## Cutscene que ficou para depois do resultado (a criança no fim do Ato 1). Devolve true se abriu.
func _abrir_cena_pendente(depois: String) -> bool:
	if str(Jogo.dados.get("cena_pendente", "")) != "crianca":
		return false
	var c = preload("res://scripts/telas/cena_crianca.gd").new()
	c.depois = depois
	principal.abrir_tela_cheia(c)
	return true

## História só nas fases do mapa (nem tutorial, nem QR, nem Evento).
func _na_historia() -> bool:
	return tutorial == 0 and qr.is_empty() and evento_etapa == 0

## Mostra as falas por cima da luta e espera o jogador terminar de ler.
func _falar(falas: Array) -> void:
	if falas.is_empty():
		return
	var vel := Engine.time_scale
	Engine.time_scale = 1.0
	var d = DIALOGO.new()
	d.falas = falas
	d.ato = int(encontro.get("ato", 0))
	d.arena = int(encontro.get("arena", 0))
	add_child(d)
	await d.terminou
	Engine.time_scale = vel

func _falar_chefe(l: Lutador, momento: String) -> void:
	var fl: Dictionary = HISTORIA.fala_chefe(str(Bestiario.ficha(l.sprite).get("id", l.tipo)), momento)
	if fl.is_empty():
		return
	var auto := automatico
	automatico = false
	await _falar([fl])
	automatico = auto

func _repetir_tutorial() -> void:
	principal.seguir_criacao()

## Recomeça a mesma fase do zero (a vida da derrota já foi gasta).
func _jogar_novamente() -> void:
	var t = preload("res://scripts/telas/combate.gd").new()
	t.fase = fase
	principal.abrir_tela_cheia(t)

func _voltar_ao_mapa() -> void:
	if _abrir_cena_pendente("mapa"):
		return
	var m = preload("res://scripts/telas/mapa.gd").new()
	principal.abrir_tela_cheia(m)

func _abrir_popup(titulo: String, botoes: Array, texto := "") -> void:
	_fechar_popup()
	popup = Janela.criar(titulo, botoes, texto)
	add_child(popup)

func _fechar_popup() -> void:
	if popup:
		popup.fechar()
		popup = null

## Onde a luta aconteceu, para o Diário ("tutorial", "qr", "evento" ou o número da fase).
func _onde() -> String:
	if tutorial > 0:
		return "tutorial"
	if evento_etapa > 0:
		return "evento"
	if not qr.is_empty():
		return "qr"
	return str(fase)

# ------------------------------------------------------------ continuar com vídeo
## Só no modo história, 1 vez por tentativa, e não depois de desistir.
func _pode_continuar() -> bool:
	return tutorial == 0 and qr.is_empty() and evento_etapa == 0 and not continuou and not desistiu and Anuncios.disponivel()

func _continuar_video() -> void:
	Anuncios.mostrar_video(self, func(ok: bool):
		if not ok:
			# cancelou o vídeo: o resultado da derrota volta como estava
			_abrir_resultado.callv(_resultado_derrota)
			return
		_continuar())

## PROVISÓRIO (meu): como a derrota é desfeita, a vida e as moedas perdidas voltam.
func _continuar() -> void:
	continuou = true
	Vidas.ganhar(1)
	Jogo.dados["moedas"] = int(Jogo.dados["moedas"]) + _perda_derrota
	_perda_derrota = 0
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	_fechar_popup()
	remove_meta("resultado")
	motor.reviver(0.5)
	Engine.time_scale = 1.0 if bool(Jogo.dados.get("velocidade_x2", false)) else VELOCIDADE_NORMAL
	heroi_caido = false
	_anim_heroi("parado")
	var t := create_tween()
	heroi.modulate = Color(2.0, 2.0, 1.6)
	t.tween_property(heroi, "modulate", Color.WHITE, 0.6)
	_sincronizar_vida()
	_atualizar_tudo()
	_mensagem(tr("MSG_CONTINUOU"), "")
	await _esperar(0.8)
	_liberar()
