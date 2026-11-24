extends Control
## Cena principal: área das telas + barra de baixo (Loja, Diário, Início, Inventário, Ranking).

const ABAS := [
	{"id": "loja", "chave": "ABA_LOJA"},
	{"id": "diario", "chave": "ABA_DIARIO"},
	{"id": "inicio", "chave": "ABA_INICIO"},
	{"id": "inventario", "chave": "ABA_INVENTARIO"},
	{"id": "ranking", "chave": "ABA_RANKING"},
]
const ALTURA_BARRA := 56
const NOVIDADES := preload("res://scripts/novidades.gd")

var conteudo: Control
var barra: HBoxContainer
var botoes_aba := {}
var aba_atual := ""
var tela_cheia: Control = null
var veu: ColorRect                 # cortina das transições (escurece, troca a tela, clareia)
var _em_transicao := false

func _ready() -> void:
	theme = Tema.tema
	add_to_group("principal")        # os popups sobem para cá (por cima da barra de baixo)
	# tela de carregamento (logo, artes, login online) antes de montar o jogo
	var carregando := preload("res://scripts/componentes/tela_carregando.gd").new()
	carregando.theme = Tema.tema
	get_tree().root.add_child.call_deferred(carregando)
	await carregando.concluido
	Anuncios.iniciar()               # AdMob (Android) / AdSense (Web), quando configurados
	# celular: o jogo não entra embaixo do recorte da câmera / barra de status (área segura do aparelho)
	RenderingServer.set_default_clear_color(Color.BLACK)
	_aplicar_area_segura()
	get_viewport().size_changed.connect(_aplicar_area_segura)
	Jogo.progresso_mudou.connect(func(): Online.sincronizar())     # ranking online (só se configurado)
	# conecta logo ao abrir o jogo (antes só conectava ao mudar o progresso ou abrir o Ranking)
	(func(): Online.sincronizar(true)).call_deferred()
	var fundo := ColorRect.new()
	fundo.color = Tema.COR_FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	conteudo = Control.new()
	conteudo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	conteudo.offset_bottom = -ALTURA_BARRA
	add_child(conteudo)

	# 0.8.3: missões de Bestiário com a ficha completada no QR antes da correção fecham agora (o "!" aparece no Diário)
	var hist := preload("res://scripts/historia.gd")
	var fechadas: Array = hist.conferir_bestiario()
	if not fechadas.is_empty():
		hist.falas_de_conclusao(fechadas)     # só para liberar a próxima missão do NPC, se houver (sem a cena)
		Jogo.salvar()
	_montar_barra()
	veu = ColorRect.new()
	veu.color = Color.BLACK
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veu)
	abrir_aba("inicio")
	if str(Jogo.dados.get("etapa", "pronto")) != "pronto":
		seguir_criacao()                 # a própria transição clareia a tela
	else:
		_em_transicao = true
		_clarear(0.6)
		if not _volta_do_google():
			_qr_do_link()
			_aviso_novidades()
	if str(Jogo.dados.get("etapa", "pronto")) != "pronto":
		NOVIDADES.marcar_visto()         # jogador novo: as novidades já fazem parte do jogo dele
		_qr_do_link()                    # antes do Início só guarda o código (o thread do QR trata)

## Aviso de uma versão nova (scripts/novidades.gd), uma vez, para quem já tinha começado a jornada.
## 0.8.0: as missões secundárias dos moradores; "Ver missões" abre o Diário na aba Missões.
func _aviso_novidades() -> void:
	var v := NOVIDADES.aviso_pendente()
	if v.is_empty():
		return
	await get_tree().create_timer(0.8).timeout
	if tela_cheia != null:               # algo abriu por cima (QR do link etc.): mostra na próxima vez
		return
	var id := str(v["aviso"])
	if id == "missoes":
		NOVIDADES.entregar_missoes_antigas()
	NOVIDADES.marcar_visto(id)                # também salva o save (com as missões entregues)
	atualizar_selos()
	var j := Janela.criar(tr("AVISO_%s_T" % id), [], tr("AVISO_%s" % id))
	j.botoes = [                         # depois de criar: o lambda precisa da janela já pronta
		["AVISO_VER_MISSOES", func():
			j.fechar()
			abrir_aba("diario")
			var d := conteudo.get_child(conteudo.get_child_count() - 1)
			if d.has_method("_trocar_aba"):
				d.call("_trocar_aba", 1)],
		["OK", func(): j.fechar()]]
	add_child(j)

## Voltou para o jogo (trocou de app ou de aba): confere se outro aparelho mandou progresso para a nuvem.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		if conteudo:                      # o jogo já está montado (passou da tela de carregamento)
			Online.sincronizar_ao_voltar()

## Web: o jogador saiu para o Google pelas Configurações ("Salvar progresso com Google") e a página recarregou.
## Reabre as Configurações, que terminam a ligação da conta. (Na tela de entrada quem trata é ela mesma.)
func _volta_do_google() -> bool:
	var r := Conta.retorno()
	if r.is_empty():
		return false
	var cfg = preload("res://scripts/telas/configuracoes.gd").new()
	cfg.retorno_google = r
	abrir_tela_cheia(cfg)
	return true

## Web: QR lido pela câmera comum do celular abre o site com "#qr=..." e o jogo faz a ação (scripts/qr/link_qr.gd).
## Carregado pelo caminho (sem depender do class_name ser reconhecido pelo editor).
func _qr_do_link() -> void:
	if not OS.has_feature("web") or not ResourceLoader.exists("res://scripts/qr/link_qr.gd"):
		return
	load("res://scripts/qr/link_qr.gd").abrir_pendente(self)

## Recua a tela inteira (barra de baixo e popups juntos) pela área segura do Android/iOS.
func _aplicar_area_segura() -> void:
	if not OS.has_feature("mobile"):
		return
	var seguro := DisplayServer.get_display_safe_area()
	var janela := DisplayServer.window_get_size()
	if janela.y <= 0 or seguro.size.y <= 0:
		return
	var esc := get_viewport().get_visible_rect().size.y / float(janela.y)
	offset_top = roundf(maxf(0.0, seguro.position.y * esc))
	offset_bottom = -roundf(maxf(0.0, (janela.y - seguro.end.y) * esc))

## Criação do personagem, na ordem: Prólogo → criação → tutorial 1 → tutorial 2 (Despertar) → jogo.
func seguir_criacao() -> void:
	var tela: Tela = null
	match str(Jogo.dados.get("etapa", "pronto")):
		"prologo":
			tela = preload("res://scripts/telas/prologo.gd").new()
		"login":
			tela = preload("res://scripts/telas/entrada.gd").new()
		"criacao":
			tela = preload("res://scripts/telas/criacao.gd").new()
		"chegada":
			tela = preload("res://scripts/telas/chegada.gd").new()
		"tutorial1", "tutorial2":
			tela = preload("res://scripts/telas/combate.gd").new()
			tela.set("tutorial", 1 if Jogo.dados["etapa"] == "tutorial1" else 2)
	if tela:
		abrir_tela_cheia(tela)
	else:
		_transicao(_voltar_ao_inicio)

func _montar_barra() -> void:
	var fundo_barra := PanelContainer.new()
	fundo_barra.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fundo_barra.offset_top = -ALTURA_BARRA
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Tema.COR_PAINEL
	estilo.border_color = Color("#545a74")
	estilo.border_width_top = 2
	fundo_barra.add_theme_stylebox_override("panel", estilo)
	add_child(fundo_barra)

	# fios entre as abas, como no kit aprovado
	var fios := Control.new()
	fios.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fios.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fios.draw.connect(func():
		for i in range(1, ABAS.size()):
			var x := floorf(360.0 * i / ABAS.size())
			fios.draw_rect(Rect2(x, 10, 1, ALTURA_BARRA - 20), Color("#2c3048")))
	fundo_barra.add_child(fios)

	barra = HBoxContainer.new()
	barra.add_theme_constant_override("separation", 0)
	fundo_barra.add_child(barra)
	for aba in ABAS:
		var b := Button.new()
		b.toggle_mode = true
		b.set_meta("sem_pulo", true)          # a aba tem o próprio pulo (ao ser escolhida)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, ALTURA_BARRA - 2)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = false
		b.text = aba["chave"]
		b.add_theme_font_override("font", Tema.fonte_numeros)
		b.add_theme_font_size_override("font_size", 8)
		var vazio := StyleBoxEmpty.new()
		vazio.content_margin_top = 8
		vazio.content_margin_bottom = 6
		for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(s, vazio)
		# aba escolhida: placa mais clara que sobe 10 px acima da barra, com moldura dourada
		var sel := StyleBoxFlat.new()
		sel.bg_color = Color("#2a2434")
		sel.border_color = Tema.COR_OURO
		sel.set_border_width_all(2)
		sel.border_width_bottom = 0
		sel.expand_margin_top = 10
		sel.expand_margin_left = 2
		sel.expand_margin_right = 2
		sel.content_margin_top = 0
		sel.content_margin_bottom = 8
		sel.shadow_color = Color(Tema.COR_OURO, 0.18)
		sel.shadow_size = 4
		b.add_theme_stylebox_override("pressed", sel)
		b.add_theme_stylebox_override("hover_pressed", sel)
		b.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
		b.add_theme_color_override("font_hover_color", Tema.COR_TEXTO_APAGADO)
		b.add_theme_color_override("font_pressed_color", Tema.COR_OURO_CLARO)
		b.add_theme_color_override("font_hover_pressed_color", Tema.COR_OURO_CLARO)
		b.pressed.connect(abrir_aba.bind(aba["id"]))
		b.add_child(_selo())
		barra.add_child(b)
		botoes_aba[aba["id"]] = b
	Jogo.progresso_mudou.connect(atualizar_selos)

## Bolinha vermelha com "!" no canto do ícone da aba (tem novidade lá dentro).
func _selo() -> Control:
	var p := Panel.new()
	p.name = "selo"
	var e := StyleBoxFlat.new()
	e.bg_color = Color("#d8394a")
	e.border_color = Color("#4a0c18")
	e.set_border_width_all(1)
	e.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", e)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.offset_left = 8
	p.offset_right = 20
	p.offset_top = 2
	p.offset_bottom = 14
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = "!"
	l.add_theme_font_override("font", Tema.fonte_numeros)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.add_child(l)
	p.visible = false
	return p

## Diário: espécie ou personagem novo ainda não aberto. Inventário: peça nova ainda não vista.
func atualizar_selos() -> void:
	var tem := {"diario": Bestiario.tem_novidade(), "inventario": false}
	for p in Equipamento.lista():
		if bool((p as Dictionary).get("novo", false)):
			tem["inventario"] = true
			break
	for id in botoes_aba:
		var selo: Control = botoes_aba[id].get_node("selo")
		selo.visible = bool(tem.get(id, false)) and id != aba_atual

func _atualizar_icones() -> void:
	for id in botoes_aba:
		var estado := "selecionado" if id == aba_atual else "normal"
		botoes_aba[id].icon = load("res://artes/interface/barra_%s_%s.png" % [id, estado])
		botoes_aba[id].set_pressed_no_signal(id == aba_atual)
	# a aba escolhida dá um pulinho
	var b: Button = botoes_aba.get(aba_atual)
	if b and b.size.x > 0:
		b.pivot_offset = Vector2(b.size.x / 2.0, b.size.y)
		var t := b.create_tween()
		t.tween_property(b, "scale", Vector2(1.08, 1.08), 0.08).set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	atualizar_selos()

func abrir_aba(id: String) -> void:
	aba_atual = id
	_atualizar_icones()
	for filho in conteudo.get_children():
		filho.queue_free()
	var tela: Tela
	match id:
		"inicio":
			tela = preload("res://scripts/telas/inicio.gd").new()
		"inventario":
			tela = preload("res://scripts/telas/inventario.gd").new()
		"loja":
			tela = preload("res://scripts/telas/loja.gd").new()
		"diario":
			tela = preload("res://scripts/telas/diario.gd").new()
		"ranking":
			tela = preload("res://scripts/telas/ranking.gd").new()
		_:
			tela = preload("res://scripts/telas/em_breve.gd").new()
			tela.set("chave_titulo", "ABA_" + id.to_upper())
	tela.principal = self
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela.modulate.a = 0.0
	conteudo.add_child(tela)
	var t := create_tween()
	t.tween_property(tela, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)

## Abre uma tela por cima de tudo (sem a barra de baixo), como o mapa de fases, com transição suave.
func abrir_tela_cheia(tela: Tela) -> void:
	_transicao(func(): _trocar_tela_cheia(tela))

func _trocar_tela_cheia(tela: Tela) -> void:
	_fechar_ja()
	tela.principal = self
	tela.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tela_cheia = tela
	add_child(tela)

func fechar_tela_cheia() -> void:
	if tela_cheia:
		_transicao(_fechar_ja)

func _fechar_ja() -> void:
	if tela_cheia:
		tela_cheia.queue_free()
		tela_cheia = null

## Escurece (0,3 s), troca a tela e clareia (0,45 s). Ignora a velocidade do combate.
func _transicao(acao: Callable) -> void:
	if _em_transicao:
		acao.call()
		move_child(veu, -1)
		return
	_em_transicao = true
	veu.visible = true
	veu.mouse_filter = Control.MOUSE_FILTER_STOP
	move_child(veu, -1)
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(veu, "color:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_executar_troca.bind(acao))
	t.tween_interval(0.08)
	await t.finished
	_clarear(0.45)

func _executar_troca(acao: Callable) -> void:
	acao.call()
	move_child(veu, -1)

func _voltar_ao_inicio() -> void:
	_fechar_ja()
	abrir_aba("inicio")
	_qr_do_link.call_deferred()      # jogador novo que chegou pelo QR: abre a leitura depois do tutorial

func _clarear(tempo: float) -> void:
	move_child(veu, -1)
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_property(veu, "color:a", 0.0, tempo).set_trans(Tween.TRANS_SINE)
	await t.finished
	veu.visible = false
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_em_transicao = false

func _unhandled_input(evento: InputEvent) -> void:
	# Botão "voltar" do Android fecha a tela cheia.
	if evento.is_action_pressed("ui_cancel") and tela_cheia:
		if tela_cheia.has_method("pedir_saida"):
			tela_cheia.call("pedir_saida")      # no combate, sair = desistir (pergunta antes)
		elif str(Jogo.dados.get("etapa", "pronto")) == "pronto":    # na criação não dá para sair
			fechar_tela_cheia()
