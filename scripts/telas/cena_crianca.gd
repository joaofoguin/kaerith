extends Tela
## Cutscene do fim do Ato 1 (DEFINIDO pelo João em 2026-11-23: uma prévia da criança, sem contato com o jogador,
## mostrando algo que acontece em outro lugar). Roteiro PROVISÓRIO na aba "História e missões por ato":
## Mata dos Ecos Velados à noite → a criança de capuz ajoelhada diante de uma pedra antiga → luzes pálidas sobem
## do chão e a cercam → ela fala com a pedra → as luzes se apagam, olhos de feras se acendem, a geada entra pelas
## bordas → a criança corre para a névoa → abertura do Capítulo 2. Só passa uma vez e pode ser pulada.
## Não mostra o nome, a Morte como elemento nem Ysmera.

const HISTORIA := preload("res://scripts/historia.gd")

var depois := "mapa"                 # para onde vai no fim: "mapa" ou "inicio"
var cena: CenaPintada
var crianca: TextureRect
var corre: Array = []                # 2 quadros da corrida
var luzes: Control
var olhos: Control
var geada: Array = []
var caixa: CaixaDialogo
var veu: ColorRect
var titulo: Label
var regiao: Label
var saindo := false
var _t := 0.0
var _luz := 0.0                      # 0 a 1: quanto as luzes pálidas já subiram
var _olhos := 0.0
var _corrida := false
var _rng := RandomNumberGenerator.new()
var _pontos: Array = []              # luzes: [x, y, fase, velocidade]

func montar() -> void:
	add_to_group("som_historia")
	palco_640 = true
	_rng.seed = 75
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	cena = CenaPintada.new("mata")
	cena.duracao = 34.0
	add_child(cena)
	# a criança e as luzes ficam presas à camada da clareira (andam junto com o parallax dela)
	var clareira: TextureRect = cena.get_node_or_null("clareira")
	crianca = TextureRect.new()
	crianca.texture = load("res://artes/cenas/crianca_ajoelhada.png")
	crianca.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crianca.position = Vector2(102, 232)
	crianca.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tira: Texture2D = load("res://artes/cenas/crianca_corre.png")
	for q in 2:
		var at := AtlasTexture.new()
		at.atlas = tira
		at.region = Rect2(q * 32, 0, 32, 36)
		corre.append(at)
	luzes = Control.new()
	luzes.size = Vector2(220, 320)
	luzes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	luzes.draw.connect(_desenhar_luzes)
	if clareira:
		clareira.add_child(luzes)
		clareira.add_child(crianca)
	else:
		add_child(luzes)
		add_child(crianca)
	for i in 14:
		_pontos.append([_rng.randf_range(84, 150), _rng.randf_range(244, 268), _rng.randf() * TAU, _rng.randf_range(0.6, 1.2)])
	var longe: TextureRect = cena.get_node_or_null("longe")
	olhos = Control.new()
	olhos.size = Vector2(220, 320)
	olhos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	olhos.draw.connect(_desenhar_olhos)
	if longe:
		longe.add_child(olhos)
	# geada que entra pelas duas bordas
	for lado in ["esq", "dir"]:
		var g := TextureRect.new()
		g.texture = load("res://artes/cenas/mata_geada_%s.png" % lado)
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.size = Vector2(220, 320)
		g.scale = Vector2(2, 2)
		g.position = Vector2(-120 if lado == "esq" else 120, 0)
		g.modulate.a = 0.0
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(g)
		geada.append(g)

	add_child(preload("res://scripts/telas/prologo.gd").sombra_de_baixo())
	titulo = _letreiro("", 24, 230)
	regiao = _letreiro("", 16, 266)
	caixa = CaixaDialogo.new()
	caixa.position = Vector2(8, 500)
	caixa.size = Vector2(344, 128)
	caixa.visible = false
	add_child(caixa)
	var pular := Button.new()
	pular.text = "PULAR"
	pular.position = Vector2(276, 8)
	pular.size = Vector2(76, 30)
	pular.modulate.a = 0.7
	pular.pressed.connect(_terminar)
	add_child(pular)
	veu = ColorRect.new()
	veu.color = Color(0, 0, 0, 1)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)
	_roteiro()

func _letreiro(texto: String, tam: int, y: float) -> Label:
	var l := Tema.rotulo(texto, tam)
	l.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color("#1a120c"))
	l.position = Vector2(0, y)
	l.size = Vector2(360, 34)
	l.modulate.a = 0.0
	add_child(l)
	return l

func _process(delta: float) -> void:
	_t += delta
	if luzes:
		luzes.queue_redraw()
	if olhos and _olhos > 0.0:
		olhos.queue_redraw()
	if _corrida:
		crianca.texture = corre[int(_t * 8.0) % 2]

## Luzes pálidas: sobem devagar do chão em volta da criança, oscilando, com halo (as de trás menores).
func _desenhar_luzes() -> void:
	if _luz <= 0.0:
		return
	for p: Array in _pontos:
		var sobe := fmod(_t * 6.0 * p[3] + p[2] * 10.0, 40.0)
		var pos := Vector2(p[0] + sin(_t * 1.3 + p[2]) * 3.0, p[1] - sobe * _luz)
		var a := _luz * (0.35 + 0.45 * (0.5 + 0.5 * sin(_t * 2.0 + p[2]))) * clampf(1.0 - sobe / 40.0, 0.0, 1.0) * 1.6
		var frente: bool = float(p[3]) > 0.9
		luzes.draw_rect(Rect2(pos.floor() - Vector2(1, 1), Vector2(3, 3)), Color(0.75, 1.0, 0.92, a * 0.25))
		luzes.draw_rect(Rect2(pos.floor(), Vector2(1, 1) * (2.0 if frente else 1.0)), Color(0.85, 1.0, 0.95, minf(a, 1.0)))

## Olhos das feras entre as árvores ao longe (pares de pontos âmbar que piscam).
func _desenhar_olhos() -> void:
	var pares := [Vector2(40, 214), Vector2(176, 206), Vector2(70, 196), Vector2(150, 224), Vector2(204, 190)]
	for i in pares.size():
		var liga := clampf(_olhos * pares.size() - i, 0.0, 1.0)
		if liga <= 0.0:
			continue
		var pisca := 0.0 if fmod(_t + i * 0.7, 3.1) < 0.12 else 1.0
		var c := Color(1.0, 0.62, 0.2, liga * pisca)
		olhos.draw_rect(Rect2(pares[i], Vector2(1, 1)), c)
		olhos.draw_rect(Rect2(pares[i] + Vector2(3, 0), Vector2(1, 1)), c)

func _roteiro() -> void:
	var t := create_tween()
	t.tween_property(veu, "color:a", 0.0, 2.2).set_trans(Tween.TRANS_SINE)
	await t.finished
	await get_tree().create_timer(0.8).timeout
	if saindo:
		return
	# as luzes pálidas sobem do chão e cercam a criança
	var tl := create_tween()
	tl.tween_property(self, "_luz", 1.0, 3.0).set_trans(Tween.TRANS_SINE)
	await tl.finished
	if saindo:
		return
	caixa.mostrar(["CENA_CRIANCA_1", "CENA_CRIANCA_2"], "???")
	await caixa.terminou
	if saindo:
		return
	caixa.visible = false
	# as luzes se apagam de uma vez; olhos se acendem; a geada entra pelas bordas
	_luz = 0.0
	await get_tree().create_timer(0.6).timeout
	var to := create_tween()
	to.tween_property(self, "_olhos", 1.0, 2.0)
	for g: TextureRect in geada:
		to.parallel().tween_property(g, "modulate:a", 1.0, 3.0)
		to.parallel().tween_property(g, "position:x", 0.0, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await to.finished
	if saindo:
		return
	# a criança corre para dentro da névoa
	_corrida = true
	crianca.position.y -= 2
	var tc := create_tween()
	tc.tween_property(crianca, "position:x", 236.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tc.parallel().tween_property(crianca, "modulate:a", 0.0, 2.2).set_delay(0.8)
	await tc.finished
	if saindo:
		return
	# escurece e mostra a abertura do Capítulo 2
	var tv := create_tween()
	tv.tween_property(veu, "color:a", 0.85, 1.4)
	await tv.finished
	titulo.text = tr("DIARIO_CAPITULO_N") % 2 + " · " + tr("DIARIO_CAP_2")
	regiao.text = tr("REGIAO_2")
	var tt := create_tween()
	tt.tween_property(titulo, "modulate:a", 1.0, 1.0)
	tt.parallel().tween_property(regiao, "modulate:a", 1.0, 1.4)
	tt.tween_interval(2.4)
	tt.tween_property(titulo, "modulate:a", 0.0, 0.8)
	tt.parallel().tween_property(regiao, "modulate:a", 0.0, 0.8)
	await tt.finished
	_terminar()

func _terminar() -> void:
	if saindo:
		return
	saindo = true
	HISTORIA.marcar("cena1")
	Jogo.dados.erase("cena_pendente")
	Jogo.salvar()
	if depois == "inicio":
		principal.abrir_aba("inicio")
		principal.fechar_tela_cheia()
	else:
		principal.abrir_tela_cheia(preload("res://scripts/telas/mapa.gd").new())
