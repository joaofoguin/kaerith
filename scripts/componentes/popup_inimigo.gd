extends "res://scripts/componentes/popup_vitrine.gd"
## Ficha de um inimigo, aberta ao tocar nele no popup da fase: retrato, nome, categoria, nível, elemento,
## família e vitórias. Habilidades e fraquezas seguem a regra do Bestiário (DEFINIDA): só aparecem depois
## de 3 vitórias contra a espécie. Chefes de ato não entram no Bestiário, então mostram só o básico.
## Uso: var p = POPUP_INIMIGO.new(); p.chave = "javali_comum"; p.categoria = "comum"; p.nivel = 3; add_child(p)

const COR_EL := {"fogo": Color("#ff7a3a"), "agua": Color("#4ab0ff"), "terra": Color("#c8964e"),
	"ar": Color("#6ee0b0"), "raio": Color("#ffe04a"), "gelo": Color("#a8e8ff")}
const COR_CAT := {"comum": Color("#6a7090"), "veterano": Color("#5aa0e0"), "elite": Color("#b07ae8"),
	"suprema": Color("#e8b33a"), "chefe": Color("#e85a4a")}
const TEXTO := Color("#d8dae6")
const CINZA := Color("#8088a8")

var chave := ""
var categoria := "comum"
var nivel := 1

func _ready() -> void:
	var el := _el()
	if el != "":
		var c: Color = COR_EL[el]
		cor_acento = c
		cor_claro = c.lightened(0.35)
		cor_fundo = Color(c.darkened(0.86), 1.0)
		cor_escuro = Color(c.darkened(0.9), 1.0)
	super._ready()

func _el() -> String:
	var el = Bestiario.ficha(chave).get("elemento")
	return str(el) if el != null else ""

func _montar(col: VBoxContainer) -> void:
	var f := Bestiario.ficha(chave)
	var id := str(f.get("id", chave))
	var el := _el()

	var nome := Tema.rotulo(str(f.get("nome", id)), 20)
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nome.add_theme_constant_override("outline_size", 4)
	nome.add_theme_color_override("font_outline_color", cor_escuro)
	Tema.caber(nome, LARGURA - 40.0, 48.0, 2, [20, 16, 14])
	var tam_nome := nome.get_theme_font_size("font_size")
	nome.custom_minimum_size = Vector2(0, (nome.text.count("\n") + 1) * Tema.altura_texto(tam_nome) + 4)
	col.add_child(nome)
	var selos := HBoxContainer.new()
	selos.alignment = BoxContainer.ALIGNMENT_CENTER
	selos.add_theme_constant_override("separation", 4)
	var cc: Color = COR_CAT.get(categoria, CINZA)
	selos.add_child(selo(tr("INIM_" + categoria.to_upper()), Color.WHITE, Color(cc.darkened(0.7), 1.0), cc))
	selos.add_child(selo("NV%d" % nivel, Tema.COR_OURO_CLARO, Color("#2a2140"), Color("#6a5a2a")))
	if el != "":
		selos.add_child(selo(tr("EL_" + el.to_upper()), cor_claro, Color("#0e0f18"), cor_acento, load("res://artes/combate/elem16_%s.png" % el)))
	else:
		selos.add_child(selo(tr("INIM_SEM_ELEMENTO"), CINZA, Color("#0e0f18"), Color("#3c4058")))
	col.add_child(selos)

	var t := TextureRect.new()
	t.texture = Bestiario.miniatura(chave)
	t.custom_minimum_size = Vector2(0, 112)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	col.add_child(t)

	var chefe := categoria == "chefe" or id in Bestiario.CHEFES
	var r := Bestiario.registro(id)
	var vit := int(r.get("vit", 0))
	col.add_child(secao("INIM_FICHA"))
	col.add_child(paragrafo(tr("DIARIO_FAMILIA") % str(f.get("familia", "")), TEXTO))
	if not chefe:
		col.add_child(paragrafo(tr("DIARIO_VITORIAS") % vit, TEXTO))
		if vit >= Bestiario.VITORIAS_REVELA:
			col.add_child(secao("INIM_HABILIDADES"))
			col.add_child(paragrafo(", ".join(Bestiario.habilidades(chave)), TEXTO))
			col.add_child(secao("INIM_FRAQUEZAS"))
			var fr: Array = Bestiario.fraquezas(el)
			var nomes: Array = fr.map(func(x): return tr("EL_" + str(x).to_upper()))
			col.add_child(paragrafo(", ".join(nomes) if not nomes.is_empty() else tr("DIARIO_SEM_FRAQUEZA"), TEXTO))
		else:
			col.add_child(paragrafo(tr("DIARIO_REVELA_3") % (Bestiario.VITORIAS_REVELA - vit), CINZA))
	var ok := Button.new()
	ok.text = "FECHAR"
	ok.custom_minimum_size = Vector2(0, 38)
	Tema.estilo_botao(ok, "secundario")
	ok.pressed.connect(fechar)
	col.add_child(ok)
