class_name CaixaDialogo
extends Control
## Caixa de diálogo de baixo (estilo definido: texto surgindo letra a letra, sem vozes).
## Toque: completa a frase; toque de novo: próxima parte. Ao fim das partes emite "terminou".
## O sinal "bip" sai a cada letra nova, para os bips de diálogo quando o áudio entrar.

signal terminou
signal bip
signal parte(indice: int)     # cada parte nova (para a cena acompanhar o texto)

const LETRAS_POR_SEGUNDO := 40.0

var partes: Array = []
var falante := ""
var _i := 0
var _letras := 0.0
var _rotulo: Label
var _nome: Label
var _seta: Polygon2D
var _ativo := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var painel := Panel.new()
	painel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(painel)
	_nome = Label.new()
	_nome.position = Vector2(12, 6)
	_nome.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	_nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_nome)
	_rotulo = Label.new()
	_rotulo.position = Vector2(12, 26)
	_rotulo.size = Vector2(size.x - 24, size.y - 34)
	_rotulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# letra dos diálogos: a fonte de letras pequenas do jogo (FusionPixel 12), mais legível que a Pixelify
	for l in [_nome, _rotulo]:
		l.add_theme_font_override("font", Tema.fonte_pequena)
		l.add_theme_font_size_override("font_size", Tema.TAM_PEQUENO)
	add_child(_rotulo)
	_seta = Polygon2D.new()
	_seta.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0, 5)])
	_seta.color = Tema.COR_OURO_CLARO
	add_child(_seta)
	resized.connect(_ajustar)
	_ajustar()

func _ajustar() -> void:
	if _rotulo:
		_rotulo.size = Vector2(size.x - 24, size.y - 34)
		_seta.position = Vector2(size.x - 16, size.y - 12)

func mostrar(novas: Array, quem := "") -> void:
	partes = novas
	falante = quem
	_i = 0
	_ativo = true
	if not visible:
		visible = true
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	_comecar_parte()

func _comecar_parte() -> void:
	_nome.text = falante
	_rotulo.text = tr(partes[_i])
	_rotulo.visible_characters = 0
	_letras = 0.0
	_seta.visible = false
	parte.emit(_i)

func _process(delta: float) -> void:
	if not _ativo or _rotulo.visible_characters < 0:
		return
	var antes := int(_letras)
	_letras += delta * LETRAS_POR_SEGUNDO
	if int(_letras) > antes:
		bip.emit()
		if Jogo.som != null and _rotulo.visible_characters >= 0:
			Jogo.som.bip()           # bips do diálogo (DEFINIDO: sem vozes)
	if int(_letras) >= _rotulo.get_total_character_count():
		_rotulo.visible_characters = -1
		_seta.visible = true
	else:
		_rotulo.visible_characters = int(_letras)
	_seta.position.y = size.y - 12 + (2 if int(Time.get_ticks_msec() / 300) % 2 == 0 else 0)

func _gui_input(evento: InputEvent) -> void:
	if not _ativo:
		return
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _rotulo.visible_characters >= 0:
			_rotulo.visible_characters = -1      # completa a frase
			_seta.visible = true
			return
		_i += 1
		if _i >= partes.size():
			_ativo = false
			terminou.emit()
		else:
			_comecar_parte()
