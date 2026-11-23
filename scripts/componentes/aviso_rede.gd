extends CanvasLayer
## Aviso do estado da rede, sempre por cima de tudo (Sistemas Distribuídos, 2026-11-23).
##   vermelho  OFFLINE · SALVO NO APARELHO (· N A ENVIAR)   sem internet ou servidor fora do ar
##   amarelo   SINCRONIZANDO N PARTIDAS                      online, com partidas na fila
##   verde     ONLINE · SINCRONIZADO                         por 4 s quando a conexão volta
## Também chama o vigia da rede (Online.vigiar) a cada segundo, que sincroniza sozinho quando a conexão volta.

const COR_OFF := Color("#b3263a")
const COR_SINC := Color("#b0801c")
const COR_OK := Color("#2e8b57")

var _caixa: PanelContainer
var _texto: Label
var _estilo: StyleBoxFlat
var _seg := 0.0

func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_caixa = PanelContainer.new()
	_caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_estilo = StyleBoxFlat.new()
	_estilo.set_corner_radius_all(3)
	_estilo.content_margin_left = 6
	_estilo.content_margin_right = 6
	_estilo.content_margin_top = 1
	_estilo.content_margin_bottom = 1
	_estilo.border_color = Color(0, 0, 0, 0.6)
	_estilo.set_border_width_all(1)
	_caixa.add_theme_stylebox_override("panel", _estilo)
	_texto = Label.new()
	_texto.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_texto.add_theme_font_override("font", Tema.fonte_numeros)
	_texto.add_theme_font_size_override("font_size", 8)
	_texto.add_theme_color_override("font_color", Color.WHITE)
	_caixa.add_child(_texto)
	add_child(_caixa)
	_caixa.visible = false

func _process(dt: float) -> void:
	_seg += dt
	if _seg < 0.25:
		return
	_seg = 0.0
	_atualizar()
	_acumulado += 0.25
	if _acumulado >= 1.0:
		_acumulado = 0.0
		Online.vigiar()               # a cada segundo

var _acumulado := 0.0

func _t(pt: String, en: String) -> String:
	return en if str(Jogo.dados.get("idioma", "pt")) == "en" else pt

func _atualizar() -> void:
	if not Online.configurado() or not Online.tentou:
		_caixa.visible = false
		return
	var fila := Historico.pendentes()
	var txt := ""
	var cor := COR_OFF
	if not Online.conectado:
		txt = _t("● SERVIDOR FORA DO AR", "● SERVER UNAVAILABLE") if Online.teste_fora \
			else _t("● OFFLINE", "● OFFLINE")
		txt += _t(" · SALVO NO APARELHO", " · SAVED ON DEVICE")
		if fila > 0:
			txt += _t(" · %d A ENVIAR", " · %d TO SEND") % fila
	elif fila > 0:
		txt = _t("● SINCRONIZANDO %d PARTIDA(S)", "● SYNCING %d MATCH(ES)") % fila
		cor = COR_SINC
	elif Online.reconectou_em > 0 and Time.get_ticks_msec() - Online.reconectou_em < 4000:
		txt = _t("● ONLINE · SINCRONIZADO", "● ONLINE · SYNCED")
		cor = COR_OK
	if txt == "":
		_caixa.visible = false
		return
	_texto.text = txt
	_estilo.bg_color = Color(cor, 0.92)
	_caixa.visible = true
	_caixa.reset_size()
	var tela := _caixa.get_viewport_rect().size
	var topo := 0.0
	if OS.has_feature("mobile"):
		var seguro := DisplayServer.get_display_safe_area()
		var janela := DisplayServer.window_get_size()
		if janela.y > 0:
			topo = roundf(maxf(0.0, seguro.position.y * tela.y / float(janela.y)))
	_caixa.position = Vector2(roundf((tela.x - _caixa.size.x) / 2.0), topo + 1)
