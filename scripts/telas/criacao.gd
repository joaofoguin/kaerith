extends Tela
## Criação do personagem (DEFINIDO): nome + sexo, pele, cabelo, barba e cor dos pelos. Sem origem narrativa.
## As opções são as camadas aprovadas do herói v5. Visual: noite com aurora ao fundo, herói num pedestal
## de luz (falso 3D, com partículas em órbita), nome num campo escuro legível e as opções num painel.

const OPCOES := {
	"corpo": [1, 2],
	"pele": [1, 2, 3, 4, 5],
	"cabelo": ["curto", "longo", "preso"],
	"barba": ["", "curta", "cheia"],
	"pelos": ["Castanho", "Castanho-escuro", "Preto", "Loiro", "Ruivo", "Grisalho", "Platinado"],
}
const ROTULOS := {"corpo": "CRI_SEXO", "pele": "CRI_PELE", "cabelo": "CRI_CABELO", "barba": "CRI_BARBA", "pelos": "CRI_PELOS"}
const COR_PELOS := {"Castanho": Color("#7a4a2a"), "Castanho-escuro": Color("#43291a"), "Preto": Color("#1e1c22"),
	"Loiro": Color("#e0bc62"), "Ruivo": Color("#b4502c"), "Grisalho": Color("#a2a2aa"), "Platinado": Color("#ece8dc")}
const PEDESTAL := Vector2(180, 262)

var visual := {}
var previa: HeroiFrente
var valores := {}
var rotulos := {}            # chave → Label do nome da linha (Corpo, Pele...)
## Larguras fixas das linhas de opção: nada muda de tamanho ao trocar a escolha.
const L_ROTULO := 100.0
const L_SETA := 40.0
const L_VALOR := 110.0       # caixa escura do valor (100+40+110+40+3×6 = 308, a largura útil do painel)
var amostra: ColorRect
var nome: LineEdit
var comecar: Button
var tras: Control
var frente: Control
var tempo := 0.0

func montar() -> void:
	palco_640 = true   # quadro fixo de 360×640 centrado (celulares altos ganham faixas pretas)
	visual = Jogo.dados["visual"].duplicate()
	visual["corpo"] = int(visual["corpo"])        # o save em JSON devolve números como float
	visual["pele"] = int(visual["pele"])
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var cena := CenaPintada.new("ouvinte")
	cena.duracao = 40.0
	cena.modulate = Color(0.75, 0.75, 0.85, 1.0)
	add_child(cena)
	var sombra := ColorRect.new()
	sombra.color = Color(0.02, 0.02, 0.06, 0.45)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sombra)

	var titulo := Tema.rotulo("CRI_TITULO", 24)
	titulo.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	titulo.add_theme_constant_override("outline_size", 4)
	titulo.add_theme_color_override("font_outline_color", Color("#1a1030"))
	titulo.position = Vector2(0, 14)
	titulo.size = Vector2(360, 32)
	add_child(titulo)
	var fio := ColorRect.new()
	fio.color = Color(Tema.COR_OURO, 0.5)
	fio.position = Vector2(120, 48)
	fio.size = Vector2(120, 2)
	add_child(fio)

	# pedestal de luz: a parte de trás e a da frente ficam em camadas separadas (falso 3D)
	tras = Control.new()
	tras.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tras.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tras.draw.connect(_desenhar_tras)
	add_child(tras)
	previa = HeroiFrente.new()
	previa.escala = 3
	previa.size = Vector2(144, 192)
	previa.position = PEDESTAL - Vector2(72, 186)
	previa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(previa)
	frente = Control.new()
	frente.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frente.draw.connect(_desenhar_frente)
	add_child(frente)

	nome = LineEdit.new()
	nome.placeholder_text = "CRI_NOME"
	nome.max_length = 12
	nome.alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.text = str(Jogo.dados.get("nome", ""))
	nome.position = Vector2(60, 292)
	nome.size = Vector2(240, 40)
	nome.add_theme_font_size_override("font_size", 24)
	nome.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	nome.add_theme_color_override("font_placeholder_color", Color(0.6, 0.62, 0.72, 0.8))
	nome.add_theme_color_override("caret_color", Tema.COR_OURO_CLARO)
	nome.add_theme_color_override("selection_color", Color(0.9, 0.7, 0.2, 0.35))
	nome.add_theme_stylebox_override("normal", _campo(Color("#545a74")))
	nome.add_theme_stylebox_override("focus", _campo(Tema.COR_OURO))
	nome.text_changed.connect(_nome_mudou)
	if Plataforma.web() and Plataforma.celular():
		# no navegador do celular o teclado não abre para o campo do Godot: o toque pede o nome numa caixa do navegador
		nome.focus_mode = Control.FOCUS_NONE
		nome.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		nome.gui_input.connect(_toque_nome_web)
	add_child(nome)

	var painel := PanelContainer.new()
	painel.position = Vector2(16, 344)
	painel.size = Vector2(328, 0)
	painel.custom_minimum_size = Vector2(328, 0)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 4)
	painel.add_child(lista)
	for chave in ["corpo", "pele", "cabelo", "barba", "pelos"]:
		lista.add_child(_linha(chave))
	add_child(painel)

	comecar = Button.new()
	comecar.text = "CRI_COMECAR"
	comecar.position = Vector2(60, 576)
	comecar.size = Vector2(240, 48)
	comecar.add_theme_font_size_override("font_size", 24)
	comecar.pressed.connect(_confirmar)
	add_child(comecar)
	_atualizar()

## Campo escuro com borda (o texto claro fica legível; a borda acende em dourado ao digitar).
func _campo(borda: Color) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = Color("#0c0d16")
	c.border_color = borda
	c.set_border_width_all(2)
	c.set_corner_radius_all(2)
	c.content_margin_left = 8
	c.content_margin_right = 8
	return c

func _linha(chave: String) -> Control:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	var r := Tema.rotulo(ROTULOS[chave], 16)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	r.add_theme_color_override("font_color", Color("#c8ccd8"))
	r.custom_minimum_size = Vector2(L_ROTULO, 38)
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(r)
	rotulos[chave] = r
	var menos := Button.new()
	menos.text = "<"
	menos.custom_minimum_size = Vector2(L_SETA, 38)
	menos.pressed.connect(_trocar.bind(chave, -1))
	linha.add_child(menos)
	var caixa := PanelContainer.new()
	caixa.custom_minimum_size = Vector2(L_VALOR, 38)
	caixa.clip_contents = true
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color("#0c0d16")
	estilo.content_margin_left = 4
	estilo.content_margin_right = 4
	caixa.add_theme_stylebox_override("panel", estilo)
	var dentro := HBoxContainer.new()
	dentro.alignment = BoxContainer.ALIGNMENT_CENTER
	dentro.add_theme_constant_override("separation", 2)
	if chave == "pelos":
		amostra = ColorRect.new()
		amostra.custom_minimum_size = Vector2(10, 10)
		amostra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dentro.add_child(amostra)
	var v := Tema.rotulo("", 16)
	v.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(L_VALOR - 8.0 - (12.0 if chave == "pelos" else 0.0), 34)
	dentro.add_child(v)
	caixa.add_child(dentro)
	linha.add_child(caixa)
	valores[chave] = v
	var mais := Button.new()
	mais.text = ">"
	mais.custom_minimum_size = Vector2(L_SETA, 38)
	mais.pressed.connect(_trocar.bind(chave, 1))
	linha.add_child(mais)
	return linha

func _process(delta: float) -> void:
	tempo += delta
	tras.queue_redraw()
	frente.queue_redraw()

## Pedestal: halo, topo claro em elipse, lateral escura e as partículas de trás (menores e apagadas).
func _desenhar_tras() -> void:
	var p := PEDESTAL
	var pulso := 0.5 + 0.5 * sin(tempo * 2.0)
	tras.draw_set_transform(p, 0, Vector2(1, 0.3))
	for i in 5:
		tras.draw_circle(Vector2.ZERO, 70.0 + i * 10.0 + pulso * 4.0, Color(0.55, 0.75, 1.0, 0.04))
	tras.draw_set_transform(p + Vector2(0, 8), 0, Vector2(1, 0.3))
	tras.draw_circle(Vector2.ZERO, 62.0, Color("#141a2c"))
	tras.draw_set_transform(p, 0, Vector2(1, 0.3))
	tras.draw_circle(Vector2.ZERO, 62.0, Color("#2a3450"))
	tras.draw_circle(Vector2.ZERO, 54.0, Color("#3c4a6a"))
	tras.draw_arc(Vector2.ZERO, 58.0, 0, TAU, 48, Color(0.7, 0.85, 1.0, 0.35 + 0.3 * pulso), 2.0)
	tras.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	_particulas(tras, false)

func _desenhar_frente() -> void:
	_particulas(frente, true)

func _particulas(alvo: Control, na_frente: bool) -> void:
	for i in 14:
		var a := tempo * 0.6 + i * TAU / 14.0
		var z := sin(a)
		if (z > 0) != na_frente:
			continue
		var pos := PEDESTAL + Vector2(cos(a) * 74.0, -30.0 - 50.0 * fposmod(i * 0.37 + tempo * 0.05, 1.0) + z * 18.0)
		var t := 2.0 if na_frente else 1.0
		var c := Color(0.7, 0.9, 1.0, 0.85 if na_frente else 0.35)
		alvo.draw_rect(Rect2(pos.floor(), Vector2(t * 2, t * 2)), c)

func _nome_mudou(_t: String) -> void:
	_atualizar()

## Web no celular: abre a caixa de texto do próprio navegador, que sempre mostra o teclado.
func _toque_nome_web(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	nome.accept_event()
	if ev.pressed:
		return
	var pergunta := JSON.stringify(tr("CRI_NOME"))
	var atual := JSON.stringify(nome.text)
	var r = JavaScriptBridge.eval("window.prompt(%s, %s)" % [pergunta, atual], true)
	if r is String:                  # null = o jogador cancelou
		nome.text = (r as String).strip_edges().left(nome.max_length)
		_nome_mudou(nome.text)

func _trocar(chave: String, passo: int) -> void:
	var lista: Array = OPCOES[chave]
	var i := lista.find(visual[chave])
	if i < 0:
		i = 0
	visual[chave] = lista[posmod(i + passo, lista.size())]
	_atualizar()
	# pulinho do herói a cada troca
	var tw := create_tween()
	tw.tween_property(previa, "position:y", PEDESTAL.y - 190.0, 0.08)
	tw.tween_property(previa, "position:y", PEDESTAL.y - 186.0, 0.12)

func _texto(chave: String) -> String:
	var v = visual[chave]
	match chave:
		"corpo":
			return tr("CRI_CORPO_%d" % int(v))
		"pele":
			return tr("CRI_TOM") % int(v)
		"barba":
			return tr("CRI_SEM_BARBA") if str(v) == "" else tr("CRI_BARBA_" + str(v).to_upper())
		"cabelo":
			return tr("CRI_CABELO_" + str(v).to_upper())
		_:
			return tr("COR_" + str(v).to_upper().replace("-", "_"))

func _atualizar() -> void:
	for chave in valores:
		var v: Label = valores[chave]
		v.text = _texto(chave)
		Tema.caber(v, v.custom_minimum_size.x, 34.0, 2, [16, 14, 12, 10])    # nomes longos cabem no quadro
		var r: Label = rotulos[chave]
		r.text = ROTULOS[chave]
		Tema.caber(r, L_ROTULO, 38.0, 2, [16, 14, 12])
	if amostra:
		amostra.color = COR_PELOS.get(str(visual["pelos"]), Color.WHITE)
	var guardado: Dictionary = Jogo.dados["visual"]
	Jogo.dados["visual"] = visual
	previa.vestir(Jogo.camadas_heroi(""))
	Jogo.dados["visual"] = guardado
	comecar.disabled = nome.text.strip_edges() == ""

func atualizar_textos() -> void:
	_atualizar()

func _confirmar() -> void:
	Jogo.dados["visual"] = visual
	Jogo.dados["nome"] = nome.text.strip_edges()
	Jogo.dados["etapa"] = "chegada"
	Jogo.salvar()
	principal.seguir_criacao()
