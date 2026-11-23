extends Tela
## Entrada (pedido do João, 2026-11-22): depois do Prólogo e antes da criação do personagem.
## "Entrar com Google" guarda o progresso na nuvem (e traz de volta um progresso que a conta já tinha);
## "Jogar como visitante" deixa o progresso só neste aparelho. O visitante pode entrar com o Google depois,
## nas Configurações. Textos ENT_*: rascunho meu (PROVISÓRIO).

const LOGO := preload("res://artes/logo/logo.png")

var status: Label
var bt_google: Button
var bt_visitante: Button

func montar() -> void:
	palco_640 = true   # quadro fixo de 360×640 centrado, como as outras telas da abertura
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)
	var cena := CenaPintada.new("ouvinte")
	cena.duracao = 40.0
	cena.modulate = Color(0.6, 0.6, 0.72, 1.0)
	add_child(cena)
	var sombra := ColorRect.new()
	sombra.color = Color(0.02, 0.02, 0.06, 0.55)
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sombra)

	var logo := TextureRect.new()
	logo.texture = LOGO
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.size = LOGO.get_size()
	logo.position = Vector2(floorf((360.0 - logo.size.x) / 2.0), 72)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	var t := create_tween().set_loops()
	t.tween_property(logo, "position:y", 68.0, 1.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(logo, "position:y", 72.0, 1.6).set_trans(Tween.TRANS_SINE)

	var titulo := Tema.rotulo("ENT_TITULO", 24)
	titulo.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	titulo.add_theme_constant_override("outline_size", 4)
	titulo.add_theme_color_override("font_outline_color", Color("#1a1030"))
	titulo.position = Vector2(0, 214)
	titulo.size = Vector2(360, 32)
	add_child(titulo)
	var fio := ColorRect.new()
	fio.color = Color(Tema.COR_OURO, 0.5)
	fio.position = Vector2(120, 250)
	fio.size = Vector2(120, 2)
	add_child(fio)
	_texto("ENT_TEXTO", 16, Vector2(30, 266), Vector2(300, 90), Tema.COR_TEXTO)

	bt_google = Button.new()
	bt_google.text = "ENT_GOOGLE"
	bt_google.position = Vector2(40, 384)
	bt_google.size = Vector2(280, 48)
	Tema.estilo_botao(bt_google, "primario")
	bt_google.pressed.connect(_google)
	add_child(bt_google)
	bt_visitante = Button.new()
	bt_visitante.text = "ENT_VISITANTE"
	bt_visitante.position = Vector2(40, 444)
	bt_visitante.size = Vector2(280, 44)
	Tema.estilo_botao(bt_visitante, "secundario")
	bt_visitante.pressed.connect(_visitante)
	add_child(bt_visitante)
	_texto("ENT_NOTA", 12, Vector2(30, 498), Vector2(300, 48), Tema.COR_TEXTO_APAGADO)

	status = _texto("", 12, Vector2(20, 556), Vector2(320, 64), Tema.COR_TEXTO)
	status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_ver_volta.call_deferred()

## Texto com quebra de linha dentro de um container (Label solto com autowrap não quebrava no Godot).
func _texto(chave: String, tam: int, pos: Vector2, tam_caixa: Vector2, cor: Color) -> Label:
	var caixa := VBoxContainer.new()
	caixa.position = pos
	caixa.size = tam_caixa
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caixa)
	var r := Tema.rotulo(chave, tam)
	r.custom_minimum_size = Vector2(tam_caixa.x, 0)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	r.add_theme_color_override("font_color", cor)
	caixa.add_child(r)
	return r

func _mostrar(texto: String, erro := false) -> void:
	status.text = texto
	status.add_theme_color_override("font_color", Color("#ff8a80") if erro else Tema.COR_TEXTO)

func _ocupar(sim: bool) -> void:
	bt_google.disabled = sim
	bt_visitante.disabled = sim

# ------------------------------------------------------------ escolhas
func _visitante() -> void:
	Jogo.dados["conta"] = {"tipo": "visitante"}
	_seguir()

func _google() -> void:
	var aviso := Conta.aviso_google()
	if aviso != "":
		_mostrar(tr(aviso), true)
		return
	_ocupar(true)
	_mostrar(tr("ENT_ABRINDO"))
	Conta.ir_para_google("login")

## A página voltou do Google: termina o login aqui mesmo.
func _ver_volta() -> void:
	var r := Conta.retorno()
	if r.is_empty():
		return
	if r.has("erro"):
		_mostrar(tr("ENT_ERRO_GOOGLE"), true)
		return
	_ocupar(true)
	_mostrar(tr("ENT_CONECTANDO"))
	var res: Dictionary = await Conta.concluir(str(r["token"]), true)
	if not res["ok"]:
		_ocupar(false)
		_mostrar(tr("ENT_ERRO") + "\n" + str(res["erro"]).left(90), true)
		return
	if res["carregou"]:
		_mostrar(tr("ENT_BEM_VINDO") % Jogo.nome_heroi())
		await get_tree().create_timer(1.2).timeout
		# progresso da nuvem: continua de onde a conta parou (se ela tinha parado na abertura, vai para a criação)
		if str(Jogo.dados.get("etapa", "")) in ["prologo", "login"]:
			Jogo.dados["etapa"] = "criacao"
			Jogo.salvar()
		principal.seguir_criacao()
		return
	_seguir()

func _seguir() -> void:
	Jogo.dados["etapa"] = "criacao"
	Jogo.salvar()
	principal.seguir_criacao()
