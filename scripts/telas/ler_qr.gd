extends Tela
## Ler QR Code: câmera (quando o aparelho tem) e "Escolher imagem" (foto do QR também vale).
## A leitura roda em segundo plano (LeitorQR) a cada ~0,3 s; o código é conferido pela assinatura (CodigoQR).
## Na Web (navegador/PWA) a câmera e a procura do QR ficam com o JavaScript da página (CameraWeb); a conferência
## da assinatura continua aqui, sem internet.

const QUADRO := Rect2(30, 92, 300, 300)
const INTERVALO := 0.3

var camera: CameraFeed = null
var visor: SubViewport
var tela_cam: TextureRect
var imagem_cam: TextureRect
var sem_camera: Label
var moldura: Control
var status: Label
var info: Label
var popup: Control = null
var _tempo := 0.0
var _anim := 0.0
var _tarefa := -1
var _resultado := ""
var _ultimo_ruim := ""
var _ruim_ate := 0.0
var _parado := false            # depois de uma leitura válida a câmera para
var _seletor: FileDialog
# versão Web
var _web := false
var _estado_web := ""
var _tex_web: ImageTexture = null
var _religar := 0.0
var _esperando_imagem := false
var _conferindo := false         # esperando a hora do servidor
var texto_inicial := ""          # código vindo do link (QR lido pela câmera comum do celular, LinkQR)

func montar() -> void:
	palco_640 = true   # quadro fixo de 360×640 centrado (celulares altos ganham faixas pretas)
	_web = CameraWeb.ativo()
	var fundo := ColorRect.new()
	fundo.color = Color("#0d0e15")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	_montar_topo()
	_montar_visor()
	status = Tema.rotulo("QR_APONTE", 16)
	# preso às bordas da tela (16 px de cada lado): a largura não muda com o texto e ele fica centrado
	status.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status.offset_left = 16
	status.offset_right = -16
	status.offset_top = 404
	status.offset_bottom = 448
	status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_child(status)
	Tema.caber(status, 328, 44, 2, [16, 14, 12])       # a quebra automática do Godot não funcionava aqui
	info = Tema.rotulo("", 12)
	info.position = Vector2(16, 450)
	info.size = Vector2(328, 32)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	add_child(info)

	atualizar_textos()
	if texto_inicial != "":
		_abrir_link.call_deferred()
	else:
		ConfigRemota.baixar()        # abriu a tela do QR: busca na hora os QR desligados no Firebase
		_ligar_camera()

## Site aberto por um QR: faz a ação na hora. Se o código for recusado, mostra o motivo e liga a câmera.
func _abrir_link() -> void:
	await ConfigRemota.baixar()      # QR desligado no Firebase já vale nesta leitura
	await _achou(texto_inicial)
	if not _parado:
		_ligar_camera()

func _montar_topo() -> void:
	var barra := ColorRect.new()
	barra.color = Color("#181a28")
	barra.position = Vector2.ZERO
	barra.size = Vector2(360, 56)
	add_child(barra)
	var fio := ColorRect.new()
	fio.color = Tema.COR_OURO
	fio.position = Vector2(0, 56)
	fio.size = Vector2(360, 2)
	add_child(fio)
	var voltar := Button.new()
	voltar.text = "VOLTAR"
	voltar.position = Vector2(8, 8)
	voltar.size = Vector2(88, 40)
	Tema.estilo_botao(voltar, "secundario")
	voltar.pressed.connect(func(): principal.fechar_tela_cheia())
	add_child(voltar)
	var icone := TextureRect.new()
	icone.texture = load("res://artes/interface/icone24_ler_qr.png")
	icone.position = Vector2(112, 16)
	icone.size = Vector2(24, 24)
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(icone)
	var t := Tema.rotulo("QR_TITULO", 24)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.position = Vector2(142, 10)
	t.size = Vector2(210, 36)
	t.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	add_child(t)

func _montar_visor() -> void:
	var caixa := ColorRect.new()
	caixa.color = Color("#05060a")
	caixa.position = QUADRO.position
	caixa.size = QUADRO.size
	add_child(caixa)
	visor = SubViewport.new()
	visor.size = Vector2i(QUADRO.size)
	visor.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	visor.transparent_bg = false
	tela_cam = TextureRect.new()
	tela_cam.size = QUADRO.size
	tela_cam.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tela_cam.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	visor.add_child(tela_cam)
	add_child(visor)
	imagem_cam = TextureRect.new()
	imagem_cam.texture = visor.get_texture()
	imagem_cam.position = QUADRO.position
	imagem_cam.size = QUADRO.size
	imagem_cam.visible = false
	add_child(imagem_cam)
	# aviso centralizado dentro do quadro; num container a quebra de linha funciona
	var centro := CenterContainer.new()
	centro.position = QUADRO.position
	centro.size = QUADRO.size
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	sem_camera = Tema.rotulo("QR_SEM_CAMERA", 12)
	sem_camera.custom_minimum_size = Vector2(QUADRO.size.x - 60, 0)
	sem_camera.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sem_camera.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	centro.add_child(sem_camera)
	moldura = Control.new()
	moldura.position = QUADRO.position
	moldura.size = QUADRO.size
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.draw.connect(_desenhar_moldura)
	add_child(moldura)

## Cantos dourados e a linha de varredura subindo e descendo.
func _desenhar_moldura() -> void:
	var s := QUADRO.size
	var cor := Tema.COR_OURO
	if Time.get_ticks_msec() / 1000.0 < _ruim_ate:
		cor = Color("#e05a5a")
	var l := 34.0
	var g := 4.0
	var cantos: Array[Vector2] = [Vector2(0, 0), Vector2(s.x, 0), Vector2(0, s.y), s]
	for c: Vector2 in cantos:
		var dx := 1.0 if c.x == 0 else -1.0
		var dy := 1.0 if c.y == 0 else -1.0
		var x0 := c.x if dx > 0 else c.x - l
		var y0 := c.y if dy > 0 else c.y - g
		moldura.draw_rect(Rect2(x0, y0, l, g), cor)
		var x1 := c.x if dx > 0 else c.x - g
		var y1 := c.y if dy > 0 else c.y - l
		moldura.draw_rect(Rect2(x1, y1, g, l), cor)
	if not _parado:
		var y := floorf((0.5 + 0.5 * sin(_anim * 2.2)) * (s.y - 24.0)) + 12.0
		moldura.draw_rect(Rect2(14, y, s.x - 28, 2), Color(cor, 0.85))
		moldura.draw_rect(Rect2(14, y - 6, s.x - 28, 6), Color(cor, 0.12))

# ------------------------------------------------------------ câmera
func _ligar_camera() -> void:
	if _web:
		CameraWeb.ligar()
		return
	if OS.get_name() == "Android":
		OS.request_permissions()
	if "monitoring_feeds" in CameraServer:
		CameraServer.set("monitoring_feeds", true)
		if CameraServer.has_signal("camera_feeds_updated"):
			CameraServer.connect("camera_feeds_updated", _escolher_camera)
	_escolher_camera()

func _escolher_camera() -> void:
	if camera != null or not is_inside_tree():
		return
	var feeds := CameraServer.feeds()
	if feeds.is_empty():
		return
	var escolhida: CameraFeed = feeds[0]
	for f in feeds:
		if f.get_position() == CameraFeed.FEED_BACK:
			escolhida = f
	camera = escolhida
	if camera.has_method("get_formats") and camera.has_method("set_format"):
		var formatos: Array = camera.get_formats()
		var melhor := -1
		var dif := 1 << 30
		for i in formatos.size():
			var fm: Dictionary = formatos[i]
			var d := absi(int(fm.get("width", 0)) - 640)
			if d < dif:
				dif = d
				melhor = i
		if melhor >= 0:
			camera.set_format(melhor, {})
	camera.feed_is_active = true
	var tex := CameraTexture.new()
	tex.camera_feed_id = camera.get_id()
	var dt := camera.get_datatype()
	if dt == CameraFeed.FEED_YCBCR_SEP or dt == CameraFeed.FEED_YCBCR:
		# só a luminância (Y): imagem em tons de cinza, que é o que o leitor usa
		tex.which_feed = CameraServer.FEED_Y_IMAGE
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvoid fragment() { float y = texture(TEXTURE, UV).r; COLOR = vec4(y, y, y, 1.0); }"
		var mat := ShaderMaterial.new()
		mat.shader = sh
		tela_cam.material = mat
	else:
		tex.which_feed = CameraServer.FEED_RGBA_IMAGE
	tela_cam.texture = tex
	imagem_cam.visible = true
	sem_camera.visible = false

func _desligar_camera() -> void:
	if _web:
		CameraWeb.desligar()
		return
	if camera != null:
		camera.feed_is_active = false

func _exit_tree() -> void:
	_desligar_camera()
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1

func _process(delta: float) -> void:
	_anim += delta
	moldura.queue_redraw()
	if _web:
		_process_web(delta)
		return
	if _tarefa >= 0:
		if WorkerThreadPool.is_task_completed(_tarefa):
			WorkerThreadPool.wait_for_task_completion(_tarefa)
			_tarefa = -1
			if _resultado != "":
				_achou(_resultado)
		return
	if _parado or camera == null or popup != null:
		return
	_tempo += delta
	if _tempo < INTERVALO:
		return
	_tempo = 0.0
	var img := visor.get_texture().get_image()
	if img == null or img.is_empty():
		return
	_ler_em_fundo(img)

func _ler_em_fundo(img: Image) -> void:
	LeitorQR._preparar()          # as tabelas são montadas aqui (fio principal) antes da tarefa
	_resultado = ""
	_tarefa = WorkerThreadPool.add_task(func(): _resultado = LeitorQR.ler(img))

# ------------------------------------------------------------ versão Web
func _process_web(delta: float) -> void:
	if _esperando_imagem:
		var r := CameraWeb.resultado_imagem()
		if r != "":
			_esperando_imagem = false
			match r:
				"!erro":
					_mostrar_status("QR_ERRO_IMAGEM", true)
				"!nada":
					_mostrar_status("QR_NAO_ACHOU", true)
				_:
					_ultimo_ruim = ""
					_achou(r)
	if _parado:
		return
	var est := CameraWeb.estado()
	if est != _estado_web:
		_estado_web = est
		_mostrar_estado_web(est)
	if est == "parada":
		# a aba foi escondida (ou a câmera caiu): religa sozinho
		_religar += delta
		if _religar >= 1.0:
			_religar = 0.0
			CameraWeb.ligar()
		return
	if est != "ligada":
		return
	_tempo += delta
	if _tempo >= 1.0 / 15.0:          # prévia a ~15 quadros por segundo
		_tempo = 0.0
		_atualizar_previa_web()
	var t := CameraWeb.lido()
	if t != "" and popup == null:
		_achou(t)

func _atualizar_previa_web() -> void:
	var bytes := CameraWeb.quadro()
	if bytes.size() != CameraWeb.LADO * CameraWeb.LADO * 4:
		return
	var img := Image.create_from_data(CameraWeb.LADO, CameraWeb.LADO, false, Image.FORMAT_RGBA8, bytes)
	if _tex_web == null:
		_tex_web = ImageTexture.create_from_image(img)
		tela_cam.texture = _tex_web
		imagem_cam.visible = true
		sem_camera.visible = false
	else:
		_tex_web.update(img)

func _mostrar_estado_web(est: String) -> void:
	var chave := ""
	match est:
		"pedindo":
			chave = "QR_WEB_PEDINDO"
		"negada":
			chave = "QR_WEB_NEGADA"
		"inseguro":
			chave = "QR_WEB_HTTPS"
		"sem_camera":
			chave = "QR_SEM_CAMERA"
	if est != "ligada":
		_tex_web = null
		imagem_cam.visible = false
	sem_camera.text = chave
	sem_camera.visible = chave != ""

# ------------------------------------------------------------ escolher imagem (foto do QR)
func _escolher_imagem() -> void:
	return # 2026-11-23 (João): QR só pela câmera, presencialmente
	if _web:
		_esperando_imagem = true
		CameraWeb.escolher_imagem()
		return
	if _seletor == null:
		_seletor = FileDialog.new()
		_seletor.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_seletor.access = FileDialog.ACCESS_FILESYSTEM
		_seletor.use_native_dialog = true
		_seletor.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Imagens"])
		_seletor.file_selected.connect(_imagem_escolhida)
		add_child(_seletor)
	_seletor.popup_centered()

func _imagem_escolhida(caminho: String) -> void:
	return # 2026-11-23 (João): QR só pela câmera, presencialmente
	var img := Image.load_from_file(caminho)
	if img == null or img.is_empty():
		_mostrar_status("QR_ERRO_IMAGEM", true)
		return
	_mostrar_status("QR_LENDO", false)
	if _tarefa >= 0:
		WorkerThreadPool.wait_for_task_completion(_tarefa)
		_tarefa = -1
	_ultimo_ruim = ""
	LeitorQR._preparar()
	var t := LeitorQR.ler(img)
	if t == "":
		_mostrar_status("QR_NAO_ACHOU", true)
		return
	_achou(t)

# ------------------------------------------------------------ código lido
func _achou(texto: String) -> void:
	if popup != null or _parado or _conferindo:
		return
	var agora := Time.get_ticks_msec() / 1000.0
	if texto == _ultimo_ruim and agora < _ruim_ate + 2.0:
		return                   # o mesmo código ruim continua na frente da câmera
	var c := CodigoQR.interpretar(texto)
	if not bool(c["ok"]):
		_ruim(texto, str(c["erro"]))
		return
	if c["tipo"] == "evento" and not CodigoQR.evento_ativo().is_empty():
		_ruim(texto, "QR_EVENTO_ATIVO")
		return
	# com internet, confere a hora no servidor antes de olhar o horário (não adianta mudar o relógio do celular)
	_conferindo = true
	_mostrar_status("QR_CONFERINDO", false)
	await CodigoQR.conferir_hora()
	_conferindo = false
	if not is_inside_tree() or popup != null or _parado:
		return
	var b := CodigoQR.bloqueio(int(c["fuso"]), true)
	if b != "":
		_ruim(texto, b)
		if b == "QR_SEM_VIDAS":
			var jv := JanelaVidas.abrir(self)
			popup = jv
			jv.fechou.connect(func(): popup = null)
		return
	if c["tipo"] == "bau" and CodigoQR.bau_usado_hoje(c):
		_ruim(texto, "QR_BAU_JA")
		return
	if c["tipo"] == "recurso" and CodigoQR.recurso_falta(c) > 0:
		_ruim(texto, TranslationServer.translate("QR_RECURSO_ESPERA") % preload("res://scripts/temporada.gd").texto_tempo(CodigoQR.recurso_falta(c)))
		return
	_parado = true
	_desligar_camera()
	CodigoQR.registrar_leitura(c)
	var raro := CodigoQR.sortear_raro()
	_vibrar()
	if Jogo.som != null:
		Jogo.som.efeito("qr_lido")
	_mostrar_status("QR_LIDO", false)
	match str(c["tipo"]):
		"recurso":
			_resultado_recurso(c, raro)
		"bau":
			_popup_bau(c, raro)
		"inimigo":
			_popup_inimigo(c, raro)
		"evento":
			_popup_evento(c, raro)

func _ruim(texto: String, chave: String) -> void:
	_ultimo_ruim = texto
	_ruim_ate = Time.get_ticks_msec() / 1000.0 + 1.5
	if Jogo.som != null:
		Jogo.som.efeito("erro")
	_mostrar_status(chave, true)

func _vibrar() -> void:
	if _web:
		CameraWeb.vibrar(80)
	elif OS.has_feature("mobile"):
		Input.vibrate_handheld(80)

func _mostrar_status(chave: String, erro: bool) -> void:
	status.text = TranslationServer.translate(chave)
	Tema.caber(status, 328, 44, 2, [16, 14, 12])
	status.add_theme_color_override("font_color", Color("#ff8a80") if erro else Tema.COR_TEXTO)
	var t := create_tween()
	status.scale = Vector2(1.06, 1.06)
	status.pivot_offset = status.size / 2.0
	t.tween_property(status, "scale", Vector2.ONE, 0.15)

func atualizar_textos() -> void:
	if info == null:
		return
	var partes: Array = []
	partes.append(tr("QR_INFO_PRONTO"))
	partes.append(tr("QR_INFO_HORARIO"))
	info.text = " · ".join(partes)

func _sub(c: Dictionary) -> String:
	return (tr("QR_N") % int(c["numero"])).to_upper()

# ------------------------------------------------------------ resultados por tipo
func _resultado_recurso(c: Dictionary, raro: bool) -> void:
	var linhas := CodigoQR.dar_recurso(raro)
	_premio(tr("QR_T_RECURSO_RARO") if raro else tr("QR_T_RECURSO"), _sub(c), tr("QR_D_RECURSO"), linhas)

func _premio(titulo: String, sub: String, texto: String, linhas: Array) -> void:
	var r := PopupResultado.new()
	r.tipo = "presente"
	r.titulo = titulo
	r.subtitulo = sub
	r.texto = texto
	r.linhas = linhas
	r.botoes = [["OK", _sair, "primario"]]
	popup = r
	add_child(r)

func _sair() -> void:
	popup = null
	principal.fechar_tela_cheia()

## Baú: mostra só a raridade (comum ou dourado). "Agora não" perde o baú (DEFINIDO).
func _popup_bau(c: Dictionary, dourado: bool) -> void:
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 6)
	var bau := TextureRect.new()
	bau.texture = load("res://artes/interface/icone24_bau.png")
	bau.custom_minimum_size = Vector2(96, 96)
	bau.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bau.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bau.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if dourado:
		bau.modulate = Color(1.25, 1.1, 0.55)
	caixa.add_child(bau)
	var rar := Tema.rotulo("QR_BAU_DOURADO" if dourado else "QR_BAU_COMUM", 24)
	rar.add_theme_color_override("font_color", Tema.COR_OURO_CLARO if dourado else Tema.COR_TEXTO)
	caixa.add_child(rar)
	var aviso := Tema.rotulo("QR_BAU_AVISO", 12)
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.custom_minimum_size = Vector2(260, 0)
	aviso.add_theme_color_override("font_color", Color("#ff8a80"))
	caixa.add_child(aviso)
	_balancar(bau)
	var j := Janela.criar(_sub(c), [["QR_ABRIR_BAU", _abrir_bau.bind(c, dourado)], ["QR_AGORA_NAO", _sair_fechando]], "", [caixa])
	j.destaque = false
	popup = j
	add_child(j)

func _balancar(no: Control) -> void:
	no.pivot_offset = Vector2(48, 60)
	var t := create_tween().set_loops()
	t.tween_property(no, "rotation", 0.08, 0.12)
	t.tween_property(no, "rotation", -0.08, 0.12)
	t.tween_property(no, "rotation", 0.0, 0.1)
	t.tween_interval(0.9)

func _sair_fechando() -> void:
	if popup is Janela:
		(popup as Janela).fechar()
	_sair()

func _abrir_bau(c: Dictionary, dourado: bool) -> void:
	if popup is Janela:
		(popup as Janela).fechar()
	popup = null
	if Jogo.som != null:
		Jogo.som.efeito("bau")
	var linhas := CodigoQR.dar_bau(dourado)
	_premio(tr("QR_T_BAU_DOURADO") if dourado else tr("QR_T_BAU"), _sub(c), "", linhas)

## Inimigo: a Elite do QR, no nível do jogador. Rara = Elite Suprema reforçada (dobro da recompensa).
func _popup_inimigo(c: Dictionary, raro: bool) -> void:
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 4)
	var acao := Artes.inimigo_acao(str(c["elite"]), "parado")
	if not acao.is_empty():
		var at := AtlasTexture.new()
		at.atlas = acao["peca"]["tex"]
		var r: Rect2 = acao["peca"]["rect"]
		at.region = Rect2(r.position, Vector2(int(acao["largura"]), int(acao["altura"])))
		var fig := TextureRect.new()
		fig.texture = at
		fig.custom_minimum_size = Vector2(128, 128)
		fig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fig.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if raro:
			fig.modulate = Color(1.2, 1.05, 0.8)
		caixa.add_child(fig)
	var ficha: Dictionary = Artes.dados_inimigos()["inimigos"].get(str(c["elite"]), {})
	var nome := Tema.rotulo(str(ficha.get("nome", c["elite"])), 24)
	nome.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	caixa.add_child(nome)
	var cat := Tema.rotulo((tr("QR_SUPREMA") if raro else tr("TIPO_ELITE")) + " · " + tr("RES_NV") % int(Jogo.dados["nivel"]), 12)
	cat.add_theme_color_override("font_color", Color("#ff8a80") if raro else Tema.COR_TEXTO_APAGADO)
	caixa.add_child(cat)
	var aviso := Tema.rotulo("QR_INIMIGO_AVISO", 12)
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.custom_minimum_size = Vector2(260, 0)
	aviso.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	caixa.add_child(aviso)
	var j := Janela.criar(_sub(c), [["QR_LUTAR", _lutar.bind(c, raro)], ["QR_AGORA_NAO", _sair_fechando]], "", [caixa])
	j.destaque = false
	popup = j
	add_child(j)

func _lutar(c: Dictionary, raro: bool) -> void:
	if popup is Janela:
		(popup as Janela).fechar()
	var tela = load("res://scripts/telas/combate.gd").new()
	tela.qr = CodigoQR.encontro_inimigo(c, raro)
	principal.abrir_tela_cheia(tela)

## Evento: abre o caminho lateral de 5 fases no mapa por 24 h.
func _popup_evento(c: Dictionary, raro: bool) -> void:
	CodigoQR.abrir_evento(c, raro)
	var j := Janela.criar(tr("QR_T_EVENTO_RARO") if raro else tr("QR_T_EVENTO"),
		[["QR_VER_MAPA", _ver_mapa], ["QR_DEPOIS", _sair_fechando]], tr("QR_D_EVENTO"))
	popup = j
	add_child(j)

func _ver_mapa() -> void:
	if popup is Janela:
		(popup as Janela).fechar()
	var m = load("res://scripts/telas/mapa.gd").new()
	principal.abrir_tela_cheia(m)
