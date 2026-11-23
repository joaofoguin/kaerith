class_name Tela
extends Control
## Base de todas as telas.

var principal  # cena principal (principal.gd)
## Telas montadas como um quadro fixo de 360×640 (cenas do Prólogo, chegada, criação): em celular mais
## alto a tela fica centrada na vertical e o resto vira faixa preta (escala inteira, sem distorcer o pixel art).
var palco_640 := false
const ALTURA_PALCO := 640.0

func _ready() -> void:
	montar()
	if palco_640:
		_montar_palco()
	Jogo.idioma_mudou.connect(_ao_mudar_idioma)
	Jogo.progresso_mudou.connect(atualizar_textos)
	Jogo.progresso_mudou.connect(_ajustar)
	Tema.ajustar_depois(self)

func montar() -> void:
	pass

## Passa tudo o que montar() criou para um quadro de 360×640 centrado (com corte nas bordas);
## a tela em si vira fundo preto do tamanho do aparelho.
var _palco: Control
func _montar_palco() -> void:
	_palco = Control.new()
	_palco.name = "Palco"
	_palco.clip_contents = true
	_palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palco.anchor_left = 0.0
	_palco.anchor_right = 1.0
	_palco.anchor_top = 0.5
	_palco.anchor_bottom = 0.5
	_palco.offset_top = -ALTURA_PALCO / 2.0
	_palco.offset_bottom = ALTURA_PALCO / 2.0
	var filhos := get_children()
	add_child(_palco)
	for f: Node in filhos:
		f.reparent(_palco, false)
	draw.connect(func(): draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK))
	queue_redraw()

## Textos fixos (por chave) se traduzem sozinhos; textos com número são refeitos aqui.
func atualizar_textos() -> void:
	pass

func _ao_mudar_idioma() -> void:
	atualizar_textos()
	Tema.ajustar_depois(self)

## Textos de botão que passariam da borda diminuem (Tema.caber_botao).
func _ajustar() -> void:
	Tema.ajustar_depois(self)
