class_name PopupResultado
extends Control
## Popup de resultado no estilo aprovado do kit (v18 · popup_vitoria): faixa vinho grande com o título,
## brilhos que piscam, raios de luz girando atrás, "FASE n · ATO n", linhas de recompensa com ícone que
## entram uma a uma contando o valor, barra de XP que enche e os botões no fim.
## Tipos: "vitoria", "derrota", "intro" (fim da introdução) e "presente" (boas-vindas do Início).
## Nunca passa da tela: largura fixa de 320 e rolagem se ficar alto demais.

const LARGURA := 320.0
const OURO := Color("#ffd66b")
const PRATA := Color("#c8ccd8")

var tipo := "vitoria"
var titulo := ""
var subtitulo := ""
var secao := "RES_RECOMPENSAS"
var texto := ""
## cada linha: {"icone": Texture2D, "nome": String, "valor": int, "pre": "+"} ou {"icone", "nome", "texto": String}
var linhas: Array = []
## barra de XP: {"nivel": int, "de": float, "para": float, "subiu": int}
var xp: Dictionary = {}
## botões: [[chave, Callable, "primario" ou "secundario"], ...]
var botoes: Array = []

var _painel: PanelContainer
var _faixa: TextureRect
var _titulo: Label
var _raios: Control
var _brilhos: Control
var _tempo := 0.0
var _linhas_ui: Array = []          # [linha, ícone, rótulo do valor, dados]
var _barra: Control
var _barra_frac := 0.0
var _rot_pct: Label
var _rot_nv: Label
var _linha_botoes: BoxContainer
var _motes: Array = []              # partículas douradas subindo (vitória/presente)
var _rng := RandomNumberGenerator.new()

static func icone(nome: String) -> Texture2D:
	return load("res://artes/resultado/icone24_%s.png" % nome)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Tema.elevar(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	if Jogo.som != null:                 # vinheta da luta ou som de prêmio (2026-11-23)
		match tipo:
			"vitoria":
				Jogo.som.vinheta("vitoria")
			"derrota":
				Jogo.som.vinheta("derrota")
			_:
				Jogo.som.efeito("moeda")
	var veu := ColorRect.new()
	veu.color = Color(0.02, 0.02, 0.05, 0.72)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veu)
	veu.modulate.a = 0.0
	var tv := create_tween().set_ignore_time_scale(true)
	tv.tween_property(veu, "modulate:a", 1.0, 0.25)

	_raios = Control.new()
	_raios.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raios.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raios.draw.connect(_desenhar_raios)
	_raios.modulate.a = 0.0
	add_child(_raios)

	_painel = PanelContainer.new()
	_painel.custom_minimum_size = Vector2(LARGURA, 0)
	var margem := MarginContainer.new()
	margem.add_theme_constant_override("margin_top", 26)      # espaço da faixa do título
	margem.add_theme_constant_override("margin_left", 4)
	margem.add_theme_constant_override("margin_right", 4)
	margem.add_theme_constant_override("margin_bottom", 2)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 6)
	margem.add_child(c)
	_painel.add_child(margem)
	add_child(_painel)
	_montar_conteudo(c)

	_faixa = TextureRect.new()
	_faixa.texture = load("res://artes/resultado/faixa_titulo.png")
	_faixa.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_faixa.stretch_mode = TextureRect.STRETCH_SCALE
	_faixa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_faixa.size = Vector2(340, 44)
	_faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tipo == "derrota":
		_faixa.modulate = Color(0.62, 0.62, 0.7)
	add_child(_faixa)
	_titulo = Label.new()
	_titulo.text = titulo
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_titulo.size = Vector2(300, 40)
	_titulo.position = Vector2(20, 1)
	_titulo.add_theme_font_size_override("font_size", 24)
	_titulo.add_theme_color_override("font_color", Color("#fff4dc") if tipo != "derrota" else PRATA)
	_titulo.add_theme_constant_override("outline_size", 4)
	_titulo.add_theme_color_override("font_outline_color", Color("#3a1020"))
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titulo.pivot_offset = Vector2(150, 20)
	_faixa.add_child(_titulo)
	Tema.caber(_titulo, 288.0, 40.0, 1, [24, 16])

	_brilhos = Control.new()
	_brilhos.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_brilhos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brilhos.draw.connect(_desenhar_brilhos)
	add_child(_brilhos)

	_painel.modulate.a = 0.0
	_faixa.modulate.a = 0.0
	_animar.call_deferred()

func _montar_conteudo(c: VBoxContainer) -> void:
	if subtitulo != "":
		var s := Tema.rotulo(subtitulo, 8, true)
		s.add_theme_color_override("font_color", Color("#9a9fb8"))
		c.add_child(s)
	if texto != "":
		var t := Tema.rotulo(texto, 16)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(LARGURA - 36, 0)
		t.add_theme_color_override("font_color", Color("#e6e6f0"))
		c.add_child(t)
	if not linhas.is_empty():
		var sec := Tema.rotulo(secao, 16)
		sec.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		sec.add_theme_color_override("font_color", PRATA)
		c.add_child(sec)
		for d in linhas:
			c.add_child(_linha(d))
	if not xp.is_empty():
		var caixa := Control.new()
		caixa.custom_minimum_size = Vector2(LARGURA - 36, 26)
		_barra = Control.new()
		_barra.position = Vector2(0, 2)
		_barra.size = Vector2(LARGURA - 36, 10)
		_barra.draw.connect(_desenhar_barra)
		caixa.add_child(_barra)
		_rot_nv = Tema.rotulo(tr("RES_NV") % int(xp["nivel"]), 8, true)
		_rot_nv.position = Vector2(0, 14)
		_rot_nv.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_rot_nv.add_theme_color_override("font_color", OURO)
		caixa.add_child(_rot_nv)
		_rot_pct = Tema.rotulo("0%", 8, true)
		_rot_pct.position = Vector2(LARGURA - 96, 14)
		_rot_pct.size = Vector2(60, 10)
		_rot_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_rot_pct.add_theme_color_override("font_color", Color("#9a9fb8"))
		caixa.add_child(_rot_pct)
		_barra_frac = float(xp["de"])
		c.add_child(caixa)
	# botões lado a lado quando cabem; senão um embaixo do outro. Um botão só de ícone (a casinha
	# do Início) sempre fica na mesma linha do botão seguinte, como nos jogos de celular.
	var soma := 0
	for par in botoes:
		soma += tr(str(par[0])).length()
	var com_texto := botoes.filter(func(p): return str(p[0]) != "").size()
	if com_texto <= 2 and soma <= 22:
		_linha_botoes = HBoxContainer.new()
	else:
		_linha_botoes = VBoxContainer.new()
	_linha_botoes.add_theme_constant_override("separation", 8)
	var par_do_icone: HBoxContainer = null
	for par in botoes:
		var b := _botao(par)
		if par_do_icone:
			par_do_icone.add_child(b)
			par_do_icone = null
		elif _linha_botoes is VBoxContainer and _so_icone(par):
			par_do_icone = HBoxContainer.new()
			par_do_icone.add_theme_constant_override("separation", 8)
			par_do_icone.add_child(b)
			_linha_botoes.add_child(par_do_icone)
		else:
			_linha_botoes.add_child(b)
	_linha_botoes.modulate.a = 0.0
	if not botoes.is_empty():
		var folga := Control.new()
		folga.custom_minimum_size = Vector2(0, 2)
		c.add_child(folga)
		c.add_child(_linha_botoes)

func _so_icone(par: Array) -> bool:
	return par.size() > 3 and str(par[0]) == ""

## Um botão do resultado: [texto, ação, estilo ("primario", "secundario", "video"...), ícone opcional].
func _botao(par: Array) -> Button:
	var b := Button.new()
	b.text = par[0]
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	if _so_icone(par):
		b.custom_minimum_size = Vector2(52, 44)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var ic := TextureRect.new()
		ic.texture = load(str(par[3]))
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		ic.offset_bottom = -3                      # centro da face do botão, acima da sombra
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
	var estilo: String = par[2] if par.size() > 2 else "primario"
	if estilo == "secundario":
		for est in ["normal", "hover", "disabled"]:
			b.add_theme_stylebox_override(est, Tema.caixa_9fatias("botao_secundario_normal_9fatias_borda6.png", 6))
		b.add_theme_stylebox_override("pressed", Tema.caixa_9fatias("botao_secundario_pressionado_9fatias_borda6.png", 6))
	elif estilo == "video":
		# "Continuar com vídeo" chamativo (DEFINIDO): verde, ícone de vídeo e brilho pulsando
		Tema.estilo_botao(b, "confirmar")
		b.custom_minimum_size = Vector2(0, 50)
		b.add_theme_font_size_override("font_size", 16)
		var tw := b.create_tween().set_loops().set_ignore_time_scale(true)
		tw.tween_property(b, "modulate", Color(1.35, 1.35, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_SINE)
	elif estilo != "primario":
		Tema.estilo_botao(b, estilo)
	Tema.cor_texto_botao(b, "confirmar" if estilo == "video" else estilo)
	b.pressed.connect(_apertou.bind(par[1]))
	return b

func _linha(d: Dictionary) -> Control:
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 3)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var ic := TextureRect.new()
	ic.texture = d["icone"]
	ic.custom_minimum_size = Vector2(24, 24)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.pivot_offset = Vector2(12, 12)
	h.add_child(ic)
	var n := Tema.rotulo(str(d["nome"]), 16)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	h.add_child(n)
	var v := Tema.rotulo(str(d.get("texto", "")), 16, not d.has("texto"))
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_color_override("font_color", OURO)
	v.add_theme_constant_override("outline_size", 4)
	v.add_theme_color_override("font_outline_color", Color("#12131c"))
	if d.has("valor"):
		v.text = "%s0" % str(d.get("pre", "+"))
	h.add_child(v)
	caixa.add_child(h)
	var fio := ColorRect.new()
	fio.color = Color("#2e3248")
	fio.custom_minimum_size = Vector2(0, 1)
	caixa.add_child(fio)
	caixa.modulate.a = 0.0
	_linhas_ui.append([caixa, ic, v, d])
	return caixa

## Encaixa na tela (rolagem se precisar) e toca a entrada em sequência.
func _animar() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_painel):
		return
	var tela := size if size.y > 0.0 else get_viewport_rect().size
	_painel.reset_size()
	var alto := tela.y - 80.0
	if _painel.size.y > alto:
		var m: Control = _painel.get_child(0)
		_painel.remove_child(m)
		var rol := ScrollContainer.new()
		rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		rol.custom_minimum_size = Vector2(LARGURA - 20, alto - 20)
		rol.add_child(m)
		_painel.add_child(rol)
		_painel.reset_size()
	_painel.size = Vector2(LARGURA, minf(_painel.size.y, alto))
	_painel.position = Vector2(floorf((tela.x - LARGURA) / 2.0), floorf((tela.y - _painel.size.y) / 2.0) + 10.0)
	_painel.pivot_offset = _painel.size / 2.0
	_faixa.position = Vector2(floorf((tela.x - 340.0) / 2.0), _painel.position.y - 22.0)
	_faixa.pivot_offset = Vector2(170, 22)
	Tema.manter_centrado(_painel, alto, 10.0, func():
		_faixa.position = Vector2(floorf((tela.x - 340.0) / 2.0), _painel.position.y - 22.0))
	Tema.ajustar_depois(self)
	if tipo != "derrota":
		for i in 26:
			_motes.append(_novo_mote(true))

	# 1) painel sobe e cresce; 2) a faixa cai com quique; 3) o título pulsa
	_painel.scale = Vector2(0.85, 0.85)
	var t := create_tween().set_parallel(true).set_ignore_time_scale(true)
	t.tween_property(_painel, "modulate:a", 1.0, 0.2)
	t.tween_property(_painel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_raios, "modulate:a", 1.0 if tipo != "derrota" else 0.0, 0.6)
	await t.finished
	_faixa.scale = Vector2(1.25, 1.25)
	var f := create_tween().set_parallel(true).set_ignore_time_scale(true)
	f.tween_property(_faixa, "modulate:a", 1.0, 0.12)
	f.tween_property(_faixa, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await f.finished
	if tipo != "derrota":
		Input.vibrate_handheld(30)
	# 4) linhas de recompensa, uma a uma, contando o valor
	for item in _linhas_ui:
		var linha: Control = item[0]
		var ic: TextureRect = item[1]
		var v: Label = item[2]
		var d: Dictionary = item[3]
		ic.scale = Vector2(0.2, 0.2)
		var l := create_tween().set_parallel(true).set_ignore_time_scale(true)
		l.tween_property(linha, "modulate:a", 1.0, 0.15)
		l.tween_property(ic, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if d.has("valor"):
			l.tween_method(_contar.bind(v, str(d.get("pre", "+"))), 0.0, float(d["valor"]), 0.45)
		await _pausa(0.22)
	# 5) barra de XP enche (e dá a volta se subiu de nível)
	if _barra:
		var subiu := int(xp.get("subiu", 0))
		var x := create_tween().set_ignore_time_scale(true)
		if subiu > 0:
			x.tween_method(_encher, _barra_frac, 1.0, 0.45)
			x.tween_callback(_subiu_nivel)
			x.tween_method(_encher, 0.0, float(xp["para"]), 0.4)
		else:
			x.tween_method(_encher, _barra_frac, float(xp["para"]), 0.55)
		await _pausa(0.3)
	var b := create_tween().set_ignore_time_scale(true)
	b.tween_property(_linha_botoes, "modulate:a", 1.0, 0.2)

func _pausa(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _contar(valor: float, rotulo: Label, pre: String) -> void:
	rotulo.text = "%s%d" % [pre, int(round(valor))]

func _encher(f: float) -> void:
	_barra_frac = f
	if _rot_pct:
		_rot_pct.text = "%d%%" % int(floor(f * 100.0 + 0.0001))      # arredonda para baixo: 99,6% não mostra 100%
	_barra.queue_redraw()

func _subiu_nivel() -> void:
	if Jogo.som != null:
		Jogo.som.efeito("nivel")
	_rot_nv.text = tr("RES_NV") % int(xp["nivel"]) + "  " + tr("RES_SUBIU")
	var t := create_tween().set_ignore_time_scale(true)
	_rot_nv.modulate = Color(2, 2, 1.4)
	t.tween_property(_rot_nv, "modulate", Color.WHITE, 0.5)

func _apertou(acao: Callable) -> void:
	if _linha_botoes.modulate.a < 0.5:
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)
	acao.call()

## Para o combate continuar usando o mesmo nome do popup antigo.
func fechar() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(self, "modulate:a", 0.0, 0.15)
	t.tween_callback(queue_free)

func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.01)
	_tempo += real
	for m in _motes:
		m[0] += m[1] * real
		if m[0].y < -6:
			var n := _novo_mote(false)
			m[0] = n[0]
			m[1] = n[1]
	_raios.queue_redraw()
	_brilhos.queue_redraw()

func _novo_mote(espalhar: bool) -> Array:
	var p := Vector2(_rng.randf_range(10, 350), _rng.randf_range(80, 660) if espalhar else 650.0)
	return [p, Vector2(_rng.randf_range(-5, 5), -_rng.randf_range(18, 42)), _rng.randf() * TAU]

## Raios de luz dourados girando devagar atrás do painel, com um halo no centro.
func _desenhar_raios() -> void:
	if _painel == null:
		return
	var centro := _painel.position + Vector2(LARGURA / 2.0, 30.0)
	var cor := Color(1.0, 0.82, 0.4) if tipo != "intro" else Color(0.6, 0.85, 1.0)
	for i in 14:
		var a := _tempo * 0.25 + i * TAU / 14.0
		var p1 := centro + Vector2.from_angle(a - 0.07) * 520.0
		var p2 := centro + Vector2.from_angle(a + 0.07) * 520.0
		_raios.draw_colored_polygon(PackedVector2Array([centro, p1, p2]), Color(cor, 0.07))
	for k in 5:
		_raios.draw_circle(centro, 40.0 + k * 22.0, Color(cor, 0.05))

## Brilhos em cruz que piscam em volta da faixa e partículas douradas subindo.
func _desenhar_brilhos() -> void:
	if _faixa == null or _faixa.modulate.a < 0.05 or tipo == "derrota":
		return
	var q := int(_tempo * 6.0)
	var base := _faixa.position
	var pontos := [Vector2(28, -6), Vector2(316, -2), Vector2(8, 30), Vector2(334, 34), Vector2(170, -12), Vector2(96, -10), Vector2(250, -9)]
	for k in pontos.size():
		if (q + k) % 3 == 0:
			continue
		var p: Vector2 = (base + pontos[k]).floor()
		var c := OURO
		_brilhos.draw_rect(Rect2(p - Vector2(4, 0), Vector2(10, 2)), Color(c, 0.85))
		_brilhos.draw_rect(Rect2(p - Vector2(0, 4), Vector2(2, 10)), Color(c, 0.85))
		_brilhos.draw_rect(Rect2(p, Vector2(2, 2)), Color("#fff8e6"))
	for m in _motes:
		var b := 0.5 + 0.5 * sin(_tempo * 3.0 + float(m[2]))
		var p: Vector2 = (m[0] / 2.0).floor() * 2.0
		_brilhos.draw_rect(Rect2(p - Vector2(1, 1), Vector2(4, 4)), Color(1, 0.85, 0.4, 0.12 * b))
		_brilhos.draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 0.9, 0.55, 0.35 + 0.5 * b))

func _desenhar_barra() -> void:
	var s := _barra.size
	_barra.draw_rect(Rect2(Vector2.ZERO, s), Color("#12131c"))
	_barra.draw_rect(Rect2(Vector2(1, 1), s - Vector2(2, 2)), Color("#2a2c3c"))
	var w := floorf((s.x - 2) * clampf(_barra_frac, 0.0, 1.0))
	if w > 0:
		_barra.draw_rect(Rect2(Vector2(1, 1), Vector2(w, s.y - 2)), Color("#7b5cff"))
		_barra.draw_rect(Rect2(Vector2(1, 1), Vector2(w, 2)), Color("#b9a6ff"))
		_barra.draw_rect(Rect2(Vector2(1, s.y - 2), Vector2(w, 1)), Color("#3e2a8c"))
