extends Tela
## Mapa de fases: a temporada inteira num mapa só (4 atos, 300 fases), rolagem vertical e popup da fase.

var dados := {}
var ato := 1
var rolagem: ScrollContainer
var desenho: MapaDesenho
var titulo: Label
var subtitulo: Label
var popup: Control
const POPUP_FASE := preload("res://scripts/componentes/popup_fase.gd")

func montar() -> void:
	var f := FileAccess.open("res://dados/mapa.json", FileAccess.READ)
	dados = JSON.parse_string(f.get_as_text())
	ato = int((int(Jogo.dados["fase_atual"]) - 1) / 75) + 1
	ato = clampi(ato, 1, 4)

	var fundo := ColorRect.new()
	fundo.color = Tema.COR_FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	rolagem = ScrollContainer.new()
	rolagem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(rolagem)
	desenho = MapaDesenho.new()
	desenho.fase_tocada.connect(_abrir_popup)
	desenho.evento_tocado.connect(_popup_evento)
	rolagem.add_child(desenho)

	# topo com fundo próprio: as fases rolam por baixo dele, sem passar por cima dos botões
	var fundo_topo := ColorRect.new()
	fundo_topo.color = Color("#12131c")
	fundo_topo.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fundo_topo.offset_bottom = 112
	add_child(fundo_topo)
	var fio := ColorRect.new()
	fio.color = Color(Tema.COR_OURO, 0.6)
	fio.set_anchors_preset(Control.PRESET_TOP_WIDE)
	fio.offset_top = 112
	fio.offset_bottom = 114
	add_child(fio)
	var topo := _topo()
	add_child(topo)
	rolagem.offset_top = 114
	_ajustar_topo.call_deferred(topo, fundo_topo, fio)
	rolagem.get_v_scroll_bar().value_changed.connect(_ao_rolar)
	_mostrar_mapa()

func _topo() -> Control:
	var caixa := VBoxContainer.new()
	caixa.set_anchors_preset(Control.PRESET_TOP_WIDE)
	caixa.offset_left = 8
	caixa.offset_right = -8
	caixa.offset_top = 6
	var linha := HBoxContainer.new()
	var voltar := Button.new()
	voltar.text = "VOLTAR"
	voltar.custom_minimum_size = Vector2(88, 36)
	Tema.estilo_botao(voltar, "secundario")
	voltar.pressed.connect(func(): principal.fechar_tela_cheia())
	linha.add_child(voltar)
	var meio := Control.new()
	meio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(meio)
	var ir := Button.new()
	ir.text = "MAPA_IR_ATUAL"
	ir.custom_minimum_size = Vector2(120, 36)
	ir.pressed.connect(_rolar_para_atual.bind(true))
	linha.add_child(ir)
	caixa.add_child(linha)
	var painel := PanelContainer.new()
	var textos := VBoxContainer.new()
	textos.add_theme_constant_override("separation", 0)
	subtitulo = Tema.rotulo("", 16)
	subtitulo.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	titulo = Tema.rotulo("", 24)
	textos.add_child(subtitulo)
	textos.add_child(titulo)
	painel.add_child(textos)
	caixa.add_child(painel)
	return caixa

## Depois do layout, o fundo e a rolagem seguem a altura real do topo.
func _ajustar_topo(topo: Control, fundo_topo: Control, fio: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(topo):
		return
	var h := ceilf(topo.position.y + topo.size.y + 6.0)
	fundo_topo.offset_bottom = h
	fio.offset_top = h
	fio.offset_bottom = h + 2
	rolagem.offset_top = h + 2

## A temporada inteira é um mapa só: o Ato 1 embaixo e o Ato 4 em cima; o título segue o ato que está na tela.
func _mostrar_mapa() -> void:
	ato = clampi(int((int(Jogo.dados["fase_atual"]) - 1) / 75) + 1, 1, 4)
	atualizar_textos()
	desenho.preparar(dados, int(Jogo.dados["fase_atual"]))
	await get_tree().process_frame
	_rolar_para_atual(false)

func _rolar_para_atual(animado: bool) -> void:
	var atual := clampi(int(Jogo.dados["fase_atual"]), 1, 300)
	var alvo := int(maxf(0.0, desenho.y_da_fase(atual) - rolagem.size.y * 0.65))
	if animado:
		var tw := create_tween()
		tw.tween_property(rolagem, "scroll_vertical", alvo, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		rolagem.scroll_vertical = alvo
	_ao_rolar(0.0)

func _ao_rolar(_v: float) -> void:
	desenho.queue_redraw()
	var novo := desenho.ato_em(rolagem.scroll_vertical + rolagem.size.y * 0.5)
	if novo != ato:
		ato = novo
		atualizar_textos()

func atualizar_textos() -> void:
	subtitulo.text = tr("TEMPORADA_ATO") % ato
	titulo.text = dados["nomes"][str(ato)]

# ---------------- popup da fase
const NOME_TIPO := {"bloqueada": "TIPO_COMBATE", "ondas": "TIPO_ONDAS", "elite": "TIPO_ELITE", "suprema": "TIPO_SUPREMA", "chefe": "TIPO_CHEFE"}

func _tipo_de(fase: int) -> String:
	return desenho.tipo_da_fase(fase)

## Popup da fase (pedido do João, 2026-11-13): ondas, inimigos (depois de jogar a fase) e prêmios possíveis.
func _abrir_popup(fase: int) -> void:
	_fechar_popup()
	var p = POPUP_FASE.new()
	p.fase = fase
	p.ao_jogar = _jogar.bind(fase)
	p.ao_vidas = _ver_vidas
	p.ao_vencer_teste = _vencer_teste.bind(fase)
	popup = p
	add_child(p)

## Fase do Evento do QR: só a próxima pode ser jogada; o prêmio vem na 5ª.
const TIPO_EVENTO := {"combate": "TIPO_COMBATE", "ondas": "TIPO_ONDAS", "elite": "TIPO_ELITE"}

func _popup_evento(etapa: int) -> void:
	_fechar_popup()
	var e := CodigoQR.evento_ativo()
	if e.is_empty():
		return
	var tipo := Tema.rotulo(TIPO_EVENTO[CodigoQR.TIPOS_EVENTO[etapa - 1]], 16)
	tipo.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	var extras: Array = [tipo]
	if etapa == 5:
		var premio := Tema.rotulo("EVENTO_PREMIO", 12)
		premio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		premio.custom_minimum_size = Vector2(260, 0)
		extras.append(premio)
	var botoes: Array = []
	var aviso := ""
	var vencidas := int(e["vencidas"])
	if etapa <= vencidas:
		aviso = "EVENTO_VENCIDA"
	elif etapa > vencidas + 1:
		aviso = "FASE_BLOQUEADA"
	elif int(Jogo.dados["vidas"]) <= 0:
		aviso = "SEM_VIDAS"
		botoes.append(["VIDAS_VER", _ver_vidas])
	else:
		botoes.append(["JOGAR", _jogar_evento.bind(etapa)])
	botoes.append(["FECHAR", _fechar_popup])
	var j := Janela.criar(tr("EVENTO_FASE") % etapa, botoes, tr(aviso) if aviso != "" else "", extras)
	j.destaque = false
	popup = j
	add_child(j)

func _jogar_evento(etapa: int) -> void:
	var tela = preload("res://scripts/telas/combate.gd").new()
	tela.evento_etapa = etapa
	principal.abrir_tela_cheia(tela)

func _ver_vidas() -> void:
	_fechar_popup()
	JanelaVidas.abrir(self)

func _jogar(fase: int) -> void:
	_fechar_popup()
	var tela = preload("res://scripts/telas/combate.gd").new()
	tela.fase = fase
	principal.abrir_tela_cheia(tela)

func _fechar_popup() -> void:
	if is_instance_valid(popup):
		popup.call("fechar")
	popup = null

## Só para testar o mapa até o combate existir: marca a fase como vencida.
func _vencer_teste(fase: int) -> void:
	Jogo.dados["fase_atual"] = min(fase + 1, 300)
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	_fechar_popup()
	_mostrar_mapa()
