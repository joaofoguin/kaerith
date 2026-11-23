extends "res://scripts/componentes/popup_vitrine.gd"
## Popup do Orbe de um elemento (toque no quadro da aba Fragmentos do Inventário): o Orbe desenhado,
## nível, fragmentos até o próximo passo, o que é preciso (fragmentos e nível do personagem), o botão
## Evoluir/Obter, as 6 habilidades do elemento e a tabela de todos os níveis com custo e exigência.
## Depois de evoluir/obter, o mesmo popup mostra a escolha: aprender uma habilidade ou melhorar uma.
## Uso: var p = POPUP_ORBE.new(); p.el = "fogo"; p.ao_mudar = refazer; add_child(p)

const ORBES := preload("res://scripts/orbes.gd")
const COR_EL := {"fogo": Color("#ff7a3a"), "agua": Color("#4ab0ff"), "terra": Color("#c8964e"),
	"ar": Color("#6ee0b0"), "raio": Color("#ffe04a"), "gelo": Color("#a8e8ff")}
const VERDE := Color("#7fd07a")
const CINZA := Color("#8088a8")
const TEXTO := Color("#d8dae6")

var el := "fogo"
var ao_mudar: Callable

var _orbe: Control

func _ready() -> void:
	var c: Color = COR_EL.get(el, Tema.COR_OURO)
	cor_acento = c
	cor_claro = c.lightened(0.35)
	cor_fundo = Color(c.darkened(0.86), 1.0)
	cor_escuro = Color(c.darkened(0.9), 1.0)
	super._ready()

func _montar(col: VBoxContainer) -> void:
	var e := ORBES.estado(el)
	var nome_el := tr("EL_" + el.to_upper())

	# cabeçalho: Orbe desenhado + nome + nível
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 10)
	_orbe = Control.new()
	_orbe.custom_minimum_size = Vector2(56, 56)
	_orbe.draw.connect(_desenhar_orbe.bind(bool(e["tem"])))
	cab.add_child(_orbe)
	var tit := VBoxContainer.new()
	tit.alignment = BoxContainer.ALIGNMENT_CENTER
	tit.add_theme_constant_override("separation", 2)
	var nome := Tema.rotulo(tr("ORBE_TITULO") % nome_el, 24)
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nome.add_theme_constant_override("outline_size", 4)
	nome.add_theme_color_override("font_outline_color", cor_escuro)
	tit.add_child(nome)
	var linha_selos := HBoxContainer.new()
	linha_selos.add_theme_constant_override("separation", 4)
	if e["tem"]:
		linha_selos.add_child(selo(tr("ORBE_NIVEL") % [int(e["nivel"]), ORBES.MAX_NIVEL], Color.WHITE, Color(cor_acento.darkened(0.5), 1.0), cor_acento))
	else:
		linha_selos.add_child(selo(tr("ORBE_NAO_OBTIDO"), CINZA, Color("#0e0f18"), Color("#3c4058")))
	if el == ORBES.base():
		linha_selos.add_child(selo(tr("ORBE_BASE"), Tema.COR_OURO_CLARO, Color("#2a2010"), Tema.COR_OURO))
	tit.add_child(linha_selos)
	cab.add_child(tit)
	col.add_child(cab)

	if ORBES.base() == "":
		col.add_child(paragrafo("ORBE_SEM_ELEMENTO", TEXTO))
		return

	# escolha pendente deste Orbe: ela vem antes de tudo
	if ORBES.pendente() == el:
		_montar_escolha(col)
		return

	# fragmentos e o que falta para o próximo passo
	var frag := ORBES.fragmentos(el)
	if not e["maximo"] and str(e["acao"]) != "":
		var custo := int(e["custo"])
		col.add_child(secao("ORBE_PRECISA" if e["acao"] == "evoluir" else "ORBE_PRECISA_OBTER", "%d/%d" % [mini(frag, custo), custo]))
		col.add_child(barra(float(frag) / maxf(1.0, float(custo)), cor_acento, 10.0))
		col.add_child(_requisito(tr("ORBE_REQ_FRAG") % [custo, nome_el], int(e["falta_frag"]) == 0, load("res://artes/resultado/icone24_fragmento.png")))
		col.add_child(_requisito(tr("ORBE_REQ_NIVEL") % int(e["nivel_req"]), not e["falta_nivel"], load("res://artes/resultado/icone24_xp.png")))
		var outro := ORBES.pendente()
		if outro != "" and outro != el:
			col.add_child(paragrafo(tr("ORBE_PENDENTE_OUTRO") % tr("EL_" + outro.to_upper()), Color("#ff9a8a")))
		var bt := Button.new()
		bt.text = "ORBE_EVOLUIR" if e["acao"] == "evoluir" else "ORBE_OBTER"
		bt.custom_minimum_size = Vector2(0, 42)
		Tema.estilo_botao(bt, "confirmar" if e["pode"] else "secundario")
		bt.disabled = not e["pode"]
		if not e["pode"]:
			bt.modulate.a = 0.6
		bt.pressed.connect(_avancar)
		col.add_child(bt)
		if Jogo.adm() and not e["pode"] and ORBES.pendente() == "":
			# versão ADM: evoluir/obter agora, sem fragmentos e sem pedir nível (para testar a escolha)
			var bt_teste := Button.new()
			bt_teste.text = "ORBE_TESTE_AGORA"
			bt_teste.custom_minimum_size = Vector2(0, 32)
			bt_teste.add_theme_font_size_override("font_size", 12)
			Tema.estilo_botao(bt_teste, "secundario")
			bt_teste.modulate.a = 0.75
			bt_teste.pressed.connect(func():
				if ORBES.avancar_teste(el):
					_refazer())
			col.add_child(bt_teste)
	elif e["maximo"]:
		col.add_child(selo(tr("ORBE_MAXIMO"), Tema.COR_OURO_CLARO, Color("#2a2010"), Tema.COR_OURO))
	else:
		col.add_child(paragrafo(tr("ORBE_LIMITE_NOVOS"), CINZA))

	# habilidades do elemento
	var habs := ORBES.habilidades_do(el)
	var conhecidas := 0
	for h in habs:
		if ORBES.conhece(h):
			conhecidas += 1
	col.add_child(secao("ORBE_HABILIDADES", "%d/%d" % [conhecidas, habs.size()]))
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 2)
	for h in habs:
		lista.add_child(_linha_hab(h))
	col.add_child(lista)

	# bônus e tabela de níveis
	col.add_child(secao("ORBE_BONUS"))
	col.add_child(paragrafo(tr("ORBE_BONUS_TEXTO") % nome_el, TEXTO))
	col.add_child(secao("ORBE_NIVEIS"))
	col.add_child(_tabela(int(e["nivel"])))

# ------------------------------------------------------------ peças
func _requisito(texto: String, ok: bool, icone: Texture2D) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var ic := TextureRect.new()
	ic.texture = icone
	ic.custom_minimum_size = Vector2(16, 16)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(ic)
	var r := Tema.rotulo(texto, 12)
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_color_override("font_color", TEXTO)
	h.add_child(r)
	var marca := Tema.rotulo("OK" if ok else tr("ORBE_FALTA"), 8, true)
	marca.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	marca.add_theme_color_override("font_color", VERDE if ok else Color("#ff7a6b"))
	marca.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(marca)
	return h

## Uma habilidade: nome à esquerda, categoria pequena e o estado à direita.
func _linha_hab(h: String) -> Control:
	var H: Dictionary = Catalogo.HAB[h]
	var conhece := ORBES.conhece(h)
	var p := PanelContainer.new()
	var est := StyleBoxFlat.new()
	est.bg_color = Color(cor_acento.darkened(0.8), 1.0) if conhece else Color("#0e0f18")
	est.border_color = Color(cor_acento, 0.5) if conhece else Color("#2a2d40")
	est.set_border_width_all(1)
	est.set_corner_radius_all(3)
	est.content_margin_left = 6
	est.content_margin_right = 6
	est.content_margin_top = 2
	est.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", est)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 6)
	var n := Tema.rotulo(str(H["nome"]), 12)
	n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	n.add_theme_color_override("font_color", Color.WHITE if conhece else CINZA)
	linha.add_child(n)
	var cat := Tema.rotulo(tr("ORBE_CAT_" + str(H["cat"]).to_upper()), 8, true)
	cat.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	cat.add_theme_color_override("font_color", CINZA)
	cat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(cat)
	var vezes := ORBES.vezes_melhorada(h)
	var estado := tr("ORBE_BLOQUEADA")
	var cor := CINZA
	if conhece:
		estado = (tr("ORBE_MELHORADA") % (vezes * 20)) if vezes > 0 else tr("ORBE_CONHECIDA")
		cor = VERDE
	var s := Tema.rotulo(estado, 8, true)
	s.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	s.custom_minimum_size = Vector2(64, 0)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.add_theme_color_override("font_color", cor)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(s)
	p.add_child(linha)
	return p

## Os 9 passos (níveis 2 a 10): custo em fragmentos e nível do personagem. Feitos em verde, o próximo
## com borda na cor do elemento.
func _tabela(atual: int) -> Control:
	var grade := GridContainer.new()
	grade.columns = 3
	grade.add_theme_constant_override("h_separation", 4)
	grade.add_theme_constant_override("v_separation", 4)
	for n: int in range(2, ORBES.MAX_NIVEL + 1):
		var feito := atual >= n
		var proximo := atual + 1 == n and atual >= 1
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(104, 0)
		var est := StyleBoxFlat.new()
		est.bg_color = Color("#14301c") if feito else Color("#0e0f18")
		est.border_color = VERDE if feito else (cor_acento if proximo else Color("#2a2d40"))
		est.set_border_width_all(2 if proximo else 1)
		est.set_corner_radius_all(3)
		est.content_margin_top = 2
		est.content_margin_bottom = 3
		p.add_theme_stylebox_override("panel", est)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var t := Tema.rotulo(tr("ORBE_NIVEL_CELULA") % n, 8, true)
		t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		t.add_theme_color_override("font_color", VERDE if feito else cor_claro)
		v.add_child(t)
		var c := Tema.rotulo(tr("ORBE_CELULA_CUSTO") % ORBES.CUSTO_NIVEL[n], 12)
		c.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		c.add_theme_color_override("font_color", Color.WHITE if not feito else VERDE)
		v.add_child(c)
		var q := Tema.rotulo(tr("ORBE_CELULA_NIVEL") % ORBES.nivel_minimo_para(n), 12)
		q.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		q.add_theme_color_override("font_color", CINZA)
		v.add_child(q)
		p.add_child(v)
		grade.add_child(p)
	return grade

# ------------------------------------------------------------ escolha depois de evoluir/obter
func _montar_escolha(col: VBoxContainer) -> void:
	var op := ORBES.opcoes(el)
	var aprender: Array = op["aprender"]
	var melhorar: Array = op["melhorar"]
	col.add_child(secao("ORBE_ESCOLHA"))
	col.add_child(paragrafo("ORBE_ESCOLHA_NOVO" if ORBES.nivel(el) <= 1 else "ORBE_ESCOLHA_TEXTO", TEXTO))
	if aprender.is_empty() and melhorar.is_empty():
		var ok := Button.new()
		ok.text = "OK"
		ok.custom_minimum_size = Vector2(0, 40)
		Tema.estilo_botao(ok, "primario")
		ok.pressed.connect(func():
			ORBES.pular_escolha()
			_refazer())
		col.add_child(ok)
		return
	if not aprender.is_empty():
		col.add_child(secao("ORBE_APRENDER"))
		for h in aprender:
			col.add_child(_opcao(h, "aprender"))
	if not melhorar.is_empty():
		col.add_child(secao("ORBE_MELHORAR"))
		for h in melhorar:
			col.add_child(_opcao(h, "melhorar"))

## Cartão tocável: nome, descrição curta e o que acontece (Aprender / +20%).
func _opcao(h: String, tipo: String) -> Control:
	var H: Dictionary = Catalogo.HAB[h]
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 50)
	var est := StyleBoxFlat.new()
	est.bg_color = Color(cor_acento.darkened(0.78), 1.0)
	est.border_color = cor_acento
	est.set_border_width_all(1)
	est.set_corner_radius_all(4)
	var ap := est.duplicate()
	ap.bg_color = Color(cor_acento.darkened(0.6), 1.0)
	for k in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(k, est)
	b.add_theme_stylebox_override("pressed", ap)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.position = Vector2(8, 4)
	v.size = Vector2(LARGURA - 32.0, 42)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var topo := HBoxContainer.new()
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := Tema.rotulo(str(H["nome"]), 12)
	n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topo.add_child(n)
	var vezes := ORBES.vezes_melhorada(h)
	var acao := tr("ORBE_APRENDER") if tipo == "aprender" else "+%d%% → +%d%%" % [vezes * 20, (vezes + 1) * 20]
	var a := Tema.rotulo(acao, 8, true)
	a.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	a.add_theme_color_override("font_color", VERDE)
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topo.add_child(a)
	v.add_child(topo)
	var linhas := Tema._quebrar(Catalogo.descrever(h), Tema.fonte_texto, 12, LARGURA - 36.0, 2)
	if linhas.is_empty():
		linhas = PackedStringArray([Catalogo.descrever(h)])
	for linha in linhas:
		var d := Tema.rotulo(linha, 12)
		d.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		d.clip_text = true
		d.add_theme_color_override("font_color", TEXTO)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(d)
	b.custom_minimum_size = Vector2(0, 22 + 16 * linhas.size())
	b.add_child(v)
	b.pressed.connect(func():
		if tipo == "aprender":
			ORBES.aprender(h)
		else:
			ORBES.melhorar(h)
		_refazer())
	return b

# ------------------------------------------------------------ ações
func _avancar() -> void:
	if ORBES.avancar(el):
		_refazer()

## Fecha e abre de novo com os dados novos (e avisa a tela de trás).
func _refazer() -> void:
	if ao_mudar.is_valid():
		ao_mudar.call()
	var p = load("res://scripts/componentes/popup_orbe.gd").new()
	p.el = el
	p.ao_mudar = ao_mudar
	get_parent().add_child(p)
	queue_free()

## Orbe: esfera em camadas na cor do elemento com brilho no alto à esquerda; apagado se não obtido.
func _desenhar_orbe(tem: bool) -> void:
	var c := Vector2(28, 28)
	var base: Color = cor_acento if tem else Color("#3c4058")
	var t := _tempo
	if tem:
		var pulso := 0.5 + 0.5 * sin(t * 2.5)
		_orbe.draw_circle(c, 27, Color(base, 0.12 + 0.1 * pulso))
	_orbe.draw_circle(c, 23, Color("#0a0b12"))
	_orbe.draw_circle(c, 22, base.darkened(0.55))
	_orbe.draw_circle(c + Vector2(-2, -2), 18, base.darkened(0.25))
	_orbe.draw_circle(c + Vector2(-4, -4), 13, base)
	_orbe.draw_circle(c + Vector2(-6, -6), 7, base.lightened(0.35))
	_orbe.draw_circle(c + Vector2(-9, -9), 3, Color(1, 1, 1, 0.9 if tem else 0.3))
	var ic: Texture2D = load("res://artes/combate/elem20_%s.png" % el)
	_orbe.draw_texture(ic, c - Vector2(10, 10) + Vector2(2, 2), Color(1, 1, 1, 1.0 if tem else 0.35))

func _process(delta: float) -> void:
	super._process(delta)
	if _orbe:
		_orbe.queue_redraw()
