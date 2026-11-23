class_name Janela
extends Control
## Popup padrão: fundo escurecido, painel centralizado que nunca passa da tela (largura fixa,
## textos com quebra de linha, rolagem se ficar alto demais) e entrada/saída suaves.
## botoes: [[chave_ou_texto, Callable], ...]. extras: Controls a mais, antes dos botões.

const LARGURA := 300.0
const MARGEM := 16.0

var titulo := ""
var texto := ""
var botoes: Array = []
var extras: Array = []
var destaque := true          # título dourado e grande
var painel: PanelContainer
var fechar_x := Callable()    # se tiver, aparece um X num círculo vermelho no canto de cima do painel
var _bt_x: Button

static func criar(t: String, b: Array, corpo := "", mais: Array = []) -> Janela:
	var j := Janela.new()
	j.titulo = t
	j.botoes = b
	j.texto = corpo
	j.extras = mais
	return j

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Tema.elevar(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vel := ColorRect.new()
	vel.color = Color(0, 0, 0, 0.55)
	vel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vel)
	painel = PanelContainer.new()
	painel.custom_minimum_size = Vector2(LARGURA, 0)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 10)
	var interno := LARGURA - 28.0
	if titulo != "":
		var t := Tema.rotulo(titulo, 24 if texto != "" or extras.size() > 0 else 16)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(interno, 0)
		if destaque and texto != "":
			t.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
		c.add_child(t)
	if texto != "":
		var corpo := Tema.rotulo(texto, 16)
		corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		corpo.custom_minimum_size = Vector2(interno, 0)
		c.add_child(corpo)
	for e in extras:
		c.add_child(e)
	# botões lado a lado só quando cabem; senão um embaixo do outro
	var soma := 0
	for par in botoes:
		soma += tr(str(par[0])).length()
	var linha: BoxContainer
	if botoes.size() <= 2 and soma <= 22:
		linha = HBoxContainer.new()
	else:
		linha = VBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	for par in botoes:
		var b := Button.new()
		b.text = par[0]
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(par[1])
		linha.add_child(b)
	if botoes.size() > 0:
		c.add_child(linha)
	painel.add_child(c)
	add_child(painel)
	if fechar_x.is_valid():
		_bt_x = Tema.botao_x()
		_bt_x.pressed.connect(fechar_x)
		_bt_x.modulate.a = 0.0
		add_child(_bt_x)
	painel.modulate.a = 0.0
	_encaixar.call_deferred()

## Depois da 1ª montagem: recalcula a altura, põe rolagem se precisar, centraliza e anima.
func _encaixar() -> void:
	await get_tree().process_frame
	if not is_instance_valid(painel):
		return
	var tela := size if size.y > 0.0 else get_viewport_rect().size
	painel.reset_size()
	var alto := tela.y - MARGEM * 4
	if painel.size.y > alto:
		var c: Control = painel.get_child(0)
		painel.remove_child(c)
		var rol := ScrollContainer.new()
		rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		rol.custom_minimum_size = Vector2(LARGURA - 24, alto - 32)
		rol.add_child(c)
		painel.add_child(rol)
		painel.reset_size()
	painel.size = Vector2(LARGURA, min(painel.size.y, alto))
	painel.position = ((tela - painel.size) / 2.0).floor()
	painel.pivot_offset = painel.size / 2.0
	painel.scale = Vector2(0.9, 0.9)
	var t := create_tween().set_parallel(true)
	t.set_ignore_time_scale(true)
	t.tween_property(painel, "modulate:a", 1.0, 0.18)
	t.tween_property(painel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Tema.manter_centrado(painel, alto, 0.0, _posicionar_x)
	if _bt_x:
		_posicionar_x()
		t.tween_property(_bt_x, "modulate:a", 1.0, 0.18).set_delay(0.12)
	Tema.ajustar_depois(self)

## O X fica preso no canto de cima, à direita, metade para fora do painel.
func _posicionar_x() -> void:
	if _bt_x and is_instance_valid(painel):
		_bt_x.position = painel.position + Vector2(painel.size.x - 26.0, -10.0)

## Fecha com um sumiço rápido.
func fechar() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)
