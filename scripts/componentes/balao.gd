class_name Balao
extends Control
## Caixinha de diálogo (balão com rabicho) que aponta para o que foi tocado: efeitos, ataques e inimigos
## no combate e habilidades no Inventário. Pedido do João (2026-11-13): no lugar da ficha decorada, um
## balão simples como nos jogos de bolso. Qualquer toque na tela fecha.
## Uso: Balao.mostrar(self, controle_tocado.get_global_rect(), "Queimadura", cor, [["texto", cor], ...])

const PAPEL := Color("#f4ecd8")
const BORDA := Color("#e8b33a")
const TINTA := Color("#22160c")
const TINTA_CLARA := Color("#6a5236")
const LARGURA_MAX := 260.0
const MARGEM := 8.0
const RABICHO := 7.0

var ancora := Rect2()
var titulo := ""
var cor_titulo := TINTA
var linhas: Array = []          # [texto, cor] ou texto

var _caixa := Rect2()
var _ponta := Vector2.ZERO
var _para_baixo := true          # balão em cima do alvo, rabicho para baixo

static func mostrar(quem: Node, ancora_global: Rect2, titulo_: String, cor: Color, linhas_: Array) -> Balao:
	var raiz: Node = quem.get_tree().get_first_node_in_group("principal")
	if raiz == null:
		raiz = quem.get_tree().root
	for velho in raiz.get_children():
		if velho is Balao:
			velho.queue_free()
	var b := Balao.new()
	b.ancora = ancora_global
	b.titulo = titulo_
	b.cor_titulo = cor
	b.linhas = linhas_
	raiz.add_child(b)
	return b

## Balão de um atributo (Força, Percepção...): o que ele faz e quanto vale agora, pelas fórmulas do Motor.
## Usado na ficha do personagem e nos ícones de atributo do Inventário. a = "forca"... ou "vida".
static func atributo(quem: Node, ancora_global: Rect2, a: String, valor: int) -> Balao:
	var fator := Lutador.fator_de(int(Jogo.dados["nivel"]))
	var base := valor / fator
	var linhas: Array = [_t("ATR_" + a.to_upper() + "_DESC")]
	match a:
		"forca":
			linhas.append([_t("ATR_FORCA_AGORA") % int(round(valor * 2.0)), TINTA_CLARA])
		"percepcao":
			linhas.append([_t("ATR_PERCEPCAO_AGORA") % [int(round(minf(50.0, 5.0 + base))), snappedf(maxf(0.0, 8.0 - 0.4 * base), 0.1)], TINTA_CLARA])
		"agilidade":
			linhas.append([_t("ATR_AGILIDADE_AGORA") % snappedf(0.2 * base, 0.1), TINTA_CLARA])
		"resistencia":
			linhas.append([_t("ATR_RESISTENCIA_AGORA") % int(round(minf(75.0, 100.0 * valor / (valor + 50.0 * fator)))), TINTA_CLARA])
		"ressonancia":
			linhas.append([_t("ATR_RESSONANCIA_AGORA") % int(round(valor * 2.5)), TINTA_CLARA])
	return mostrar(quem, ancora_global, _t("ATR_" + a.to_upper()), TINTA, linhas)

static func _t(chave: String) -> String:
	return String(TranslationServer.translate(chave))

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_montar.call_deferred()

func _montar() -> void:
	var tela := get_global_rect()
	var a := Rect2(ancora.position - tela.position, ancora.size)
	var util := LARGURA_MAX - MARGEM * 2.0
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var largura := 0.0
	var itens: Array = []
	if titulo != "":
		itens.append([titulo, cor_titulo, true])
	for x in linhas:
		if x is Array:
			itens.append([str(x[0]), x[1] if x.size() > 1 else TINTA, false])
		else:
			itens.append([str(x), TINTA, false])
	for it: Array in itens:
		var fonte: Font = Tema.fonte_pequena
		var partes := Tema._quebrar(str(it[0]), fonte, 12, util, 8)
		if partes.is_empty():
			partes = PackedStringArray([str(it[0])])
		for p in partes:
			var l := Label.new()
			l.text = p.strip_edges()
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			l.add_theme_font_override("font", fonte)
			l.add_theme_font_size_override("font_size", 12)
			l.add_theme_color_override("font_color", it[1])
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(l)
			largura = maxf(largura, fonte.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
		if it[2]:
			var fio := ColorRect.new()
			fio.color = Color(BORDA, 0.6)
			fio.custom_minimum_size = Vector2(0, 1)
			fio.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(fio)
	add_child(col)
	await get_tree().process_frame
	if not is_instance_valid(col):
		return
	var w := ceilf(minf(LARGURA_MAX, largura + MARGEM * 2.0 + 2.0))
	var h := ceilf(col.get_combined_minimum_size().y + MARGEM * 2.0)
	# em cima do alvo (rabicho para baixo); se não couber, embaixo
	var cx := a.position.x + a.size.x / 2.0
	var x := clampf(floorf(cx - w / 2.0), 6.0, size.x - w - 6.0)
	var y := a.position.y - h - RABICHO - 2.0
	_para_baixo = true
	if y < 6.0:
		y = a.end.y + RABICHO + 2.0
		_para_baixo = false
	y = clampf(y, 6.0, size.y - h - 6.0)
	_caixa = Rect2(floorf(x), floorf(y), w, h)
	_ponta = Vector2(clampf(floorf(cx), x + 10.0, x + w - 10.0), y + h + RABICHO if _para_baixo else y - RABICHO)
	col.position = _caixa.position + Vector2(MARGEM, MARGEM - 1.0)
	col.size = Vector2(w - MARGEM * 2.0, 0)
	queue_redraw()
	# aparece com um pulinho
	modulate.a = 0.0
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(self, "modulate:a", 1.0, 0.1)

func _draw() -> void:
	if _caixa.size.x <= 0.0:
		return
	var r := _caixa
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))       # sombra
	draw_rect(r.grow(2), TINTA)
	draw_rect(r.grow(1), BORDA)
	draw_rect(r, PAPEL)
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 1), Color(1, 1, 1, 0.6))
	# rabicho em degraus (pixel art), da borda do balão até a ponta
	var base_y := r.end.y if _para_baixo else r.position.y
	var dir := 1.0 if _para_baixo else -1.0
	for k in int(RABICHO):
		var meia := RABICHO - k
		var yy := base_y + dir * k
		var ry := yy if _para_baixo else yy - 1.0
		draw_rect(Rect2(_ponta.x - meia - 1.0, ry, meia * 2.0 + 2.0, 1), TINTA)
		draw_rect(Rect2(_ponta.x - meia, ry, meia * 2.0, 1), BORDA if k > 0 else PAPEL)
		if meia > 1.0:
			draw_rect(Rect2(_ponta.x - meia + 1.0, ry, meia * 2.0 - 2.0, 1), PAPEL)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		fechar()
		accept_event()

func fechar() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := create_tween().set_ignore_time_scale(true)
	t.tween_property(self, "modulate:a", 0.0, 0.1)
	t.tween_callback(queue_free)
