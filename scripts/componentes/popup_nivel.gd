class_name PopupNivel
extends PopupResultado
## Popup de subida de nível (pedido do João, 2026-11-24): mesmo visual do resultado (faixa vinho, raios e brilhos),
## com o que melhorou no herói: Vida e os 5 atributos (antes › depois, +ganho), o que o novo nível libera
## (Orbes) e quanto XP falta para o próximo. Abre sozinho por cima do resultado quando a barra de XP sobe de nível.

const VERDE := Color("#8fe07a")
const CINZA := Color("#9a9fb8")
const ICONES := {"vida": "icone16_vida", "forca": "icone16_forca", "percepcao": "icone16_percepcao",
	"agilidade": "icone16_agilidade", "resistencia": "icone16_resistencia", "ressonancia": "icone16_ressonancia"}
const NOMES := {"vida": "ATR_VIDA", "forca": "ATR_FORCA", "percepcao": "ATR_PERCEPCAO", "agilidade": "ATR_AGILIDADE",
	"resistencia": "ATR_RESISTENCIA", "ressonancia": "ATR_RESSONANCIA"}
const ORBES := preload("res://scripts/orbes.gd")

var nivel_de := 1
var nivel_para := 2

## Cria o popup para quem foi do nível `de` ao `para`. ao_fechar é chamado no Continuar.
static func criar(de: int, para: int, ao_fechar := Callable()) -> PopupNivel:
	var p := PopupNivel.new()
	p.tipo = "nivel"
	p.nivel_de = de
	p.nivel_para = para
	p.titulo = TranslationServer.translate("NIVEL_TITULO") % para
	p.subtitulo = (TranslationServer.translate("NIVEL_SUB") % [de, para]).to_upper()
	p.texto = TranslationServer.translate("NIVEL_EXPLICA")
	p.botoes = [["CONTINUAR", ao_fechar if ao_fechar.is_valid() else func(): pass, "primario"]]
	return p

func _montar_conteudo(c: VBoxContainer) -> void:
	var el := str(Jogo.dados.get("elemento", ""))
	var modelo: Array = Catalogo.MODELO_JOGADOR.get(el, Catalogo.MODELO_JOGADOR[""])
	var antes := Equipamento.atributos_finais(modelo, Lutador.fator_de(nivel_de))
	var depois := Equipamento.atributos_finais(modelo, Lutador.fator_de(nivel_para))
	var s := Tema.rotulo(subtitulo, 8, true)
	s.add_theme_color_override("font_color", CINZA)
	c.add_child(s)
	var t := Tema.rotulo(texto, 12)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(LARGURA - 36, 0)
	t.add_theme_color_override("font_color", Color("#e6e6f0"))
	c.add_child(t)
	c.add_child(_secao("NIVEL_MELHOROU"))
	for a in ["vida", "forca", "percepcao", "agilidade", "resistencia", "ressonancia"]:
		c.add_child(_linha_atributo(a, float(antes[a]), float(depois[a])))
	var novidades := _novidades()
	if not novidades.is_empty():
		c.add_child(_secao("NIVEL_NOVIDADES"))
		for n: String in novidades:
			c.add_child(_linha_texto(n))
	var falta := Jogo.xp_para(int(Jogo.dados["nivel"])) - int(Jogo.dados["xp"])
	var prox := Tema.rotulo(tr("NIVEL_PROXIMO") % [int(Jogo.dados["nivel"]) + 1, maxi(0, falta)], 12)
	prox.add_theme_color_override("font_color", CINZA)
	c.add_child(prox)
	# botão (mesmo da base)
	_linha_botoes = HBoxContainer.new()
	_linha_botoes.add_theme_constant_override("separation", 8)
	for par in botoes:
		_linha_botoes.add_child(_botao(par))
	_linha_botoes.modulate.a = 0.0
	var folga := Control.new()
	folga.custom_minimum_size = Vector2(0, 2)
	c.add_child(folga)
	c.add_child(_linha_botoes)

func _secao(chave: String) -> Label:
	var sec := Tema.rotulo(chave, 16)
	sec.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sec.add_theme_color_override("font_color", PRATA)
	return sec

## Uma linha: ícone, nome, valor de antes (cinza) › valor novo (dourado) e o ganho (verde). Entra animada como as do resultado.
## A Vida aparece inteira; os atributos com 1 casa (cada nível soma 5% do valor base, que às vezes é menos de 1 ponto).
func _num(a: String, v: float) -> String:
	if a == "vida":
		return str(int(round(v)))
	var t := "%.1f" % (round(v * 10.0) / 10.0)
	return t.replace(".", ",") if TranslationServer.get_locale().begins_with("pt") else t

func _linha_atributo(a: String, v_antes: float, v_depois: float) -> Control:
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 3)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var ic := TextureRect.new()
	ic.texture = load("res://artes/interface/%s.png" % ICONES[a])
	ic.custom_minimum_size = Vector2(24, 24)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED          # 16 px no meio, sem borrar o pixel art
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.pivot_offset = Vector2(12, 12)
	h.add_child(ic)
	var n := Tema.rotulo(NOMES[a], 16)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	h.add_child(n)
	var va := Tema.rotulo(_num(a, v_antes), 16, true)
	va.add_theme_color_override("font_color", CINZA)
	h.add_child(va)
	var seta := Tema.rotulo(">", 16, true)
	seta.add_theme_color_override("font_color", CINZA)
	h.add_child(seta)
	var vd := Tema.rotulo(_num(a, v_depois), 16, true)
	vd.add_theme_color_override("font_color", OURO)
	vd.add_theme_constant_override("outline_size", 4)
	vd.add_theme_color_override("font_outline_color", Color("#12131c"))
	h.add_child(vd)
	var dif: float = (round(v_depois) - round(v_antes)) if a == "vida" else (round(v_depois * 10.0) - round(v_antes * 10.0)) / 10.0
	var ganho := Tema.rotulo("+" + _num(a, maxf(0.0, dif)), 8, true)
	ganho.custom_minimum_size = Vector2(30, 0)
	ganho.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ganho.add_theme_color_override("font_color", VERDE if dif > 0.0 else CINZA)
	h.add_child(ganho)
	caixa.add_child(h)
	caixa.add_child(_fio())
	caixa.modulate.a = 0.0
	_linhas_ui.append([caixa, ic, vd, {}])
	return caixa

func _linha_texto(texto_linha: String) -> Control:
	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 3)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var ic := TextureRect.new()
	ic.texture = load("res://artes/interface/icone16_mais.png")
	ic.custom_minimum_size = Vector2(24, 24)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.pivot_offset = Vector2(12, 12)
	h.add_child(ic)
	var r := Tema.rotulo(texto_linha, 12)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size = Vector2(LARGURA - 72, 0)
	h.add_child(r)
	caixa.add_child(h)
	caixa.add_child(_fio())
	caixa.modulate.a = 0.0
	_linhas_ui.append([caixa, ic, r, {}])
	return caixa

func _fio() -> ColorRect:
	var fio := ColorRect.new()
	fio.color = Color("#2e3248")
	fio.custom_minimum_size = Vector2(0, 1)
	return fio

## O que os níveis novos liberam: obter um Orbe novo e evoluir o Orbe até um nível maior (regras de orbes.gd).
func _novidades() -> Array:
	var r: Array = []
	if str(Jogo.dados.get("elemento", "")) == "":
		return r
	for i in ORBES.NIVEL_NOVO.size():
		var nv := int(ORBES.NIVEL_NOVO[i])
		if nv > nivel_de and nv <= nivel_para:
			r.append(tr("NIVEL_LIBERA_ORBE_NOVO") % (i + 1))
	for n in range(2, ORBES.MAX_NIVEL + 1):
		var nv := ORBES.nivel_minimo_para(n)
		if nv > nivel_de and nv <= nivel_para:
			r.append(tr("NIVEL_LIBERA_ORBE_NIVEL") % n)
	return r
