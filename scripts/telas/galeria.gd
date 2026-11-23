extends Tela
## Galeria de teste (etapa 2): confere no Godot as artes aprovadas — herói, inimigos e itens.

const ANIM_HEROI := ["parado", "ataque", "dano", "queda"]
const ARMAS := ["arma_espada_Comum_-", "arma_machado_Comum_-", "arma_cajado_Comum_-", "arma_lanca_Comum_-"]
const ARMADURAS := ["", "armadura_gibao_Couro_Comum_-", "armadura_malha_Ferro_Comum_-", "armadura_placas_Ferro_Comum_-"]

var area: Control
var info: Label
var i_arma := 0
var i_armadura := 0
var i_inimigo := 0
var heroi_costas: SpriteCamadas
var heroi_frente: SpriteCamadas
var inimigo: SpriteCamadas
var caixa_acoes: HBoxContainer

func montar() -> void:
	var fundo := ColorRect.new()
	fundo.color = Tema.COR_FUNDO
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fundo)

	var raiz := VBoxContainer.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.offset_left = 8
	raiz.offset_right = -8
	raiz.offset_top = 8
	raiz.offset_bottom = -8
	raiz.add_theme_constant_override("separation", 6)
	add_child(raiz)

	var topo := HBoxContainer.new()
	var voltar := Button.new()
	voltar.text = "VOLTAR"
	voltar.pressed.connect(func(): principal.fechar_tela_cheia())
	topo.add_child(voltar)
	for par in [["GAL_HEROI", _mostrar_heroi], ["GAL_INIMIGOS", _mostrar_inimigos], ["GAL_ITENS", _mostrar_itens]]:
		var b := Button.new()
		b.text = par[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(par[1])
		topo.add_child(b)
	raiz.add_child(topo)

	info = Tema.rotulo("", 16)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	raiz.add_child(info)

	area = VBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	raiz.add_child(area)
	_mostrar_heroi()

func _limpar() -> void:
	for f in area.get_children():
		f.queue_free()

func _botoes(lista: Array) -> HBoxContainer:
	var linha := HBoxContainer.new()
	for par in lista:
		var b := Button.new()
		b.text = par[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(par[1])
		linha.add_child(b)
	return linha

# ---------------- Herói
func _mostrar_heroi() -> void:
	_limpar()
	var meta: Dictionary = Artes.dados_heroi()
	var poses := HBoxContainer.new()
	poses.size_flags_vertical = Control.SIZE_EXPAND_FILL
	heroi_frente = SpriteCamadas.new()
	heroi_costas = SpriteCamadas.new()
	for s in [heroi_frente, heroi_costas]:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(100, 140)
		poses.add_child(s)
	area.add_child(poses)
	heroi_costas.terminou.connect(func(): _anim_heroi("parado"))
	# quadro de costas tem folga para a arma: o desenho de 48 px começa em desenho_x
	heroi_costas.largura_quadro = int(meta["quadro"][0])
	heroi_costas.ancora_x = float(meta.get("desenho_x", 0)) + 24.0
	var linha := HBoxContainer.new()
	for nome in ANIM_HEROI:
		var b := Button.new()
		b.text = nome
		b.add_theme_font_size_override("font_size", 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_anim_heroi.bind(nome))
		linha.add_child(b)
	area.add_child(linha)
	area.add_child(_botoes([["GAL_ARMA", _proxima_arma], ["GAL_ARMADURA", _proxima_armadura]]))
	_vestir()
	_anim_heroi("parado")
	info.text = tr("GAL_HEROI_INFO") % [meta["costas"]["imagens"].size(), meta["frente"]["imagens"].size()]

func _proxima_arma() -> void:
	i_arma = (i_arma + 1) % ARMAS.size()
	_vestir()

func _proxima_armadura() -> void:
	i_armadura = (i_armadura + 1) % ARMADURAS.size()
	_vestir()

func _vestir() -> void:
	var arma: String = ARMAS[i_arma]
	var armadura: String = ARMADURAS[i_armadura]
	var nomes := ["corpo_1_Pele-3", "roupa_1"]
	if armadura != "":
		nomes.append(armadura)
	nomes.append("cabelo_curto_Castanho")
	nomes.append("braco_Pele-3")
	if armadura != "":
		nomes.append(armadura.replace("armadura_", "braco_armadura_"))
	nomes.append(arma)
	heroi_costas.camadas = nomes.map(func(n): return Artes.heroi_costas(n))
	heroi_frente.camadas = nomes.map(func(n): return Artes.heroi_frente(n))
	heroi_costas.queue_redraw()
	heroi_frente.queue_redraw()

func _anim_heroi(nome: String) -> void:
	var seq: Array = Artes.dados_heroi()["animacoes"][nome]
	heroi_costas.tocar(seq, Artes.dados_heroi()["fps"], nome == "parado")

# ---------------- Inimigos
func _mostrar_inimigos() -> void:
	_limpar()
	inimigo = SpriteCamadas.new()
	inimigo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inimigo.custom_minimum_size = Vector2(0, 280)
	inimigo.terminou.connect(func(): _anim_inimigo("parado"))
	area.add_child(inimigo)
	area.add_child(_botoes([["<", func(): _trocar_inimigo(-1)], [">", func(): _trocar_inimigo(1)]]))
	caixa_acoes = HBoxContainer.new()
	area.add_child(caixa_acoes)
	_trocar_inimigo(0)

func _trocar_inimigo(passo: int) -> void:
	var lista := Artes.lista_inimigos()
	i_inimigo = posmod(i_inimigo + passo, lista.size())
	var chave: String = lista[i_inimigo]
	var ficha: Dictionary = Artes.dados_inimigos()["inimigos"][chave]
	info.text = "%d/%d  %s" % [i_inimigo + 1, lista.size(), ficha["nome"]]
	var acoes := caixa_acoes
	for f in acoes.get_children():
		f.queue_free()
	for acao in ficha["acoes"]:
		var b := Button.new()
		b.text = acao
		b.add_theme_font_size_override("font_size", 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_anim_inimigo.bind(acao))
		acoes.add_child(b)
	_anim_inimigo("parado")

func _anim_inimigo(acao: String) -> void:
	var chave: String = Artes.lista_inimigos()[i_inimigo]
	var a := Artes.inimigo_acao(chave, acao)
	if a.is_empty():
		return
	inimigo.camadas = [a["peca"]]
	inimigo.largura_quadro = int(a["largura"])
	inimigo.altura_quadro = int(a["altura"])
	# escala inteira que caiba na área (chefes 96–128 px ficam ×2)
	inimigo.escala = 3 if inimigo.altura_quadro <= 64 else 2
	inimigo.tocar(range(int(a["quadros"])), float(a["fps"]), acao == "parado")

# ---------------- Itens
func _mostrar_itens() -> void:
	_limpar()
	var lista: Array = Artes.dados_itens()["itens"]
	info.text = tr("GAL_ITENS_INFO") % lista.size()
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	area.add_child(rolagem)
	var grade := GridContainer.new()
	grade.columns = 8
	grade.add_theme_constant_override("h_separation", 2)
	grade.add_theme_constant_override("v_separation", 2)
	rolagem.add_child(grade)
	for it in lista:
		grade.add_child(_celula_item(it))

func _celula_item(it: Dictionary) -> Control:
	var celula := Button.new()
	celula.custom_minimum_size = Vector2(40, 40)
	celula.flat = true
	var vazio := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus"]:
		celula.add_theme_stylebox_override(s, vazio)
	var moldura := TextureRect.new()
	moldura.texture = load("res://artes/interface/moldura_%s.png" % it["raridade"])
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	celula.add_child(moldura)
	var ic := SpriteCamadas.new()
	ic.escala = 1
	ic.largura_quadro = 32
	ic.altura_quadro = 32
	ic.position = Vector2(4, 4)
	ic.size = Vector2(32, 32)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if it.get("icone_anim") != null:
		ic.camadas = [Artes.icone(it["icone_anim"])]
		ic.tocar([0, 1, 2, 3], 8.0, true)
	else:
		ic.camadas = [Artes.icone(it["icone"])]
	celula.add_child(ic)
	celula.pressed.connect(func(): info.text = "%s\n%s" % [it["nome"], it["papel"]])
	return celula
