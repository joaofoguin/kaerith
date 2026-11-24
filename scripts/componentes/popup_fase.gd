extends "res://scripts/componentes/popup_vitrine.gd"
## Popup de jogar uma fase do mapa (pedido do João, 2026-11-13): tipo da fase, quantas ondas, os inimigos
## de cada onda (só depois de o jogador ter jogado a fase; antes aparecem como "?") e os prêmios possíveis.
## Tocar num inimigo abre a ficha dele (POPUP_INIMIGO).
## PROVISÓRIO (meu): "já jogou" = entrou na fase pelo menos uma vez (vencendo ou não); vitórias de saves
## antigos também contam. Os prêmios mostrados seguem as regras do fim da luta em telas/combate.gd.
## Uso: var p = POPUP_FASE.new(); p.fase = 12; p.ao_jogar = ...; add_child(p)

const POPUP_INIMIGO := preload("res://scripts/componentes/popup_inimigo.gd")
const LIMITE_REPETICOES := 20
const ORBES_F := preload("res://scripts/orbes.gd")
const HISTORIA := preload("res://scripts/historia.gd")
const NOME_TIPO := {"combate": "TIPO_COMBATE", "ondas": "TIPO_ONDAS", "elite": "TIPO_ELITE", "suprema": "TIPO_SUPREMA", "chefe": "TIPO_CHEFE"}
const COR_CAT := {"comum": Color("#6a7090"), "veterano": Color("#5aa0e0"), "elite": Color("#b07ae8"),
	"suprema": Color("#e8b33a"), "chefe": Color("#e85a4a")}
const TEXTO := Color("#d8dae6")
const CINZA := Color("#8088a8")

var fase := 1
var ao_jogar: Callable
var ao_vidas: Callable
var ao_vencer_teste: Callable

var _enc: Dictionary = {}

static func jogou(f: int) -> bool:
	var j: Dictionary = Jogo.dados.get("jogadas", {})
	var v: Dictionary = Jogo.dados.get("vitorias", {})
	return int(j.get(str(f), 0)) > 0 or int(v.get(str(f), 0)) > 0

static func repeticoes_hoje(f: int) -> int:
	var r: Dictionary = Jogo.dados.get("repeticoes", {})
	if str(r.get("dia", "")) != Time.get_date_string_from_system():
		return 0
	var fs: Dictionary = r.get("fases", {})
	return int(fs.get(str(f), 0))

func _montar(col: VBoxContainer) -> void:
	_enc = Encontros.gerar(fase)
	var tipo := str(_enc["tipo"])
	var atual := int(Jogo.dados["fase_atual"])
	var ondas: Array = _enc["ondas"]

	# cabeçalho: "Fase N", tipo e ato
	var nome := Tema.rotulo(tr("FASE_N") % fase, 24)
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nome.add_theme_constant_override("outline_size", 4)
	nome.add_theme_color_override("font_outline_color", cor_escuro)
	col.add_child(nome)
	var selos := HBoxContainer.new()
	selos.alignment = BoxContainer.ALIGNMENT_CENTER
	selos.add_theme_constant_override("separation", 4)
	var ct: Color = COR_CAT.get(tipo if tipo != "combate" and tipo != "ondas" else "comum", CINZA)
	selos.add_child(selo(tr(NOME_TIPO.get(tipo, "TIPO_COMBATE")), Tema.COR_OURO_CLARO, Color(ct.darkened(0.7), 1.0), ct))
	selos.add_child(selo(tr("ATO_N") % int(_enc["ato"]), TEXTO, Color("#0e0f18"), Color("#3c4058")))
	selos.add_child(selo("NV%d" % Encontros.nivel_da_fase(fase), Tema.COR_OURO_CLARO, Color("#2a2140"), Color("#6a5a2a")))
	col.add_child(selos)

	# ondas e inimigos
	var visto := jogou(fase)
	col.add_child(secao("FASE_ONDAS", tr("FASE_ONDAS_N") % ondas.size() if ondas.size() != 1 else tr("FASE_ONDA_1")))
	for i in ondas.size():
		col.add_child(_linha_onda(i, ondas[i], visto))
	if not visto:
		col.add_child(paragrafo("FASE_INIMIGOS_OCULTOS", CINZA))

	# prêmios possíveis
	var rep := repeticoes_hoje(fase)
	var rejogando := fase < atual
	var com_premio := not rejogando or rep < LIMITE_REPETICOES
	col.add_child(secao("FASE_PREMIOS", ("%d/%d" % [rep, LIMITE_REPETICOES]) if rejogando else ""))
	col.add_child(_premios(com_premio))
	if rejogando:
		col.add_child(paragrafo("FASE_PREMIOS_HOJE" if com_premio else "FASE_PREMIOS_ESGOTADOS", CINZA if com_premio else Color("#ff9a8a")))

	# missões em andamento que esta fase ajuda (ícone do mapa)
	var missoes: Array = HISTORIA.missoes_na_fase(fase)
	if not missoes.is_empty():
		col.add_child(secao("DIARIO_MISSOES", ""))
		for id: String in missoes:
			var npc := str(HISTORIA.MISSOES[id]["npc"])
			col.add_child(paragrafo(HISTORIA.nome_npc(npc) + ": " + HISTORIA.objetivo(id),
				HISTORIA.cor_do_elemento(str(HISTORIA.NPCS.get(npc, ""))).lightened(0.2)))

	# botões
	var ato_fase := int((fase - 1) / 75) + 1
	if fase > atual:
		col.add_child(paragrafo("FASE_BLOQUEADA", Color("#ff9a8a")))
	elif not ConfigRemota.ato_aberto(ato_fase):    # venceu o ato anterior, mas este ainda não abriu (Firebase)
		var falta := maxi(0, ConfigRemota.abertura_do_ato(ato_fase) - ConfigRemota.agora())
		col.add_child(paragrafo(tr("ATO_ABRE_EM") % [Temporada.romano(ato_fase), Temporada.texto_tempo(falta)], Color("#ff9a8a")))
	elif int(Jogo.dados["vidas"]) <= 0:
		col.add_child(paragrafo("SEM_VIDAS", Color("#ff9a8a")))
		col.add_child(_botao("VIDAS_VER", "secundario", ao_vidas))
	else:
		col.add_child(_botao("JOGAR", "primario", ao_jogar))
	if fase == atual and ao_vencer_teste.is_valid() and Jogo.adm():
		col.add_child(_botao("VENCER_TESTE", "secundario", ao_vencer_teste))

# ------------------------------------------------------------ peças
func _botao(chave: String, estilo: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = chave
	b.custom_minimum_size = Vector2(0, 40)
	Tema.estilo_botao(b, estilo)
	b.pressed.connect(func():
		if acao.is_valid():
			acao.call())
	return b

## "Onda 1" à esquerda e os inimigos dela em quadros (ou "?" se a fase nunca foi jogada).
func _linha_onda(i: int, onda: Array, visto: bool) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var r := Tema.rotulo(tr("FASE_ONDA_I") % (i + 1), 8, true)
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.custom_minimum_size = Vector2(56, 0)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	r.add_theme_color_override("font_color", cor_claro)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(r)
	for spec: Dictionary in onda:
		h.add_child(_quadro(spec, visto))
	return h

func _quadro(spec: Dictionary, visto: bool) -> Control:
	var cat := str(spec["categoria"])
	var cor: Color = COR_CAT.get(cat, CINZA)
	var b := Button.new()
	b.custom_minimum_size = Vector2(60, 60)
	b.focus_mode = Control.FOCUS_NONE
	for estado: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var e := StyleBoxFlat.new()
		e.bg_color = Color("#0e0f18") if estado != "pressed" else Color(cor.darkened(0.7), 1.0)
		e.border_color = cor if visto else Color("#3c4058")
		e.set_border_width_all(1 if cat in ["comum", "veterano"] else 2)
		e.set_corner_radius_all(3)
		b.add_theme_stylebox_override(estado, e)
	if not visto:
		var q := Tema.rotulo("?", 24)
		q.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		q.add_theme_color_override("font_color", CINZA)
		q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(q)
		b.disabled = true
		return b
	var chave := str(spec["sprite"])
	var t := TextureRect.new()
	t.texture = Bestiario.miniatura(chave)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.position = Vector2(3, 3)
	t.size = Vector2(54, 46)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(t)
	var nv := Tema.rotulo("NV%d" % int(spec["nivel"]), 8, true)
	nv.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nv.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	nv.add_theme_constant_override("outline_size", 2)
	nv.add_theme_color_override("font_outline_color", Color.BLACK)
	nv.position = Vector2(3, 47)
	nv.size = Vector2(54, 11)
	nv.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nv)
	var el := _elemento(chave)
	if el != "":
		var ic := TextureRect.new()
		ic.texture = load("res://artes/combate/elem16_%s.png" % el)
		ic.position = Vector2(42, 2)
		ic.size = Vector2(16, 16)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ic)
	b.pressed.connect(_abrir_inimigo.bind(spec))
	return b

func _abrir_inimigo(spec: Dictionary) -> void:
	var p = POPUP_INIMIGO.new()
	p.chave = str(spec["sprite"])
	p.categoria = str(spec["categoria"])
	p.nivel = int(spec["nivel"])
	get_parent().add_child(p)

static func _elemento(chave: String) -> String:
	var el = Bestiario.ficha(chave).get("elemento")
	return str(el) if el != null else ""

## Família do inimigo, como o Motor calcula (para a chance maior de fragmento com bandido elemental).
static func _familia(spec: Dictionary) -> String:
	var tipo := str(spec["sprite"])
	var cat := str(spec["categoria"])
	if cat == "suprema":
		tipo = str(Catalogo.SUPREMAS.get(tipo, tipo))
	elif cat != "chefe" and tipo != "urso_de_barranco":
		for suf: String in ["_comum", "_veterano", "_elite"]:
			if tipo.ends_with(suf):
				tipo = tipo.substr(0, tipo.length() - suf.length())
		tipo = Catalogo.tipo_do_sprite(tipo)
	var t: Dictionary = Catalogo.TIPOS.get(tipo, {})
	return str(t.get("fam", ""))

## Linhas de prêmio: XP e moedas (soma de todos os inimigos), fragmentos, peça e cristais.
func _premios(com_premio: bool) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	var xp := 0.0
	var moedas := 0.0
	var frasco := false
	for onda: Array in _enc["ondas"]:
		for spec: Dictionary in onda:
			var cat := str(spec["categoria"])
			var fat := Lutador.fator_de(int(spec["nivel"]))
			xp += Catalogo.xp_de(cat, fat, int(spec["nivel"]), int(Jogo.dados["nivel"]))
			moedas += Catalogo.MOEDAS[cat] * fat
			if _familia(spec) == "bandidos" and _elemento(str(spec["sprite"])) != "":
				frasco = true
	var tipo := str(_enc["tipo"])
	v.add_child(_linha(PopupResultado.icone("xp"), tr("RES_L_XP"), str(int(round(xp))) if com_premio else "0"))
	v.add_child(_linha(PopupResultado.icone("moeda"), tr("RES_L_MOEDAS"), str(int(round(moedas)))))
	if not com_premio:
		return v
	var chance := int(round(100.0 * (ORBES_F.FRAG_CHANCE_ELEMENTAL if frasco else ORBES_F.FRAG_CHANCE)))
	var frag := tr("FASE_FRAG_CHANCE") % [chance, int(ORBES_F.FRAG_SORTE[0]), int(ORBES_F.FRAG_SORTE[1])]
	if ORBES_F.FRAG_FIXO.has(tipo):
		var fx: Array = ORBES_F.FRAG_FIXO[tipo]
		frag = tr("FASE_FRAG_FIXO") % [int(fx[0]), int(fx[1])] + " + " + frag
	v.add_child(_linha(PopupResultado.icone("fragmento"), tr("FASE_FRAGMENTOS"), frag))
	match tipo:
		"elite":
			v.add_child(_linha(null, tr("RES_L_ITEM"), "20% · " + tr("RAR_INCOMUM")))
		"suprema", "chefe":
			# 1ª vitória: peça garantida; ao rejogar: "Comum a Épico (5%)" (Catalogo.PECA_REJOGAR, 2026-11-24)
			var vit: Dictionary = Jogo.dados.get("vitorias", {})
			var rar := str(Catalogo.PECA_1A_VEZ[tipo])
			if int(vit.get(str(fase), 0)) == 0:
				v.add_child(_linha(null, tr("RES_L_ITEM"), tr("RAR_" + rar.to_upper()) + " · " + tr("FASE_SO_1A_VEZ")))
			else:
				v.add_child(_linha(null, tr("RES_L_ITEM"), tr("FASE_PECA_REJOGAR") % [tr("RAR_" + rar.to_upper()), int(Catalogo.PECA_REJOGAR[tipo][0][1])]))
			if tipo == "chefe" and int(vit.get(str(fase), 0)) == 0:
				v.add_child(_linha(PopupResultado.icone("cristal"), tr("RES_L_CRISTAIS"), "50 · " + tr("FASE_SO_1A_VEZ")))
	return v

func _linha(icone: Texture2D, nome: String, valor: String) -> Control:
	var p := PanelContainer.new()
	var est := StyleBoxFlat.new()
	est.bg_color = Color("#0e0f18")
	est.border_color = Color(cor_acento, 0.35)
	est.set_border_width_all(1)
	est.set_corner_radius_all(3)
	est.content_margin_left = 6
	est.content_margin_right = 6
	est.content_margin_top = 1
	est.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", est)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(16, 16)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if icone:
		ic.texture = icone
	else:
		# peça de equipamento: losango dourado no lugar do ícone
		ic.draw.connect(func():
			ic.draw_colored_polygon(PackedVector2Array([Vector2(8, 1), Vector2(15, 8), Vector2(8, 15), Vector2(1, 8)]), Tema.COR_OURO)
			ic.draw_colored_polygon(PackedVector2Array([Vector2(8, 4), Vector2(12, 8), Vector2(8, 12), Vector2(4, 8)]), Tema.COR_OURO_CLARO))
	h.add_child(ic)
	var n := Tema.rotulo(nome, 12)
	n.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.add_theme_color_override("font_color", TEXTO)
	h.add_child(n)
	var val := Tema.rotulo(valor, 8, true)
	val.set_meta("fonte_fixa", true)           # XP, moedas e cristais na fonte original (pedido do João)
	val.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(val)
	p.add_child(h)
	return p
