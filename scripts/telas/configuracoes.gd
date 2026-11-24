extends Tela
## Configurações (engrenagem do Início), no formato dos jogos de celular: quadros por assunto.
##   Som – música e efeitos (− / +, de 10 em 10) e vibração
##   Tela – economia de bateria (30 fps) e tremor de tela
##   Notificações – vidas cheias, eventos e promoções
##   Idioma – Português / English
##   Conta – nome, ID do jogador (copiar), tipo de conta (visitante/Google) e excluir conta/personagem
##   Ajuda e sobre – suporte (página do site com contato e perguntas), privacidade, termos, sobre o jogo e versão
##   Teste – galeria e reiniciar (só na versão ADM)

const CONFIG := preload("res://scripts/config.gd")
const NOVIDADES := preload("res://scripts/novidades.gd")
const COR_QUADRO := Color("#171928")
const COR_BORDA := Color("#3c4058")
const COR_TEXTO2 := Color("#a8acc0")
const LARGURA := 344.0

var lista: VBoxContainer
var popup: Janela
var _confirmar_reinicio := false
## Volta do Google (Web) depois de "Salvar progresso com Google": principal.gd preenche e esta tela termina a ligação.
var retorno_google := {}

func montar() -> void:
	Tema.fundo(self, Tema.COR_FUNDO)
	Tema.cabecalho(self, "CONFIG", 230)
	var voltar := Button.new()
	voltar.text = "VOLTAR"
	voltar.position = Vector2(266, 6)
	voltar.size = Vector2(88, 32)
	voltar.add_theme_font_size_override("font_size", 12)
	Tema.estilo_botao(voltar, "secundario")
	voltar.pressed.connect(func(): principal.fechar_tela_cheia())
	add_child(voltar)

	var rolagem := ScrollContainer.new()
	rolagem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rolagem.offset_left = 8
	rolagem.offset_right = -8
	rolagem.offset_top = 54
	rolagem.offset_bottom = -6
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(rolagem)
	lista = VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 10)
	rolagem.add_child(lista)
	_preencher()
	if not retorno_google.is_empty():
		_terminar_google.call_deferred(retorno_google)
		retorno_google = {}

func atualizar_textos() -> void:
	for f in lista.get_children():
		f.queue_free()
	_preencher()

func _preencher() -> void:
	var som := _bloco("CFG_SOM")
	som.add_child(_linha_volume("CFG_MUSICA", "musica"))
	som.add_child(_linha_volume("CFG_EFEITOS", "efeitos"))
	som.add_child(_linha_chave("CFG_VIBRACAO", "vibracao"))

	var tela := _bloco("CFG_TELA")
	tela.add_child(_linha_chave("CFG_ECONOMIA", "economia", "CFG_ECONOMIA_DESC"))
	tela.add_child(_linha_chave("CFG_TREMOR", "tremor"))

	var notif := _bloco("CFG_NOTIFICACOES")
	notif.add_child(_linha_chave("CFG_NOTIF_VIDAS", "notif_vidas"))
	notif.add_child(_linha_chave("CFG_NOTIF_EVENTOS", "notif_eventos"))

	var idioma := _bloco("CFG_IDIOMA")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for par in [["pt", "Português"], ["en", "English"]]:
		var b := Button.new()
		b.text = par[1]
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Tema.estilo_botao(b, "primario" if Jogo.dados["idioma"] == par[0] else "secundario")
		b.pressed.connect(func():
			if Jogo.dados["idioma"] != par[0]:
				Jogo.trocar_idioma(par[0]))
		h.add_child(b)
	idioma.add_child(h)

	var conta := _bloco("CFG_CONTA")
	conta.add_child(_linha_texto("CFG_NOME", Jogo.nome_heroi()))
	var id := CONFIG.id_jogador()
	var linha_id := _linha_texto("CFG_ID", id.substr(0, 12))
	var copiar := _botao_pequeno("CFG_COPIAR")
	copiar.pressed.connect(func():
		DisplayServer.clipboard_set(id)
		copiar.text = "CFG_COPIADO")
	linha_id.add_child(copiar)
	conta.add_child(linha_id)
	_linhas_google(conta)
	# Excluir conta (Google) ou personagem (visitante), com confirmação (pedido do João, 2026-11-24)
	var excluir := _linha_botao("CFG_EXCLUIR_CONTA" if Conta.google() else "CFG_EXCLUIR_PERSONAGEM", _excluir)
	Tema.estilo_botao(excluir, "perigo")
	conta.add_child(excluir)

	# novidades de cada versão (pedido do João, 2026-11-24); a lista fica em scripts/novidades.gd
	var novidades := _bloco("CFG_NOVIDADES")
	novidades.add_child(_descricao("CFG_NOVIDADES_DESC"))
	novidades.add_child(_linha_botao("CFG_VER_NOVIDADES", _novidades))

	var ajuda := _bloco("CFG_AJUDA")
	# páginas do site (pedido do João, 2026-11-22); o suporte já leva o ID do jogador e a versão
	var suporte := "suporte.html?id=%s&v=%s" % [CONFIG.id_jogador().uri_encode(), Jogo.versao().uri_encode()]
	for par in [["CFG_SUPORTE", Jogo.abrir_site.bind(suporte)], ["CFG_PRIVACIDADE", Jogo.abrir_site.bind("privacidade.html")],
			["CFG_TERMOS", Jogo.abrir_site.bind("termos.html")], ["CFG_SOBRE", _creditos]]:
		ajuda.add_child(_linha_botao(par[0], par[1]))
	var versao := Tema.rotulo(tr("CFG_VERSAO") % Jogo.versao(), 12)
	versao.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	versao.add_theme_color_override("font_color", COR_TEXTO2)
	ajuda.add_child(versao)

	# opções de teste: só na versão ADM (pedido do João, 2026-11-22)
	if Jogo.adm():
		var teste := _bloco("CFG_TESTE")
		teste.add_child(_linha_botao("GALERIA", func(): principal.abrir_tela_cheia(preload("res://scripts/telas/galeria.gd").new())))
		teste.add_child(_linha_botao("REINICIAR_TESTE", _reiniciar))

# ------------------------------------------------------------ conta Google
func _linhas_google(conta: VBoxContainer) -> void:
	if Conta.google():
		var em := Conta.email()
		conta.add_child(_linha_texto("CFG_TIPO_CONTA", em.left(22) if em != "" else "Google"))
		conta.add_child(_descricao("CFG_NUVEM_OK"))
		conta.add_child(_linha_botao("CFG_SALVAR_AGORA", _salvar_agora))
		var sair := _linha_botao("CFG_SAIR", _sair)
		Tema.estilo_botao(sair, "perigo")
		conta.add_child(sair)
	else:
		conta.add_child(_linha_texto("CFG_TIPO_CONTA", tr("CFG_VISITANTE")))
		conta.add_child(_descricao("CFG_SALVAR_GOOGLE_DESC"))
		var b := _linha_botao("CFG_SALVAR_GOOGLE", _salvar_google)
		Tema.estilo_botao(b, "primario")
		conta.add_child(b)

func _descricao(chave: String) -> Label:
	var d := Tema.rotulo(chave, 12)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(300, 0)
	d.add_theme_color_override("font_color", COR_TEXTO2)
	return d

func _aviso(titulo: String, texto: String) -> void:
	_fechar_popup()
	popup = Janela.criar(titulo, [["OK", _fechar_popup]], texto)
	add_child(popup)

func _salvar_google() -> void:
	var aviso := Conta.aviso_google()
	if aviso != "":
		_aviso(tr("CFG_SALVAR_GOOGLE"), tr(aviso))
		return
	_fechar_popup()
	popup = Janela.criar(tr("CFG_SALVAR_GOOGLE"), [], tr("ENT_ABRINDO"))
	add_child(popup)
	Conta.ir_para_google("vincular")
	if not Plataforma.web():         # APK: o login acontece no navegador; espera o token aqui
		_fechar_popup()
		popup = Janela.criar(tr("CFG_SALVAR_GOOGLE"), [["CANCELAR", func():
			Conta.cancelar_app()
			_fechar_popup()]], tr("ENT_ESPERANDO_GOOGLE"))
		add_child(popup)
		var r: Dictionary = await Conta.esperar_app()
		if not r.is_empty():
			_terminar_google(r)

func _salvar_agora() -> void:
	_fechar_popup()
	popup = Janela.criar(tr("CFG_SALVAR_AGORA"), [], tr("ENT_CONECTANDO"))
	add_child(popup)
	var ok: bool = await Online.enviar_save()
	_aviso(tr("CFG_SALVAR_AGORA"), tr("CFG_SALVO_NUVEM") if ok else tr("ENT_ERRO") + "\n" + Online.ultimo_erro.left(90))

## Sair da conta Google: salva na nuvem, apaga o progresso deste aparelho e volta para a tela de entrada.
func _sair() -> void:
	_fechar_popup()
	popup = Janela.criar(tr("CFG_SAIR"), [["CFG_SAIR_SIM", _sair_salvando], ["CANCELAR", _fechar_popup]], tr("CFG_SAIR_TEXTO"))
	add_child(popup)

func _sair_salvando() -> void:
	_fechar_popup()
	popup = Janela.criar(tr("CFG_SAIR"), [], tr("CFG_SAIR_SALVANDO"))
	add_child(popup)
	var ok: bool = await Online.enviar_save()
	if not ok:
		_fechar_popup()
		popup = Janela.criar(tr("CFG_SAIR"), [["CFG_SAIR_MESMO", _sair_agora], ["CANCELAR", _fechar_popup]], tr("CFG_SAIR_SEM_NUVEM"))
		add_child(popup)
		return
	_sair_agora()

func _sair_agora() -> void:
	_fechar_popup()
	Conta.sair()
	# 2026-11-23 (bug do João: o logoff caía no Início): só abre a entrada. Antes havia também um
	# fechar_tela_cheia() aqui; a transição dele terminava depois e fechava a tela de entrada recém-aberta.
	# abrir_tela_cheia (dentro do seguir_criacao) já fecha as Configurações na troca.
	principal.seguir_criacao()

## Excluir conta/personagem: confirma, apaga do servidor (ranking, save da nuvem e a conta) e deste aparelho,
## e volta para a tela de entrada (Google ou visitante). Idioma e configurações do aparelho ficam.
func _excluir() -> void:
	var chave := "CFG_EXCLUIR_CONTA" if Conta.google() else "CFG_EXCLUIR_PERSONAGEM"
	_fechar_popup()
	popup = Janela.criar(tr(chave), [["CFG_EXCLUIR_SIM", _excluir_servidor], ["CANCELAR", _fechar_popup]],
		tr("CFG_EXCLUIR_TEXTO") % Jogo.nome_heroi())
	_perigo_no_primeiro_botao(popup)
	add_child(popup)

func _excluir_servidor() -> void:
	_fechar_popup()
	popup = Janela.criar(tr("CFG_EXCLUIR_SIM"), [], tr("CFG_EXCLUINDO"))
	add_child(popup)
	var ok: bool = await Online.excluir_conta()
	if not ok:
		_fechar_popup()
		popup = Janela.criar(tr("CFG_EXCLUIR_SIM"), [["CFG_EXCLUIR_MESMO", _excluir_agora], ["CANCELAR", _fechar_popup]],
			tr("CFG_EXCLUIR_SEM_REDE"))
		_perigo_no_primeiro_botao(popup)
		add_child(popup)
		return
	_excluir_agora()

func _excluir_agora() -> void:
	_fechar_popup()
	var aparelho_conflito := Online.ARQUIVO_CONFLITO
	if FileAccess.file_exists(aparelho_conflito):
		DirAccess.remove_absolute(aparelho_conflito)
	Conta.sair()                      # zera o progresso, mantém idioma e config, etapa "login"
	principal.seguir_criacao()       # abre a tela de entrada (mesma regra do _sair_agora)

## O botão de confirmar (o primeiro) fica vermelho, como o "Sair" da conta.
func _perigo_no_primeiro_botao(j: Janela) -> void:
	j.ready.connect(func():
		var b := _achar_botao(j)
		if b:
			Tema.estilo_botao(b, "perigo"))

func _achar_botao(n: Node) -> Button:
	for f in n.get_children():
		if f is Button and str(f.text) == "CFG_EXCLUIR_SIM" or f is Button and str(f.text) == "CFG_EXCLUIR_MESMO":
			return f
		var x := _achar_botao(f)
		if x:
			return x
	return null

## A página voltou do Google: liga a conta e, se ela já tinha outro progresso, pergunta qual fica.
func _terminar_google(r: Dictionary) -> void:
	if r.has("erro"):
		_aviso(tr("CFG_SALVAR_GOOGLE"), tr("ENT_ERRO_GOOGLE"))
		return
	_fechar_popup()
	popup = Janela.criar(tr("CFG_SALVAR_GOOGLE"), [], tr("ENT_CONECTANDO"))
	add_child(popup)
	var res: Dictionary = await Conta.concluir(str(r.get("token", "")), false)
	if not res["ok"]:
		_aviso(tr("CFG_SALVAR_GOOGLE"), tr("ENT_ERRO") + "\n" + str(res["erro"]).left(90))
		return
	if res.has("remoto"):
		var remoto: Dictionary = res["remoto"]
		var info: Dictionary = res["info"]
		var texto := tr("CFG_CONFLITO") % [int(remoto.get("nivel", 1)), int(Jogo.dados["nivel"])]
		_fechar_popup()
		popup = Janela.criar(tr("CFG_CONFLITO_T"), [
			["CFG_USAR_NUVEM", func():
				Conta.usar_nuvem(remoto, info)
				_aviso(tr("CFG_GOOGLE_OK"), tr("CFG_GOOGLE_OK_TEXTO"))
				atualizar_textos()],
			["CFG_MANTER_APARELHO", func():
				await Conta.manter_local(info)
				_aviso(tr("CFG_GOOGLE_OK"), tr("CFG_GOOGLE_OK_TEXTO"))
				atualizar_textos()],
		], texto)
		add_child(popup)
		return
	_aviso(tr("CFG_GOOGLE_OK"), tr("CFG_GOOGLE_OK_TEXTO"))
	atualizar_textos()

# ------------------------------------------------------------ peças
## Quadro com título (faixa) e uma coluna de linhas; devolve a coluna.
func _bloco(chave: String) -> VBoxContainer:
	var q := PanelContainer.new()
	var e := StyleBoxFlat.new()
	e.bg_color = COR_QUADRO
	e.border_color = COR_BORDA
	e.set_border_width_all(1)
	e.set_corner_radius_all(4)
	e.content_margin_left = 10
	e.content_margin_right = 10
	e.content_margin_top = 8
	e.content_margin_bottom = 10
	q.add_theme_stylebox_override("panel", e)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 6)
	var marca := ColorRect.new()
	marca.color = Tema.COR_OURO
	marca.custom_minimum_size = Vector2(4, 12)
	marca.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cab.add_child(marca)
	var t := Tema.rotulo(chave, 16)
	t.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	cab.add_child(t)
	var fio := ColorRect.new()
	fio.color = Color(Tema.COR_OURO, 0.35)
	fio.custom_minimum_size = Vector2(0, 1)
	fio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cab.add_child(fio)
	v.add_child(cab)
	q.add_child(v)
	lista.add_child(q)
	return v

func _rotulo_linha(chave: String) -> Label:
	var r := Tema.rotulo(chave, 16)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r

## Volume: nome, "−", barra de 10 gomos, "+" e a porcentagem.
func _linha_volume(chave: String, cfg: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var topo := HBoxContainer.new()
	topo.add_child(_rotulo_linha(chave))
	var pct := Tema.rotulo("", 8, true)
	pct.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	pct.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
	pct.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	topo.add_child(pct)
	v.add_child(topo)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var menos := _botao_pequeno("-")
	var barra := Control.new()
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.custom_minimum_size = Vector2(0, 28)
	var mais := _botao_pequeno("+")
	var mostrar := func():
		var n := int(CONFIG.valor(cfg))
		pct.text = "%d%%" % n
		barra.queue_redraw()
	barra.draw.connect(func():
		var n := int(CONFIG.valor(cfg)) / 10
		var w := (barra.size.x - 18.0) / 10.0
		for i in 10:
			var r := Rect2(floorf(i * (w + 2.0)), 6, floorf(w), barra.size.y - 12)
			barra.draw_rect(r, Color("#0a0b12"))
			if i < n:
				barra.draw_rect(r.grow(-1), Tema.COR_OURO)
				barra.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 2)), Tema.COR_OURO_CLARO)
			else:
				barra.draw_rect(r, COR_BORDA, false, 1.0))
	# tocar na barra também ajusta (no gomo tocado)
	# só com toque de verdade (rolar a tela por cima não mexe no volume)
	Tema.ao_tocar(barra, func(pos: Vector2):
		var n := clampi(int(ceil(pos.x / barra.size.x * 10.0)), 0, 10)
		CONFIG.mudar(cfg, n * 10)
		mostrar.call())
	menos.pressed.connect(func():
		CONFIG.mudar(cfg, clampi(int(CONFIG.valor(cfg)) - 10, 0, 100))
		mostrar.call())
	mais.pressed.connect(func():
		CONFIG.mudar(cfg, clampi(int(CONFIG.valor(cfg)) + 10, 0, 100))
		mostrar.call())
	h.add_child(menos)
	h.add_child(barra)
	h.add_child(mais)
	v.add_child(h)
	mostrar.call()
	return v

## Liga/desliga: nome (e descrição opcional) à esquerda e a chavinha à direita.
func _linha_chave(chave: String, cfg: String, desc := "") -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 0)
	textos.add_child(_rotulo_linha(chave))
	if desc != "":
		var d := Tema.rotulo(desc, 12)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(240, 0)
		d.add_theme_color_override("font_color", COR_TEXTO2)
		textos.add_child(d)
	h.add_child(textos)
	var chave_ui := Control.new()
	chave_ui.custom_minimum_size = Vector2(52, 28)
	chave_ui.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chave_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	chave_ui.draw.connect(func():
		var on := bool(CONFIG.valor(cfg))
		var s := chave_ui.size
		chave_ui.draw_rect(Rect2(Vector2.ZERO, s), Color("#12131c"))
		chave_ui.draw_rect(Rect2(Vector2(1, 1), s - Vector2(2, 2)), Color("#3f9a4a") if on else Color("#2a2d40"))
		chave_ui.draw_rect(Rect2(2, 2, s.x - 4, 2), Color(1, 1, 1, 0.15))
		var x := s.x - 24.0 if on else 2.0
		chave_ui.draw_rect(Rect2(x, 2, 22, s.y - 4), Color("#12131c"))
		chave_ui.draw_rect(Rect2(x + 1, 3, 20, s.y - 6), Color("#e6e6f0") if on else Color("#868ca6"))
		chave_ui.draw_rect(Rect2(x + 1, 3, 20, 2), Color.WHITE))
	Tema.ao_tocar(chave_ui, func(_pos: Vector2):
		CONFIG.mudar(cfg, not bool(CONFIG.valor(cfg)))
		if cfg == "vibracao":
			CONFIG.vibrar(60)
		chave_ui.queue_redraw())
	h.add_child(chave_ui)
	return h

func _linha_texto(chave: String, valor: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(_rotulo_linha(chave))
	var v := Tema.rotulo(valor, 12)
	v.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_theme_color_override("font_color", COR_TEXTO2)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(v)
	return h

func _linha_botao(chave: String, acao: Callable) -> Button:
	var b := Button.new()
	b.text = chave
	b.custom_minimum_size = Vector2(0, 36)
	Tema.estilo_botao(b, "secundario")
	b.pressed.connect(acao)
	return b

func _botao_pequeno(texto: String) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(36 if texto.length() <= 1 else 76, 28)
	b.add_theme_font_size_override("font_size", 12)
	Tema.estilo_botao(b, "secundario")
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return b

# ------------------------------------------------------------ popups
func _fechar_popup() -> void:
	if popup:
		popup.fechar()
		popup = null

func _em_breve(chave: String) -> void:
	_fechar_popup()
	popup = Janela.criar(tr(chave), [["OK", _fechar_popup]], tr("EM_BREVE_TEXTO"))
	add_child(popup)

## Novidades: cada versão com a data e o que mudou para o jogador, da mais nova para a mais antiga.
func _novidades() -> void:
	_fechar_popup()
	var mais: Array = []
	for v in NOVIDADES.LISTA:
		var cab := Tema.rotulo(tr("NOV_VERSAO") % [v["versao"], v["data"]], 16)
		cab.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		cab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cab.add_theme_color_override("font_color", Tema.COR_OURO_CLARO)
		mais.append(cab)
		var t := Tema.rotulo(NOVIDADES.texto(v), 12)
		t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size = Vector2(Janela.LARGURA - 40.0, 0)
		mais.append(t)
	popup = Janela.criar(tr("CFG_NOVIDADES"), [["OK", _fechar_popup]], "", mais)
	add_child(popup)

## Sobre o jogo: créditos, versão e o site.
func _creditos() -> void:
	_fechar_popup()
	popup = Janela.criar(tr("CFG_SOBRE"), [["CFG_SITE", Jogo.abrir_site.bind("suporte.html")], ["OK", _fechar_popup]],
		tr("CFG_CREDITOS_TEXTO") + "\n\n" + tr("CFG_VERSAO") % Jogo.versao())
	add_child(popup)

## Dois toques: o primeiro pede confirmação, o segundo zera o progresso.
func _reiniciar() -> void:
	if not _confirmar_reinicio:
		_confirmar_reinicio = true
		_fechar_popup()
		popup = Janela.criar(tr("REINICIAR_TESTE"), [["REINICIAR_SIM", _reiniciar], ["CANCELAR", func():
			_confirmar_reinicio = false
			_fechar_popup()]], tr("REINICIAR_AVISO"))
		add_child(popup)
		return
	_confirmar_reinicio = false
	_fechar_popup()
	Jogo.reiniciar()
	principal.seguir_criacao()       # mesmo motivo do _sair_agora: sem fechar_tela_cheia antes
