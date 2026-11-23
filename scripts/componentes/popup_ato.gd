class_name PopupAto
extends "res://scripts/componentes/popup_vitrine.gd"
const TEMPORADA := preload("res://scripts/temporada.gd")
## Popup do ato em curso (botão do numeral no Início), todo nas cores do ato: cenário animado com o
## medalhão do numeral, tempo que falta para o ato acabar, um resumo da região, a jornada do jogador no
## ato (fases vencidas e o chefe, oculto até ser encontrado) e as criaturas já vistas.
## Uso: var p := PopupAto.new(); p.ato = 1; p.ao_ver_mapa = abrir_mapa; add_child(p)

var ato := 1
var ao_ver_mapa: Callable

var _cenario: Array[Texture2D] = []
var _banner: Control
var _q := 0
var _t_quadro := 0.0
var _tempo_rot: Label
var _tempo_barra: Control

func _ready() -> void:
	var c := TEMPORADA.cores(ato)
	cor_fundo = c["fundo"]
	cor_acento = c["acento"]
	cor_claro = c["claro"]
	cor_escuro = c["escuro"]
	for q in 4:
		_cenario.append(load("res://artes/arenas/ato%d_0_q%d.png" % [ato, q]))
	super._ready()

func _montar(col: VBoxContainer) -> void:
	col.add_child(_montar_banner())

	# título: "Temporada 1 · Ato I" e o nome da região
	var sub := Tema.rotulo(tr("TEMPORADA_ATO") % ato, 12)
	sub.add_theme_color_override("font_color", cor_claro)
	col.add_child(sub)
	var nome := Tema.rotulo(TEMPORADA.nome(ato), 24)
	nome.add_theme_constant_override("outline_size", 4)
	nome.add_theme_color_override("font_outline_color", cor_escuro)
	nome.add_theme_constant_override("line_spacing", -4)
	Tema.caber(nome, LARGURA - 24.0, 34.0, 1, [24, 16])
	col.add_child(nome)

	# tempo do ato
	var agora := TEMPORADA.agora()
	var chave := "ATO_TERMINA_EM"
	if agora < TEMPORADA.comeco_do_ato(ato):
		chave = "ATO_COMECA_EM"
	var cab := secao(chave, "")
	var d := Tema.rotulo("", 8, true)
	d.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	d.add_theme_color_override("font_color", Color.WHITE)
	cab.add_child(d)
	_tempo_rot = d
	col.add_child(cab)
	_tempo_barra = barra(TEMPORADA.passado(ato), cor_acento, 8.0)
	col.add_child(_tempo_barra)
	_atualizar_tempo()

	# resumo da região
	col.add_child(paragrafo("ATO_DESC_%d" % ato, Color("#d8dae6")))

	# a jornada do jogador: chefe à esquerda, fases à direita
	var vencidas := TEMPORADA.vencidas_no_ato(ato)
	col.add_child(secao("ATO_JORNADA", "%d/75" % vencidas))
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	linha.add_child(_quadro_chefe())
	var dir := VBoxContainer.new()
	dir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir.alignment = BoxContainer.ALIGNMENT_CENTER
	dir.add_theme_constant_override("separation", 4)
	var fases := Tema.rotulo("ATO_FASES_VENCIDAS", 12)
	fases.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	fases.add_theme_color_override("font_color", Color("#d8dae6"))
	dir.add_child(fases)
	dir.add_child(barra(vencidas / 75.0, Color("#7fd07a"), 10.0))
	var ch := TEMPORADA.chefe(ato)
	var rot_chefe := Tema.rotulo(tr("ATO_CHEFE") + ": " + (str(ch["nome"]) if ch["visto"] else "???"), 12)
	rot_chefe.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rot_chefe.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rot_chefe.add_theme_color_override("font_color", cor_claro)
	rot_chefe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rot_chefe.custom_minimum_size = Vector2(230, 0)
	dir.add_child(rot_chefe)
	linha.add_child(dir)
	col.add_child(linha)

	# criaturas do ato: miniatura de quem já foi visto, "?" para o resto
	var lista := TEMPORADA.criaturas(ato)
	var vistas := 0
	for e in lista:
		if e["visto"]:
			vistas += 1
	col.add_child(secao("ATO_CRIATURAS", "%d/%d" % [vistas, lista.size()]))
	var grade := GridContainer.new()
	grade.columns = 9
	grade.add_theme_constant_override("h_separation", 3)
	grade.add_theme_constant_override("v_separation", 3)
	grade.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for e in lista:
		grade.add_child(_celula(e))
	col.add_child(grade)

	var ver := Button.new()
	ver.text = "ATO_VER_MAPA"
	ver.custom_minimum_size = Vector2(0, 40)
	Tema.estilo_botao(ver, "primario")
	ver.pressed.connect(func():
		fechar()
		if ao_ver_mapa.is_valid():
			ao_ver_mapa.call())
	col.add_child(ver)

## Cenário do ato (recorte da arena, ×2, animado) com escurecido embaixo, selo "Em curso" e o medalhão.
func _montar_banner() -> Control:
	_banner = Control.new()
	_banner.custom_minimum_size = Vector2(LARGURA - 16.0, 112)
	_banner.clip_contents = true
	_banner.draw.connect(_desenhar_banner)
	if TEMPORADA.ato_em_curso() == ato:
		var s := selo(tr("ATO_EM_CURSO").to_upper(), Color("#12131c"), cor_acento, cor_escuro)
		s.position = Vector2(6, 6)
		_banner.add_child(s)
	return _banner

func _desenhar_banner() -> void:
	var s := _banner.size
	_banner.draw_texture_rect_region(_cenario[_q], Rect2(Vector2.ZERO, Vector2(s.x, s.y)), Rect2(10, 22, s.x / 2.0, s.y / 2.0))
	for i in 10:
		_banner.draw_rect(Rect2(0, s.y - 40 + i * 4, s.x, 4), Color(cor_fundo, 0.1 * (i + 1)))
	_banner.draw_rect(Rect2(Vector2.ZERO, s), cor_escuro, false, 2.0)
	# medalhão com o numeral, embaixo no meio, com raios girando
	var c := Vector2(s.x / 2.0, s.y - 30)
	for i in 12:
		var a := _tempo * 0.6 + i * TAU / 12.0
		_banner.draw_line(c + Vector2.from_angle(a) * 25, c + Vector2.from_angle(a) * 31, Color(cor_acento, 0.8), 2.0)
	_banner.draw_circle(c, 24, cor_escuro)
	_banner.draw_circle(c, 22, cor_acento)
	_banner.draw_circle(c, 18, cor_escuro)
	_banner.draw_arc(c, 15, 0, TAU, 32, Color(cor_acento, 0.5), 1.0)
	var num := TEMPORADA.romano(ato)
	var fn := Tema.fonte_numeros
	var w := fn.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_banner.draw_string(fn, Vector2(floorf(c.x - w / 2.0), c.y + 6), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cor_claro)

func _quadro_chefe() -> Control:
	var ch := TEMPORADA.chefe(ato)
	var q := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = cor_escuro
	e.border_color = cor_acento
	e.set_border_width_all(2)
	e.set_corner_radius_all(3)
	q.add_theme_stylebox_override("panel", e)
	q.custom_minimum_size = Vector2(60, 60)
	var tex: Texture2D = Bestiario.miniatura(str(ch["chave"])) if str(ch["chave"]) != "" else null
	if tex:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.custom_minimum_size = Vector2(56, 56)
		if not ch["visto"]:
			t.modulate = Color(0, 0, 0, 0.85)       # silhueta até o encontro
		q.add_child(t)
	if not ch["visto"]:
		var p := Tema.rotulo("?", 24, true)
		p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_theme_color_override("font_color", cor_acento)
		q.add_child(p)
	return q

func _celula(e: Dictionary) -> Control:
	var q := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = cor_escuro if e["visto"] else Color("#0a0b12")
	st.border_color = Color(cor_acento, 0.9 if e["visto"] else 0.35)
	st.set_border_width_all(1)
	st.set_corner_radius_all(2)
	q.add_theme_stylebox_override("panel", st)
	q.custom_minimum_size = Vector2(32, 32)
	if e["visto"]:
		var t := TextureRect.new()
		t.texture = Bestiario.miniatura(str(e["chave"]))
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.custom_minimum_size = Vector2(28, 28)
		q.add_child(t)
	else:
		var p := Tema.rotulo("?", 16, true)
		p.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_theme_color_override("font_color", Color(cor_acento, 0.6))
		q.add_child(p)
	return q

func _atualizar_tempo() -> void:
	var agora := TEMPORADA.agora()
	if agora < TEMPORADA.comeco_do_ato(ato):
		_tempo_rot.text = TEMPORADA.texto_tempo(TEMPORADA.comeco_do_ato(ato) - agora)
	elif TEMPORADA.restante(ato) <= 0:
		_tempo_rot.text = tr("ATO_ENCERRADO").to_upper()
	else:
		_tempo_rot.text = TEMPORADA.texto_tempo(TEMPORADA.restante(ato))

func _process(delta: float) -> void:
	super._process(delta)
	_t_quadro += delta / maxf(Engine.time_scale, 0.01)
	if _t_quadro >= 0.125:
		_t_quadro = 0.0
		_q = (_q + 1) % 4
		_atualizar_tempo()
	if _banner:
		_banner.queue_redraw()
