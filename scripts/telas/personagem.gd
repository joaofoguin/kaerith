extends Tela
## Ficha do personagem, no formato das fichas de RPG: cada assunto no seu quadro.
##   1. Identidade  – retrato, nome, nível, elemento, experiência e Vida
##   2. Atributos   – um quadrinho por atributo (o bônus das peças aparece em verde)
##   3. Equipamentos – os 5 espaços, só para consulta (troca-se no Inventário)
##   4. Habilidades – as 4 equipadas, numeradas como no combate
## Abre ao tocar no herói do Início ou no botão Ficha do Inventário.
## Para mudar o visual de todos os quadros de uma vez, mexa em _bloco() e nas cores abaixo.

const ICONE_ATR := {"forca": "icone16_forca.png", "percepcao": "icone16_percepcao.png", "agilidade": "icone16_agilidade.png",
	"resistencia": "icone16_resistencia.png", "ressonancia": "icone16_ressonancia.png", "vida": "icone16_vida.png"}
const ROTULO_ESPACO := {"cabeca": "EQ_CABECA", "arma": "EQ_ARMA", "acessorio1": "EQ_ACESSORIO_1", "armadura": "EQ_ARMADURA", "acessorio2": "EQ_ACESSORIO_2"}
const ORDEM_ESPACOS := ["cabeca", "armadura", "arma", "acessorio1", "acessorio2"]
const COR_EL := {"fogo": Color("#ff7a3a"), "agua": Color("#4ab0ff"), "terra": Color("#c8964e"),
	"ar": Color("#6ee0b0"), "raio": Color("#ffe04a"), "gelo": Color("#a8e8ff"), "": Color("#b8bccc")}
const COR_QUADRO := Color("#171928")
const COR_BORDA := Color("#3c4058")
const COR_CELULA := Color("#0f101a")
const COR_DESCRICAO := Color("#c8ccd8")
const COR_BONUS := Color("#7fd07a")
const LARGURA := 344.0                 # largura útil da ficha (tela de 360 com 8 de margem)

var lista: VBoxContainer

func montar() -> void:
	Tema.fundo(self, Tema.COR_FUNDO)
	Tema.cabecalho(self, "FICHA_TITULO", 230)
	var voltar := Button.new()
	voltar.text = "VOLTAR"
	voltar.position = Vector2(266, 6)
	voltar.size = Vector2(88, 32)
	voltar.add_theme_font_size_override("font_size", 12)
	Tema.estilo_botao(voltar, "secundario")
	voltar.pressed.connect(_voltar)
	add_child(voltar)

	var rolagem := ScrollContainer.new()
	rolagem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rolagem.offset_left = 8
	rolagem.offset_right = -8
	rolagem.offset_top = 52
	rolagem.offset_bottom = -6
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(rolagem)
	lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 10)
	rolagem.add_child(lista)
	_preencher()

func atualizar_textos() -> void:
	for f in lista.get_children():
		f.queue_free()
	_preencher()

func _preencher() -> void:
	var nv := int(Jogo.dados["nivel"])
	var el := str(Jogo.dados["elemento"])
	var modelo: Array = Catalogo.MODELO_JOGADOR.get(el, Catalogo.MODELO_JOGADOR[""])
	var finais := Equipamento.atributos_finais(modelo, Lutador.fator_de(nv))      # já soma os equipamentos
	var pontos: Dictionary = Equipamento.bonus()["pontos"]
	_bloco_identidade(nv, el, int(round(float(finais["vida"]))))
	_bloco_atributos(finais, pontos)
	_bloco_equipamentos()
	_bloco_habilidades()

# ------------------------------------------------------------ peças comuns
func _caixa(fundo: Color, borda: Color, grossura := 1, margem := 6) -> StyleBoxFlat:
	var e := StyleBoxFlat.new()
	e.bg_color = fundo
	e.border_color = borda
	e.set_border_width_all(grossura)
	e.set_corner_radius_all(3)
	e.set_content_margin_all(margem)
	return e

## Quadro de uma seção: título dourado com losango e fio, e o conteúdo embaixo. Devolve a coluna do conteúdo.
func _bloco(chave: String) -> VBoxContainer:
	var quadro := PanelContainer.new()
	quadro.add_theme_stylebox_override("panel", _caixa(COR_QUADRO, COR_BORDA, 1, 8))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	quadro.add_child(col)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 6)
	var marca := ColorRect.new()                           # marcador dourado ao lado do título
	marca.color = Tema.COR_OURO
	marca.custom_minimum_size = Vector2(4, 12)
	marca.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(marca)
	var t := Tema.rotulo(chave, 16)
	t.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	topo.add_child(t)
	var fio := ColorRect.new()
	fio.color = Color(Tema.COR_OURO, 0.45)
	fio.custom_minimum_size = Vector2(0, 1)
	fio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(fio)
	col.add_child(topo)
	lista.add_child(quadro)
	return col

func _icone(caminho: String) -> TextureRect:
	var ic := TextureRect.new()
	ic.texture = load(caminho)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.custom_minimum_size = Vector2(16, 16)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic

## Barra com rótulo à esquerda e números à direita (experiência e Vida).
func _barra(chave: String, texto_valor: String, valor: float, maximo: float, cor: Color, icone := "") -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 3)
	if icone != "":
		linha.add_child(_icone(icone))
	var r := Tema.rotulo(chave, 8, true)
	r.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.uppercase = true
	linha.add_child(r)
	var v := Tema.rotulo(texto_valor, 8, true)
	v.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	linha.add_child(v)
	col.add_child(linha)
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 8)
	barra.max_value = maxf(maximo, 1.0)
	barra.value = valor
	var cheio := StyleBoxFlat.new()
	cheio.bg_color = cor
	cheio.border_color = cor.lightened(0.35)
	cheio.border_width_top = 2
	barra.add_theme_stylebox_override("fill", cheio)
	var vazio := StyleBoxFlat.new()
	vazio.bg_color = Color("#0c0d16")
	vazio.border_color = COR_BORDA
	vazio.set_border_width_all(1)
	barra.add_theme_stylebox_override("background", vazio)
	col.add_child(barra)
	return col

## Etiqueta pequena com fundo (nível, elemento, categoria da habilidade).
func _etiqueta(texto: String, cor_texto: Color, fundo: Color, borda: Color, icone := "") -> PanelContainer:
	var p := PanelContainer.new()
	var e := _caixa(fundo, borda, 1, 3)
	e.content_margin_left = 6
	e.content_margin_right = 6
	p.add_theme_stylebox_override("panel", e)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	if icone != "":
		h.add_child(_icone(icone))
	var r := Tema.rotulo(texto, 12)
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.add_theme_color_override("font_color", cor_texto)
	h.add_child(r)
	p.add_child(h)
	return p

# ------------------------------------------------------------ 1. identidade
func _bloco_identidade(nv: int, el: String, vida: int) -> void:
	var quadro := PanelContainer.new()
	quadro.add_theme_stylebox_override("panel", _caixa(COR_QUADRO, Color(Tema.COR_OURO, 0.7), 1, 8))
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 10)
	quadro.add_child(linha)
	lista.add_child(quadro)

	# retrato emoldurado
	var retrato := PanelContainer.new()
	retrato.add_theme_stylebox_override("panel", _caixa(Color("#0c0d16"), Tema.COR_OURO, 2, 2))
	var heroi := HeroiFrente.new()
	heroi.escala = 2
	heroi.custom_minimum_size = Vector2(96, 128)
	heroi.vestir(Jogo.camadas_heroi())
	retrato.add_child(heroi)
	linha.add_child(retrato)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 7)
	linha.add_child(info)
	var nome := Tema.rotulo(Jogo.nome_heroi(), 24)
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nome.clip_text = true
	info.add_child(nome)
	var etiquetas := HBoxContainer.new()
	etiquetas.add_theme_constant_override("separation", 6)
	etiquetas.add_child(_etiqueta(tr("NIVEL_N") % nv, Tema.COR_TEXTO_ESCURO, Tema.COR_OURO, Tema.COR_OURO_CLARO))
	var cor_el: Color = COR_EL.get(el, COR_EL[""])
	etiquetas.add_child(_etiqueta(tr("EL_" + el.to_upper()) if el != "" else tr("SEM_ELEMENTO"), cor_el,
		Color(cor_el.darkened(0.8), 1.0), Color(cor_el, 0.8), "res://artes/combate/elem16_%s.png" % (el if el != "" else "comum")))
	info.add_child(etiquetas)
	var xp := int(Jogo.dados["xp"])
	var xp_max: int = Jogo.xp_para(nv)
	info.add_child(_barra("FICHA_EXPERIENCIA", "%d / %d" % [xp, xp_max], xp, xp_max, Color("#4aa8e8")))
	info.add_child(_barra("ATR_VIDA", str(vida), 1.0, 1.0, Color("#d8394a")))

# ------------------------------------------------------------ 2. atributos
func _bloco_atributos(finais: Dictionary, pontos: Dictionary) -> void:
	var col := _bloco("ATRIBUTOS")
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 6)
	grade.add_theme_constant_override("v_separation", 6)
	for a in Equipamento.ATRIBUTOS:
		grade.add_child(_celula_atributo(a, int(round(float(finais[a]))), int(pontos.get(a, 0))))
	grade.add_child(_celula_atributo("vida", int(round(float(finais["vida"]))), 0))
	col.add_child(grade)

## Quadrinho de um atributo: ícone e nome em cima, número grande embaixo.
func _celula_atributo(a: String, valor: int, bonus: int) -> Control:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", _caixa(COR_CELULA, COR_BORDA, 1, 5))
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 2)
	p.add_child(c)
	var topo := HBoxContainer.new()
	topo.alignment = BoxContainer.ALIGNMENT_CENTER
	topo.add_theme_constant_override("separation", 3)
	topo.add_child(_icone("res://artes/interface/" + ICONE_ATR[a]))
	var n := Tema.rotulo("ATR_" + a.to_upper(), 12)
	n.add_theme_color_override("font_color", COR_DESCRICAO)
	topo.add_child(n)
	c.add_child(topo)
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 4)
	var v := Tema.rotulo(str(valor), 16, true)             # número de relance: Silkscreen 16 (kit)
	v.add_theme_color_override("font_color", COR_BONUS if bonus > 0 else Tema.COR_OURO_CLARO)
	linha.add_child(v)
	if bonus > 0:
		var b := Tema.rotulo("+%d" % bonus, 8, true)
		b.add_theme_color_override("font_color", COR_BONUS)
		linha.add_child(b)
	c.add_child(linha)
	# tocar no quadrinho explica o atributo (pedido do João, 2026-11-13)
	Tema.ao_tocar(p, func(_pos: Vector2): _balao_atributo(a, valor, p))
	return p

## Balão com o que o atributo faz e quanto ele vale agora (fórmulas do Motor, em Balao.atributo).
func _balao_atributo(a: String, valor: int, quem: Control) -> void:
	Balao.atributo(self, quem.get_global_rect(), a, valor)

# ------------------------------------------------------------ 3. equipamentos
func _bloco_equipamentos() -> void:
	var col := _bloco("FICHA_EQUIPAMENTOS")
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 8)
	for e in ORDEM_ESPACOS:
		linha.add_child(_espaco(e))
	col.add_child(linha)

func _espaco(e: String) -> Control:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 3)
	c.custom_minimum_size = Vector2(56, 0)
	var quadro := Panel.new()
	quadro.custom_minimum_size = Vector2(48, 48)
	quadro.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var p := Equipamento.em(e)
	if p.is_empty():
		quadro.add_theme_stylebox_override("panel", _caixa(COR_CELULA, COR_BORDA, 1, 0))
		var traco := Tema.rotulo("-", 16, true)
		traco.add_theme_color_override("font_color", COR_BORDA)
		traco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		traco.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		quadro.add_child(traco)
	else:
		var id := str(p["id"])
		var cor: Color = Equipamento.COR_RARIDADE.get(Equipamento.raridade_de(id), Color.WHITE)
		quadro.add_theme_stylebox_override("panel", _caixa(Color(cor.darkened(0.75), 1.0), cor.darkened(0.15), 1, 0))
		var m := TextureRect.new()
		m.texture = Equipamento.moldura(id)
		m.position = Vector2(4, 4)
		m.size = Vector2(40, 40)
		quadro.add_child(m)
		var ic := TextureRect.new()
		ic.texture = Equipamento.icone(id)
		ic.position = Vector2(8, 8)
		ic.size = Vector2(32, 32)
		quadro.add_child(ic)
	c.add_child(quadro)
	var r := Tema.rotulo(ROTULO_ESPACO[e], 8, true)
	r.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	r.uppercase = true
	r.clip_text = true
	c.add_child(r)
	return c

# ------------------------------------------------------------ 4. habilidades
func _bloco_habilidades() -> void:
	var col := _bloco("HABILIDADES")
	var n := 1
	for h in Jogo.habilidades():
		col.add_child(_habilidade(n, h))
		n += 1
	var dica := Tema.rotulo("HAB_ONDE_TROCAR", 12)
	dica.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	col.add_child(dica)

## Cartão de uma habilidade: número do espaço, ícone e nome, categoria à direita e a descrição embaixo.
func _habilidade(numero: int, h: String) -> Control:
	var H: Dictionary = Catalogo.HAB[h]
	var el := str(H.get("el", ""))
	var cor: Color = COR_EL.get(el, COR_EL[""])
	var painel := PanelContainer.new()
	var est := _caixa(COR_CELULA, COR_BORDA, 1, 6)
	est.border_width_left = 4                              # faixa da cor do elemento
	est.border_color = Color(cor, 0.85)
	painel.add_theme_stylebox_override("panel", est)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	painel.add_child(linha)
	var num := Tema.rotulo(str(numero), 16, true)
	num.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	num.custom_minimum_size = Vector2(14, 0)
	linha.add_child(num)
	var c := VBoxContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_constant_override("separation", 3)
	linha.add_child(c)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 4)
	topo.add_child(_icone("res://artes/combate/elem16_%s.png" % (el if el != "" else "comum")))
	var nome := Tema.rotulo(str(H["nome"]), 16)
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nome.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.clip_text = true
	topo.add_child(nome)
	var cat := str(H["cat"])
	var txt_cat := tr("CAT_COMUM") if cat == "comum" else tr("CAT_" + cat.to_upper()) % int(Catalogo.USOS[cat])
	var rc := Tema.rotulo(txt_cat, 8, true)
	rc.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	rc.uppercase = true
	rc.add_theme_color_override("font_color", cor if cat != "comum" else Tema.COR_TEXTO_APAGADO)
	rc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(rc)
	c.add_child(topo)
	var d := Tema.rotulo(Catalogo.descrever(h), 12)
	d.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(LARGURA - 70.0, 0)
	d.add_theme_color_override("font_color", COR_DESCRICAO)
	c.add_child(d)
	return painel

func _voltar() -> void:
	principal.fechar_tela_cheia()
