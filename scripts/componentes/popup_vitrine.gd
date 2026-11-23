class_name PopupVitrine
extends Control
## Base dos popups decorados do Início (o do ato e o da promoção): véu escuro, raios de luz girando na cor
## do tema, cartão com moldura dupla e cantos com losangos, X vermelho no canto e entrada com "pop".
## Quem herda só preenche o conteúdo em _montar(coluna) e pode trocar as cores antes de entrar na árvore.
## Uso: var p := PopupAto.new(); p.ato = 1; principal.add_child(p)

const LARGURA := 336.0

var cor_fundo := Color("#181a28")
var cor_acento := Tema.COR_OURO
var cor_claro := Tema.COR_OURO_CLARO
var cor_escuro := Color("#0e0f18")

var _cartao: PanelContainer
var _raios: Control
var _enfeites: Control
var _tempo := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Tema.elevar(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var veu := ColorRect.new()
	veu.color = Color(0.02, 0.02, 0.05, 0.78)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)
	_raios = Control.new()
	_raios.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raios.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raios.draw.connect(_desenhar_raios)
	add_child(_raios)

	_cartao = PanelContainer.new()
	_cartao.custom_minimum_size = Vector2(LARGURA, 0)
	_cartao.add_theme_stylebox_override("panel", _estilo_cartao())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_cartao.add_child(col)
	add_child(_cartao)
	_montar(col)

	# losangos nos cantos e brilhos, por cima do cartão
	_enfeites = Control.new()
	_enfeites.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_enfeites.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enfeites.draw.connect(_desenhar_enfeites)
	add_child(_enfeites)

	var x := Tema.botao_x()
	x.pressed.connect(fechar)
	add_child(x)
	# cartão sempre centrado (as telas de abas têm 584 de altura útil; o popup usa a tela toda)
	_cartao.resized.connect(func():
		var alto := get_viewport_rect().size.y
		_cartao.position = (Vector2(get_viewport_rect().size.x, alto) - _cartao.size) / 2.0
		_cartao.position = _cartao.position.floor()
		x.position = _cartao.position + Vector2(_cartao.size.x - 22, -10)
		_cartao.pivot_offset = _cartao.size / 2.0)
	# conteúdo trocado (carrossel, textos): o cartão volta ao tamanho mínimo em vez de ficar do maior já visto
	_cartao.minimum_size_changed.connect(func(): _cartao.reset_size.call_deferred())
	# entrada: o véu clareia e o cartão "salta"
	modulate.a = 0.0
	_cartao.scale = Vector2(0.86, 0.86)
	var t := create_tween().set_ignore_time_scale(true).set_parallel(true)
	t.tween_property(self, "modulate:a", 1.0, 0.18)
	t.tween_property(_cartao, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Preenchido por quem herda.
func _montar(_col: VBoxContainer) -> void:
	pass

func _estilo_cartao() -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = cor_fundo
	e.border_color = cor_acento
	e.set_border_width_all(2)
	e.set_corner_radius_all(4)
	e.shadow_color = Color(0, 0, 0, 0.5)
	e.shadow_size = 6
	e.content_margin_left = 8
	e.content_margin_right = 8
	e.content_margin_top = 8
	e.content_margin_bottom = 10
	return e

func fechar() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)

func _process(delta: float) -> void:
	_tempo += delta / maxf(Engine.time_scale, 0.01)
	_raios.queue_redraw()
	_enfeites.queue_redraw()

func _desenhar_raios() -> void:
	if _cartao == null:
		return
	var centro := _cartao.position + Vector2(LARGURA / 2.0, 70.0)
	for i in 16:
		var a := _tempo * 0.2 + i * TAU / 16.0
		_raios.draw_colored_polygon(PackedVector2Array([centro, centro + Vector2.from_angle(a - 0.06) * 560.0,
			centro + Vector2.from_angle(a + 0.06) * 560.0]), Color(cor_acento, 0.06))
	for k in 5:
		_raios.draw_circle(centro, 50.0 + k * 26.0, Color(cor_acento, 0.04))

## Moldura de dentro (filete claro), losangos nos 4 cantos e brilhos em cruz piscando.
func _desenhar_enfeites() -> void:
	if _cartao == null:
		return
	var r := Rect2(_cartao.position, _cartao.size * _cartao.scale)
	if _cartao.scale.x < 0.99:
		return
	_enfeites.draw_rect(r.grow(-4), Color(cor_acento, 0.35), false, 1.0)
	for c in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var p: Vector2 = c.round()
		_enfeites.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -6), p + Vector2(6, 0), p + Vector2(0, 6), p + Vector2(-6, 0)]), cor_escuro)
		_enfeites.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]), cor_acento)
		_enfeites.draw_rect(Rect2(p + Vector2(-1, -2), Vector2(1, 1)), cor_claro)
	var q := int(_tempo * 5.0)
	var pontos := [Vector2(30, -8), Vector2(LARGURA - 60, -6), Vector2(-8, 60), Vector2(LARGURA + 6, 120), Vector2(LARGURA / 2.0, -12)]
	for k in pontos.size():
		if (q + k) % 4 != 0:
			continue
		var p: Vector2 = r.position + pontos[k]
		_enfeites.draw_rect(Rect2(p + Vector2(-3, 0), Vector2(7, 1)), Color(cor_claro, 0.9))
		_enfeites.draw_rect(Rect2(p + Vector2(0, -3), Vector2(1, 7)), Color(cor_claro, 0.9))

# ------------------------------------------------------------ peças comuns para os conteúdos
## Faixa de seção: losango, título em caixa alta e fio que vai até o fim.
func secao(chave: String, direita := "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var marca := ColorRect.new()
	marca.color = cor_acento
	marca.custom_minimum_size = Vector2(4, 10)
	marca.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(marca)
	var t := Tema.rotulo(chave, 8, true)
	t.uppercase = true
	t.add_theme_color_override("font_color", cor_claro)
	h.add_child(t)
	var fio := ColorRect.new()
	fio.color = Color(cor_acento, 0.4)
	fio.custom_minimum_size = Vector2(0, 1)
	fio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(fio)
	if direita != "":
		var d := Tema.rotulo(direita, 8, true)
		d.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		d.add_theme_color_override("font_color", cor_claro)
		h.add_child(d)
	return h

## Barra fina com cor e brilho em cima.
func barra(fracao: float, cor: Color, altura := 8.0) -> Control:
	var b := Control.new()
	b.custom_minimum_size = Vector2(0, altura)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.draw.connect(func():
		var s := b.size
		b.draw_rect(Rect2(Vector2.ZERO, s), Color("#0a0b12"))
		b.draw_rect(Rect2(Vector2.ZERO, s), Color(cor_acento, 0.5), false, 1.0)
		var w := floorf((s.x - 2) * clampf(fracao, 0.0, 1.0))
		if w > 0:
			b.draw_rect(Rect2(1, 1, w, s.y - 2), cor)
			b.draw_rect(Rect2(1, 1, w, 1), cor.lightened(0.4)))
	return b

## Selo (pílula) com ícone opcional e texto em Silkscreen.
func selo(texto: String, cor_texto: Color, fundo: Color, borda: Color, icone: Texture2D = null) -> PanelContainer:
	var p := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = fundo
	e.border_color = borda
	e.set_border_width_all(1)
	e.set_corner_radius_all(3)
	e.content_margin_left = 6
	e.content_margin_right = 6
	e.content_margin_top = 2
	e.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", e)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	if icone:
		var ic := TextureRect.new()
		ic.texture = icone
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(ic)
	var r := Tema.rotulo(texto, 8, true)
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.add_theme_color_override("font_color", cor_texto)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(r)
	p.add_child(h)
	return p

## Texto corrido (Pixelify 12) quebrado na largura do cartão: uma linha por rótulo, cada uma centrada
## (a quebra automática do Godot deixava as linhas tortas).
func paragrafo(texto: String, cor: Color) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var linhas := Tema._quebrar(tr(texto), Tema.fonte_texto, 12, LARGURA - 32.0, 8)
	if linhas.is_empty():
		linhas = PackedStringArray([tr(texto)])
	for linha in linhas:
		var l := Tema.rotulo(linha.strip_edges(), 12)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_color_override("font_color", cor)
		v.add_child(l)
	return v
