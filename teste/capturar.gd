extends Node
const TEMPORADA := preload("res://scripts/temporada.gd")
const POPUP_ATO := preload("res://scripts/componentes/popup_ato.gd")
const POPUP_PROMOCAO := preload("res://scripts/componentes/popup_promocao.gd")
const POPUP_ORBE := preload("res://scripts/componentes/popup_orbe.gd")
const POPUP_FASE := preload("res://scripts/componentes/popup_fase.gd")
const POPUP_INIMIGO := preload("res://scripts/componentes/popup_inimigo.gd")
## Só para conferir o visual: abre cada tela do jogo e salva um print de 360×640 em res://capturas/.
## Como usar: abra teste/capturar.tscn no Godot e aperte F6. A janela fecha sozinha no fim (~40 s).
## Não muda o save: guarda uma cópia dos dados e devolve no final.

var p          # cena principal (principal.gd)
var pasta := ""
var n := 0

## Altura da janela de teste: 800 = celular alto (Pixel 7). Troque para 640 para ver o tamanho original.
const ALTURA := 800

func _ready() -> void:
	get_window().size = Vector2i(360, ALTURA)
	pasta = ProjectSettings.globalize_path("res://capturas")
	DirAccess.make_dir_recursive_absolute(pasta)
	var copia: Dictionary = Jogo.dados.duplicate(true)
	# para ver todas as telas liberadas, sem passar pela criação
	Jogo.dados["etapa"] = "pronto"
	Jogo.dados["loja_teste"] = true
	if str(Jogo.dados.get("elemento", "")) == "":
		Jogo.dados["elemento"] = "fogo"
	p = load("res://cenas/principal.tscn").instantiate()
	get_tree().root.add_child.call_deferred(p)
	await _esperar(5.0)                      # tela de carregamento + login online
	await _foto("inicio")
	for id in ["loja", "diario", "inventario", "ranking"]:
		p.abrir_aba(id)
		await _esperar(1.2)
		await _foto(id)
		var tela: Node = p.conteudo.get_child(p.conteudo.get_child_count() - 1)
		if id in ["diario", "inventario"]:
			for i in range(1, 4):
				tela.call("_trocar_aba", i)
				await _esperar(0.8)
				await _foto("%s_aba%d" % [id, i])
		if id == "loja":
			var rol: ScrollContainer = tela.get("rolagem")
			if rol:
				rol.scroll_vertical = 600
				await _esperar(0.5)
				await _foto("loja_meio")
	p.abrir_aba("inicio")
	await _esperar(1.0)
	for nome in ["mapa", "personagem", "ler_qr"]:
		var tc: Node = load("res://scripts/telas/%s.gd" % nome).new()
		p.abrir_tela_cheia(tc)
		await _esperar(1.8)
		await _foto(nome)
		if nome == "mapa":
			# placa do próximo ato bloqueado (o medalhão com o numeral e o cadeado)
			var prox := clampi(int((int(Jogo.dados["fase_atual"]) - 1) / 75) + 2, 2, 4)
			var des = tc.get("desenho")
			var rol: ScrollContainer = tc.get("rolagem")
			rol.scroll_vertical = int(des.y_do_ato(prox) + 4200.0 - 420.0 - 200.0)
			await _esperar(1.0)
			await _foto("mapa_bloqueado")
		p.fechar_tela_cheia()
		await _esperar(1.2)
	# popups decorados do Início: ato em curso e promoções (as duas)
	var inicio: Node = p.conteudo.get_child(p.conteudo.get_child_count() - 1)
	var pa = POPUP_ATO.new()
	pa.ato = TEMPORADA.ato_em_curso()
	inicio.add_child(pa)
	await _esperar(1.2)
	await _foto("popup_ato")
	pa.fechar()
	await _esperar(0.6)
	for id in ["bolsa", "conjunto"]:
		var pp = POPUP_PROMOCAO.new()
		pp.promo = id
		inicio.add_child(pp)
		await _esperar(1.2)
		await _foto("popup_promo_" + id)
		pp.fechar()
		await _esperar(0.6)
	# popups dos Orbes: o do elemento base (ou fogo) e um que ainda não foi obtido
	var base_el := str(Jogo.dados.get("elemento", ""))
	var lista_orbes: Array = [base_el if base_el != "" else "fogo", "gelo" if base_el != "gelo" else "agua"]
	for el_o: String in lista_orbes:
		var po = POPUP_ORBE.new()
		po.el = el_o
		inicio.add_child(po)
		await _esperar(1.0)
		await _foto("popup_orbe_" + el_o)
		po.fechar()
		await _esperar(0.6)
	# popup da fase: a 1ª (jogada no tutorial ou não), uma Elite e o chefe do Ato 1; e a ficha de um inimigo
	for f_cap: int in [1, 10, 75]:
		var pf = POPUP_FASE.new()
		pf.fase = f_cap
		inicio.add_child(pf)
		await _esperar(1.0)
		await _foto("popup_fase_%d" % f_cap)
		pf.fechar()
		await _esperar(0.6)
	var pi = POPUP_INIMIGO.new()
	pi.chave = str(Encontros.gerar(10)["ondas"][0][0]["sprite"])
	pi.categoria = "elite"
	pi.nivel = Encontros.nivel_da_fase(10)
	inicio.add_child(pi)
	await _esperar(1.0)
	await _foto("popup_inimigo")
	pi.fechar()
	await _esperar(0.6)
	p.abrir_tela_cheia(load("res://scripts/telas/configuracoes.gd").new())
	await _esperar(1.5)
	await _foto("configuracoes")
	p.fechar_tela_cheia()
	await _esperar(1.0)
	JanelaVidas.abrir(p.conteudo.get_child(p.conteudo.get_child_count() - 1))
	await _esperar(1.0)
	await _foto("popup_vidas")
	var t: Tela = load("res://scripts/telas/combate.gd").new()
	t.set("fase", maxi(1, int(copia.get("fase_atual", 1))))
	p.abrir_tela_cheia(t)
	await _esperar(3.0)
	await _foto("combate")
	Engine.time_scale = 1.0
	Jogo.dados = copia
	Jogo.salvar()
	print("CAPTURAS PRONTAS: ", n, " em ", pasta)
	get_tree().quit()

func _esperar(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	n += 1
	img.save_png(pasta.path_join("%02d_%s.png" % [n, nome]))
