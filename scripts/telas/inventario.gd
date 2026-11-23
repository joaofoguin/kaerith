extends Tela
## Inventário (etapa 6, wireframe aprovado). Topo escuro com filete dourado; o herói vestido num pedestal
## de luz com os 5 espaços em volta (moldura na cor da raridade); atributos finais numa linha; conjunto;
## abas no estilo do kit e a lista dentro de um painel. Peças equipadas NÃO aparecem na lista: saem dela
## ao equipar e voltam ao trocar ou tirar. Acessório: a ficha só tem "Equipar"; depois os espaços
## Acess. 1 e 2 piscam em dourado e o jogador toca no que quer.

const ROTULO_ESPACO := {"cabeca": "EQ_CABECA", "arma": "EQ_ARMA", "acessorio1": "EQ_ACESSORIO_1", "armadura": "EQ_ARMADURA", "acessorio2": "EQ_ACESSORIO_2"}
const POS_ESPACO := {"cabeca": Vector2(16, 60), "arma": Vector2(16, 124), "acessorio1": Vector2(16, 188),
	"armadura": Vector2(288, 60), "acessorio2": Vector2(288, 124)}
## Tamanhos de letra do Inventário (pedido do João: nada menor que isto para ser legível no celular).
const ORBES := preload("res://scripts/orbes.gd")
const POPUP_ORBE := preload("res://scripts/componentes/popup_orbe.gd")
const TAM_TEXTO := 12        # Pixelify: rótulos, filtros, categorias
const TAM_NUMERO := 16       # Silkscreen: números de relance
const FILTROS := ["todos", "arma", "armadura", "cabeca", "acessorio"]
const ICONE_ATR := {"forca": "icone16_forca.png", "percepcao": "icone16_percepcao.png", "agilidade": "icone16_agilidade.png",
	"resistencia": "icone16_resistencia.png", "ressonancia": "icone16_ressonancia.png"}

var heroi: HeroiFrente
var espacos := {}            # espaço → Button
var destaques := {}          # espaço → Panel (borda dourada que pisca na escolha do acessório)
var rotulo_conjunto: Label
var rotulo_moedas: Label
var linha_atr: HBoxContainer
var barra: BarraAbas
var aba := 0
var filtro := 0
var filtro_el: Array = []    # elementos marcados (vários ao mesmo tempo); vazio = todos. "" = sem elemento
var conteudo: VBoxContainer
var rolagem: ScrollContainer
var ficha: FichaPeca
var popup: Janela
var escolhendo_uid := -1      # acessório esperando o jogador tocar no espaço 1 ou 2
var aviso_escolha: Control
var palco: Control
var tempo := 0.0

func montar() -> void:
	Tema.fundo(self)
	palco = Control.new()             # luz do pedestal e partículas (desenhadas atrás do herói)
	palco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	palco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	palco.draw.connect(_desenhar_palco)
	add_child(palco)

	# topo: título dourado e moedas numa pílula
	Tema.cabecalho(self, "ABA_INVENTARIO", 210)
	var pilula := PanelContainer.new()
	var ep := StyleBoxFlat.new()
	ep.bg_color = Color("#0c0d16")
	ep.border_color = Color("#545a74")
	ep.set_border_width_all(1)
	ep.set_corner_radius_all(10)
	ep.content_margin_left = 8
	ep.content_margin_right = 10
	pilula.add_theme_stylebox_override("panel", ep)
	pilula.position = Vector2(240, 10)
	pilula.custom_minimum_size = Vector2(110, 24)
	var hm := HBoxContainer.new()
	hm.add_theme_constant_override("separation", 6)
	var ic := TextureRect.new()
	ic.texture = load("res://artes/interface/icone16_moeda.png")
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	hm.add_child(ic)
	rotulo_moedas = Tema.rotulo("", 16, true)
	rotulo_moedas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotulo_moedas.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hm.add_child(rotulo_moedas)
	pilula.add_child(hm)
	add_child(pilula)

	heroi = HeroiFrente.new()
	heroi.escala = 3
	heroi.position = Vector2(108, 50)
	heroi.size = Vector2(144, 192)
	heroi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(heroi)
	for e in POS_ESPACO:
		var b := _espaco(e)
		b.position = POS_ESPACO[e]
		add_child(b)
		espacos[e] = b
	var bficha := Button.new()
	bficha.position = Vector2(288, 188)               # 3º quadro da coluna da direita, do tamanho dos espaços
	Tema.estilo_botao(bficha, "secundario")
	BarraAbas.vestir(bficha, "EQ_FICHA_CURTA", "res://artes/interface/abas/personagens.png", Vector2(56, 56))
	bficha.pressed.connect(_abrir_ficha_personagem)
	add_child(bficha)

	linha_atr = HBoxContainer.new()
	linha_atr.position = Vector2(8, 250)
	linha_atr.size = Vector2(344, 22)
	linha_atr.alignment = BoxContainer.ALIGNMENT_CENTER
	linha_atr.add_theme_constant_override("separation", 6)
	add_child(linha_atr)
	rotulo_conjunto = Tema.rotulo("", 12)
	rotulo_conjunto.position = Vector2(8, 274)
	rotulo_conjunto.size = Vector2(344, 16)
	rotulo_conjunto.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	add_child(rotulo_conjunto)

	barra = BarraAbas.criar([
		["EQ_ABA_PECAS", "res://artes/interface/abas/equip.png"],
		["HABILIDADES", "res://artes/interface/abas/habilidades.png"],
		["EQ_ABA_CONSUMIVEIS", "res://artes/interface/abas/consumiveis.png"],
		["EQ_ABA_FRAGMENTOS", "res://artes/interface/icone16_fragmento.png"]], 348)
	barra.position = Vector2(6, 294)
	barra.trocou.connect(_trocar_aba)
	add_child(barra)
	var moldura := PanelContainer.new()
	moldura.position = Vector2(4, 338)
	moldura.size = Vector2(352, 244)
	add_child(moldura)
	rolagem = ScrollContainer.new()
	rolagem.position = Vector2(12, 346)
	rolagem.size = Vector2(336, 228)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	conteudo = VBoxContainer.new()
	conteudo.custom_minimum_size = Vector2(330, 0)
	conteudo.add_theme_constant_override("separation", 6)
	rolagem.add_child(conteudo)
	add_child(rolagem)
	# a lista vai até o fim da tela (celulares mais altos que 584 ganham mais linhas)
	_moldura = moldura
	resized.connect(_ajustar_altura)
	_ajustar_altura.call_deferred()
	atualizar_textos()

var _moldura: PanelContainer
func _ajustar_altura() -> void:
	var h := maxf(584.0, size.y)
	_moldura.size = Vector2(352, h - 340.0)
	rolagem.size = Vector2(336, h - 356.0)

func _process(delta: float) -> void:
	tempo += delta
	palco.queue_redraw()
	# destaque dos espaços de acessório enquanto o jogador escolhe
	var pulso := 0.5 + 0.5 * sin(tempo * 6.0)
	for e in destaques:
		var d: Panel = destaques[e]
		d.visible = escolhendo_uid >= 0
		d.modulate.a = 0.45 + 0.55 * pulso

## Pedestal de luz (elipse com borda dourada), halo e partículas subindo em volta do herói.
func _desenhar_palco() -> void:
	var centro := Vector2(180, 236)
	palco.draw_set_transform(centro, 0, Vector2(1, 0.28))
	for i in 6:
		palco.draw_circle(Vector2.ZERO, 70.0 + i * 9.0 + 3.0 * sin(tempo * 2.0), Color(0.55, 0.65, 1.0, 0.035))
	palco.draw_circle(Vector2.ZERO, 58.0, Color("#191c30"))
	palco.draw_circle(Vector2.ZERO, 50.0, Color("#262a46"))
	palco.draw_arc(Vector2.ZERO, 56.0, 0, TAU, 48, Color(Tema.COR_OURO, 0.45 + 0.25 * sin(tempo * 2.0)), 2.0)
	palco.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# coluna de luz suave atrás do herói
	for i in 8:
		var a := 0.035 * (1.0 - i / 8.0)
		palco.draw_rect(Rect2(130 + i * 2, 60, 100 - i * 4, 176), Color(0.6, 0.7, 1.0, a))
	for i in 16:
		var f := fposmod(tempo * 0.12 + i * 0.0625, 1.0)
		var x := 180.0 + sin(i * 2.3 + tempo * 0.8) * 62.0
		var y := 236.0 - f * 170.0
		var cor := Color(1.0, 0.9, 0.6, (1.0 - f) * 0.7) if i % 3 == 0 else Color(0.7, 0.85, 1.0, (1.0 - f) * 0.5)
		palco.draw_rect(Rect2(Vector2(floorf(x / 2) * 2, floorf(y / 2) * 2), Vector2(2, 2)), cor)

func atualizar_textos() -> void:
	rotulo_moedas.text = str(int(Jogo.dados["moedas"]))
	_atualizar_alertas()
	heroi.vestir(Jogo.camadas_heroi())
	for e in espacos:
		_preencher_espaco(e)
	_atualizar_atributos()
	var b := Equipamento.bonus()
	var partes: Array = []
	var conj: Dictionary = b["conjuntos"]
	for c in conj:
		var n := int(conj[c])
		var extra := ""
		if n >= 5:
			extra = tr("EQ_CONJ_5")
		elif n >= 3:
			extra = tr("EQ_CONJ_3")
		else:
			extra = tr("EQ_CONJ_FALTA") % (3 - n)
		partes.append("%s %d/5 (%s)" % [c, n, extra])
	rotulo_conjunto.text = " · ".join(partes) if not partes.is_empty() else tr("EQ_SEM_CONJUNTO")
	if partes.is_empty():
		rotulo_conjunto.add_theme_color_override("font_color", Color("#8a90a8"))
	else:
		rotulo_conjunto.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	Tema.caber(rotulo_conjunto, 344.0, 16.0, 1, [12, 10, 8])
	if barra:
		barra.marcar(aba)
	_montar_aba()

## Atributos finais (nível + equipamentos), com ícone, numa linha embaixo do pedestal.
func _atualizar_atributos() -> void:
	for f in linha_atr.get_children():
		f.queue_free()
	var el := str(Jogo.dados.get("elemento", ""))
	var modelo: Array = Catalogo.MODELO_JOGADOR.get(el, Catalogo.MODELO_JOGADOR[""])
	var finais := Equipamento.atributos_finais(modelo, Lutador.fator_de(int(Jogo.dados["nivel"])))
	var pts: Dictionary = Equipamento.bonus()["pontos"]
	for a in Equipamento.ATRIBUTOS:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		var ic := TextureRect.new()
		ic.texture = load("res://artes/interface/" + ICONE_ATR[a])
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(ic)
		var v := Tema.rotulo(str(int(round(float(finais[a])))), TAM_NUMERO, true)
		v.add_theme_color_override("font_color", Color("#7fd07a") if int(pts[a]) > 0 else Color("#c8ccd8"))
		h.add_child(v)
		linha_atr.add_child(h)
		_tocar_atributo(h, a, int(round(float(finais[a]))))
	var hv := HBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	var iv := TextureRect.new()
	iv.texture = load("res://artes/interface/icone16_vida.png")
	iv.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	hv.add_child(iv)
	hv.add_child(Tema.rotulo(str(int(round(float(finais["vida"])))), TAM_NUMERO, true))
	linha_atr.add_child(hv)
	_tocar_atributo(hv, "vida", int(round(float(finais["vida"]))))

## Pedido do João (2026-11-22): tocar no ícone (ou no número) do atributo abre o balão explicativo,
## o mesmo da ficha do personagem.
func _tocar_atributo(c: Control, a: String, valor: int) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	for f in c.get_children():
		if f is Control:
			(f as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	Tema.ao_tocar(c, func(_pos: Vector2): Balao.atributo(self, c.get_global_rect(), a, valor))

# ------------------------------------------------------------ espaços em volta do herói
func _espaco(e: String) -> Button:
	var b := Button.new()
	b.size = Vector2(56, 56)
	b.pressed.connect(_tocou_espaco.bind(e))
	_estilo_espaco(b, Color("#545a74"), Color("#0e0f18"))
	if e.begins_with("acessorio"):
		var d := Panel.new()
		var ed := StyleBoxFlat.new()
		ed.bg_color = Color(1.0, 0.84, 0.42, 0.12)
		ed.border_color = Tema.COR_OURO_CLARO
		ed.set_border_width_all(3)
		ed.set_corner_radius_all(4)
		ed.shadow_color = Color(1.0, 0.8, 0.3, 0.5)
		ed.shadow_size = 6
		d.add_theme_stylebox_override("panel", ed)
		d.position = Vector2(-3, -3)
		d.size = Vector2(62, 62)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		d.visible = false
		b.add_child(d)
		destaques[e] = d
	return b

func _estilo_espaco(b: Button, borda: Color, fundo: Color) -> void:
	var est := StyleBoxFlat.new()
	est.bg_color = fundo
	est.border_color = borda
	est.set_border_width_all(2)
	est.set_corner_radius_all(4)
	var apertado := est.duplicate()
	apertado.bg_color = fundo.lightened(0.1)
	for k in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(k, est)
	b.add_theme_stylebox_override("pressed", apertado)

func _preencher_espaco(e: String) -> void:
	var b: Button = espacos[e]
	for f in b.get_children():
		if not destaques.has(e) or f != destaques[e]:
			f.queue_free()
	var p := Equipamento.em(e)
	if p.is_empty():
		_estilo_espaco(b, Color("#3c4058"), Color("#0e0f18"))
		# nome do espaço centralizado dentro do quadro; quebra à mão (uma linha por Label) e diminui se precisar
		var texto := tr(ROTULO_ESPACO[e])
		var linhas := PackedStringArray()
		var tam := TAM_TEXTO
		for t: int in [TAM_TEXTO, 10, 8]:
			tam = t
			linhas = Tema._quebrar(texto, Tema.fonte_texto, t, 46.0, 2)
			if not linhas.is_empty():
				break
		if linhas.is_empty():
			linhas = PackedStringArray([texto])
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 0)
		col.position = Vector2(0, 0)
		col.size = Vector2(56, 54)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for linha in linhas:
			var r := Tema.rotulo(linha, tam)
			r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			r.add_theme_color_override("font_color", Color("#8088a8"))
			r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			r.autowrap_mode = TextServer.AUTOWRAP_OFF
			r.custom_minimum_size = Vector2(56, 0)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(r)
		b.add_child(col)
		return
	var cor: Color = Equipamento.COR_RARIDADE.get(Equipamento.raridade_de(str(p["id"])), Color.WHITE)
	_estilo_espaco(b, cor.darkened(0.15), Color(cor.darkened(0.75), 1.0))
	b.add_child(_peca_visual(str(p["id"]), Vector2(8, 8)))

## Moldura da raridade (40×40) com o ícone 32×32 dentro.
func _peca_visual(id: String, pos: Vector2) -> Control:
	var m := TextureRect.new()
	m.texture = Equipamento.moldura(id)
	m.position = pos
	m.size = Vector2(40, 40)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = Equipamento.icone(id)
	ic.position = Vector2(4, 4)
	ic.size = Vector2(32, 32)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(ic)
	return m

func _tocou_espaco(e: String) -> void:
	if escolhendo_uid >= 0:
		if e.begins_with("acessorio"):
			var uid := escolhendo_uid
			_cancelar_escolha()
			_equipar(uid, e)
		return
	var p := Equipamento.em(e)
	if not p.is_empty():
		_abrir_peca(int(p["uid"]))
		return
	# espaço vazio: mostra só as peças que servem nele
	aba = 0
	filtro = FILTROS.find("acessorio" if e.begins_with("acessorio") else e)
	atualizar_textos()

func _abrir_ficha_personagem() -> void:
	principal.abrir_tela_cheia(preload("res://scripts/telas/personagem.gd").new())

# ------------------------------------------------------------ abas
func _trocar_aba(i: int) -> void:
	aba = i
	atualizar_textos()

func _montar_aba() -> void:
	for f in conteudo.get_children():
		f.queue_free()
	match aba:
		0:
			_aba_equipamentos()
		1:
			_aba_habilidades()
		2:
			_aba_consumiveis()
		3:
			_aba_fragmentos()

## Só as peças fora do corpo (a equipada sai da lista e volta quando é trocada ou tirada).
func _guardadas() -> Array:
	var r: Array = []
	for p in Equipamento.lista():
		if Equipamento.espaco_de_uid(int(p["uid"])) == "":
			r.append(p)
	return r

func _aba_equipamentos() -> void:
	# filtro em fichas lado a lado (um toque escolhe), como nos jogos de coleção
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 3)
	for k in FILTROS.size():
		var bf := Button.new()
		bf.text = "EQ_F_" + str(FILTROS[k]).to_upper()
		bf.custom_minimum_size = Vector2(0, 30)
		bf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bf.add_theme_font_size_override("font_size", TAM_TEXTO)
		bf.clip_text = true
		var ativo := k == filtro
		var e := StyleBoxFlat.new()
		e.bg_color = Color("#3a2c12") if ativo else Color("#161828")
		e.border_color = Tema.COR_OURO if ativo else Color("#3c4058")
		e.set_border_width_all(1)
		e.set_corner_radius_all(12)
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			bf.add_theme_stylebox_override(st, e)
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			bf.add_theme_color_override(c, Tema.COR_OURO_CLARO if ativo else Color("#a8acc0"))
		bf.pressed.connect(_escolher_filtro.bind(k))
		if _tem_nova(str(FILTROS[k])):
			bf.add_child(_ponto_novo())
		topo.add_child(bf)
	conteudo.add_child(topo)
	conteudo.add_child(_fileira_elementos())
	var lista := _guardadas()
	var f: String = FILTROS[filtro]
	if f != "todos":
		lista = lista.filter(_serve_no_filtro.bind(f))
	if not filtro_el.is_empty():
		lista = lista.filter(func(p: Dictionary): return filtro_el.has(Equipamento.elemento_de(str(p["id"]))))
	lista.sort_custom(_ordem)
	var linha := HBoxContainer.new()
	var qtd := Tema.rotulo(tr("EQ_PECAS_N") % lista.size(), TAM_TEXTO)
	qtd.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	qtd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qtd.add_theme_color_override("font_color", Color("#8a90a8"))
	linha.add_child(qtd)
	var teste := Button.new()
	teste.text = "EQ_TESTE"
	teste.custom_minimum_size = Vector2(150, 28)
	teste.add_theme_font_size_override("font_size", TAM_TEXTO)
	Tema.estilo_botao(teste, "secundario")
	teste.modulate = Color(1, 1, 1, 0.7)
	teste.pressed.connect(_ganhar_teste)
	if Jogo.adm():                   # botão de teste só na versão ADM
		linha.add_child(teste)
	else:
		teste.queue_free()
	conteudo.add_child(linha)
	if lista.is_empty():
		var v := Tema.rotulo("EQ_VAZIO", 16)
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.custom_minimum_size = Vector2(330, 60)
		v.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
		conteudo.add_child(v)
		return
	var grade := GridContainer.new()
	grade.columns = 6
	grade.add_theme_constant_override("h_separation", 3)
	grade.add_theme_constant_override("v_separation", 3)
	for i in lista.size():
		var cel := _celula(lista[i])
		cel.modulate.a = 0.0
		grade.add_child(cel)
		var t := create_tween()
		t.tween_property(cel, "modulate:a", 1.0, 0.15).set_delay(minf(i * 0.02, 0.4))
	conteudo.add_child(grade)

## Selo "!" na aba e pontinho vermelho no filtro que têm peça nova ainda não vista (como no Diário).
func _atualizar_alertas() -> void:
	if barra:
		barra.alerta(0, _tem_nova("todos"))

func _tem_nova(f: String) -> bool:
	for p in _guardadas():
		if bool(p.get("novo", false)) and (f == "todos" or _serve_no_filtro(p, f)):
			return true
	return false

func _ponto_novo() -> Panel:
	var ponto := Panel.new()
	var e := StyleBoxFlat.new()
	e.bg_color = Color("#ff4a4a")
	e.border_color = Color("#4a0c18")
	e.set_border_width_all(1)
	e.set_corner_radius_all(4)
	ponto.add_theme_stylebox_override("panel", e)
	ponto.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ponto.offset_left = -10
	ponto.offset_right = -2
	ponto.offset_top = 2
	ponto.offset_bottom = 10
	ponto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ponto

func _serve_no_filtro(p: Dictionary, f: String) -> bool:
	return Equipamento.tipo_de(str(p["id"])) == f

func _ordem(a: Dictionary, b: Dictionary) -> bool:
	var ra: int = Equipamento.ORDEM_RARIDADE.get(Equipamento.raridade_de(str(a["id"])), 9)
	var rb: int = Equipamento.ORDEM_RARIDADE.get(Equipamento.raridade_de(str(b["id"])), 9)
	if ra != rb:
		return ra < rb
	return int(a["uid"]) > int(b["uid"])

## Célula: degradê na cor da raridade, moldura + ícone, losangos da raridade embaixo,
## brilho pulsando no Épico e no Lendário e o pontinho de "novo".
func _celula(p: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 60)
	var id := str(p["id"])
	var rar := Equipamento.raridade_de(id)
	var cor: Color = Equipamento.COR_RARIDADE.get(rar, Color.WHITE)
	var nivel := 5 - int(Equipamento.ORDEM_RARIDADE.get(rar, 4))     # 1 (comum) a 5 (lendário)
	var vazio := StyleBoxEmpty.new()
	for k in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(k, vazio)
	b.draw.connect(func():
		var t := b.size
		for i in 6:
			b.draw_rect(Rect2(0, t.y * i / 6.0, t.x, t.y / 6.0 + 1), Color(cor.darkened(0.82 - i * 0.06), 1.0))
		b.draw_rect(Rect2(0, t.y - 12, t.x, 12), Color(0, 0, 0, 0.35))
		b.draw_rect(Rect2(Vector2.ZERO, t), Color(cor, 0.55), false, 1.0)
		b.draw_rect(Rect2(1, 1, t.x - 2, 1), Color(1, 1, 1, 0.12))
		var x0 := t.x / 2.0 - (nivel * 6 - 2) / 2.0
		for k in nivel:
			var c := Vector2(floorf(x0 + k * 6 + 2), t.y - 6)
			b.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2), c + Vector2(2, 0), c + Vector2(0, 2), c + Vector2(-2, 0)]), cor.lightened(0.2)))
	b.add_child(_peca_visual(id, Vector2(6, 4)))
	if nivel >= 4:
		var brilho := ColorRect.new()
		brilho.color = Color(cor, 0.0)
		brilho.position = Vector2(1, 1)
		brilho.size = Vector2(50, 46)
		brilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(brilho)
		var tw := brilho.create_tween().set_loops()
		tw.tween_property(brilho, "color:a", 0.16, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(brilho, "color:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	if bool(p.get("novo", false)):
		var ponto := Panel.new()
		var e := StyleBoxFlat.new()
		e.bg_color = Color("#ff4a4a")
		e.border_color = Color("#4a0c18")
		e.set_border_width_all(1)
		e.set_corner_radius_all(4)
		ponto.add_theme_stylebox_override("panel", e)
		ponto.position = Vector2(42, 2)
		ponto.size = Vector2(8, 8)
		ponto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ponto)
	b.pressed.connect(_abrir_peca.bind(int(p["uid"])))
	return b

# ------------------------------------------------------------ filtro por elemento (peças e habilidades)
const EL_FILTRO := ["", "fogo", "agua", "terra", "ar", "raio", "gelo"]
const COR_FILTRO := {"": Color("#b8bccc"), "fogo": Color("#ff7a3a"), "agua": Color("#4ab0ff"), "terra": Color("#c8964e"),
	"ar": Color("#6ee0b0"), "raio": Color("#ffe04a"), "gelo": Color("#a8e8ff")}

## Fichas com o ícone de cada elemento (e "sem elemento"); dá para marcar várias ao mesmo tempo.
## Nenhuma marcada = mostra tudo. Pedido do João (2026-11-13).
func _fileira_elementos() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	for el: String in EL_FILTRO:
		var marcado := filtro_el.has(el)
		var cor: Color = COR_FILTRO[el]
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 26)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.icon = load("res://artes/combate/elem16_%s.png" % (el if el != "" else "comum"))
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = false
		b.modulate = Color.WHITE if (marcado or filtro_el.is_empty()) else Color(1, 1, 1, 0.55)
		var e := StyleBoxFlat.new()
		e.bg_color = Color(cor.darkened(0.7), 1.0) if marcado else Color("#161828")
		e.border_color = cor if marcado else Color("#3c4058")
		e.set_border_width_all(2 if marcado else 1)
		e.set_corner_radius_all(12)
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			b.add_theme_stylebox_override(st, e)
		b.pressed.connect(_alternar_elemento.bind(el))
		h.add_child(b)
	return h

func _alternar_elemento(el: String) -> void:
	if filtro_el.has(el):
		filtro_el.erase(el)
	else:
		filtro_el.append(el)
	var y := rolagem.scroll_vertical if rolagem else 0
	_montar_aba()
	if rolagem:
		(func(): rolagem.scroll_vertical = y).call_deferred()

func _passa_elemento_hab(h: String) -> bool:
	return filtro_el.is_empty() or filtro_el.has(str(Catalogo.HAB.get(h, {}).get("el", "")))

func _proximo_filtro() -> void:
	_escolher_filtro((filtro + 1) % FILTROS.size())

func _escolher_filtro(k: int) -> void:
	filtro = k
	_montar_aba()

## Só para testes: uma peça de cada raridade.
func _ganhar_teste() -> void:
	for r in ["comum", "incomum", "raro", "epico", "lendario"]:
		var id := Equipamento.sortear(r)
		if id != "":
			Equipamento.dar(id)
	Jogo.salvar()
	atualizar_textos()

func _aba_consumiveis() -> void:
	var itens := {}
	for it in Artes.dados_itens()["itens"]:
		itens[it["id"]] = it
	var pocoes: Dictionary = Jogo.dados["pocoes"]
	var tem := false
	for id in pocoes:
		if int(pocoes[id]) <= 0 or not itens.has(id):
			continue
		tem = true
		var it: Dictionary = itens[id]
		var cor: Color = Equipamento.COR_RARIDADE.get(str(it["raridade"]), Color.WHITE)
		var linha := PanelContainer.new()
		var el := StyleBoxFlat.new()
		el.bg_color = Color(cor.darkened(0.8), 1.0)
		el.border_color = Color(cor, 0.35)
		el.set_border_width_all(1)
		el.set_corner_radius_all(4)
		el.content_margin_left = 6
		el.content_margin_right = 8
		el.content_margin_top = 4
		el.content_margin_bottom = 4
		linha.add_theme_stylebox_override("panel", el)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var ic := TextureRect.new()
		var pc := Artes.icone(it["icone"])
		if not pc.is_empty():
			var at := AtlasTexture.new()
			at.atlas = pc["tex"]
			at.region = Rect2(pc["rect"].position, Vector2(32, 32))
			ic.texture = at
		ic.custom_minimum_size = Vector2(32, 32)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		h.add_child(ic)
		var textos := VBoxContainer.new()
		textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		textos.add_theme_constant_override("separation", 0)
		var n := Tema.rotulo(str(it["nome"]), 16)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		n.add_theme_color_override("font_color", cor.lightened(0.2))
		textos.add_child(n)
		var ef := Tema.rotulo(str(it.get("efeito", "")).split(" · ")[-1], 12)
		ef.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ef.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ef.custom_minimum_size = Vector2(200, 0)
		ef.add_theme_color_override("font_color", Color("#c8ccd8"))
		textos.add_child(ef)
		h.add_child(textos)
		var q := Tema.rotulo("x%d" % int(pocoes[id]), 16, true)
		q.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
		h.add_child(q)
		linha.add_child(h)
		conteudo.add_child(linha)
	if not tem:
		var v := Tema.rotulo("SEM_POCOES", 16)
		v.custom_minimum_size = Vector2(330, 40)
		conteudo.add_child(v)
	var nota := Tema.rotulo("EQ_NOTA_CONSUMIVEIS", 12)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size = Vector2(330, 0)
	nota.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	conteudo.add_child(nota)

func _aba_fragmentos() -> void:
	var cores := {"fogo": Color("#ff7a3a"), "agua": Color("#4ab0ff"), "terra": Color("#c8964e"),
		"ar": Color("#6ee0b0"), "raio": Color("#ffe04a"), "gelo": Color("#a8e8ff")}
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 6)
	grade.add_theme_constant_override("v_separation", 6)
	var f: Dictionary = Jogo.dados["fragmentos"]
	for el in Catalogo.ELEMENTOS:
		var cor: Color = cores[el]
		var cx := PanelContainer.new()
		cx.custom_minimum_size = Vector2(106, 0)
		var e := StyleBoxFlat.new()
		e.bg_color = Color(cor.darkened(0.8), 1.0)
		e.border_color = Color(cor, 0.5)
		e.set_border_width_all(1)
		e.set_corner_radius_all(4)
		e.content_margin_top = 6
		e.content_margin_bottom = 6
		cx.add_theme_stylebox_override("panel", e)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := TextureRect.new()
		ic.texture = load("res://artes/combate/elem20_%s.png" % el)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		v.add_child(ic)
		var nome := Tema.rotulo("EL_" + str(el).to_upper(), 12)
		nome.add_theme_color_override("font_color", cor)
		v.add_child(nome)
		var q := Tema.rotulo(str(int(f.get(el, 0))), 16, true)
		q.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
		v.add_child(q)
		# nível do Orbe (ou "Sem Orbe") e aviso quando dá para evoluir/obter
		var est_orbe := ORBES.estado(str(el))
		var tx_orbe := (tr("ORBE_NV_CURTO") % int(est_orbe["nivel"])) if est_orbe["tem"] else tr("ORBE_SEM")
		var ro := Tema.rotulo(tx_orbe, 12)
		ro.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		ro.add_theme_color_override("font_color", Color.WHITE if est_orbe["tem"] else Color("#8088a8"))
		v.add_child(ro)
		if est_orbe["pode"] or ORBES.pendente() == str(el):
			var pronto := Tema.rotulo(tr("ORBE_PRONTO"), 8, true)
			pronto.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			pronto.add_theme_color_override("font_color", Color("#7fd07a"))
			v.add_child(pronto)
		cx.add_child(v)
		cx.mouse_filter = Control.MOUSE_FILTER_STOP
		cx.gui_input.connect(_toque_fragmento.bind(str(el)))
		grade.add_child(cx)
	conteudo.add_child(grade)
	var novos := Tema.rotulo(tr("ORBE_OBTIDO_N") % ORBES.novos(), 12)
	novos.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	novos.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	conteudo.add_child(novos)
	var teste := Button.new()
	teste.text = "ORBE_TESTE"
	teste.custom_minimum_size = Vector2(0, 28)
	teste.add_theme_font_size_override("font_size", TAM_TEXTO)
	Tema.estilo_botao(teste, "secundario")
	teste.modulate = Color(1, 1, 1, 0.7)
	teste.pressed.connect(func():
		for e2: String in Catalogo.ELEMENTOS:
			f[e2] = int(f.get(e2, 0)) + 500
		Jogo.salvar()
		_montar_aba())
	teste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var teste_nv := Button.new()
	teste_nv.text = "ORBE_TESTE_NIVEL"
	teste_nv.custom_minimum_size = Vector2(0, 28)
	teste_nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teste_nv.add_theme_font_size_override("font_size", TAM_TEXTO)
	Tema.estilo_botao(teste_nv, "secundario")
	teste_nv.modulate = Color(1, 1, 1, 0.7)
	teste_nv.pressed.connect(func():
		Jogo.dados["nivel"] = mini(100, int(Jogo.dados["nivel"]) + 5)
		Jogo.dados["xp"] = 0
		Jogo.salvar()
		Jogo.progresso_mudou.emit()
		_montar_aba())
	# pedido do João (2026-11-22): botão para acumular Orbes no teste (+1 nível em todos, sem custo)
	var teste_orbes := Button.new()
	teste_orbes.text = "ORBE_TESTE_ACUMULAR"
	teste_orbes.custom_minimum_size = Vector2(0, 28)
	teste_orbes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	teste_orbes.add_theme_font_size_override("font_size", TAM_TEXTO)
	Tema.estilo_botao(teste_orbes, "secundario")
	teste_orbes.modulate = Color(1, 1, 1, 0.7)
	teste_orbes.pressed.connect(func():
		ORBES.acumular_teste()
		_montar_aba())
	var testes := HBoxContainer.new()
	testes.add_theme_constant_override("separation", 6)
	testes.add_child(teste)
	testes.add_child(teste_nv)
	var testes2 := HBoxContainer.new()
	testes2.add_child(teste_orbes)
	if Jogo.adm():                   # botões de teste só na versão ADM
		conteudo.add_child(testes)
		conteudo.add_child(testes2)
	else:
		testes.queue_free()
		testes2.queue_free()
	var nota := Tema.rotulo("ORBE_TOQUE", 12)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size = Vector2(330, 0)
	nota.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	conteudo.add_child(nota)

## Toque num quadro de fragmentos: abre o popup do Orbe daquele elemento.
func _toque_fragmento(ev: InputEvent, el: String) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		var p = POPUP_ORBE.new()
		p.el = el
		p.ao_mudar = _montar_aba
		add_child(p)

# ------------------------------------------------------------ habilidades (trocar os ataques)
const COR_EL := {"fogo": Color("#ff7a3a"), "agua": Color("#4ab0ff"), "terra": Color("#c8964e"),
	"ar": Color("#6ee0b0"), "raio": Color("#ffe04a"), "gelo": Color("#a8e8ff"), "": Color("#b8bccc")}

## Os 4 espaços de habilidade; tocar num deles abre a lista do que pode entrar no lugar.
func _aba_habilidades() -> void:
	var dica := Tema.rotulo("HAB_DICA", 12)
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica.custom_minimum_size = Vector2(330, 0)
	dica.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	conteudo.add_child(dica)
	var habs := Jogo.habilidades()
	for i in habs.size():
		conteudo.add_child(_cartao_hab(str(habs[i]), i + 1, _escolher_hab.bind(i)))
	var guardadas: Array = []
	for h in Jogo.habilidades_conhecidas():
		if not habs.has(h):
			guardadas.append(h)
	var t := Tema.rotulo("HAB_GUARDADAS", 16)
	t.add_theme_color_override("font_color", Tema.COR_OURO)
	conteudo.add_child(t)
	conteudo.add_child(_fileira_elementos())
	guardadas = guardadas.filter(_passa_elemento_hab)
	if guardadas.is_empty():
		var v := Tema.rotulo("HAB_NENHUMA", 12)
		v.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
		conteudo.add_child(v)
	for h in guardadas:
		conteudo.add_child(_cartao_hab(str(h), 0, Callable()))

## Cartão de habilidade: faixa na cor do elemento, ícone, nome, categoria e descrição.
## espaco > 0 mostra o número do espaço; acao válida deixa o cartão tocável.
func _cartao_hab(h: String, espaco: int, acao: Callable, largura := 330.0) -> Control:
	var H: Dictionary = Catalogo.HAB[h]
	var el := str(H.get("el", ""))
	var cor: Color = COR_EL.get(el, COR_EL[""])
	var cartao: Control
	if acao.is_valid():
		var b := Button.new()
		b.pressed.connect(acao)
		cartao = b
	else:
		cartao = PanelContainer.new()
	var est := StyleBoxFlat.new()
	est.bg_color = Color("#1a1c2c")
	est.border_color = Color(cor, 0.7)
	est.set_border_width_all(1)
	est.border_width_left = 4
	est.set_corner_radius_all(4)
	est.content_margin_left = 10
	est.content_margin_right = 8
	est.content_margin_top = 6
	est.content_margin_bottom = 6
	var apertado := est.duplicate() as StyleBoxFlat
	apertado.bg_color = Color("#262a40")
	for e in ["normal", "hover", "focus", "panel", "disabled"]:
		cartao.add_theme_stylebox_override(e, est)
	for e in ["pressed", "hover_pressed"]:
		cartao.add_theme_stylebox_override(e, apertado)
	cartao.custom_minimum_size = Vector2(largura, 0)
	var linhas := VBoxContainer.new()
	linhas.custom_minimum_size = Vector2(largura - 18.0, 0)
	linhas.add_theme_constant_override("separation", 2)
	linhas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 6)
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if espaco > 0:
		var n := Tema.rotulo(str(espaco), 12, true)
		n.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
		topo.add_child(n)
	var ic := TextureRect.new()
	ic.texture = load("res://artes/combate/elem16_%s.png" % (el if el != "" else "comum"))
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	topo.add_child(ic)
	var nome := Tema.rotulo(str(H["nome"]), 16)
	nome.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(nome)
	var cat := str(H["cat"])
	var txt_cat := tr("CAT_COMUM") if cat == "comum" else tr("CAT_" + cat.to_upper()) % int(Catalogo.USOS.get(cat, 0))
	var c := Tema.rotulo(txt_cat, TAM_TEXTO)
	c.add_theme_color_override("font_color", cor)
	topo.add_child(c)
	linhas.add_child(topo)
	var d := Tema.rotulo(Catalogo.descrever(h), 12)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(largura - 24.0, 0)
	d.add_theme_color_override("font_color", Color("#c8ccd8"))
	linhas.add_child(d)
	for f in linhas.find_children("*", "Control", true, false):
		(f as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartao.add_child(linhas)
	Tema.ao_segurar(cartao, _ficha_hab.bind(h, cartao))
	if cartao is Button:
		# o botão cresce junto com o texto de dentro
		linhas.resized.connect(func():
			if is_instance_valid(cartao):
				cartao.custom_minimum_size.y = linhas.size.y + 12.0)
		linhas.position = Vector2(10, 6)
	return cartao

## Segurar o cartão: caixinha com tipo, usos por luta, efeito e melhorias (mesmo balão do combate).
func _ficha_hab(h: String, c: Control) -> void:
	var H: Dictionary = Catalogo.HAB[h]
	var cat := str(H["cat"])
	var linhas: Array = []
	var usos := tr("HAB_INFO_SEM_LIMITE") if cat == "comum" else tr("HAB_INFO_POR_LUTA") % (int(Catalogo.USOS.get(cat, 2)) + ORBES.usos_extras(h))
	linhas.append([tr("HAB_INFO_CAT_" + cat.to_upper()) + " · " + usos, Balao.TINTA_CLARA])
	linhas.append(Catalogo.descrever(h))
	var vezes := ORBES.vezes_melhorada(h)
	if vezes > 0:
		linhas.append([tr("HAB_INFO_MELHORADA") % [vezes, int(round((ORBES.fator(h) - 1.0) * 100.0))], Color("#1e6a2a")])
	Balao.mostrar(self, c.get_global_rect(), str(H["nome"]), Balao.TINTA, linhas)

func _escolher_hab(i: int) -> void:
	var habs := Jogo.habilidades()
	var opcoes := VBoxContainer.new()
	opcoes.add_theme_constant_override("separation", 6)
	var tem := false
	for h in Jogo.habilidades_conhecidas():
		if h == habs[i]:
			continue
		tem = true
		opcoes.add_child(_cartao_hab(str(h), 0, _trocar_hab.bind(i, str(h)), 280.0))
	var aviso := "" if tem else tr("HAB_NENHUMA")
	_abrir_popup(tr("HAB_TROCAR") % (i + 1), [["FECHAR", _fechar_popup]], aviso, [opcoes] if tem else [])

func _trocar_hab(i: int, h: String) -> void:
	var erro := Jogo.trocar_habilidade(i, h)
	_fechar_popup()
	if erro != "":
		_abrir_popup(tr("HABILIDADES"), [["OK", _fechar_popup]], tr(erro))
		return
	atualizar_textos()

# ------------------------------------------------------------ ficha da peça
func _abrir_peca(uid: int) -> void:
	var p := Equipamento.peca(uid)
	if p.is_empty():
		return
	if bool(p.get("novo", false)):
		p["novo"] = false
		Jogo.salvar()
		_atualizar_alertas()
	_fechar_ficha()
	ficha = FichaPeca.new()
	ficha.uid = uid
	ficha.escolheu.connect(_na_ficha.bind(uid))
	add_child(ficha)

func _na_ficha(acao: String, uid: int) -> void:
	match acao:
		"equipar":
			var id := str(Equipamento.peca(uid).get("id", ""))
			var opcoes := Equipamento.espacos_para(id)
			_fechar_ficha()
			if opcoes.size() == 1:
				_equipar(uid, opcoes[0])
			else:
				_comecar_escolha(uid)
		"tirar":
			_fechar_ficha()
			Equipamento.desequipar(Equipamento.espaco_de_uid(uid))
			_depois_de_mudar()
		"vender":
			_fechar_ficha()
			Equipamento.vender(uid)
			_depois_de_mudar()
		"excluir":
			_confirmar_excluir(uid)
		_:
			_fechar_ficha()

func _fechar_ficha() -> void:
	if ficha:
		ficha.fechar()
		ficha = null

## Acessório: os espaços 1 e 2 piscam em dourado e um aviso pede para tocar num deles.
func _comecar_escolha(uid: int) -> void:
	escolhendo_uid = uid
	aviso_escolha = PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = Color("#2a2140")
	e.border_color = Tema.COR_OURO_CLARO
	e.set_border_width_all(2)
	e.set_corner_radius_all(4)
	e.content_margin_left = 8
	e.content_margin_right = 6
	e.content_margin_top = 4
	e.content_margin_bottom = 4
	aviso_escolha.add_theme_stylebox_override("panel", e)
	aviso_escolha.position = Vector2(8, 294)
	aviso_escolha.size = Vector2(344, 40)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var ic := TextureRect.new()
	ic.texture = Equipamento.icone(str(Equipamento.peca(uid).get("id", "")))
	ic.custom_minimum_size = Vector2(32, 32)
	h.add_child(ic)
	var r := Tema.rotulo("EQ_ESCOLHA_ACESS", 12)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	h.add_child(r)
	var cancelar := Button.new()
	cancelar.text = "CANCELAR"
	cancelar.custom_minimum_size = Vector2(84, 30)
	cancelar.add_theme_font_size_override("font_size", 12)
	Tema.estilo_botao(cancelar, "secundario")
	cancelar.pressed.connect(_cancelar_escolha)
	h.add_child(cancelar)
	aviso_escolha.add_child(h)
	add_child(aviso_escolha)
	aviso_escolha.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(aviso_escolha, "modulate:a", 1.0, 0.15)

func _cancelar_escolha() -> void:
	escolhendo_uid = -1
	if aviso_escolha:
		aviso_escolha.queue_free()
		aviso_escolha = null

func _equipar(uid: int, espaco: String) -> void:
	Equipamento.equipar(uid, espaco)
	_depois_de_mudar()
	# a peça "voa" para o espaço com um brilho, e o herói dá um pulinho
	var b: Button = espacos[espaco]
	b.pivot_offset = Vector2(28, 28)
	b.scale = Vector2(1.3, 1.3)
	var tb := create_tween()
	tb.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var t := create_tween()
	t.tween_property(heroi, "position:y", 44.0, 0.08)
	t.tween_property(heroi, "position:y", 50.0, 0.14)
	heroi.modulate = Color(1.6, 1.6, 1.3)
	var tl := create_tween()
	tl.tween_property(heroi, "modulate", Color.WHITE, 0.4)

func _confirmar_excluir(uid: int) -> void:
	var nome := str(Equipamento.ficha(str(Equipamento.peca(uid)["id"]))["nome"])
	_abrir_popup(tr("EQ_EXCLUIR_PERGUNTA") % nome, [["EQ_EXCLUIR", _excluir.bind(uid)], ["NAO", _fechar_popup]])

func _excluir(uid: int) -> void:
	_fechar_ficha()
	Equipamento.remover(uid)
	_depois_de_mudar()

func _depois_de_mudar() -> void:
	_fechar_popup()
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	atualizar_textos()

func _abrir_popup(titulo: String, botoes: Array, texto := "", mais: Array = []) -> void:
	_fechar_popup()
	popup = Janela.criar(titulo, botoes, texto, mais)
	add_child(popup)

func _fechar_popup() -> void:
	if popup:
		popup.fechar()
		popup = null
