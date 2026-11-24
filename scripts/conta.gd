class_name Conta
extends RefCounted
## Conta do jogador (pedido do João, 2026-11-22):
##   visitante: o progresso fica só neste aparelho (conta anônima do Firebase só para o ranking);
##   Google: o progresso também fica na nuvem (Firestore saves/{uid}) e volta ao entrar em outro aparelho.
## O login com Google funciona na versão Web: a página vai ao Google e volta com o token (KaerithWeb.googleEntrar).
## No APK (pedido do João, 2026-11-24), sem plugin: o jogo abre no navegador do celular a página
## SITE/entrar_app.html com um código aleatório; ela faz o login no Google e deixa o token no Firestore em
## login_app/{código}; o jogo busca o token pelo código (Conta.esperar_app), apaga o documento e segue igual à Web.
## Jogo.dados["conta"] = {"tipo": "visitante" | "google", "email", "nome"}. Sem o campo = visitante.

static func tipo() -> String:
	return str(Jogo.dados.get("conta", {}).get("tipo", "visitante"))

static func google() -> bool:
	return tipo() == "google"

static func email() -> String:
	return str(Jogo.dados.get("conta", {}).get("email", ""))

## "" se dá para entrar com o Google aqui; senão a chave do aviso.
static func aviso_google() -> String:
	if not Plataforma.web():
		return "" if Online.google_configurado() else "CONTA_SEM_CONFIG"
	if not Online.google_configurado():
		return "CONTA_SEM_CONFIG"
	if not CameraWeb.ativo():
		return "CONTA_SEM_PAGINA"
	return ""

## Sai da página para o Google. motivo: "login" (tela de entrada) ou "vincular" (Configurações).
static func ir_para_google(motivo: String) -> void:
	if not Plataforma.web():
		_ir_pelo_navegador(motivo)
		return
	Jogo.salvar()
	# o navegador grava o save no armazenamento dele no quadro seguinte; espera um pouco antes de sair da página
	await Jogo.get_tree().create_timer(0.8).timeout
	JavaScriptBridge.eval("window.KaerithWeb.googleEntrar(%s, %s)" % [
		JSON.stringify(Online.google_client_id()), JSON.stringify(motivo)], true)

# ------------------------------------------------------------ APK: login pelo navegador do celular
static var _codigo_app := ""
static var _motivo_app := ""
static var _cancelado := false

static func _ir_pelo_navegador(motivo: String) -> void:
	_codigo_app = Crypto.new().generate_random_bytes(16).hex_encode()      # 32 letras, impossível de adivinhar
	_motivo_app = motivo
	_cancelado = false
	OS.shell_open("%s/entrar_app.html#c=%s&id=%s" % [Jogo.SITE, _codigo_app, Online.google_client_id().uri_encode()])

## Espera o token que a página entrar_app.html deixou no Firestore (confere a cada 2 s; com o app em segundo
## plano o jogo fica parado e confere ao voltar). Devolve o mesmo que retorno(): {"motivo", "token"},
## {"motivo", "erro"} ou {} se o jogador cancelou.
static func esperar_app(limite := 300.0) -> Dictionary:
	var codigo := _codigo_app
	var fim := Time.get_ticks_msec() + int(limite * 1000)
	while not _cancelado and codigo == _codigo_app and Time.get_ticks_msec() < fim:
		await Jogo.get_tree().create_timer(2.0).timeout
		if _cancelado or codigo != _codigo_app:
			break
		var tok: String = await Online.pegar_login_app(codigo)
		if tok != "":
			_codigo_app = ""
			return {"motivo": _motivo_app, "token": tok}
	if _cancelado:
		return {}
	_codigo_app = ""
	return {"motivo": _motivo_app, "erro": "tempo"}

static func cancelar_app() -> void:
	_cancelado = true
	_codigo_app = ""

## Volta do Google: {} (nada), {"motivo", "token"} ou {"motivo", "erro"}. Cada volta é entregue uma vez só.
static func retorno() -> Dictionary:
	if not Plataforma.web():
		return {}
	var s = JavaScriptBridge.eval("window.KaerithWeb ? window.KaerithWeb.pegarGoogle() : ''", true)
	if not (s is String) or s == "":
		return {}
	var p := (s as String).split("|")
	if p[0] == "!erro":
		return {"motivo": p[1] if p.size() > 1 else "", "erro": p[2] if p.size() > 2 else "?"}
	return {"motivo": p[0], "token": p[1] if p.size() > 1 else ""}

## Termina o login com o token do Google.
## - Conta Google nova, ou ligada à conta de visitante deste aparelho: o progresso daqui sobe para a nuvem.
## - Conta Google que já tinha progresso: com carregar = true ele é carregado na hora (tela de entrada);
##   senão volta em "remoto" para o jogador escolher (Configurações).
## Devolve {"ok", "erro", "carregou", "remoto", "info"}.
static func concluir(token: String, carregar: bool) -> Dictionary:
	var r: Dictionary = await Online.entrar_google(token)
	if not r["ok"]:
		return {"ok": false, "erro": str(r.get("erro", ""))}
	var info := {"tipo": "google", "email": str(r["email"]), "nome": str(r["nome"])}
	var nuvem: Dictionary = {}
	if not r["ligou"]:
		var b: Dictionary = await Online.baixar_save()
		if not b["ok"]:
			return {"ok": false, "erro": Online.ultimo_erro}
		nuvem = b["dados"]
	if nuvem.is_empty():
		await manter_local(info)
		return {"ok": true, "erro": "", "carregou": false}
	if carregar:
		usar_nuvem(nuvem, info)
		return {"ok": true, "erro": "", "carregou": true}
	return {"ok": true, "erro": "", "carregou": false, "remoto": nuvem, "info": info}

## Fica com o progresso deste aparelho e manda para a nuvem.
static func manter_local(info: Dictionary) -> void:
	Jogo.dados["conta"] = info
	Jogo.salvar()
	await Online.enviar_save(true)     # o jogador escolheu este progresso (ou a nuvem estava vazia)
	Online.sincronizar(true)

## Sair da conta Google (pedido do João, 2026-11-22: jogadores gostam de ter mais de uma conta).
## Quem chama já mandou o save para a nuvem. Aqui o progresso deste aparelho é apagado (fica só na conta)
## e o jogo volta para a tela de entrada, onde dá para entrar com outra conta Google ou como visitante.
## O idioma e as configurações do aparelho continuam.
static func sair() -> void:
	var idioma := str(Jogo.dados.get("idioma", "pt"))
	var cfg = Jogo.dados.get("config", null)
	Jogo.reiniciar()
	Jogo.dados["idioma"] = idioma
	if cfg != null:
		Jogo.dados["config"] = cfg
	Jogo.dados["etapa"] = "login"          # o Prólogo já foi visto neste aparelho
	Jogo.dados.erase("conta")
	Jogo.dados.erase("online")
	Online.esquecer_login()
	Jogo.salvar()
	Jogo.progresso_mudou.emit()

## Troca o progresso deste aparelho pelo da nuvem.
static func usar_nuvem(nuvem: Dictionary, info: Dictionary) -> void:
	var online: Dictionary = Jogo.dados.get("online", {})
	Jogo.aplicar_save(nuvem)
	Jogo.dados["online"] = online
	Jogo.dados["conta"] = info
	Online.marcar_baixado()           # este save agora é igual ao da nuvem (sincronização entre aparelhos)
	Jogo.salvar()
	Jogo.idioma_mudou.emit()
	Jogo.progresso_mudou.emit()
