extends Node
## Monta o tema visual a partir das artes do kit de interface aprovado.

const COR_FUNDO := Color("#12131c")
const COR_PAINEL := Color("#181a28")
const COR_TEXTO := Color("#e6e6f0")
const COR_TEXTO_APAGADO := Color("#868ca6")
const COR_OURO := Color("#e8b33a")
const COR_OURO_CLARO := Color("#ffd66b")
const COR_TEXTO_ESCURO := Color("#2a1608")    # texto em botão dourado (contraste)

var fonte_texto: FontFile
var fonte_numeros: FontFile
## Fontes (pedido do João, 2026-11-13): textos PEQUENOS (até 14) usam a família Fusion Pixel (OFL,
## github.com/TakWolf/fusion-pixel-font), que é nítida nesses tamanhos: até 11 → Fusion 10; 12 a 14 → Fusion 12.
## Textos médios e grandes (15 ou mais) ficam na fonte de antes (Pixelify ou Silkscreen). Troca sozinha em
## _ajustar_fonte.
var fonte_pequena: FontFile       # Fusion Pixel 12
var fonte_10: FontFile            # Fusion Pixel 10
const TAM_PEQUENO := 12
var tema: Theme

func _ready() -> void:
	fonte_texto = _fonte_pixel("res://artes/fontes/PixelifySans.ttf")
	fonte_numeros = _fonte_pixel("res://artes/fontes/Silkscreen-Regular.ttf")
	fonte_pequena = _fonte_pixel("res://artes/fontes/FusionPixel12.otf")
	fonte_10 = _fonte_pixel("res://artes/fontes/FusionPixel10.otf")
	# símbolos que a Fusion não tem (…, –) vêm da Pixelify
	fonte_pequena.fallbacks = [fonte_texto]
	fonte_10.fallbacks = [fonte_texto]
	tema = _montar_tema()
	get_tree().node_added.connect(_no_novo)

func _fonte_pixel(caminho: String) -> FontFile:
	var f: FontFile = load(caminho)
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	# sem ligaduras: a PixelifySans juntava "fi" num desenho estranho ("Ver Ficha" virava "Ver Acha")
	var ts := TextServerManager.get_primary_interface()
	f.opentype_feature_overrides = {ts.name_to_tag("liga"): 0, ts.name_to_tag("clig"): 0, ts.name_to_tag("dlig"): 0}
	return f

func caixa_9fatias(arquivo: String, borda: int) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load("res://artes/interface/" + arquivo)
	s.texture_margin_left = borda
	s.texture_margin_right = borda
	s.texture_margin_top = borda
	s.texture_margin_bottom = borda
	s.content_margin_left = borda + 2
	s.content_margin_right = borda + 2
	s.content_margin_top = borda - 2
	s.content_margin_bottom = borda - 2
	return s

func _montar_tema() -> Theme:
	var t := Theme.new()
	t.default_font = fonte_texto
	t.default_font_size = 16
	t.set_color("font_color", "Label", COR_TEXTO)
	# Botões
	t.set_stylebox("normal", "Button", caixa_9fatias("botao_primario_normal_9fatias_borda6.png", 6))
	t.set_stylebox("hover", "Button", caixa_9fatias("botao_primario_normal_9fatias_borda6.png", 6))
	t.set_stylebox("pressed", "Button", caixa_9fatias("botao_primario_pressionado_9fatias_borda6.png", 6))
	t.set_stylebox("disabled", "Button", caixa_9fatias("botao_primario_desativado_9fatias_borda6.png", 6))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", COR_TEXTO_ESCURO)      # o botão padrão é o dourado
	t.set_color("font_disabled_color", "Button", COR_TEXTO_APAGADO)
	# Interruptores e caixas de marcar: sem fundo de botão, letra clara (senão herdam o dourado)
	for tipo in ["CheckButton", "CheckBox"]:
		for est in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			t.set_stylebox(est, tipo, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(c, tipo, COR_TEXTO)
	# Painéis
	t.set_stylebox("panel", "PanelContainer", caixa_9fatias("painel_9fatias_borda8.png", 8))
	t.set_stylebox("panel", "Panel", caixa_9fatias("painel_9fatias_borda8.png", 8))
	return t

## Rótulo pronto (texto já traduzido por chave).
func rotulo(chave: String, tamanho := 16, numeros := false) -> Label:
	var l := Label.new()
	l.text = chave
	l.add_theme_font_size_override("font_size", tamanho)
	if numeros:
		l.add_theme_font_override("font", fonte_numeros)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

## Faz o texto caber no quadro sem a quebra automática do Godot: quebra as palavras em até
## `max_linhas` linhas por conta própria e diminui a fonte (16, 14, 12, 10) até tudo caber.
## A borda (outline) e uma folga entram na conta, então o texto nunca encosta na moldura.
func caber(r: Label, largura: float, altura: float, max_linhas := 2, tamanhos: Array = [16, 14, 12, 10]) -> void:
	var fonte: Font = r.get_theme_font("font") if r.has_theme_font_override("font") else fonte_texto
	var borda := 0.0
	if r.has_theme_constant_override("outline_size"):
		borda = float(r.get_theme_constant("outline_size"))
	var espaco := 0.0
	if r.has_theme_constant_override("line_spacing"):
		espaco = float(r.get_theme_constant("line_spacing"))
	var texto := r.tr(r.text).replace("\n", " ")
	var fixa := r.has_meta("fonte_fixa")     # mantém a fonte original mesmo quando diminui (botões de ataque)
	var util := largura - borda - 2.0
	var escolhido: int = tamanhos[tamanhos.size() - 1]
	var linhas := PackedStringArray([texto])
	for tam in tamanhos:
		var t: int = tam
		var l := _quebrar(texto, fonte, t, util, max_linhas, fixa)
		if l.is_empty():
			continue
		var fr: Array = [fonte, t] if fixa else fonte_real(fonte, t)
		var alto := l.size() * ((fr[0] as Font).get_height(int(fr[1])) + espaco) - espaco + borda
		if alto <= altura:
			escolhido = t
			linhas = l
			break
		if tam == tamanhos[tamanhos.size() - 1]:
			linhas = l
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.text = "\n".join(linhas)
	r.clip_text = true
	r.add_theme_font_size_override("font_size", escolhido)

## Quebra gulosa por palavras; devolve vazio se alguma linha não couber em `util` ou passar de max_linhas.
func _quebrar(texto: String, fonte_pedida: Font, tam_pedido: int, util: float, max_linhas: int, fixa := false) -> PackedStringArray:
	var fr: Array = [fonte_pedida, tam_pedido] if fixa else fonte_real(fonte_pedida, tam_pedido)
	var fonte: Font = fr[0]
	var tam: int = fr[1]
	var linhas := PackedStringArray()
	var atual := ""
	for palavra in texto.split(" ", false):
		var junto := palavra if atual == "" else atual + " " + palavra
		if fonte.get_string_size(junto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x <= util:
			atual = junto
		else:
			if atual != "":
				linhas.append(atual)
			atual = palavra
			if fonte.get_string_size(atual, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > util:
				return PackedStringArray()
	if atual != "":
		linhas.append(atual)
	if linhas.size() > max_linhas:
		return PackedStringArray()
	return linhas

## Botão no estilo do kit: "primario", "secundario", "confirmar" ou "perigo" (9 fatias de interface/).
func estilo_botao(b: Button, tipo: String) -> void:
	var normal := caixa_9fatias("botao_%s_normal_9fatias_borda6.png" % tipo, 6)
	var apertado := caixa_9fatias("botao_%s_pressionado_9fatias_borda6.png" % tipo, 6)
	for est in ["normal", "hover", "disabled", "focus"]:
		b.add_theme_stylebox_override(est, normal)
	for est in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(est, apertado)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	cor_texto_botao(b, tipo)

## Cor da letra que contrasta com o botão: escura no dourado, clara nos outros.
func cor_texto_botao(b: Button, tipo: String) -> void:
	var cor := COR_TEXTO_ESCURO if tipo == "primario" else COR_TEXTO
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, cor)

# ------------------------------------------------------------ caber nos botões e nas caixas
## Diminui a fonte dos botões (de 2 em 2, até 8) quando o texto passaria da borda do botão.
## Guarda o tamanho original, então o texto volta a crescer se couber de novo (troca de idioma).
func ajustar_botoes(raiz: Node) -> void:
	if not is_instance_valid(raiz):
		return
	for n in raiz.find_children("*", "Button", true, false):
		caber_botao(n as Button)

func caber_botao(b: Button) -> void:
	if b == null or b.text == "" or b.size.x <= 0.0 or not b.is_visible_in_tree():
		return
	var texto := b.tr(b.text) if b.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else b.text
	if "\n" in texto:
		return
	var orig: int = int(b.get_meta("tam_orig")) if b.has_meta("tam_orig") else b.get_theme_font_size("font_size")
	b.set_meta("tam_orig", orig)
	var fonte := b.get_theme_font("font")
	var est := b.get_theme_stylebox("normal")
	var util := b.size.x - 4.0
	if est:
		util -= est.get_margin(SIDE_LEFT) + est.get_margin(SIDE_RIGHT)
	if b.icon:
		util -= b.icon.get_width() + b.get_theme_constant("h_separation")
	if b is CheckButton or b is CheckBox:
		util -= b.get_theme_icon("unchecked").get_width() + b.get_theme_constant("h_separation")
	var tam := orig
	while tam > 8 and fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x > util:
		tam -= 2
	if tam != b.get_theme_font_size("font_size"):
		b.add_theme_font_size_override("font_size", tam)

## Ajusta os botões depois que o layout assentou (um quadro depois).
func ajustar_depois(raiz: Node) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	ajustar_botoes(raiz)

## Mantém um popup centralizado se o conteúdo mudar de tamanho depois de aberto (texto que quebra,
## botão que aparece). Se crescer além de alto_max, o conteúdo passa a rolar em vez de sair da tela.
func manter_centrado(painel: Control, alto_max: float, dy := 0.0, depois := Callable()) -> void:
	painel.resized.connect(func():
		if not is_instance_valid(painel):
			return
		if painel.size.y > alto_max + 0.5 and painel.get_child_count() > 0 and not (painel.get_child(0) is ScrollContainer):
			_rolar.call_deferred(painel, alto_max)
			return
		var pai := painel.get_parent_control()
		var tela := pai.size if pai else painel.get_viewport_rect().size
		painel.position = Vector2(floorf((tela.x - painel.size.x) / 2.0), floorf((tela.y - painel.size.y) / 2.0) + dy)
		painel.pivot_offset = painel.size / 2.0
		if depois.is_valid():
			depois.call())

func _rolar(painel: Control, alto_max: float) -> void:
	if not is_instance_valid(painel) or painel.get_child(0) is ScrollContainer:
		return
	var c: Control = painel.get_child(0)
	painel.remove_child(c)
	var rol := ScrollContainer.new()
	rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rol.custom_minimum_size = Vector2(painel.size.x - 24.0, alto_max - 24.0)
	rol.add_child(c)
	painel.add_child(rol)
	painel.reset_size()

## Botão de fechar: X branco num círculo vermelho (32×32).
func botao_x() -> Button:
	var b := Button.new()
	b.text = "X"
	b.size = Vector2(32, 32)
	b.custom_minimum_size = Vector2(32, 32)
	b.add_theme_font_override("font", fonte_numeros)
	b.add_theme_font_size_override("font_size", 16)
	for par in [["normal", Color("#d8394a")], ["hover", Color("#e8505e")], ["pressed", Color("#a82434")], ["focus", Color("#d8394a")]]:
		var e := StyleBoxFlat.new()
		e.bg_color = par[1]
		e.border_color = Color("#4a0c18")
		e.set_border_width_all(2)
		e.set_corner_radius_all(16)
		e.shadow_color = Color(0, 0, 0, 0.4)
		e.shadow_size = 2
		e.shadow_offset = Vector2(0, 2)
		b.add_theme_stylebox_override(par[0], e)
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	return b

## Popups abertos dentro de uma aba ficavam centralizados na tela inteira, mas a aba termina antes da
## barra de baixo: a parte de baixo do popup sumia atrás da barra. Agora o popup sobe para a cena
## principal (por cima de tudo, com o véu cobrindo também a barra) e some junto com a tela que o abriu.
func elevar(popup: Control) -> void:
	var raiz := get_tree().get_first_node_in_group("principal") if is_inside_tree() else null
	var dono := popup.get_parent()
	if raiz == null or dono == null or dono == raiz:
		return
	dono.tree_exiting.connect(popup.queue_free, CONNECT_ONE_SHOT)
	popup.reparent.call_deferred(raiz, false)
	(func():
		if is_instance_valid(popup):
			popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)).call_deferred()

# ------------------------------------------------------------ toque com resposta (todos os botões)
## Todo botão afunda um pouco ao ser apertado e volta com um pulinho, como nos jogos de celular.
## Botões que já pulsam sozinhos (escala diferente de 1) ficam de fora; set_meta("sem_pulo", true) também.
func _no_novo(n: Node) -> void:
	if n is Control:
		_liberar_rolagem.call_deferred(n)
	# o nó pode entrar na árvore de novo (reparent, palco_640): liga cada sinal uma vez só
	if n is Label or n is Button or n is LineEdit:
		var f := _ajustar_fonte.bind(n)
		if not (n as Control).theme_changed.is_connected(f):
			(n as Control).theme_changed.connect(f)
		_ajustar_fonte.call_deferred(n)
	# som de toque em todo botão (2026-11-23); set_meta("sem_som", true) tira
	if n is BaseButton and not (n as BaseButton).pressed.is_connected(_som_toque.bind(n)):
		(n as BaseButton).pressed.connect(_som_toque.bind(n))
	if n is Button and not (n is CheckButton or n is CheckBox):
		var b := n as Button
		if not b.button_down.is_connected(_apertar.bind(b)):
			b.button_down.connect(_apertar.bind(b))
			b.button_up.connect(_soltar.bind(b))

## Fonte e tamanho de verdade para um pedido. `original` é a fonte que o texto pediu (Pixelify ou Silkscreen).
func alvo_fonte(tam: int, original: Font = null) -> Array:
	if tam <= 11:
		return [fonte_10, 10]
	if tam <= 14:
		return [fonte_pequena, TAM_PEQUENO]
	return [original if original != null else fonte_texto, tam]

func _fonte_do_jogo(f: Font) -> bool:
	return f == fonte_texto or f == fonte_numeros or f == fonte_pequena or f == fonte_10

## Troca a fonte do controle conforme o tamanho. Roda quando o controle entra na tela e sempre que a fonte
## ou o tamanho dele mudam (theme_changed). Guarda a fonte original para voltar a ela se o texto crescer.
func _ajustar_fonte(c: Control) -> void:
	if not is_instance_valid(c) or c.has_meta("_ajustando") or c.has_meta("fonte_fixa"):
		return
	var f := c.get_theme_font("font")
	if not _fonte_do_jogo(f):
		return
	if f == fonte_texto or f == fonte_numeros:
		c.set_meta("fonte_orig", f)
	var original: Font = c.get_meta("fonte_orig", fonte_texto)
	var s := c.get_theme_font_size("font_size")
	var alvo := alvo_fonte(s, original)
	c.set_meta("_ajustando", true)
	if f != alvo[0]:
		c.add_theme_font_override("font", alvo[0])
	if s != int(alvo[1]):
		c.add_theme_font_size_override("font_size", int(alvo[1]))
	c.remove_meta("_ajustando")

## Fonte e tamanho que o texto usa de verdade na tela (para medir).
func fonte_real(fonte: Font, tam: int) -> Array:
	if _fonte_do_jogo(fonte):
		var original: Font = fonte if (fonte == fonte_texto or fonte == fonte_numeros) else fonte_texto
		return alvo_fonte(tam, original)
	return [fonte, tam]

## Altura de uma linha de texto (Pixelify nos tamanhos médios) no tamanho pedido.
func altura_texto(tam: int, original: Font = null) -> float:
	var a := alvo_fonte(tam, original)
	return (a[0] as Font).get_height(int(a[1]))

## No celular, o dedo que arrasta em cima de um botão ou quadro (filtro STOP) não chegava à lista:
## dentro de qualquer ScrollContainer tudo passa a deixar o toque seguir para a rolagem (PASS).
func _liberar_rolagem(c) -> void:   # sem tipo: o nó pode ter sido liberado antes da chamada adiada
	if not is_instance_valid(c) or not (c is Control) or c.mouse_filter != Control.MOUSE_FILTER_STOP or c is ScrollContainer:
		return
	var p: Node = c.get_parent()
	while p != null:
		if p is ScrollContainer:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
			return
		p = p.get_parent()

## Segurar o dedo parado num botão ou quadro por SEGURAR_S chama `acao` (ex.: ficha da habilidade).
## O toque que solta depois não conta como clique, e arrastar (rolar a lista) cancela.
const SEGURAR_S := 0.45
const TOQUE_FOLGA := 10.0

func ao_segurar(c: Control, acao: Callable) -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = SEGURAR_S
	t.ignore_time_scale = true
	c.add_child(t, false, Node.INTERNAL_MODE_BACK)
	var est := {"ini": Vector2.ZERO, "travou": false}
	t.timeout.connect(func():
		if not is_instance_valid(c) or not c.is_visible_in_tree():
			return
		# desliga o botão até o dedo sair, para o soltar não virar um clique
		if c is BaseButton and not (c as BaseButton).disabled:
			(c as BaseButton).disabled = true
			est["travou"] = true
		acao.call())
	c.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := ev as InputEventMouseButton
			if mb.pressed:
				est["ini"] = mb.global_position
				t.start()
			else:
				t.stop()
				if est["travou"]:
					est["travou"] = false
					(c as BaseButton).disabled = false
		elif ev is InputEventMouseMotion and not t.is_stopped():
			if (ev as InputEventMouseMotion).global_position.distance_to(est["ini"]) > TOQUE_FOLGA:
				t.stop())

## Toque de verdade (apertar e soltar quase no mesmo lugar) num Control que não é botão. Dentro de listas
## que rolam, o "apertar" sozinho disparava a ação só de passar o dedo. `acao` recebe a posição local.
func ao_tocar(c: Control, acao: Callable) -> void:
	var est := {"ini": Vector2.ZERO, "valendo": false}
	c.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := ev as InputEventMouseButton
			if mb.pressed:
				est["ini"] = mb.global_position
				est["valendo"] = true
			elif est["valendo"]:
				est["valendo"] = false
				if mb.global_position.distance_to(est["ini"]) <= TOQUE_FOLGA and Rect2(Vector2.ZERO, c.size).has_point(mb.position):
					acao.call(mb.position)
		elif ev is InputEventMouseMotion and est["valendo"]:
			if (ev as InputEventMouseMotion).global_position.distance_to(est["ini"]) > TOQUE_FOLGA:
				est["valendo"] = false)

func _som_toque(b: BaseButton) -> void:
	if is_instance_valid(b) and not b.has_meta("sem_som") and Jogo.som != null:
		Jogo.som.toque()

func _apertar(b: Button) -> void:
	if not is_instance_valid(b) or b.disabled or b.has_meta("sem_pulo"):
		return
	if not b.has_meta("pulando") and not b.scale.is_equal_approx(Vector2.ONE):
		return
	b.set_meta("pulando", true)
	b.pivot_offset = b.size / 2.0
	var t := b.create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(b, "scale", Vector2(0.93, 0.93), 0.06).set_trans(Tween.TRANS_SINE)

func _soltar(b: Button) -> void:
	if not is_instance_valid(b) or not b.has_meta("pulando"):
		return
	var t := b.create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(b, "scale", Vector2(1.05, 1.05), 0.07).set_trans(Tween.TRANS_SINE)
	t.tween_property(b, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_fim_pulo.bind(b))

func _fim_pulo(b: Button) -> void:
	if is_instance_valid(b):
		b.remove_meta("pulando")

# ------------------------------------------------------------ fundo e cabeçalho das abas
## Fundo das abas: degradê escuro em faixas (pixel art), losangos discretos e cantos mais escuros.
func fundo(pai: Control, base := Color("#0f101a")) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var t := c.size
		var faixas := 8
		for i in faixas:
			var y0 := floorf(t.y * i / faixas)
			var y1 := floorf(t.y * (i + 1) / faixas)
			c.draw_rect(Rect2(0, y0, t.x, y1 - y0), base.lightened(0.05 * (1.0 - float(i) / faixas)))
		var ponto := base.lightened(0.12)
		for y in range(12, int(t.y), 24):
			var x0 := 12 if (y / 24) % 2 == 0 else 24
			for x in range(x0, int(t.x), 24):
				c.draw_rect(Rect2(x, y - 1, 1, 3), ponto)
				c.draw_rect(Rect2(x - 1, y, 3, 1), ponto)
		for i in 4:
			var a := 0.10 + 0.06 * i
			var m := 4.0 * (4 - i)
			c.draw_rect(Rect2(0, 0, m, t.y), Color(0, 0, 0, a))
			c.draw_rect(Rect2(t.x - m, 0, m, t.y), Color(0, 0, 0, a))
			c.draw_rect(Rect2(0, t.y - m, t.x, m), Color(0, 0, 0, a)))
	pai.add_child(c)
	return c

## Cabeçalho das abas (Inventário, Diário, Ranking): faixa com degradê, fio dourado duplo,
## losango dourado antes do título e título dourado com contorno e sombra. Devolve o título.
func cabecalho(pai: Control, chave: String, largura_titulo := 220.0, altura := 44.0) -> Label:
	var faixa := Control.new()
	faixa.position = Vector2.ZERO
	faixa.size = Vector2(360, altura + 4)
	faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faixa.draw.connect(func():
		var cores := [Color("#232742"), Color("#1d2038"), Color("#181a2e"), Color("#14162a")]
		for i in cores.size():
			faixa.draw_rect(Rect2(0, altura * i / cores.size(), 360, altura / cores.size() + 1), cores[i])
		faixa.draw_rect(Rect2(0, 0, 360, 1), Color("#3a3f62"))
		faixa.draw_rect(Rect2(0, altura, 360, 2), COR_OURO)
		faixa.draw_rect(Rect2(0, altura, 360, 1), COR_OURO_CLARO)
		faixa.draw_rect(Rect2(0, altura + 2, 360, 2), Color(0, 0, 0, 0.45))
		var cy := altura / 2.0
		for d in [Vector2(12, cy)]:
			faixa.draw_colored_polygon(PackedVector2Array([d + Vector2(0, -5), d + Vector2(5, 0), d + Vector2(0, 5), d + Vector2(-5, 0)]), Color("#7a4a12"))
			faixa.draw_colored_polygon(PackedVector2Array([d + Vector2(0, -3), d + Vector2(3, 0), d + Vector2(0, 3), d + Vector2(-3, 0)]), COR_OURO_CLARO))
	pai.add_child(faixa)
	var titulo := rotulo(chave, 24)
	titulo.add_theme_color_override("font_color", COR_OURO_CLARO)
	titulo.add_theme_constant_override("outline_size", 4)
	titulo.add_theme_color_override("font_outline_color", Color("#2a1830"))
	titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	titulo.add_theme_constant_override("shadow_offset_x", 0)
	titulo.add_theme_constant_override("shadow_offset_y", 2)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.position = Vector2(24, 4)
	titulo.size = Vector2(largura_titulo, altura - 8)
	pai.add_child(titulo)
	return titulo
