extends Control
## Tela de carregamento ao abrir o jogo (pedido do João, 2026-11-13): logo em pixel art flutuando, faíscas
## nas cores dos elementos subindo, barra de progresso e o passo atual (dados, artes, conexão).
## A principal espera o sinal `concluido` antes de montar as telas.
## PROVISÓRIO (meu): os textos de cada passo, o mínimo de 1,6 s na tela e o limite de 8 s para o login online
## (sem resposta, o jogo segue offline, como sempre).

signal concluido

const LOGO := preload("res://artes/logo/logo.png")
const TEMPO_MINIMO := 1.6
const LIMITE_ONLINE := 8.0
const LIMITE_NOVIDADES := 6.0     # promoções e artes do Firebase; sem resposta, usa o que já está guardado
## Web (pedido do João, 2026-11-22: atualização e sincronização acontecem aqui, para o jogador não ver lacunas).
const LIMITE_PROCURAR := 4.0      # perguntar ao servidor se há versão nova; sem resposta, segue com a guardada
const LIMITE_PARADO := 20.0       # baixando a versão nova sem avançar por esse tempo: segue com a guardada
const LIMITE_NUVEM := 8.0         # progresso da conta Google; sem resposta, segue com o do aparelho
const CORES := [Color("#ff7a3a"), Color("#4ab0ff"), Color("#c8964e"), Color("#6ee0b0"), Color("#ffe04a"), Color("#a8e8ff")]

var _tempo := 0.0
var _progresso := 0.0         # o que a barra mostra (anda suave até o alvo)
var _alvo := 0.0
var _logo: TextureRect
var _barra: Control
var _status: Label
var _faiscas: Array = []      # [pos, velocidade, cor, vida]
var _ceu: Control
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	_rng.randomize()
	var fundo := ColorRect.new()
	fundo.color = Color("#0b0b14")
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_ceu = Control.new()
	_ceu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ceu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ceu.draw.connect(_desenhar_ceu)
	add_child(_ceu)

	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.size = LOGO.get_size()
	add_child(_logo)

	_barra = Control.new()
	_barra.size = Vector2(200, 10)
	_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barra.draw.connect(_desenhar_barra)
	add_child(_barra)

	_status = Tema.rotulo("CARREGANDO_DADOS", 12)
	_status.add_theme_color_override("font_color", Color("#bfe3ff"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.size = Vector2(320, 18)
	add_child(_status)

	var versao := Tema.rotulo(tr("CFG_VERSAO") % str(ProjectSettings.get_setting("application/config/version", "0.1")), 8, true)
	versao.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	versao.add_theme_color_override("font_color", Color("#545a74"))
	versao.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versao.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	versao.offset_top = -22
	versao.offset_bottom = -8
	versao.offset_left = -100
	versao.offset_right = 100
	add_child(versao)

	resized.connect(_posicionar)
	_posicionar()
	_carregar.call_deferred()

func _posicionar() -> void:
	var t := size if size.x > 0 else get_viewport_rect().size
	_logo.position = Vector2(floorf((t.x - _logo.size.x) / 2.0), floorf(t.y * 0.36 - _logo.size.y / 2.0))
	_barra.position = Vector2(floorf((t.x - _barra.size.x) / 2.0), floorf(t.y * 0.66))
	_status.position = Vector2(floorf((t.x - _status.size.x) / 2.0), _barra.position.y + 16)

# ------------------------------------------------------------ passos
func _carregar() -> void:
	var inicio := Time.get_ticks_msec()
	# 1. salvamento (o Jogo já leu ao iniciar; aqui só confere)
	_passo("CARREGANDO_DADOS", 0.2)
	await get_tree().process_frame
	# 2. artes e catálogos (as folhas-atlas são as partes mais pesadas)
	_passo("CARREGANDO_ARTES", 0.45)
	await get_tree().process_frame
	Artes.dados_heroi()
	Artes.dados_inimigos()
	Artes.dados_itens()
	await get_tree().process_frame
	# 3. Web: versão nova do jogo (baixa aqui e recarrega a página antes de o jogo abrir)
	await _versao_web()
	# 4. login de convidado no servidor (só se o online estiver configurado)
	if Online.configurado():
		_passo("CARREGANDO_ONLINE", 0.7)
		var estado := {"feito": false, "ok": false}
		var tarefa := func():
			estado["ok"] = await Online.entrar()
			estado["feito"] = true
		tarefa.call()
		var limite := Time.get_ticks_msec() + int(LIMITE_ONLINE * 1000)
		while not estado["feito"] and Time.get_ticks_msec() < limite:
			await get_tree().process_frame
		# 5. conta Google: traz o progresso de outro aparelho (ou manda o daqui) antes de montar as telas
		if estado["ok"] and Conta.google() and str(Jogo.dados.get("etapa", "")) == "pronto":
			_passo("CARREGANDO_NUVEM", 0.76)
			var nuvem := {"feito": false}
			var sinc := func():
				await Online.enviar_save()
				nuvem["feito"] = true
			sinc.call()
			var ate := Time.get_ticks_msec() + int(LIMITE_NUVEM * 1000)
			while not nuvem["feito"] and Time.get_ticks_msec() < ate:
				await get_tree().process_frame
		# 6. novidades do Firebase (promoções, artes, atos, QR desligados) antes de o jogo abrir
		if estado["ok"]:
			_passo("CARREGANDO_NOVIDADES", 0.8)
			await ConfigRemota.preparar(LIMITE_NOVIDADES)
		_passo("CARREGANDO_CONECTADO" if estado["ok"] else "CARREGANDO_OFFLINE", 0.9)
		await get_tree().create_timer(0.35).timeout
	# 7. pronto (fica um mínimo na tela para a logo aparecer)
	_passo("CARREGANDO_PRONTO", 1.0)
	var falta := TEMPO_MINIMO - (Time.get_ticks_msec() - inicio) / 1000.0
	if falta > 0:
		await get_tree().create_timer(falta).timeout
	await get_tree().create_timer(0.25).timeout
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.KaerithVersao ? KaerithVersao.fimCarregamento() : ''", true)
	concluido.emit()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(queue_free)

## Web: pergunta ao service worker se há versão nova (KaerithVersao em web/kaerith_shell.html).
## Já baixada → salva e recarrega a página. Baixando → mostra a porcentagem e espera. Sem internet → segue.
## Retorno do JavaScript sempre em texto (o booleano não chega certo no Godot 4.7 Web).
func _versao_web() -> void:
	if not OS.has_feature("web"):
		return
	var r = JavaScriptBridge.eval("window.KaerithVersao ? KaerithVersao.procurar() : 'nada'", true)
	if str(r) == "nada" or r == null:
		return
	_passo("CARREGANDO_VERSAO", 0.5)
	var comeco := Time.get_ticks_msec()
	var mudou_em := comeco
	var ultimo := -1
	while true:
		await get_tree().create_timer(0.1).timeout
		var p := str(JavaScriptBridge.eval("window.KaerithVersao ? KaerithVersao.situacao() : 'nada|0'", true)).split("|")
		var e := p[0]
		var pct := int(p[1]) if p.size() > 1 else 0
		var agora := Time.get_ticks_msec()
		match e:
			"procurando":
				if agora - comeco > LIMITE_PROCURAR * 1000:
					return
			"baixando":
				if pct != ultimo:
					ultimo = pct
					mudou_em = agora
				_status.text = tr("CARREGANDO_BAIXANDO") % pct
				_alvo = 0.5 + 0.15 * pct / 100.0
				if agora - mudou_em > LIMITE_PARADO * 1000:
					return                   # rede ruim: joga com a versão guardada; o aviso aparece depois
			"pronta":
				_passo("CARREGANDO_ATUALIZANDO", 0.7)
				Jogo.salvar()
				await get_tree().create_timer(0.6).timeout     # o navegador grava o save antes de recarregar
				JavaScriptBridge.eval("KaerithVersao.aplicar()", true)
				await get_tree().create_timer(6.0).timeout     # a página recarrega; se não recarregar, segue
				return
			_:
				return

func _passo(chave: String, alvo: float) -> void:
	_status.text = chave
	_alvo = alvo

# ------------------------------------------------------------ animação
func _process(delta: float) -> void:
	_tempo += delta
	_progresso = move_toward(_progresso, _alvo, delta * 0.9)
	# a logo sobe e desce 2 px, em passos inteiros (pixel art)
	var t := size if size.x > 0 else get_viewport_rect().size
	_logo.position.y = floorf(t.y * 0.36 - _logo.size.y / 2.0) + roundf(sin(_tempo * 1.6) * 2.0)
	# faíscas dos elementos subindo do pé da tela
	if _rng.randf() < delta * 14.0:
		_faiscas.append([Vector2(_rng.randf_range(10, t.x - 10), t.y + 4), Vector2(_rng.randf_range(-6, 6), -_rng.randf_range(18, 40)),
			CORES[_rng.randi() % CORES.size()], _rng.randf_range(4.0, 9.0)])
	var vivas: Array = []
	for f: Array in _faiscas:
		var pos: Vector2 = f[0] + (f[1] as Vector2) * delta
		pos.x += sin(_tempo * 2.0 + pos.y * 0.05) * 0.3
		f[0] = pos
		f[3] -= delta
		if f[3] > 0 and f[0].y > -4:
			vivas.append(f)
	_faiscas = vivas
	_ceu.queue_redraw()
	_barra.queue_redraw()

func _desenhar_ceu() -> void:
	var t := _ceu.size
	# faixas de luz atrás da logo (degradê em degraus, como no resto do jogo)
	var c := Vector2(t.x / 2.0, t.y * 0.36)
	for k in 6:
		var r := 150.0 - k * 22.0
		_ceu.draw_circle(c, r, Color(0.16, 0.13, 0.25, 0.10 + k * 0.03))
	for f: Array in _faiscas:
		var p: Vector2 = (f[0] as Vector2).floor()
		var cor: Color = f[2]
		cor.a = clampf(float(f[3]) / 2.0, 0.0, 1.0)
		_ceu.draw_rect(Rect2(p, Vector2(1, 1)), cor)
		if int(_tempo * 6.0 + p.x) % 3 == 0:            # algumas piscam em cruz
			_ceu.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, 1)), Color(cor, cor.a * 0.6))
			_ceu.draw_rect(Rect2(p + Vector2(0, -1), Vector2(1, 3)), Color(cor, cor.a * 0.6))

func _desenhar_barra() -> void:
	var s := _barra.size
	_barra.draw_rect(Rect2(Vector2(-2, -2), s + Vector2(4, 4)), Color("#0e1424"))
	_barra.draw_rect(Rect2(Vector2(-1, -1), s + Vector2(2, 2)), Color("#3a5a8a"))
	_barra.draw_rect(Rect2(Vector2.ZERO, s), Color("#0e1424"))
	var w := floorf(s.x * clampf(_progresso, 0.0, 1.0))
	if w <= 0:
		return
	_barra.draw_rect(Rect2(0, 0, w, s.y), Color("#7fa8d8"))
	_barra.draw_rect(Rect2(0, 0, w, 3), Color("#cfe8ff"))
	_barra.draw_rect(Rect2(0, s.y - 2, w, 2), Color("#5a80b8"))
	# brilho que corre dentro da parte cheia
	var x := fmod(_tempo * 90.0, w + 20.0) - 10.0
	if x > 0 and x < w - 3:
		_barra.draw_rect(Rect2(floorf(x), 1, 3, s.y - 2), Color(1, 1, 1, 0.6))
	# folhinha na ponta, como os galhos da logo
	_barra.draw_rect(Rect2(w - 1, -4, 2, 2), Color("#9ff0c8"))
	_barra.draw_rect(Rect2(w + 1, -5, 2, 2), Color("#2f8f6a"))
