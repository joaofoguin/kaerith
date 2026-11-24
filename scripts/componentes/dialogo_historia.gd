extends Control
## Diálogo da história por cima de qualquer tela (fim de fase, chefes no meio da luta, missões).
## Uso (sem class_name, por preload):
##   var d = preload("res://scripts/componentes/dialogo_historia.gd").new()
##   d.falas = [Historia.fala("mirela", ["HIST_14"]), ...]
##   d.ato = 1; d.arena = 0          # fundo (0 = ato em que o jogador está)
##   add_child(d); await d.terminou
## Cena: o fundo animado da arena do ato, o herói à esquerda e quem fala à direita, em meio corpo
## (as pernas ficam atrás da caixa). Quem fala fica aceso e sobe um pouco; quem ouve fica na sombra.
## A caixa é a mesma CaixaDialogo do Prólogo (bips, toque completa a frase).
## Cada fala: {"npc", "quem", "partes": [chaves], "el", "titulo" (só no capítulo)}.

signal terminou

const SOMBRA := Color(0.42, 0.42, 0.52)
const SUBIR := 6.0
const ESCALA_HEROI := 4
const ESCALA_NPC := 4          # NPCs no mesmo tamanho do herói
const ESCALA_CHEFE := 4        # chefes (quadro 96×96) maiores que o herói
## linha da cintura dentro do quadro: fica um pouco abaixo do topo da caixa (meio corpo à mostra)
const CINTURA_HEROI := 50
const CINTURA_NPC := 50          # NPCs: quadro 48×64, igual ao herói
const CINTURA_CHEFE := 56        # chefes: quadro 96×96
const CENTRO_NPC := 266.0       # x do centro de quem fala à direita
## chefes: onde termina o desenho dentro do quadro de 96 (borda direita), para encostá-lo na direita da tela
const BORDA_CHEFE := {"mestre_calder": 83, "thessa_vurn": 78, "semeadora_velada": 96, "ysmera": 96}
const DIREITA_CHEFE := 370.0    # pode passar 10 px da tela
const X_HEROI := -34.0
const CORTE := 12.0             # a cintura fica 12 px acima da caixa: um pouco cortados por ela

var falas: Array = []
var ato := 0
var arena := 0

var _i := 0
var _fundo: TextureRect
var _quadros: Array = []
var _q := 0
var _tempo_fundo := 0.0
var _tempo := 0.0
var _heroi: HeroiFrente
var _outro: SpriteCamadas
var _outro_npc := ""
var _luz: Control           # a Voz não tem corpo: uma luz que pulsa no alto
var _caixa: CaixaDialogo
var _titulo: Label
var _topo_caixa := 0.0
var _palco: Control         # corta os personagens no topo da caixa (meio corpo)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Tema.tema            # mesma caixa dos popups e mesmas fontes do jogo, em qualquer tela
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	z_index = 50
	process_mode = Node.PROCESS_MODE_ALWAYS     # o combate pode estar acelerado (Engine.time_scale)
	modulate.a = 0.0

	var preto := ColorRect.new()
	preto.color = Color("#0b0b12")
	preto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preto)
	_fundo = TextureRect.new()
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_fundo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fundo)
	var a := ato if ato > 0 else Temporada.ato_do_jogador()
	for q in 4:
		# a arena do ato sem as sombras redondas dos lutadores
		var caminho := "res://artes/arenas/dialogo/ato%d_%d_q%d.png" % [a, arena, q]
		if ResourceLoader.exists(caminho):
			_quadros.append(load(caminho))
	if not _quadros.is_empty():
		_fundo.texture = _quadros[0]
	var veu := ColorRect.new()
	veu.color = Color(0.03, 0.03, 0.07, 0.38)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)

	_luz = Control.new()
	_luz.size = Vector2(120, 120)
	_luz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_luz.modulate.a = 0.0
	_luz.draw.connect(_desenhar_luz)
	add_child(_luz)

	_palco = Control.new()
	_palco.clip_contents = true
	_palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_palco)
	_heroi = HeroiFrente.new()
	_heroi.escala = ESCALA_HEROI
	_heroi.size = Vector2(48 * ESCALA_HEROI, 64 * ESCALA_HEROI)
	_heroi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heroi.vestir(Jogo.camadas_heroi())
	_heroi.modulate = SOMBRA
	_palco.add_child(_heroi)
	_outro = SpriteCamadas.new()
	_outro.escala = ESCALA_NPC
	_outro.size = Vector2(48 * ESCALA_NPC, 64 * ESCALA_NPC)
	_outro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outro.visible = false
	_palco.add_child(_outro)

	_titulo = Tema.rotulo("", 24)
	_titulo.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	_titulo.add_theme_constant_override("outline_size", 4)
	_titulo.add_theme_color_override("font_outline_color", Color("#3a2418"))
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titulo.modulate.a = 0.0
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_titulo)

	_caixa = CaixaDialogo.new()
	_caixa.visible = false
	add_child(_caixa)
	_caixa.terminou.connect(_proxima)
	resized.connect(_posicionar)
	_posicionar()
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)
	_mostrar.call_deferred()

## A caixa fica embaixo; os pés dos personagens ficam escondidos atrás dela (meio corpo à mostra).
func _posicionar() -> void:
	var h := maxf(size.y, 640.0)
	_caixa.position = Vector2(8, h - 140.0)
	_caixa.size = Vector2(344, 128)
	_topo_caixa = h - 140.0
	_palco.size = Vector2(360, _topo_caixa + 2.0)
	_heroi.position = Vector2(X_HEROI, _y_de(_heroi, false))
	_outro.position = Vector2(_x_outro(), _y_de(_outro, false))
	_luz.position = Vector2(180 - 60, h * 0.22)
	_titulo.position = Vector2(16, h * 0.12)
	_titulo.size = Vector2(328, 80)

## Toque fora da caixa também passa a fala (a caixa só pega toques dentro dela).
func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_caixa._gui_input(evento)

func _mostrar() -> void:
	if _i >= falas.size():
		_fechar()
		return
	var fl: Dictionary = falas[_i]
	var npc := str(fl.get("npc", ""))
	var voz := str(fl.get("el", "")) == "voz"
	if npc != "" and npc != _outro_npc:
		_trocar_outro(npc)
	# destaque: quem fala acende e sobe; os outros ficam na sombra
	_destacar(_outro, npc != "" and _outro.visible)
	_destacar(_heroi, false)
	create_tween().tween_property(_luz, "modulate:a", 1.0 if voz else 0.0, 0.4)
	_titulo.text = str(fl.get("titulo", ""))
	_titulo.modulate.a = 0.0
	if _titulo.text != "":
		create_tween().tween_property(_titulo, "modulate:a", 1.0, 0.6)
	var partes: Array = []
	for p in fl["partes"]:
		partes.append_array(dividir(tr(str(p))))
	_caixa.mostrar(partes, str(fl.get("quem", "")))

func _destacar(no: Control, falando: bool) -> void:
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(no, "modulate", Color.WHITE if falando else SOMBRA, 0.25)
	t.tween_property(no, "position:y", _y_de(no, falando), 0.25)

## y do controle para a cintura ficar CORTE px acima do topo da caixa.
func _y_de(no: Control, falando: bool) -> float:
	var cintura := CINTURA_HEROI * ESCALA_HEROI
	if no != _heroi:
		cintura = (CINTURA_NPC if _outro.altura_quadro == 64 else CINTURA_CHEFE) * _outro.escala
	var altura_quadro := 64 * ESCALA_HEROI if no == _heroi else _outro.altura_quadro * _outro.escala
	return _topo_caixa - CORTE - cintura - (no.size.y - altura_quadro) - (SUBIR if falando else 0.0)

func _x_outro() -> float:
	if _outro.altura_quadro == 64:
		return CENTRO_NPC - _outro.size.x / 2.0
	return DIREITA_CHEFE - float(BORDA_CHEFE.get(_outro_npc, 90)) * _outro.escala

## Quem entra na conversa desliza da direita; quem sai desliza de volta.
func _trocar_outro(npc: String) -> void:
	var camada := {}
	var largura := 96
	var altura := 96
	var n := 4
	var fps := 6.0
	if Bestiario.CHEFES.has(npc):
		var a := Artes.inimigo_acao(npc, "parado")
		if not a.is_empty():
			camada = a["peca"]
			largura = int(a["largura"])
			altura = int(a["altura"])
			n = int(a.get("quadros", 4))
			fps = float(a.get("fps", 6))
	else:
		var caminho := "res://artes/personagens/%s.png" % npc
		if ResourceLoader.exists(caminho):
			var tex: Texture2D = load(caminho)
			camada = {"tex": tex, "rect": Rect2(Vector2.ZERO, tex.get_size())}
			largura = 48                      # NPC: tira de 4 quadros 48×64 (mesmo modelo do herói)
			altura = 64
			n = maxi(1, int(tex.get_width() / 48))
	var entrar := func():
		_outro_npc = npc
		_outro.visible = not camada.is_empty()
		_outro.camadas = [camada]
		_outro.largura_quadro = largura
		_outro.altura_quadro = altura
		_outro.escala = ESCALA_NPC if altura == 64 else ESCALA_CHEFE
		_outro.size = Vector2(largura, altura) * _outro.escala
		var x_final := _x_outro()
		_outro.tocar(range(n), fps, true)
		_outro.position = Vector2(380.0, _y_de(_outro, true))
		_destacar(_outro, true)
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) \
			.tween_property(_outro, "position:x", x_final, 0.35)
	if _outro.visible:
		var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(_outro, "position:x", 380.0, 0.2)
		t.tween_callback(entrar)
	else:
		entrar.call()

## Textos longos viram várias caixas (a caixa cabe ~3 linhas): corta no fim das frases, até MAX_LETRAS por caixa.
const MAX_LETRAS := 100
static func dividir(texto: String) -> Array:
	if texto.length() <= MAX_LETRAS:
		return [texto]
	var frases: Array = []
	var atual := ""
	for i in texto.length():
		atual += texto[i]
		if texto[i] in ".!?" and (i + 1 >= texto.length() or texto[i + 1] == " "):
			frases.append(atual.strip_edges())
			atual = ""
	if atual.strip_edges() != "":
		frases.append(atual.strip_edges())
	var r: Array = []
	var caixa := ""
	for f: String in frases:
		if caixa != "" and caixa.length() + 1 + f.length() > MAX_LETRAS:
			r.append(caixa)
			caixa = f
		else:
			caixa = f if caixa == "" else caixa + " " + f
	if caixa != "":
		r.append(caixa)
	return r

func _proxima() -> void:
	_i += 1
	_mostrar()

func _fechar() -> void:
	_caixa.visible = false
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		terminou.emit()
		queue_free())

func _process(delta: float) -> void:
	_tempo += delta
	_tempo_fundo += delta
	if _tempo_fundo >= 0.125 and not _quadros.is_empty():
		_tempo_fundo = 0.0
		_q = (_q + 1) % _quadros.size()
		_fundo.texture = _quadros[_q]
	if _luz.modulate.a > 0.0:
		_luz.queue_redraw()

## A Voz: luz branca que pulsa, com faíscas em órbita (as de trás menores e escuras).
func _desenhar_luz() -> void:
	var centro := _luz.size / 2.0
	var pulso := 0.5 + 0.5 * sin(_tempo * 2.4)
	for k in 4:
		_luz.draw_circle(centro, 26.0 - k * 6.0 + pulso * 3.0, Color(0.85, 0.9, 1.0, 0.08 + 0.1 * k))
	_luz.draw_circle(centro, 5.0, Color(1, 1, 1, 0.95))
	for k in 8:
		var a := _tempo * 0.9 + k * TAU / 8.0
		var p := centro + Vector2(cos(a) * 44.0, sin(a) * 14.0)
		var frente := sin(a) > 0.0
		_luz.draw_rect(Rect2(p.round(), Vector2(2, 2) if frente else Vector2(1, 1)), Color(0.9, 0.95, 1.0, 0.9 if frente else 0.4))
