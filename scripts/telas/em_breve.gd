extends Tela
## Tela provisória para as abas que ainda vão ser programadas.

var chave_titulo := ""

func montar() -> void:
	var caixa := VBoxContainer.new()
	caixa.set_anchors_preset(Control.PRESET_CENTER)
	caixa.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caixa.grow_vertical = Control.GROW_DIRECTION_BOTH
	caixa.add_child(Tema.rotulo(chave_titulo, 24))
	var aviso := Tema.rotulo("EM_BREVE", 16)
	aviso.add_theme_color_override("font_color", Tema.COR_TEXTO_APAGADO)
	caixa.add_child(aviso)
	add_child(caixa)
