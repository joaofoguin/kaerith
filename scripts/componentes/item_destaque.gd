class_name ItemDestaque
extends VBoxContainer
## Ladrilho de item em destaque (vitrines e popups): fundo em degradê da raridade, brilho atrás do ícone,
## moldura dupla com losangos nos cantos, faixa de luz que passa de tempos em tempos, selo de quantidade
## e o nome embaixo. Épico e Lendário ainda pulsam de leve.
## Uso: add_child(ItemDestaque.criar(icone, "Lâmina", "epico", "×1", selo_elemento))

const COR := {"comum": Color("#b8b0a0"), "incomum": Color("#7fd07a"), "raro": Color("#5aa8ff"), "epico": Color("#c07cff"), "lendario": Color("#ffc24a")}

var icone: Texture2D
var nome := ""
var raridade := "comum"
var quantidade := ""
var selo: Texture2D
var largura := 92.0
var atraso := 0.0          # para os ladrilhos lado a lado não brilharem juntos

var _quadro: Control
var _tempo := 0.0

static func criar(p_icone: Texture2D, p_nome: String, p_raridade: String, p_qtd := "", p_selo: Texture2D = null, p_largura := 92.0) -> Control:
	var d = load("res://scripts/componentes/item_destaque.gd").new()
	d.icone = p_icone
	d.nome = p_nome
	d.raridade = p_raridade if COR.has(p_raridade) else "comum"
	d.quantidade = p_qtd
	d.selo = p_selo
	d.largura = p_largura
	return d

func _ready() -> void:
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quadro = Control.new()
	_quadro.custom_minimum_size = Vector2(largura, largura)
	_quadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quadro.draw.connect(_desenhar)
	add_child(_quadro)
	# ícone em escala inteira (pixel art nítida), o maior que couber com folga
	if icone:
		var lado := float(icone.get_width())
		var escala := maxf(1.0, floorf((largura - 16.0) / lado))
		var ic := TextureRect.new()
		ic.texture = icone
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size = Vector2(icone.get_width(), icone.get_height()) * escala
		ic.position = ((Vector2(largura, largura) - ic.size) / 2.0).floor() + Vector2(0, -2)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_quadro.add_child(ic)
	if selo:
		var s := TextureRect.new()
		s.texture = selo
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = Vector2(7, 7)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_quadro.add_child(s)
	if quantidade != "":
		var q := PanelContainer.new()
		var e := StyleBoxFlat.new()
		e.bg_color = Color("#12131c")
		e.border_color = COR[raridade]
		e.set_border_width_all(1)
		e.set_corner_radius_all(2)
		e.content_margin_left = 4
		e.content_margin_right = 4
		e.content_margin_top = 1
		e.content_margin_bottom = 1
		q.add_theme_stylebox_override("panel", e)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var r := Tema.rotulo(quantidade, 8, true)
		r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		r.add_theme_color_override("font_color", Color.WHITE)
		q.add_child(r)
		_quadro.add_child(q)
		q.resized.connect(func(): q.position = Vector2(largura - q.size.x - 5, largura - q.size.y - 5).floor())
	if nome != "":
		var n := Tema.rotulo(nome, 12)
		n.custom_minimum_size = Vector2(largura, 0)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.add_theme_constant_override("line_spacing", -2)
		n.add_theme_color_override("font_color", COR[raridade].lightened(0.35))
		add_child(n)

func _process(delta: float) -> void:
	_tempo += delta / maxf(Engine.time_scale, 0.01)
	_quadro.queue_redraw()

func _desenhar() -> void:
	var cor: Color = COR[raridade]
	var s := Vector2(largura, largura)
	var c := _quadro
	# fundo em degradê (faixas de 4 px, do tom escuro da raridade para quase preto)
	c.draw_rect(Rect2(Vector2.ZERO, s), Color("#0a0b12"))
	var faixas := int(s.y / 4.0)
	for i in faixas:
		var k := float(i) / float(faixas - 1)
		c.draw_rect(Rect2(2, 2 + i * (s.y - 4) / faixas, s.x - 4, ceilf((s.y - 4) / faixas)), cor.darkened(0.55 + 0.3 * k))
	# brilho redondo atrás do ícone (pulsa nos raros de verdade)
	var pulso := 0.0
	if raridade in ["epico", "lendario"]:
		pulso = 0.5 + 0.5 * sin(_tempo * 3.0)
	var centro := s / 2.0 + Vector2(0, -2)
	for k in 4:
		c.draw_circle(centro, s.x * (0.42 - k * 0.08), Color(cor, 0.07 + 0.03 * k + 0.04 * pulso))
	# raios finos girando atrás (só Épico e Lendário)
	if pulso > 0.0 or raridade == "lendario":
		for i in 8:
			var a := _tempo * 0.5 + i * TAU / 8.0
			c.draw_colored_polygon(PackedVector2Array([centro, centro + Vector2.from_angle(a - 0.08) * s.x * 0.5,
				centro + Vector2.from_angle(a + 0.08) * s.x * 0.5]), Color(cor.lightened(0.4), 0.08))
	# faixa de luz em diagonal, recortada no quadro, a cada 3 s
	var ciclo := fmod(_tempo + atraso, 3.0) / 0.7
	if ciclo < 1.0:
		var x := lerpf(-s.x * 0.6, s.x * 1.4, ciclo)
		var faixa := PackedVector2Array([Vector2(x, 0), Vector2(x + 14, 0), Vector2(x + 14 - s.y * 0.5, s.y), Vector2(x - s.y * 0.5, s.y)])
		var quadro := PackedVector2Array([Vector2(2, 2), Vector2(s.x - 2, 2), Vector2(s.x - 2, s.y - 2), Vector2(2, s.y - 2)])
		for p in Geometry2D.intersect_polygons(faixa, quadro):
			c.draw_colored_polygon(p, Color(1, 1, 1, 0.16))
	# moldura dupla: escura por fora, cor da raridade, filete claro por dentro
	c.draw_rect(Rect2(Vector2.ZERO, s), Color("#12131c"), false, 2.0)
	c.draw_rect(Rect2(Vector2(2, 2), s - Vector2(4, 4)), cor, false, 2.0)
	c.draw_rect(Rect2(Vector2(5, 5), s - Vector2(10, 10)), Color(cor.lightened(0.4), 0.35), false, 1.0)
	c.draw_rect(Rect2(4, 4, s.x - 8, 1), Color(cor.lightened(0.5), 0.6))
	# losangos nos cantos
	for p in [Vector2(3, 3), Vector2(s.x - 3, 3), Vector2(3, s.y - 3), Vector2(s.x - 3, s.y - 3)]:
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]), Color("#12131c"))
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3), p + Vector2(3, 0), p + Vector2(0, 3), p + Vector2(-3, 0)]), cor.lightened(0.2))
	# brilho em cruz piscando num canto (Épico e Lendário)
	if pulso > 0.7:
		var b := Vector2(s.x - 14, 12)
		c.draw_rect(Rect2(b + Vector2(-3, 0), Vector2(7, 1)), Color(1, 1, 1, 0.9))
		c.draw_rect(Rect2(b + Vector2(0, -3), Vector2(1, 7)), Color(1, 1, 1, 0.9))
