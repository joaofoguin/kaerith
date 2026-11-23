extends Tela
## Prólogo (só na primeira entrada; pode pular). Texto do autor, "A Voz Entre os Ecos", sem mudar
## nenhuma palavra, dividido em partes na caixa de diálogo de baixo. Cada trecho tem a sua cena pintada:
## o silêncio do cosmos antigo → as eras que passaram → quem escuta → o aviso.

const PARTES := ["PROLOGO_1", "PROLOGO_2", "PROLOGO_3", "PROLOGO_4", "PROLOGO_5", "PROLOGO_6", "PROLOGO_7", "PROLOGO_8", "PROLOGO_9"]
const CENA_DA_PARTE := ["silencio", "silencio", "eras", "eras", "ouvinte", "ouvinte", "aviso", "aviso", "aviso"]

var palco: Control
var cena: CenaPintada
var titulo: Label
var brilho_titulo: Label
var caixa: CaixaDialogo
var veu: ColorRect
var efeitos: EfeitosPrologo
var saindo := false

func montar() -> void:
	add_to_group("som_historia")      # música da história (scripts/som.gd)
	palco_640 = true   # quadro fixo de 360×640 centrado (celulares altos ganham faixas pretas)
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	palco = Control.new()
	palco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(palco)
	efeitos = EfeitosPrologo.new()
	add_child(efeitos)
	add_child(sombra_de_baixo())

	brilho_titulo = Tema.rotulo("TITULO_JOGO", 24)
	brilho_titulo.add_theme_color_override("font_color", Color(0.75, 0.65, 1.0))
	brilho_titulo.add_theme_constant_override("outline_size", 8)
	brilho_titulo.add_theme_color_override("font_outline_color", Color(0.45, 0.3, 0.9, 0.5))
	titulo = Tema.rotulo("TITULO_JOGO", 24)
	titulo.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	titulo.add_theme_constant_override("outline_size", 2)
	titulo.add_theme_color_override("font_outline_color", Color("#3a2050"))
	for r in [brilho_titulo, titulo]:
		r.position = Vector2(0, 236)
		r.size = Vector2(360, 40)
		r.modulate.a = 0.0
		add_child(r)

	var pular := Button.new()
	pular.text = "PULAR"
	pular.position = Vector2(276, 8)
	pular.size = Vector2(76, 30)
	pular.modulate.a = 0.7
	pular.pressed.connect(_terminar)
	add_child(pular)
	caixa = CaixaDialogo.new()
	caixa.position = Vector2(8, 500)
	caixa.size = Vector2(344, 128)
	caixa.visible = false
	caixa.parte.connect(_na_parte)
	caixa.terminou.connect(_final)
	add_child(caixa)
	veu = ColorRect.new()
	veu.color = Color(1, 1, 1, 0)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)
	_trocar_cena("silencio", 3.0)
	_abertura()

## Escurece a parte de baixo para o texto ficar legível sobre a pintura.
static func sombra_de_baixo() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.75))
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.fill_from = Vector2(0, 0)
	tx.fill_to = Vector2(0, 1)
	tx.width = 4
	tx.height = 64
	var r := TextureRect.new()
	r.texture = tx
	r.position = Vector2(0, 400)
	r.size = Vector2(360, 240)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _abertura() -> void:
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_property(titulo, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(brilho_titulo, "modulate:a", 0.8, 1.8).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(titulo, "position:y", 226.0, 4.0).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(brilho_titulo, "position:y", 226.0, 4.0).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.8)
	t.tween_property(titulo, "modulate:a", 0.0, 1.4)
	t.parallel().tween_property(brilho_titulo, "modulate:a", 0.0, 1.4)
	t.tween_callback(func(): caixa.mostrar(PARTES, "???"))

func _na_parte(i: int) -> void:
	var nova: String = CENA_DA_PARTE[i]
	if cena and cena.nome != nova:
		_trocar_cena(nova, 1.8)
	efeitos.cena = cena
	efeitos.mostrar(i)
	if i == 2:
		_eras_passando()
	elif i == 6:
		_tremor()

## "Vi o mundo mudar": o céu das ruínas passa por dia, entardecer e noite várias vezes (o tempo correndo).
func _eras_passando() -> void:
	for camada in ["ceu", "longe"]:
		var no := cena.get_node_or_null(camada)
		if no == null:
			continue
		var t := create_tween()
		for c in [Color(1.3, 1.12, 0.9), Color(0.62, 0.58, 0.95), Color(1.2, 0.85, 0.72), Color(0.55, 0.55, 0.9), Color(1.25, 1.08, 0.95), Color.WHITE]:
			t.tween_property(no, "modulate", c, 0.9).set_trans(Tween.TRANS_SINE)

## "Mas tenha cuidado": um tremor curto na pintura.
func _tremor() -> void:
	var t := create_tween()
	for k in 6:
		t.tween_property(palco, "position", Vector2(4 if k % 2 == 0 else -4, 2 if k % 3 == 0 else -2), 0.05)
	t.tween_property(palco, "position", Vector2.ZERO, 0.08)

## Troca de cena com dissolução: a nova surge por cima e a antiga some depois.
func _trocar_cena(nome: String, tempo: float) -> void:
	var antiga := cena
	cena = CenaPintada.new(nome)
	cena.duracao = 22.0
	cena.modulate.a = 0.0
	palco.add_child(cena)
	var t := create_tween()
	t.tween_property(cena, "modulate:a", 1.0, tempo).set_trans(Tween.TRANS_SINE)
	if antiga:
		t.tween_callback(antiga.queue_free)

## Fim do texto: a luz cresce até branco e a criação começa.
func _final() -> void:
	if saindo:
		return
	saindo = true
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(veu, "color:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_terminar)

func _terminar() -> void:
	if Jogo.dados["etapa"] != "prologo":
		return
	Jogo.dados["etapa"] = "login"       # tela de entrada: Google ou visitante
	Jogo.salvar()
	principal.seguir_criacao()
