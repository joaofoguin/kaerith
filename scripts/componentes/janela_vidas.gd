class_name JanelaVidas
extends Control
## Popup das vidas: 5 corações, tempo até a próxima vida e, com zero vidas, a recarga por 80 cristais.
## Tem também as opções de teste (perder 1 vida e recarga rápida).

signal fechou

const LARGURA := 300.0

var painel: PanelContainer
var coracoes: Array = []
var rot_estado: Label
var rot_tempo: Label
var bt_recarga: Button
var bt_video: Button
var chk_rapido: CheckButton
var _seg := 0.0
var _encaixado := false
var _estado := -1          # 0 cheias, 1 contando, 2 zeradas (muda a altura do popup)

static func abrir(pai: Node) -> JanelaVidas:
	var j := JanelaVidas.new()
	pai.add_child(j)
	return j

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Tema.elevar(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veu := ColorRect.new()
	veu.color = Color(0, 0, 0, 0.6)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			fechar())
	add_child(veu)
	painel = PanelContainer.new()
	painel.custom_minimum_size = Vector2(LARGURA, 0)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 10)
	painel.add_child(c)
	add_child(painel)

	var t := Tema.rotulo("VIDAS_TITULO", 24)
	t.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	c.add_child(t)
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 6)
	for i in Vidas.MAX:
		var h := TextureRect.new()
		h.texture = load("res://artes/interface/icone16_vida.png")
		h.custom_minimum_size = Vector2(36, 36)
		h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		h.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		h.pivot_offset = Vector2(18, 18)
		linha.add_child(h)
		coracoes.append(h)
	c.add_child(linha)
	rot_estado = Tema.rotulo("", 16)
	rot_estado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rot_estado.custom_minimum_size = Vector2(LARGURA - 28, 0)
	c.add_child(rot_estado)
	rot_tempo = Tema.rotulo("", 24, true)
	c.add_child(rot_tempo)

	bt_recarga = Button.new()
	bt_recarga.custom_minimum_size = Vector2(0, 44)
	bt_recarga.icon = load("res://artes/interface/icone16_cristal.png")
	Tema.estilo_botao(bt_recarga, "confirmar")
	bt_recarga.pressed.connect(_recarregar)
	c.add_child(bt_recarga)
	bt_video = Button.new()
	bt_video.text = "VIDAS_VIDEO"
	bt_video.custom_minimum_size = Vector2(0, 44)
	Tema.estilo_botao(bt_video, "primario")
	bt_video.pressed.connect(_video)
	c.add_child(bt_video)

	# opções de teste
	var teste := HBoxContainer.new()
	teste.add_theme_constant_override("separation", 6)
	var menos := Button.new()
	menos.text = "VIDAS_TESTE_MENOS"
	menos.add_theme_font_size_override("font_size", 12)
	Tema.estilo_botao(menos, "secundario")
	menos.pressed.connect(_perder_teste)
	teste.add_child(menos)
	chk_rapido = CheckButton.new()
	chk_rapido.text = "VIDAS_TESTE_RAPIDO"
	chk_rapido.add_theme_font_size_override("font_size", 10)
	chk_rapido.button_pressed = bool(Jogo.dados.get("vidas_teste_rapido", false))
	chk_rapido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chk_rapido.toggled.connect(_rapido)
	teste.add_child(chk_rapido)
	if Jogo.adm():                   # opções de teste só na versão ADM
		c.add_child(teste)
	else:
		teste.queue_free()

	var fechar_bt := Button.new()
	fechar_bt.text = "FECHAR"
	fechar_bt.custom_minimum_size = Vector2(0, 40)
	Tema.estilo_botao(fechar_bt, "secundario")
	fechar_bt.pressed.connect(fechar)
	c.add_child(fechar_bt)

	_atualizar()
	painel.modulate.a = 0.0
	_encaixar.call_deferred()

func _encaixar() -> void:
	await get_tree().process_frame
	painel.reset_size()
	var tela := size if size.y > 0.0 else get_viewport_rect().size
	painel.position = ((tela - painel.size) / 2.0).floor()
	painel.pivot_offset = painel.size / 2.0
	painel.scale = Vector2(0.9, 0.9)
	Tema.manter_centrado(painel, tela.y - 64.0)
	Tema.ajustar_depois(self)
	_encaixado = true
	var tw := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tw.tween_property(painel, "modulate:a", 1.0, 0.18)
	tw.tween_property(painel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	_seg += delta
	if _seg >= 0.25:
		_seg = 0.0
		_atualizar()

func _atualizar() -> void:
	var v := Vidas.qtd()
	for i in coracoes.size():
		var h: TextureRect = coracoes[i]
		h.modulate = Color.WHITE if i < v else Color(0.25, 0.25, 0.32)
	if v >= Vidas.MAX:
		rot_estado.text = tr("VIDAS_CHEIAS")
		rot_tempo.text = ""
	else:
		rot_estado.text = tr("VIDAS_PROXIMA") % [v, Vidas.MAX]
		rot_tempo.text = Vidas.texto_faltam()
	bt_recarga.visible = v <= 0
	bt_video.visible = v <= 0 and Anuncios.disponivel()
	var estado := 0 if v >= Vidas.MAX else (2 if v <= 0 else 1)
	if estado != _estado:
		_estado = estado
		if _encaixado:
			painel.reset_size.call_deferred()      # encolhe ou cresce e volta ao centro
	if int(Jogo.dados["cristais"]) >= Vidas.PRECO_RECARGA:
		bt_recarga.text = tr("VIDAS_RECARREGAR") % Vidas.PRECO_RECARGA
		bt_recarga.disabled = false
	else:
		bt_recarga.text = tr("VIDAS_SEM_CRISTAIS") % Vidas.PRECO_RECARGA
		bt_recarga.disabled = true

func _recarregar() -> void:
	if not Vidas.recarregar():
		return
	_atualizar()
	for i in coracoes.size():
		var h: TextureRect = coracoes[i]
		var tw := create_tween()
		tw.tween_interval(i * 0.07)
		tw.tween_property(h, "scale", Vector2(1.5, 1.5), 0.1)
		tw.tween_property(h, "scale", Vector2.ONE, 0.15)

func _video() -> void:
	Anuncios.mostrar_video(self, func(ok: bool):
		if ok and is_instance_valid(self):
			Vidas.ganhar(1)
			_atualizar()
			var h: TextureRect = coracoes[0]
			var tw := create_tween()
			tw.tween_property(h, "scale", Vector2(1.6, 1.6), 0.12)
			tw.tween_property(h, "scale", Vector2.ONE, 0.18))

func _perder_teste() -> void:
	Vidas.gastar()
	Jogo.progresso_mudou.emit()
	_atualizar()

func _rapido(on: bool) -> void:
	Jogo.dados["vidas_teste_rapido"] = on
	if Vidas.qtd() < Vidas.MAX:
		Jogo.dados["vidas_desde"] = Vidas.agora()     # recomeça a contagem no novo ritmo
	Jogo.salvar()
	_atualizar()

func fechar() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
	fechou.emit()
