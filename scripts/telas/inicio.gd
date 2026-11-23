extends Tela
const TEMPORADA := preload("res://scripts/temporada.gd")
const POPUP_ATO := preload("res://scripts/componentes/popup_ato.gd")
const POPUP_PROMOCAO := preload("res://scripts/componentes/popup_promocao.gd")
## Início no layout APROVADO do kit (v6): biblioteca com velas animadas e bordas escuras; HUD só com recursos
## (vidas com o relógio, moedas, cristais) e engrenagem; caixa da temporada com o lugar atual; botões redondos
## (Evento e Promoção à esquerda, Ato e Ler QR à direita, o QR em dourado e pulsando); herói ×3 no tapete;
## emblema de nível com a placa do nome e a barra de XP; botão "Jogar fase n". As opções de teste (reiniciar,
## galeria) e o idioma ficam na engrenagem. Peças em artes/inicio/ (ferramentas/montar_inicio.py).

const PASTA := "res://artes/inicio/"
const POS_HEROI := Vector2(108, 258)

var fundo: TextureRect
var _quadros: Array[Texture2D] = []
var _q := 0
var _t := 0.0
var botao_jogar: Button
var heroi: HeroiFrente
var contadores := {}
var rotulo_tempo_vida: Label
var rotulo_lugar: Label
var rotulo_temporada: Label
var rotulo_ato: Label
var numeral_ato: Label
var _botoes_promo: Array = []      # [botão, fita, rótulo do tempo, fim]
var _versao_promos := -1            # ConfigRemota.versao quando os botões foram montados
var bevento: Control                # botão Evento (some quando o Firebase desliga)
var rotulo_nivel: Label
var rotulo_nome: Label
var barra_xp: ProgressBar
var bqr: Control
var popup: Janela
var confirmar_reinicio := false

func montar() -> void:
	for q in 4:
		_quadros.append(load(PASTA + "fundo_q%d.png" % q))
	fundo = TextureRect.new()
	fundo.texture = _quadros[0]
	fundo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fundo.position = Vector2.ZERO
	fundo.size = Vector2(360, 584)
	add_child(fundo)
	# telas mais altas que 584: o assoalho continua para baixo (as duas fileiras de tábuas do fim da
	# pintura, repetidas e um pouco mais escuras) e o botão Jogar desce junto
	var tabuas := AtlasTexture.new()
	tabuas.atlas = _quadros[0]
	tabuas.region = Rect2(0, 504, 360, 54)
	_piso = TextureRect.new()
	_piso.texture = tabuas
	_piso.stretch_mode = TextureRect.STRETCH_TILE
	_piso.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_piso.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_piso.modulate = Color(0.72, 0.72, 0.72)
	_piso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_piso.position = Vector2(0, 584)
	_piso.size = Vector2(360, 0)
	add_child(_piso)

	# herói no tapete (o mesmo pixel ×3 do cenário); tocar abre a tela do personagem
	heroi = HeroiFrente.new()
	heroi.escala = 3
	heroi.position = POS_HEROI
	heroi.size = Vector2(144, 192)
	heroi.mouse_filter = Control.MOUSE_FILTER_STOP
	heroi.gui_input.connect(_toque_heroi)
	heroi.vestir(Jogo.camadas_heroi())
	add_child(heroi)

	_montar_hud()
	_montar_temporada()
	bqr = _redondo("ic_qr.png", "LER_QR", Vector2(284, 236), true, func(): principal.abrir_tela_cheia(preload("res://scripts/telas/ler_qr.gd").new()))
	# Evento: ligado e desligado pelo Firebase (config/inicio.evento); desligado, as promoções sobem para o lugar dele
	bevento = _redondo("ic_evento.png", "EVENTO", Vector2(16, 144), false, _em_breve.bind("EVENTO"))
	# promoções: um botão temático para cada uma (arte da própria oferta + fita com o tempo que falta).
	# Vêm do Firebase (ConfigRemota): no máximo 2 aqui; a Loja mostra todas.
	_montar_promos()
	# ato em curso: numeral romano no lugar do ícone e "Em curso" embaixo; abre o popup do ato
	var ato := _redondo("", "ATO_EM_CURSO", Vector2(284, 144), false, _abrir_ato)
	rotulo_ato = ato.get_meta("rotulo")
	numeral_ato = Tema.rotulo("", 24, true)
	numeral_ato.position = Vector2(0, 14)
	numeral_ato.size = Vector2(60, 32)
	numeral_ato.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	numeral_ato.mouse_filter = Control.MOUSE_FILTER_IGNORE
	numeral_ato.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	numeral_ato.add_theme_constant_override("outline_size", 4)
	numeral_ato.add_theme_color_override("font_outline_color", Color("#2a1608"))
	(ato.get_meta("botao") as Control).add_child(numeral_ato)
	_montar_nome()

	botao_jogar = Button.new()
	botao_jogar.position = Vector2(44, 520)
	botao_jogar.size = Vector2(272, 48)
	botao_jogar.add_theme_font_size_override("font_size", 24)
	Tema.estilo_botao(botao_jogar, "primario")
	botao_jogar.pressed.connect(_abrir_mapa)
	add_child(botao_jogar)

	resized.connect(_ajustar_altura)
	_ajustar_altura.call_deferred()
	atualizar_textos()
	Jogo.tique.connect(_tique_vidas)
	if bool(Jogo.dados.get("presente_pendente", false)):
		_boas_vindas()

var _piso: TextureRect

func _ajustar_altura() -> void:
	var h := size.y
	_piso.size = Vector2(maxf(360.0, size.x), maxf(0.0, h - 584.0))
	# o Jogar fica a 64 px do fim da tela (como no 584 original)
	botao_jogar.position.y = maxf(520.0, floorf(h - 64.0))

func _process(delta: float) -> void:
	_t += delta
	if _t >= 0.125:          # 8 fps, como as velas do kit
		_t = 0.0
		_q = (_q + 1) % 4
		fundo.texture = _quadros[_q]

# ------------------------------------------------------------ HUD do topo
func _montar_hud() -> void:
	var faixa := ColorRect.new()
	faixa.color = Color("#181a28")
	faixa.size = Vector2(360, 46)
	add_child(faixa)
	var ouro := ColorRect.new()
	ouro.color = Tema.COR_OURO
	ouro.position = Vector2(0, 46)
	ouro.size = Vector2(360, 1)
	add_child(ouro)
	var sombra := ColorRect.new()
	sombra.color = Color("#12131c")
	sombra.position = Vector2(0, 47)
	sombra.size = Vector2(360, 1)
	add_child(sombra)
	var vidas := _pilula("hud_vida.png", Vector2(4, 11), 109, true)
	contadores["vidas"] = vidas.get_meta("valor")
	rotulo_tempo_vida = Tema.rotulo("", 8, true)
	rotulo_tempo_vida.set_meta("fonte_fixa", true)
	rotulo_tempo_vida.add_theme_color_override("font_color", Color("#ff8a80"))
	(vidas.get_meta("caixa") as HBoxContainer).add_child(rotulo_tempo_vida)
	(vidas.get_meta("caixa") as HBoxContainer).move_child(rotulo_tempo_vida, 2)
	vidas.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			JanelaVidas.abrir(principal))
	var moedas := _pilula("hud_moeda.png", Vector2(124, 11), 88, false)
	contadores["moedas"] = moedas.get_meta("valor")
	var cristais := _pilula("hud_cristal.png", Vector2(218, 11), 100, true)
	contadores["cristais"] = cristais.get_meta("valor")
	cristais.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			principal.abrir_aba("loja"))
	var cfg := TextureButton.new()
	cfg.texture_normal = load(PASTA + "redondo_pequeno.png")
	cfg.position = Vector2(326, 8)
	cfg.size = Vector2(28, 31)
	cfg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cfg.pressed.connect(_configuracoes)
	var ic := TextureRect.new()
	ic.texture = load(PASTA + "ic_config.png")
	ic.position = Vector2(6, 6)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cfg.add_child(ic)
	add_child(cfg)

## Pílula do HUD (24 px): ícone 20, número em Silkscreen 16 e, se "mais", o + verde no fim.
func _pilula(icone: String, pos: Vector2, largura: float, mais: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = Color("#0e0f18")
	e.border_color = Color("#12131c")
	e.set_border_width_all(2)
	e.set_corner_radius_all(4)
	e.border_width_bottom = 3
	e.content_margin_left = 0
	e.content_margin_right = 2
	p.add_theme_stylebox_override("panel", e)
	p.position = pos
	p.custom_minimum_size = Vector2(largura, 24)
	p.size = Vector2(largura, 24)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var ic := TextureRect.new()
	ic.texture = load(PASTA + icone)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(ic)
	var v := Tema.rotulo("0", 14, true)
	v.set_meta("fonte_fixa", true)       # Vida, moedas e cristais na fonte original (pedido do João)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.clip_text = true
	h.add_child(v)
	if mais:
		var m := TextureRect.new()
		m.texture = load(PASTA + "hud_mais.png")
		m.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		m.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.add_child(m)
	p.add_child(h)
	p.set_meta("valor", v)
	p.set_meta("caixa", h)
	add_child(p)
	return p

# ------------------------------------------------------------ temporada, botões redondos, nome
func _montar_temporada() -> void:
	var tp := PanelContainer.new()
	tp.position = Vector2(40, 58)
	tp.size = Vector2(280, 68)
	tp.custom_minimum_size = Vector2(280, 68)
	tp.mouse_filter = Control.MOUSE_FILTER_STOP
	tp.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_abrir_mapa())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	rotulo_temporada = Tema.rotulo("", 16)
	rotulo_temporada.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	v.add_child(rotulo_temporada)
	rotulo_lugar = Tema.rotulo("", 24)
	rotulo_lugar.add_theme_constant_override("outline_size", 4)
	rotulo_lugar.add_theme_color_override("font_outline_color", Color("#12131c"))
	v.add_child(rotulo_lugar)
	tp.add_child(v)
	add_child(tp)

## Botão redondo de 60 px com ícone 32 e plaquinha do nome embaixo (Pixelify 16).
func _redondo(icone: String, chave: String, pos: Vector2, dourado: bool, acao: Callable) -> Control:
	var caixa := Control.new()
	caixa.position = pos
	caixa.size = Vector2(60, 82)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var b := TextureButton.new()
	b.texture_normal = load(PASTA + ("redondo_primario.png" if dourado else "redondo_secundario.png"))
	b.size = Vector2(60, 63)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.pressed.connect(acao)
	b.button_down.connect(func(): b.position.y = 2)
	b.button_up.connect(func(): b.position.y = 0)
	if icone != "":
		var ic := TextureRect.new()
		ic.texture = load(PASTA + icone)
		ic.position = Vector2(14, 14)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_child(ic)
	caixa.add_child(b)
	var placa := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = Color("#181a28")
	e.border_color = Color("#12131c")
	e.set_border_width_all(1)
	e.content_margin_left = 5
	e.content_margin_right = 5
	placa.add_theme_stylebox_override("panel", e)
	placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := Tema.rotulo(chave, 16)
	r.add_theme_constant_override("line_spacing", -4)
	placa.add_child(r)
	caixa.add_child(placa)
	# a plaquinha fica centrada embaixo do botão, mesmo quando o texto muda de largura
	placa.resized.connect(func(): placa.position = Vector2(floorf((60.0 - placa.size.x) / 2.0), 61))
	caixa.set_meta("rotulo", r)
	caixa.set_meta("botao", b)
	add_child(caixa)
	return caixa

func _montar_nome() -> void:
	var gx := 82.0
	var gy := 452.0
	var placa := TextureRect.new()
	placa.texture = load(PASTA + "placa_nome.png")
	placa.position = Vector2(gx + 26, gy + 6)
	placa.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(placa)
	rotulo_nome = Tema.rotulo("", 24)
	rotulo_nome.position = Vector2(gx + 52, gy + 6)
	rotulo_nome.size = Vector2(144, 32)
	rotulo_nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotulo_nome.add_theme_constant_override("outline_size", 4)
	rotulo_nome.add_theme_color_override("font_outline_color", Color("#3a1020"))
	rotulo_nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(rotulo_nome)
	barra_xp = ProgressBar.new()
	barra_xp.show_percentage = false
	barra_xp.position = Vector2(gx + 54, gy + 38)
	barra_xp.size = Vector2(140, 8)
	barra_xp.custom_minimum_size = Vector2(140, 8)
	var fundo_b := StyleBoxFlat.new()
	fundo_b.bg_color = Color("#0e0f18")
	fundo_b.border_color = Color("#12131c")
	fundo_b.set_border_width_all(1)
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = Color("#6cc4ff")
	cheio.border_color = Color("#12131c")
	cheio.set_border_width_all(1)
	barra_xp.add_theme_stylebox_override("background", fundo_b)
	barra_xp.add_theme_stylebox_override("fill", cheio)
	add_child(barra_xp)
	var em := TextureRect.new()
	em.texture = load(PASTA + "emblema_nivel.png")
	em.position = Vector2(gx, gy - 4)
	em.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(em)
	var nv := Tema.rotulo("NV", 16)
	nv.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	nv.position = Vector2(gx, gy + 2)
	nv.size = Vector2(52, 16)
	em.add_child(nv)
	nv.position = Vector2(0, 5)
	rotulo_nivel = Tema.rotulo("", 24)
	rotulo_nivel.position = Vector2(0, 18)
	rotulo_nivel.size = Vector2(52, 24)
	rotulo_nivel.add_theme_constant_override("outline_size", 4)
	rotulo_nivel.add_theme_color_override("font_outline_color", Color("#3a1020"))
	em.add_child(rotulo_nivel)

func _boas_vindas() -> void:
	await get_tree().create_timer(0.8).timeout
	if not is_inside_tree() or not bool(Jogo.dados.get("presente_pendente", false)):
		return
	var pocao := Artes.icone("pocao32_pocao_de_vida_i")
	var ic_pocao: Texture2D = null
	if not pocao.is_empty():
		var at := AtlasTexture.new()
		at.atlas = pocao["tex"]
		at.region = pocao["rect"]
		ic_pocao = at
	var r := PopupResultado.new()
	r.tipo = "presente"
	r.titulo = tr("BV_TITULO")
	r.subtitulo = tr("BV_SUB").to_upper()
	r.texto = tr("BV_TEXTO") % Jogo.nome_heroi()
	r.secao = "BV_RECEBE"
	r.linhas = [
		{"icone": PopupResultado.icone("moeda"), "nome": tr("BV_L_MOEDAS"), "valor": 500},
		{"icone": PopupResultado.icone("cristal"), "nome": tr("BV_L_CRISTAIS"), "valor": 20},
		{"icone": ic_pocao, "nome": tr("BV_L_POCAO"), "valor": 3, "pre": "x"},
	]
	r.botoes = [["BV_COLETAR", _coletar_presente, "primario"]]
	principal.add_child(r)

func _coletar_presente() -> void:
	if not bool(Jogo.dados.get("presente_pendente", false)):
		return
	Jogo.dados["presente_pendente"] = false
	Jogo.dar_presente()
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	atualizar_textos()
	# os contadores dão um pulinho para mostrar que o presente entrou
	for k in ["moedas", "cristais"]:
		var l: Label = contadores[k]
		l.pivot_offset = l.size / 2.0
		var t := create_tween()
		t.tween_property(l, "scale", Vector2(1.6, 1.6), 0.12)
		t.tween_property(l, "scale", Vector2.ONE, 0.2)


func _toque_heroi(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		principal.abrir_tela_cheia(preload("res://scripts/telas/personagem.gd").new())

func atualizar_textos() -> void:
	var fase: int = Jogo.dados["fase_atual"]
	var ato := clampi(int((fase - 1) / 75) + 1, 1, 4)
	botao_jogar.text = tr("JOGAR_FASE") % fase
	Tema.caber_botao(botao_jogar)
	rotulo_temporada.text = tr("TEMPORADA_ATO") % ato
	rotulo_lugar.text = _nome_ato(ato)
	numeral_ato.text = TEMPORADA.romano(TEMPORADA.ato_em_curso())
	rotulo_nivel.text = str(int(Jogo.dados["nivel"]))
	rotulo_nome.text = Jogo.nome_heroi()
	Tema.caber(rotulo_nome, 140.0, 30.0, 1, [24, 16])
	var n := int(Jogo.dados["nivel"])
	barra_xp.max_value = maxf(1.0, float(Jogo.xp_para(n)))
	barra_xp.value = float(Jogo.dados["xp"])
	contadores["moedas"].text = _num(int(Jogo.dados["moedas"]))
	contadores["cristais"].text = _num(int(Jogo.dados["cristais"]))
	_tique_vidas()
	_tique_promos()
	heroi.vestir(Jogo.camadas_heroi())

func _nome_ato(ato: int) -> String:
	var f := FileAccess.get_file_as_string("res://dados/mapa.json")
	var d = JSON.parse_string(f)
	if d is Dictionary:
		return str(d["nomes"][str(ato)])
	return ""

func _num(n: int) -> String:
	var s := str(n)
	var r := ""
	var k := 0
	for i in range(s.length() - 1, -1, -1):
		r = s[i] + r
		k += 1
		if k % 3 == 0 and i > 0:
			r = "." + r
	return r

## Relógio da próxima vida dentro da pílula (some com as vidas cheias).
func _tique_vidas() -> void:
	_tique_promos()
	if rotulo_tempo_vida == null:
		return
	contadores["vidas"].text = "%d/%d" % [Vidas.qtd(), Vidas.MAX]
	rotulo_tempo_vida.text = Vidas.texto_faltam() if Vidas.qtd() < Vidas.MAX else ""

func _abrir_mapa() -> void:
	principal.abrir_tela_cheia(preload("res://scripts/telas/mapa.gd").new())

func _abrir_ato() -> void:
	_fechar_popup()
	var p = POPUP_ATO.new()
	p.ato = TEMPORADA.ato_em_curso()
	p.ao_ver_mapa = _abrir_mapa
	add_child(p)

func _abrir_promocao(id: String) -> void:
	_fechar_popup()
	var p = POPUP_PROMOCAO.new()
	p.promo = id
	add_child(p)

## Refaz os botões das promoções (no máximo 2) com a lista do Firebase.
func _montar_promos() -> void:
	for par in _botoes_promo:
		(par[0] as Node).queue_free()
		(par[1] as Node).queue_free()
	_botoes_promo.clear()
	var lista := ConfigRemota.promocoes()
	_versao_promos = ConfigRemota.versao
	var com_evento := ConfigRemota.evento_ligado()
	if bevento:
		bevento.visible = com_evento
	var posicoes := [Vector2(10, 228), Vector2(10, 316)] if com_evento else [Vector2(10, 144), Vector2(10, 232)]
	for i in mini(lista.size(), posicoes.size()):
		var p: Dictionary = lista[i]
		_botoes_promo.append(_botao_promo(p, posicoes[i]))

## Botão lateral de uma promoção: ícone 72×72 da oferta (pula de leve) e fita vermelha com o tempo.
func _botao_promo(p: Dictionary, pos: Vector2) -> Array:
	var id := str(p["id"])
	var fim := int(p["fim"])
	var b := TextureButton.new()
	b.texture_normal = POPUP_PROMOCAO.icone_da(p)      # arte nova do site (campo "icone") ou a do modelo
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.position = pos
	b.size = Vector2(72, 72)
	b.pivot_offset = Vector2(36, 36)
	b.pressed.connect(_abrir_promocao.bind(id))
	add_child(b)
	var fita := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = Color("#c8283a")
	e.border_color = Color("#12081a")
	e.set_border_width_all(2)
	e.set_corner_radius_all(3)
	e.content_margin_left = 4
	e.content_margin_right = 4
	e.content_margin_top = 1
	e.content_margin_bottom = 2
	fita.add_theme_stylebox_override("panel", e)
	fita.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r := Tema.rotulo("", 8, true)
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.add_theme_color_override("font_color", Color.WHITE)
	fita.add_child(r)
	add_child(fita)
	fita.resized.connect(func(): fita.position = Vector2(floorf(pos.x + 36 - fita.size.x / 2.0), pos.y + 62))
	return [b, fita, r, fim]

## Tempo nas fitas das promoções (o fim vem do Firebase). Config nova ou promoção vencida: refaz os botões.
func _tique_promos() -> void:
	var t := ConfigRemota.agora()
	var refazer := ConfigRemota.versao != _versao_promos
	for par in _botoes_promo:
		if t >= int(par[3]):
			refazer = true
	if refazer:
		_montar_promos()
	for par in _botoes_promo:
		(par[2] as Label).text = TEMPORADA.texto_tempo(maxi(0, int(par[3]) - t))

func _em_breve(chave: String) -> void:
	_fechar_popup()
	popup = Janela.criar(tr(chave), [["OK", _fechar_popup]], tr("EM_BREVE_TEXTO"))
	add_child(popup)

func _fechar_popup() -> void:
	if popup:
		popup.fechar()
		popup = null

# ------------------------------------------------------------ engrenagem: idioma e opções de teste
func _configuracoes() -> void:
	_fechar_popup()
	principal.abrir_tela_cheia(preload("res://scripts/telas/configuracoes.gd").new())

func _trocar_idioma() -> void:
	Jogo.trocar_idioma("en" if Jogo.dados["idioma"] == "pt" else "pt")

## Dois toques: o primeiro pede confirmação, o segundo zera o progresso.
func _reiniciar() -> void:
	if not confirmar_reinicio:
		confirmar_reinicio = true
		_fechar_popup()
		popup = Janela.criar(tr("REINICIAR_TESTE"), [["REINICIAR_SIM", _reiniciar], ["CANCELAR", _fechar_popup]], tr("REINICIAR_AVISO"))
		add_child(popup)
		return
	confirmar_reinicio = false
	_fechar_popup()
	Jogo.reiniciar()
	principal.seguir_criacao()       # volta ao Prólogo, como num jogo novo
