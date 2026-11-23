extends "res://scripts/componentes/popup_vitrine.gd"
## Ficha de uma habilidade, aberta ao SEGURAR o botão dela (pedido do João, 2026-11-13): no combate e na
## troca de habilidades (Inventário > Habilidades). Mostra nome, tipo, elemento, efeito, usos e melhorias.
## Uso: var p = POPUP_HAB.new(); p.hab = "golpe"; p.restam = 2; add_child(p)

const ORBES := preload("res://scripts/orbes.gd")
const COR_EL := {"fogo": Color("#ff7a3a"), "agua": Color("#4ab0ff"), "terra": Color("#c8964e"),
	"ar": Color("#6ee0b0"), "raio": Color("#ffe04a"), "gelo": Color("#a8e8ff")}
const TEXTO := Color("#d8dae6")
const CINZA := Color("#8088a8")

var hab := ""
var restam := -2        # no combate: usos que sobram nesta luta (-1 = sem limite); -2 = fora do combate

func _ready() -> void:
	var el := str(Catalogo.HAB.get(hab, {}).get("el", ""))
	if COR_EL.has(el):
		var c: Color = COR_EL[el]
		cor_acento = c
		cor_claro = c.lightened(0.35)
		cor_fundo = Color(c.darkened(0.86), 1.0)
		cor_escuro = Color(c.darkened(0.9), 1.0)
	super._ready()

func _montar(col: VBoxContainer) -> void:
	var H: Dictionary = Catalogo.HAB[hab]
	var el := str(H.get("el", ""))
	var cat := str(H.get("cat", "comum"))

	var topo := HBoxContainer.new()
	topo.alignment = BoxContainer.ALIGNMENT_CENTER
	topo.add_theme_constant_override("separation", 8)
	var ic := TextureRect.new()
	ic.texture = load("res://artes/combate/elem20_%s.png" % (el if el != "" else "comum"))
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	topo.add_child(ic)
	var nome := Tema.rotulo(str(H["nome"]), 20)
	nome.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	nome.add_theme_color_override("font_color", cor_claro)
	nome.add_theme_constant_override("outline_size", 4)
	nome.add_theme_color_override("font_outline_color", cor_escuro)
	Tema.caber(nome, LARGURA - 80.0, 28.0, 1, [20, 16, 14])
	topo.add_child(nome)
	col.add_child(topo)

	var selos := HBoxContainer.new()
	selos.alignment = BoxContainer.ALIGNMENT_CENTER
	selos.add_theme_constant_override("separation", 4)
	selos.add_child(selo(tr("HAB_INFO_CAT_" + cat.to_upper()), Color.WHITE, Color("#0e0f18"), cor_acento))
	if el != "":
		selos.add_child(selo(tr("EL_" + el.to_upper()), cor_claro, Color("#0e0f18"), cor_acento, load("res://artes/combate/elem16_%s.png" % el)))
	var vezes := ORBES.vezes_melhorada(hab)
	if vezes > 0:
		selos.add_child(selo("+%d" % vezes, Tema.COR_OURO_CLARO, Color("#2a2140"), Color("#6a5a2a")))
	col.add_child(selos)

	col.add_child(secao("HAB_INFO_EFEITO"))
	col.add_child(paragrafo(Catalogo.descrever(hab), TEXTO))
	if vezes > 0:
		var pct := int(round((ORBES.fator(hab) - 1.0) * 100.0))
		col.add_child(paragrafo(tr("HAB_INFO_MELHORADA") % [vezes, pct], Tema.COR_OURO_CLARO))

	col.add_child(secao("HAB_INFO_USOS"))
	if cat == "comum":
		col.add_child(paragrafo("HAB_INFO_SEM_LIMITE", TEXTO))
	else:
		var maximo := int(Catalogo.USOS.get(cat, 2)) + ORBES.usos_extras(hab)
		col.add_child(paragrafo(tr("HAB_INFO_POR_LUTA") % maximo, TEXTO))
		if restam >= 0:
			col.add_child(paragrafo(tr("HAB_INFO_RESTAM") % restam, cor_claro if restam > 0 else Color("#e85a4a")))

	var ok := Button.new()
	ok.text = "FECHAR"
	ok.custom_minimum_size = Vector2(0, 38)
	Tema.estilo_botao(ok, "secundario")
	ok.pressed.connect(fechar)
	col.add_child(ok)
