class_name BarraAbas
extends Control
## Fileira de abas com ícone em cima e nome embaixo (Diário, Inventário, Ranking).
## Tudo que é medida fica aqui: as abas dividem a largura por igual, com um vão fixo entre elas,
## e o botão não tem texto próprio (o ícone e o nome são filhos), então uma palavra comprida
## nunca estica a aba por cima da vizinha.
##
## Uso:
##   var barra := BarraAbas.criar([["CHAVE_TEXTO", "res://icone.png"], ...], 348)
##   barra.position = Vector2(6, 52)
##   barra.trocou.connect(_trocar_aba)      # toque do jogador
##   barra.marcar(0)                        # só muda o visual, sem avisar

signal trocou(indice: int)

const VAO := 4.0                      # espaço entre as abas
const COR_APAGADA := Color("#d4d8e4")

var escolhida := -1
var _botoes: Array[Button] = []
var _rotulos: Array[Label] = []
var _icones: Array[TextureRect] = []

static func criar(itens: Array, largura: float, altura := 40.0) -> BarraAbas:
	var barra := BarraAbas.new()
	barra.size = Vector2(largura, altura)
	barra.custom_minimum_size = barra.size
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := itens.size()
	var w := floorf((largura - VAO * (n - 1)) / n)
	for i in n:
		barra._nova_aba(i, itens[i][0], itens[i][1], Vector2(i * (w + VAO), 0), Vector2(w, altura))
	return barra

func _nova_aba(i: int, chave: String, icone: String, pos: Vector2, tam: Vector2) -> void:
	var b := Button.new()
	b.position = pos
	b.pressed.connect(_tocou.bind(i))
	add_child(b)
	var partes := vestir(b, chave, icone, tam)
	_botoes.append(b)
	_icones.append(partes[0])
	_rotulos.append(partes[1])

## Transforma um botão comum num botão "ícone em cima, nome embaixo" de tamanho fixo `tam`.
## Serve também fora da barra (ex.: o botão Ficha do Inventário). Devolve [ícone, rótulo].
static func vestir(b: Button, chave: String, icone: String, tam: Vector2) -> Array:
	b.text = ""                       # sem texto próprio: o botão não cresce com a palavra
	b.icon = null
	b.custom_minimum_size = tam
	b.size = tam
	var alto_texto := ceilf(Tema.altura_texto(8))
	var ic := TextureRect.new()
	ic.texture = load(icone)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.position = Vector2(0, 3)
	ic.size = Vector2(tam.x, tam.y - alto_texto - 15)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var r := Label.new()
	r.text = chave
	r.add_theme_font_override("font", Tema.fonte_numeros)
	r.add_theme_font_size_override("font_size", 8)
	r.add_theme_color_override("font_color", COR_APAGADA)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.clip_text = true
	r.position = Vector2(3, tam.y - alto_texto - 12)     # o texto desce uns 3 px além da caixa: fica acima da sombra do botão
	r.size = Vector2(tam.x - 6, alto_texto)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(r)
	return [ic, r]

## Bolinha vermelha com "!" no canto da aba `i` (tem novidade lá dentro). Pedido do João: o jogador vê
## em qual aba está a novidade, não só que o Diário tem alguma.
func alerta(i: int, ligado: bool) -> void:
	if i < 0 or i >= _botoes.size():
		return
	var b := _botoes[i]
	var s: Control = b.get_node_or_null("alerta")
	if s == null:
		if not ligado:
			return
		s = Panel.new()
		s.name = "alerta"
		var e := StyleBoxFlat.new()
		e.bg_color = Color("#d8394a")
		e.border_color = Color("#4a0c18")
		e.set_border_width_all(1)
		e.set_corner_radius_all(6)
		s.add_theme_stylebox_override("panel", e)
		s.size = Vector2(12, 12)
		s.position = Vector2(b.size.x - 14, 2)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.text = "!"
		l.add_theme_font_override("font", Tema.fonte_numeros)
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		s.add_child(l)
		b.add_child(s)
	s.visible = ligado

func _tocou(i: int) -> void:
	marcar(i)
	trocou.emit(i)

## Destaca a aba `i` (dourada, ícone aceso); as outras ficam azuis com o ícone mais apagado.
func marcar(i: int) -> void:
	escolhida = i
	for k in _botoes.size():
		var ativa := k == i
		Tema.estilo_botao(_botoes[k], "primario" if ativa else "secundario")
		_rotulos[k].add_theme_color_override("font_color", Tema.COR_TEXTO_ESCURO if ativa else COR_APAGADA)
		_icones[k].modulate = Color.WHITE if ativa else Color(1, 1, 1, 0.8)
