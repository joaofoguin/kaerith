class_name Anuncios
extends RefCounted
## Vídeos com prêmio (DEFINIDO): +1 vida por vídeo, sem limite diário; continuar depois da derrota com 50% da Vida
## (1 vez por tentativa, só no modo história). "Cancelar"/fechar antes do fim não dá prêmio.
##
## Quem mostra o vídeo (2026-11-22, pedido do João: "ativar o AdMob ou o que pagar mais"):
##   - Android: AdMob, pelo plugin "AdMob" da Poing Studios (AssetLib). Sem o plugin instalado, cai na espera.
##     Versão ADM usa SEMPRE o bloco de teste do Google; a pública usa o bloco de dados/anuncios.json.
##   - Web: H5 Games Ads do Google AdSense (o AdMob não roda em navegador). Liga quando dados/anuncios.json
##     tem "adsense_cliente" (ca-pub-...). O JavaScript fica em web/kaerith_shell.html (KaerithAds).
##   - Sem anúncio disponível (sem plugin, sem conta, sem internet): a tela de espera de 5 s do próprio jogo.
## As classes do plugin são buscadas pelo nome em tempo de execução, então o jogo compila sem o plugin.

const DURACAO := 5.0
const CONFIG := "res://dados/anuncios.json"
## Bloco de anúncio com prêmio de TESTE do Google (Android). Pode ser usado à vontade sem risco à conta.
const ID_TESTE_ANDROID := "ca-app-pub-3940256099942544/5224354917"

static var _iniciado := false
static var _carregado = null           # RewardedAd do plugin, pronto para mostrar
static var _carregando := false
static var _cfg := {}

static func disponivel() -> bool:
	return true

## Onde o vídeo vai passar agora: "admob", "web" ou "espera".
static func provedor() -> String:
	if OS.has_feature("android") and _classe("MobileAds") != null:
		return "admob"
	if OS.has_feature("web") and _web_ligado():
		return "web"
	return "espera"

## Chamado uma vez na abertura (principal._ready): liga o SDK e já deixa um vídeo carregado.
static func iniciar() -> void:
	if _iniciado:
		return
	_iniciado = true
	_cfg = _ler_config()
	if OS.has_feature("android") and _classe("MobileAds") != null:
		_classe("MobileAds").initialize()
		_carregar()
	elif OS.has_feature("web"):
		var cliente := str(_cfg.get("adsense_cliente", ""))
		if cliente != "":
			JavaScriptBridge.eval("window.KaerithAds && KaerithAds.iniciar(%s, %s); 'ok'" % [JSON.stringify(cliente), "true" if (Jogo.adm() or bool(_cfg.get("adsense_teste", true))) else "false"], true)

## Mostra o vídeo e chama ao_fim(true) se ele foi até o fim, ou ao_fim(false) se foi fechado antes.
static func mostrar_video(pai: Node, ao_fim: Callable) -> void:
	iniciar()
	match provedor():
		"admob":
			if _carregado != null:
				_mostrar_admob(ao_fim)
				return
			_carregar()             # ainda não carregou (internet lenta): espera e tenta de novo na próxima
		"web":
			_mostrar_web(pai, ao_fim)
			return
	_mostrar_espera(pai, ao_fim)

# ------------------------------------------------------------ espera (sem anúncio)
static func _mostrar_espera(pai: Node, ao_fim: Callable) -> void:
	var t := TelaAnuncio.new()
	t.ao_fim = ao_fim
	var raiz := pai.get_tree().get_first_node_in_group("principal")
	(raiz if raiz else pai).add_child(t)

# ------------------------------------------------------------ AdMob (Android)
static func _classe(nome: String):
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == nome:
			return load(str(c["path"]))
	return null

static func _id_admob() -> String:
	var id := str(_cfg.get("admob_recompensa_android", ""))
	if Jogo.adm() or id == "":
		return ID_TESTE_ANDROID
	return id

static func _carregar() -> void:
	if _carregando or _carregado != null or _classe("RewardedAdLoader") == null:
		return
	_carregando = true
	var cb = _classe("RewardedAdLoadCallback").new()
	cb.on_ad_loaded = func(ad) -> void:
		Anuncios._carregado = ad
		Anuncios._carregando = false
	cb.on_ad_failed_to_load = func(_erro) -> void:
		Anuncios._carregando = false
	_classe("RewardedAdLoader").new().load(_id_admob(), _classe("AdRequest").new(), cb)

static func _mostrar_admob(ao_fim: Callable) -> void:
	var ad = _carregado
	_carregado = null
	var estado := {"ganhou": false, "fim": false}
	var terminar := func(ok: bool) -> void:
		if estado["fim"]:
			return
		estado["fim"] = true
		if ad != null and ad.has_method("destroy"):
			ad.destroy()
		Anuncios._carregar()          # já prepara o próximo
		if ao_fim.is_valid():
			ao_fim.call_deferred(ok)
	var tela = _classe("FullScreenContentCallback").new()
	tela.on_ad_dismissed_full_screen_content = func() -> void:
		terminar.call(estado["ganhou"])
	tela.on_ad_failed_to_show_full_screen_content = func(_erro) -> void:
		terminar.call(false)
	ad.full_screen_content_callback = tela
	var premio = _classe("OnUserEarnedRewardListener").new()
	premio.on_user_earned_reward = func(_item) -> void:
		estado["ganhou"] = true
	ad.show(premio)

# ------------------------------------------------------------ Web (H5 Games Ads / AdSense)
static func _web_ligado() -> bool:
	if _cfg.is_empty():
		_cfg = _ler_config()
	if str(_cfg.get("adsense_cliente", "")) == "":
		return false
	# retorno sempre em texto: o booleano do JavaScriptBridge não compara direito no Godot 4.7 Web
	return str(JavaScriptBridge.eval("(window.KaerithAds && KaerithAds.pronto()) ? 'sim' : 'nao'", true)) == "sim"

static func _mostrar_web(pai: Node, ao_fim: Callable) -> void:
	JavaScriptBridge.eval("KaerithAds.recompensa(); 'ok'", true)
	var espia := Timer.new()
	espia.wait_time = 0.25
	espia.ignore_time_scale = true
	espia.process_mode = Node.PROCESS_MODE_ALWAYS
	var raiz: Node = pai.get_tree().get_first_node_in_group("principal")
	(raiz if raiz else pai).add_child(espia)
	espia.timeout.connect(_espiar_web.bind(espia, pai, ao_fim))
	espia.start()

static func _espiar_web(espia: Timer, pai: Node, ao_fim: Callable) -> void:
	var e := str(JavaScriptBridge.eval("KaerithAds.estado()", true))
	if e == "ganhou" or e == "fechou":
		espia.queue_free()
		ao_fim.call(e == "ganhou")
	elif e == "indisponivel":
		# sem vídeo para mostrar agora (comum nos primeiros dias da conta): usa a espera
		espia.queue_free()
		_mostrar_espera(pai, ao_fim)

static func _ler_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	return d if d is Dictionary else {}
