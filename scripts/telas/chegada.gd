extends Tela
## Chegada aos Campos de Auren (entre a criação e o 1º combate): contexto do mundo e da batalha.
## O herói chega pela estrada ao entardecer, a Voz conta onde ele está e por que há perigo,
## um Batedor bloqueia o caminho e a cena corta para a luta. Textos CHEG_*: rascunho PROVISÓRIO.

const FALAS_VOZ := ["CHEG_1", "CHEG_2", "CHEG_3", "CHEG_4"]

var cena: CenaPintada
var heroi: HeroiFrente
var bandido: SpriteCamadas
var caixa: CaixaDialogo
var veu: ColorRect
var regiao: Label
var saindo := false

func montar() -> void:
	add_to_group("som_historia")      # música da história (scripts/som.gd)
	palco_640 = true   # quadro fixo de 360×640 centrado (celulares altos ganham faixas pretas)
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	cena = CenaPintada.new("auren")
	cena.duracao = 30.0
	add_child(cena)

	heroi = HeroiFrente.new()
	heroi.escala = 2
	heroi.size = Vector2(96, 128)
	heroi.position = Vector2(150, 660)
	heroi.vestir(Jogo.camadas_heroi())
	heroi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(heroi)

	bandido = SpriteCamadas.new()
	bandido.escala = 2
	bandido.size = Vector2(120, 110)
	bandido.position = Vector2(400, 360)
	bandido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := Artes.inimigo_acao("batedor_comum", "parado")
	if not a.is_empty():
		bandido.camadas = [a["peca"]]
		bandido.largura_quadro = int(a["largura"])
		bandido.altura_quadro = int(a["altura"])
		bandido.tocar(range(int(a["quadros"])), float(a["fps"]), true)
	add_child(bandido)
	# sombra no chão sob os pés (o Batedor tem os pés na base do quadro; o herói tem 6 px de folga)
	heroi.add_child(_sombra_pes(Vector2(48, 116), 22.0))
	bandido.add_child(_sombra_pes(Vector2(60, 108), 26.0))

	add_child(preload("res://scripts/telas/prologo.gd").sombra_de_baixo())
	regiao = Tema.rotulo("CHEG_REGIAO", 24)
	regiao.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	regiao.add_theme_constant_override("outline_size", 4)
	regiao.add_theme_color_override("font_outline_color", Color("#3a2418"))
	regiao.position = Vector2(0, 120)
	regiao.size = Vector2(360, 40)
	regiao.modulate.a = 0.0
	add_child(regiao)

	caixa = CaixaDialogo.new()
	caixa.position = Vector2(8, 500)
	caixa.size = Vector2(344, 128)
	caixa.visible = false
	add_child(caixa)
	veu = ColorRect.new()
	veu.color = Color(1, 1, 1, 0)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)
	_roteiro()

## A paisagem nasce do escuro em camadas: primeiro o céu do entardecer, depois as colinas ao longe,
## o trigo e por fim a beira da estrada e o pólen no ar (nada de tela preta parada).
func _revelar() -> void:
	var camadas := cena.get_children()
	for i in camadas.size():
		var c: CanvasItem = camadas[i]
		c.modulate.a = 0.0
		var t := create_tween()
		t.tween_interval(0.25 + i * 0.7)
		t.tween_property(c, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	# o sol termina de nascer: a cena sai de um tom frio e escuro para a cor do entardecer
	cena.modulate = Color(0.45, 0.45, 0.65, 1.0)
	var luz := create_tween()
	luz.tween_property(cena, "modulate", Color.WHITE, 4.5).set_trans(Tween.TRANS_SINE)

func _roteiro() -> void:
	_revelar()
	await get_tree().create_timer(1.6).timeout
	# o nome da região surge e o herói vem andando pela estrada
	var t := create_tween()
	t.tween_property(regiao, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(heroi, "position", Vector2(118, 340), 4.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.6)
	t.tween_property(regiao, "modulate:a", 0.0, 1.0)
	await t.finished
	caixa.mostrar(FALAS_VOZ, "???")
	await caixa.terminou
	# um Batedor sai do trigo e fecha a estrada
	var t2 := create_tween()
	t2.tween_property(bandido, "position", Vector2(206, 360), 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.parallel().tween_property(heroi, "position:x", 70.0, 0.6).set_trans(Tween.TRANS_SINE)
	await t2.finished
	caixa.mostrar(["CHEG_5"], tr("CHEG_BATEDOR"))
	await caixa.terminou
	caixa.mostrar(["CHEG_6"], "???")
	await caixa.terminou
	_para_a_luta()

## Corte para a batalha: tremida, clarão e o combate do tutorial.
func _para_a_luta() -> void:
	if saindo:
		return
	saindo = true
	caixa.visible = false
	var t := create_tween()
	for i in 6:
		t.tween_property(cena, "position", Vector2(4 if i % 2 == 0 else -4, 2 if i % 3 == 0 else -2), 0.05)
	t.tween_property(cena, "position", Vector2.ZERO, 0.05)
	t.tween_property(veu, "color:a", 1.0, 0.35)
	t.tween_callback(_terminar)

func _terminar() -> void:
	Jogo.dados["etapa"] = "tutorial1"
	Jogo.salvar()
	principal.seguir_criacao()

func _sombra_pes(centro: Vector2, raio: float) -> Control:
	var c := Control.new()
	c.show_behind_parent = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_desenhar_sombra.bind(c, centro, raio))
	return c

func _desenhar_sombra(c: Control, centro: Vector2, raio: float) -> void:
	c.draw_set_transform(centro, 0, Vector2(1, 0.28))
	c.draw_circle(Vector2.ZERO, raio, Color(0.1, 0.05, 0.02, 0.35))
	c.draw_circle(Vector2.ZERO, raio * 0.6, Color(0.1, 0.05, 0.02, 0.25))
