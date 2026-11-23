extends Tela
## Ranking (kit aprovado): abas Nível, Caçador, Bestiário e Geral. Geral fica trancado até o fechamento da
## temporada (DEFINIDO). A linha do jogador fica presa embaixo o tempo todo (DEFINIDO). Ranking do QR em 2 etapas:
## escolhe o inimigo do QR enfrentado e vê quem venceu primeiro no dia (DEFINIDO, kit v17).
## Sem configuração do Firebase (dados/online.json) a tela avisa e mostra só a linha do jogador.

const ABAS := [["RANK_NIVEL", "pts_nivel", "nivel"], ["RANK_CACADOR", "pts_cacador", "cacador"],
	["RANK_BESTIARIO", "pts_bestiario", "bestiario"], ["RANK_GERAL", "", ""]]
const COR_TOPO := [Color("#ffd66b"), Color("#d8dce8"), Color("#e09a5a")]

var aba := 0
var barra: BarraAbas
var lista: VBoxContainer
var rolagem: ScrollContainer
var linha_minha: PanelContainer
var aviso: Label
var bt_qr: Button
var _pedido := 0              # descarta respostas atrasadas quando o jogador troca de aba

func montar() -> void:
	Tema.fundo(self)
	Tema.cabecalho(self, "ABA_RANKING", 210)
	var atualizar := Button.new()
	atualizar.text = "RANK_ATUALIZAR"
	atualizar.position = Vector2(244, 6)
	atualizar.size = Vector2(108, 32)
	atualizar.add_theme_font_size_override("font_size", 12)
	Tema.estilo_botao(atualizar, "secundario")
	atualizar.pressed.connect(_carregar)
	add_child(atualizar)

	var icones := ["res://artes/interface/icone16_xp.png", "res://artes/interface/abas/cacador.png",
		"res://artes/interface/abas/bestiario.png", "res://artes/interface/abas/geral.png"]
	var itens: Array = []
	for i in ABAS.size():
		itens.append([ABAS[i][0], icones[i]])
	barra = BarraAbas.criar(itens, 348)
	barra.position = Vector2(6, 52)
	barra.trocou.connect(_trocar_aba)
	add_child(barra)

	bt_qr = Button.new()
	bt_qr.text = "RANK_QR"
	bt_qr.icon = load("res://artes/interface/icone24_ler_qr.png")
	bt_qr.position = Vector2(6, 96)
	bt_qr.size = Vector2(348, 36)
	bt_qr.add_theme_font_size_override("font_size", 12)
	Tema.estilo_botao(bt_qr, "secundario")
	bt_qr.pressed.connect(_escolher_qr)
	add_child(bt_qr)

	var moldura := PanelContainer.new()
	moldura.position = Vector2(6, 96)
	moldura.size = Vector2(348, 412)
	moldura.name = "moldura"
	add_child(moldura)
	rolagem = ScrollContainer.new()
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	moldura.add_child(rolagem)
	lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 3)
	rolagem.add_child(lista)
	aviso = Tema.rotulo("", 14)
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.custom_minimum_size = Vector2(320, 0)
	aviso.add_theme_color_override("font_color", Color("#a8acc0"))

	# linha do jogador, presa embaixo
	linha_minha = PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = Color("#2a2234")
	e.border_color = Tema.COR_OURO
	e.set_border_width_all(2)
	e.set_corner_radius_all(4)
	e.content_margin_left = 8
	e.content_margin_right = 8
	linha_minha.add_theme_stylebox_override("panel", e)
	linha_minha.position = Vector2(6, 514)
	linha_minha.size = Vector2(348, 64)
	add_child(linha_minha)
	resized.connect(_ajustar_altura)
	_trocar_aba(0)

## Lista e linha do jogador acompanham a altura da tela (a linha fica sempre presa embaixo).
func _ajustar_altura() -> void:
	var h := maxf(584.0, size.y)
	var moldura: Control = get_node_or_null("moldura")
	if moldura == null or linha_minha == null:
		return
	var topo := 138.0 if aba == 1 else 96.0
	moldura.position = Vector2(6, topo)
	moldura.size = Vector2(348, h - 76.0 - topo)
	linha_minha.position = Vector2(6, h - 70.0)

func _trocar_aba(i: int) -> void:
	aba = i
	if barra:
		barra.marcar(aba)
	lista.modulate.a = 0.0                       # a lista nova aparece suavemente
	create_tween().tween_property(lista, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
	# o botão do ranking do QR só aparece na aba Caçador (empurra a lista para baixo)
	bt_qr.visible = aba == 1
	var moldura: Control = get_node("moldura")
	_ajustar_altura()
	_carregar()

func _limpar() -> void:
	for f in lista.get_children():
		if f != aviso:
			f.queue_free()
	if aviso.get_parent():
		aviso.get_parent().remove_child(aviso)

func _avisar(chave: String) -> void:
	_limpar()
	aviso.text = tr(chave)
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 90)
	lista.add_child(c)
	lista.add_child(aviso)

func _carregar() -> void:
	_pedido += 1
	var meu := _pedido
	var campo: String = ABAS[aba][1]
	var p := Online.pontos()
	_linha_jogador(0, p.get(ABAS[aba][2], 0) if campo != "" else 0)
	if campo == "":
		_avisar("RANK_GERAL_FECHADO")
		return
	if not Online.configurado():
		_avisar("RANK_SEM_ONLINE")
		return
	_avisar("RANK_CARREGANDO")
	var r: Dictionary = await Online.ranking(campo)
	if meu != _pedido or not is_instance_valid(lista):
		return
	if not r["ok"]:
		_avisar("RANK_SEM_CONEXAO")
		return
	_limpar()
	var docs: Array = r["lista"]
	if docs.is_empty():
		_avisar("RANK_VAZIO")
	for i in docs.size():
		var d: Dictionary = docs[i]
		lista.add_child(_linha(i + 1, str(d.get("nome", "?")), str(d.get("elemento", "")), _valor_txt(d.get(ABAS[aba][2], 0)), str(d["_id"]) == Online.uid()))
	_linha_jogador(int(r["posicao"]), p.get(ABAS[aba][2], 0))

func _valor_txt(v) -> String:
	match aba:
		0:
			return tr("NIVEL_N") % int(v)
		1:
			return tr("RANK_PTS") % int(v)
		2:
			return "%d/%d" % [int(v), Bestiario.especies().size()]
	return str(v)

## Uma linha: posição (ouro, prata, bronze no top 3), ícone do elemento, nome e valor.
func _linha(pos: int, nome: String, el: String, valor: String, eu: bool) -> Control:
	var p := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = Color("#2a2234") if eu else Color("#181a28")
	e.border_color = Tema.COR_OURO if eu else Color("#2e3248")
	e.set_border_width_all(1)
	e.set_corner_radius_all(3)
	e.content_margin_left = 6
	e.content_margin_right = 8
	e.content_margin_top = 4
	e.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", e)
	p.add_child(_conteudo_linha(pos, nome, el, valor))
	return p

func _conteudo_linha(pos: int, nome: String, el: String, valor: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var n := Tema.rotulo(str(pos) if pos > 0 else "-", 16, true)
	n.custom_minimum_size = Vector2(40, 28)
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.add_theme_color_override("font_color", COR_TOPO[pos - 1] if pos >= 1 and pos <= 3 else Color("#a8acc0"))
	h.add_child(n)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(20, 20)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var caminho := "res://artes/combate/elem16_%s.png" % el
	if el != "" and ResourceLoader.exists(caminho):
		ic.texture = load(caminho)
	h.add_child(ic)
	var nm := Tema.rotulo(nome, 14)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED     # nome de jogador não é chave de texto
	h.add_child(nm)
	var v := Tema.rotulo(valor, 12, true)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(84, 0)
	v.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	h.add_child(v)
	return h

func _linha_jogador(pos: int, valor) -> void:
	for f in linha_minha.get_children():
		f.queue_free()
	var v := Tema.rotulo("RANK_VOCE", 8, true)
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	caixa.add_child(v)
	caixa.add_child(_conteudo_linha(pos, Jogo.nome_heroi(), str(Jogo.dados.get("elemento", "")), _valor_txt(valor) if ABAS[aba][1] != "" else "-"))
	linha_minha.add_child(caixa)

# ------------------------------------------------------------ ranking do QR (2 etapas)
func _escolher_qr() -> void:
	_limpar()
	var v: Dictionary = Jogo.dados.get("qr_vitorias", {})
	if v.is_empty():
		_avisar("RANK_QR_NENHUM")
		return
	var t := _tinta_titulo("RANK_QR_ESCOLHA")
	lista.add_child(t)
	var nums: Array = v.keys()
	nums.sort_custom(func(a, b): return int(a) < int(b))
	for k in nums:
		var horas: Array = v[k]
		var ultima := int(horas[horas.size() - 1])
		var dia := Time.get_date_string_from_unix_time(ultima + int(Time.get_time_zone_from_system()["bias"]) * 60)
		var b := Button.new()
		b.text = tr("QR_N") % int(k) + "  ·  " + dia
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 14)
		Tema.estilo_botao(b, "secundario")
		b.pressed.connect(_ver_qr.bind(int(k), dia))
		lista.add_child(b)

func _tinta_titulo(chave: String) -> Label:
	var t := Tema.rotulo(chave, 14)
	t.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	return t

func _ver_qr(numero: int, dia: String) -> void:
	_pedido += 1
	var meu := _pedido
	if not Online.configurado():
		_avisar("RANK_SEM_ONLINE")
		return
	_avisar("RANK_CARREGANDO")
	var r: Dictionary = await Online.ranking_qr(numero, dia)
	if meu != _pedido or not is_instance_valid(lista):
		return
	if not r["ok"]:
		_avisar("RANK_SEM_CONEXAO")
		return
	_limpar()
	lista.add_child(_tinta_titulo(tr("QR_N") % numero + " · " + dia))
	var voltar := Button.new()
	voltar.text = "RANK_QR_VOLTAR"
	voltar.custom_minimum_size = Vector2(0, 32)
	voltar.add_theme_font_size_override("font_size", 12)
	Tema.estilo_botao(voltar, "secundario")
	voltar.pressed.connect(_escolher_qr)
	lista.add_child(voltar)
	var docs: Array = r["lista"]
	for i in docs.size():
		var d: Dictionary = docs[i]
		var hora := Time.get_time_string_from_unix_time(int(d.get("hora", 0)) + int(Time.get_time_zone_from_system()["bias"]) * 60)
		lista.add_child(_linha(i + 1, str(d.get("nome", "?")), str(d.get("elemento", "")), hora, str(d["_id"]) == Online.uid()))
	var pe := Tema.rotulo("RANK_QR_PREMIO", 10)
	pe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pe.custom_minimum_size = Vector2(320, 0)
	pe.add_theme_color_override("font_color", Color("#a8acc0"))
	lista.add_child(pe)
