class_name TelaAnuncio
extends CanvasLayer
## Anúncio de teste em tela cheia: "vídeo" de 5 s com barra de progresso e depois "Receber prêmio".
## Fica numa camada própria (por cima de tudo, inclusive popups) e conta o tempo real, então funciona
## mesmo com o combate em câmera lenta. Antes os botões saíam da tela (âncora no centro + posição fixa).

var ao_fim: Callable
var _inicio := 0
var _rot: Label
var _barra: ProgressBar
var _receber: Button
var _feito := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_inicio = Time.get_ticks_msec()
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	raiz.theme = Tema.tema
	add_child(raiz)
	var fundo := ColorRect.new()
	fundo.color = Color("#05060a")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(fundo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(centro)
	var c := VBoxContainer.new()
	c.custom_minimum_size = Vector2(300, 0)
	c.add_theme_constant_override("separation", 12)
	centro.add_child(c)

	# versão ADM: "Anúncio de teste"; pública: espera do prêmio, sem a palavra teste (pedido do João, 2026-11-22)
	var t := Tema.rotulo("ANUNCIO_TESTE" if Jogo.adm() else "ANUNCIO_ESPERA", 24)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	c.add_child(t)
	# "tela do vídeo": quadro escuro com a contagem no meio
	var video := PanelContainer.new()
	video.custom_minimum_size = Vector2(300, 170)
	c.add_child(video)
	_rot = Tema.rotulo("", 32, true)
	_rot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	video.add_child(_rot)
	_barra = ProgressBar.new()
	_barra.show_percentage = false
	_barra.custom_minimum_size = Vector2(300, 8)
	_barra.max_value = Anuncios.DURACAO
	c.add_child(_barra)
	var d := Tema.rotulo("ANUNCIO_TESTE_DESC" if Jogo.adm() else "ANUNCIO_ESPERA_DESC", 12)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.custom_minimum_size = Vector2(300, 0)
	d.add_theme_color_override("font_color", Color("#a8acc0"))
	c.add_child(d)
	_receber = Button.new()
	_receber.text = "ANUNCIO_RECEBER"
	_receber.custom_minimum_size = Vector2(300, 44)
	Tema.estilo_botao(_receber, "confirmar")
	_receber.disabled = true
	_receber.pressed.connect(_terminar.bind(true))
	c.add_child(_receber)
	var cancelar := Button.new()
	cancelar.text = "CANCELAR"
	cancelar.custom_minimum_size = Vector2(300, 36)
	Tema.estilo_botao(cancelar, "secundario")
	cancelar.pressed.connect(_terminar.bind(false))
	c.add_child(cancelar)
	_mostrar()

func _process(_delta: float) -> void:
	_mostrar()

func _passado() -> float:
	return (Time.get_ticks_msec() - _inicio) / 1000.0

func _mostrar() -> void:
	var resta := maxf(Anuncios.DURACAO - _passado(), 0.0)
	var s := int(ceil(resta))
	_rot.text = str(s) if s > 0 else "OK"
	_barra.value = Anuncios.DURACAO - resta
	_receber.disabled = s > 0

func _terminar(ok: bool) -> void:
	if _feito:
		return
	_feito = true
	queue_free()
	if ao_fim.is_valid():
		ao_fim.call(ok)
