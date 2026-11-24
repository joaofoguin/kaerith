class_name Online
extends RefCounted
## Parte online (DEFINIDO): Firebase Spark grátis, sem Cloud Functions. Login de convidado (anônimo), Firestore para
## os rankings, relógio do servidor para conferir as vidas. O jogo continua 100% jogável offline.
## Tudo por REST (HTTPRequest), sem plugin. Fica DESLIGADO até existir dados/online.json com a chave do projeto.
## PROVISÓRIO (meu): pontos do ranking Caçador = 1 por vitória em QR Inimigo (os 3/2/1 do pódio diário precisam do
## fechamento no servidor, etapa 2 com Functions); Bestiário = espécies descobertas; envio a cada 60 s no máximo.

const ARQUIVO := "res://dados/online.json"
const INTERVALO_ENVIO := 60

static var _cfg := {}
static var _lido := false
static var _token := ""
static var _token_ate := 0
static var _enviado_em := 0
static var _enviando := false
static var conectado := false       # o servidor respondeu na última tentativa (2026-11-23: antes = resposta 2xx)
static var ultimo_erro := ""
## Sistemas Distribuídos (2026-11-23): estado da rede para o aviso na tela (componentes/aviso_rede.gd).
static var tentou := false          # já houve pelo menos uma tentativa de falar com o servidor
static var reconectou_em := 0       # ticks (ms) da última vez que a conexão voltou
## Testes da apresentação (Configurações → Rede e sincronização): servidor "fora do ar" sem desligar a internet.
static var teste_fora := false

# ------------------------------------------------------------ configuração
static func configurado() -> bool:
	_ler_cfg()
	if _cfg.is_empty():
		ultimo_erro = "sem dados/online.json"
	return str(_cfg.get("api_key", "")) != "" and str(_cfg.get("projeto", "")) != ""

static func _ler_cfg() -> void:
	if _lido:
		return
	_lido = true
	if not FileAccess.file_exists(ARQUIVO):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO))
	if d is Dictionary:
		_cfg = d

static func uid() -> String:
	return str(Jogo.dados.get("online", {}).get("uid", ""))

## ID do cliente OAuth da Web (Firebase → Authentication → Google → configuração do SDK da Web).
static func google_client_id() -> String:
	_ler_cfg()
	return str(_cfg.get("google_client_id", ""))

static func google_configurado() -> bool:
	return configurado() and google_client_id() != ""

static func _base() -> String:
	return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % str(_cfg["projeto"])

# ------------------------------------------------------------ HTTP
## Devolve {"ok", "codigo", "dados", "data"} (data = hora do servidor em unix, 0 se não veio).
static func _http(metodo: int, url: String, corpo = null, com_token := true) -> Dictionary:
	if teste_fora:
		_marcar_rede(false)
		ultimo_erro = "TESTE: servidor indisponível"
		await Jogo.get_tree().create_timer(0.3).timeout
		return {"ok": false, "codigo": 0, "dados": null, "data": 0}
	var r := HTTPRequest.new()
	r.timeout = 12.0
	# na Web o navegador já descompacta a resposta; se o Godot tentar de novo dá RESULT_BODY_DECOMPRESS_FAILED (8)
	r.accept_gzip = not OS.has_feature("web")
	Jogo.add_child(r)
	var cab := PackedStringArray(["Content-Type: application/json"])
	if com_token and _token != "":
		cab.append("Authorization: Bearer " + _token)
	var texto: String = "" if corpo == null else (str(corpo) if corpo is String else JSON.stringify(corpo))
	var err := r.request(url, cab, metodo, texto)
	if err != OK:
		r.queue_free()
		_marcar_rede(false)
		ultimo_erro = "request %d" % err
		return {"ok": false, "codigo": 0, "dados": null, "data": 0}
	var res: Array = await r.request_completed
	r.queue_free()
	var codigo: int = res[1]
	var corpo_txt: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var dados = JSON.parse_string(corpo_txt) if corpo_txt != "" else null
	var data := 0
	for h: String in res[2]:
		if h.to_lower().begins_with("date:"):
			data = _data_http(h.substr(5).strip_edges())
	if data == 0:
		data = _data_corpo(dados)          # na Web o navegador esconde o cabeçalho Date
	var ok: bool = res[0] == HTTPRequest.RESULT_SUCCESS and codigo >= 200 and codigo < 300
	# conectado = o servidor respondeu (um 404 ou 409 também é o servidor falando)
	_marcar_rede(res[0] == HTTPRequest.RESULT_SUCCESS and codigo > 0)
	if ok:
		ultimo_erro = ""
	else:
		ultimo_erro = "%d %d %s" % [res[0], codigo, corpo_txt.left(200)]
		push_warning("Online: " + url.get_slice("?", 0) + " -> " + ultimo_erro)
	if data > 0:
		_conferir_relogio(data)
	return {"ok": ok, "codigo": codigo, "dados": dados, "data": data}

static func _marcar_rede(ok: bool) -> void:
	if ok and not conectado and tentou:
		reconectou_em = Time.get_ticks_msec()
	conectado = ok
	tentou = true

## Teste da apresentação: a conexão "caiu" no meio da sincronização (Historico.teste_perder_confirmacao).
static func simular_queda(msg: String) -> void:
	conectado = false
	tentou = true
	ultimo_erro = msg

## "Thu, 12 Nov 2026 22:40:00 GMT" → unix.
static func _data_http(s: String) -> int:
	var p := s.split(" ")
	if p.size() < 5:
		return 0
	var meses := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var hms := p[4].split(":")
	if hms.size() < 3:
		return 0
	var d := {"year": int(p[3]), "month": meses.find(p[2]) + 1, "day": int(p[1]),
		"hour": int(hms[0]), "minute": int(hms[1]), "second": int(hms[2])}
	return Time.get_unix_time_from_datetime_dict(d)

## Hora do servidor tirada do corpo da resposta do Firestore (updateTime do documento ou readTime da consulta).
## Na Web o navegador não deixa o jogo ler o cabeçalho Date (regra de CORS), então o relógio vem daqui.
static func _data_corpo(dados) -> int:
	var s := ""
	if dados is Dictionary:
		s = str(dados.get("updateTime", dados.get("readTime", "")))
	elif dados is Array and not (dados as Array).is_empty() and dados[0] is Dictionary:
		s = str(dados[0].get("readTime", ""))
	if s.length() < 19:
		return 0
	return Time.get_unix_time_from_datetime_string(s.left(19))   # "2026-11-12T22:40:00", em UTC

## Vidas pelo horário do servidor (DEFINIDO): guarda a diferença entre o servidor e o aparelho.
## Vidas.agora() soma essa diferença, então adiantar o relógio do aparelho para de dar vidas ao reconectar.
static func _conferir_relogio(servidor: int) -> void:
	var dif := servidor - int(Time.get_unix_time_from_system())
	if absi(dif) < 120:
		dif = 0                            # diferença pequena é só atraso da rede
	if dif != int(Jogo.dados.get("relogio_dif", 0)):
		Jogo.dados["relogio_dif"] = dif
		Vidas.atualizar()

# ------------------------------------------------------------ login de convidado
static func entrar() -> bool:
	if not configurado():
		return false
	var agora := int(Time.get_unix_time_from_system())
	if _token != "" and agora < _token_ate - 60:
		return true
	var conta: Dictionary = Jogo.dados.get("online", {})
	var chave := str(_cfg["api_key"])
	var r: Dictionary
	if str(conta.get("refresh", "")) != "":
		r = await _http(HTTPClient.METHOD_POST, "https://securetoken.googleapis.com/v1/token?key=" + chave,
			{"grant_type": "refresh_token", "refresh_token": str(conta["refresh"])}, false)
		if r["ok"]:
			_token = str(r["dados"]["id_token"])
			_token_ate = agora + int(r["dados"]["expires_in"])
			conta["refresh"] = str(r["dados"]["refresh_token"])
			conta["uid"] = str(r["dados"]["user_id"])
			Jogo.dados["online"] = conta
			return true
		if int(r["codigo"]) == 0:
			return false                   # sem resposta (offline): NÃO cria outra conta de convidado
	r = await _http(HTTPClient.METHOD_POST, "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + chave,
		{"returnSecureToken": true}, false)
	if not r["ok"]:
		return false
	_token = str(r["dados"]["idToken"])
	_token_ate = agora + int(r["dados"]["expiresIn"])
	Jogo.dados["online"] = {"uid": str(r["dados"]["localId"]), "refresh": str(r["dados"]["refreshToken"])}
	Jogo.salvar()
	return true

## Excluir conta ou personagem (pedido do João, 2026-11-24): apaga do servidor o ranking (jogadores/uid),
## o save da nuvem (saves/uid) e a conta do Firebase Auth. Devolve true se o servidor confirmou
## (ou se o jogo não usa servidor). As partidas antigas (partidas/uid) ficam, sem nome, ligadas a um ID que deixa de existir.
static func excluir_conta() -> bool:
	if not configurado():
		return true
	if str(Jogo.dados.get("online", {}).get("uid", "")) == "":
		return true                         # nunca entrou no servidor: não há nada lá
	if not await entrar():
		return false
	for colecao in ["jogadores", "saves"]:
		var r: Dictionary = await _http(HTTPClient.METHOD_DELETE, _base() + "/" + colecao + "/" + uid())
		if not r["ok"] and int(r["codigo"]) != 404:
			return false
	var conta: Dictionary = await _http(HTTPClient.METHOD_POST,
		"https://identitytoolkit.googleapis.com/v1/accounts:delete?key=" + str(_cfg["api_key"]), {"idToken": _token}, false)
	return bool(conta["ok"])

## Sair da conta (Conta.sair): esquece o acesso guardado na memória; o "online" do save é apagado junto com o save.
static func esquecer_login() -> void:
	_token = ""
	_token_ate = 0
	_enviado_em = 0
	conectado = false
	_nuvem_vista = ""

# ------------------------------------------------------------ Firestore
static func _valor(v) -> Dictionary:
	match typeof(v):
		TYPE_BOOL:
			return {"booleanValue": v}
		TYPE_INT:
			return {"integerValue": str(v)}
		TYPE_FLOAT:
			return {"doubleValue": v}
	return {"stringValue": str(v)}

static func _ler_valor(v: Dictionary):
	if v.has("integerValue"):
		return int(v["integerValue"])
	if v.has("doubleValue"):
		return float(v["doubleValue"])
	if v.has("booleanValue"):
		return bool(v["booleanValue"])
	return str(v.get("stringValue", ""))

static func _campos(d: Dictionary) -> Dictionary:
	var f := {}
	for k in d:
		f[k] = _valor(d[k])
	return {"fields": f}

static func _ler_doc(doc: Dictionary) -> Dictionary:
	var r := {"_id": str(doc.get("name", "")).get_file()}
	var f: Dictionary = doc.get("fields", {})
	for k in f:
		r[k] = _ler_valor(f[k])
	return r

# ------------------------------------------------------------ pontos do jogador
static func pontos() -> Dictionary:
	var cac := 0
	for lista in Jogo.dados.get("qr_vitorias", {}).values():
		cac += (lista as Array).size()
	var vit := 0
	for r in Bestiario.dados().values():
		vit += int(r.get("vit", 0))
	var n := int(Jogo.dados["nivel"])
	var b := Bestiario.vistas()
	return {
		"nome": Jogo.nome_heroi(), "elemento": str(Jogo.dados.get("elemento", "")),
		"nivel": n, "pts_nivel": n * 1000000 + int(Jogo.dados["xp"]),
		"cacador": cac, "pts_cacador": cac,
		"bestiario": b, "pts_bestiario": b * 100000 + mini(vit, 99999),
		"atualizado": int(Time.get_unix_time_from_system()),
	}

## Controle de acessos ao Firebase (2026-11-24; o plano grátis Spark tem 50 mil leituras e 20 mil gravações por dia,
## somando todos os jogadores). Antes, com o jogo aberto e online, a cada 20 s ia 1 gravação (pontos) + 1 leitura
## (save da nuvem): ~180 gravações e ~180 leituras por hora de cada jogador, mesmo parado no menu. Agora:
##   - os pontos do ranking só vão quando mudam (ou quando forçado: abrir o jogo, voltar ao app, Configurações);
##   - o save da nuvem só é conferido quando o progresso daqui mudou, a cada 3 min (para pegar o de outro aparelho)
##     ou quando forçado;
##   - o vigia da rede, quando não há nada para mandar, só "bate na porta" do site (Hosting), que não gasta
##     leitura nem gravação do Firestore.
const INTERVALO_NUVEM := 180
static var _pontos_enviados := ""     # impressão dos últimos pontos que o servidor confirmou
static var _nuvem_conferida_em := 0

static func _impressao_pontos() -> String:
	var p := pontos()
	p.erase("atualizado")
	return JSON.stringify(p).sha256_text()

static func _pontos_mudaram() -> bool:
	return _impressao_pontos() != _pontos_enviados

static func _save_mudou() -> bool:
	return str(Jogo.dados.get("nuvem_hash", "")) != _hash(Jogo.dados)

## Manda os pontos do jogador (no máximo a cada 60 s, a não ser com forcar) e confere a nuvem (conta Google).
## forcar: manda mesmo sem mudança (abrir o jogo, voltar ao app, botões das Configurações).
## rotina: chamado pelo vigia da rede; ignora os 60 s, mas só manda o que mudou.
static func sincronizar(forcar := false, rotina := false) -> bool:
	if not configurado() or _enviando or str(Jogo.dados.get("etapa", "")) != "pronto":
		return false
	var agora := int(Time.get_unix_time_from_system())
	if not forcar and not rotina and agora - _enviado_em < INTERVALO_ENVIO:
		return true
	_enviando = true
	var ok: bool = await entrar()
	if ok and str(Jogo.dados.get("etapa", "")) != "pronto":
		ok = false                           # saiu da conta enquanto conectava: não manda o progresso zerado
	if ok:
		var imp := _impressao_pontos()
		if forcar or imp != _pontos_enviados:
			var r: Dictionary = await _http(HTTPClient.METHOD_PATCH, _base() + "/jogadores/" + uid(), _campos(pontos()))
			ok = r["ok"]
			if ok:
				_pontos_enviados = imp
		if ok:
			_enviado_em = agora
			await Historico.enviar()         # partidas jogadas (inclusive offline) que ainda não foram
			if Conta.google() and (forcar or _save_mudou() or agora - _nuvem_conferida_em >= INTERVALO_NUVEM):
				if await enviar_save():      # conta Google: o progresso também vai para a nuvem
					_nuvem_conferida_em = agora
	_enviando = false
	return ok

## Vigia da rede (Sistemas Distribuídos, 2026-11-23), chamado a cada segundo pelo aviso_rede.gd.
## Offline: tenta de novo a cada 5 s. Online: confere a cada 20 s (ou 5 s se há partidas na fila).
## Na Web, o navigator.onLine avisa na hora que a internet caiu ou voltou.
## Quando a conexão volta, a sincronização acontece sozinha, com o jogo aberto, sem reiniciar nada.
static var _vigia_seg := 0
static var _vigiando := false
static var _nav_online := true
static func vigiar() -> void:
	if not configurado():
		return
	if OS.has_feature("web"):
		# no Godot 4.7 Web o booleano do eval não compara direito: devolve texto
		var on: bool = str(JavaScriptBridge.eval("navigator.onLine === false ? 'nao' : 'sim'", true)) != "nao"
		if not on:
			if conectado or not tentou:
				simular_queda("sem internet (o navegador avisou)")
			_nav_online = false
			return
		if not _nav_online:
			_nav_online = true
			_vigia_seg = 999                 # a internet acabou de voltar: confere agora
	_vigia_seg += 1
	var intervalo := 20 if conectado else 5
	if conectado and Historico.pendentes() > 0:
		intervalo = 5
	if _vigia_seg < intervalo or _vigiando or _enviando:
		return
	_vigia_seg = 0
	_vigiando = true
	var agora := int(Time.get_unix_time_from_system())
	var pronto := str(Jogo.dados.get("etapa", "")) == "pronto"
	var tem_o_que_mandar := pronto and (Historico.pendentes() > 0 or _pontos_mudaram()
		or (Conta.google() and (_save_mudou() or agora - _nuvem_conferida_em >= INTERVALO_NUVEM)))
	if tem_o_que_mandar:
		await sincronizar(false, true)
	else:
		var voltou := not conectado
		await _bater_na_porta()
		if voltou and conectado and pronto:
			await sincronizar(false, true)   # a conexão voltou: manda o que ficou parado
	_vigiando = false

## Confere se a internet e o servidor respondem sem gastar o Firestore: pede um arquivo pequeno do site
## (hospedagem/paginas/ping.txt). Qualquer resposta do servidor (até um 404) conta como "online".
static func _bater_na_porta() -> void:
	await _http(HTTPClient.METHOD_GET, Jogo.SITE + "/ping.txt?t=%d" % Time.get_ticks_msec(), null, false)

## Uma partida do histórico (Historico.enviar). Devolve "ok", "duplicada" (o servidor já tinha esse ID) ou "falhou".
static func gravar_partida(item: Dictionary) -> String:
	if not configurado() or not await entrar():
		return "falhou"
	var campos: Dictionary = item.duplicate()
	campos.erase("id")
	var url := "%s/partidas/%s/lista/%s?currentDocument.exists=false" % [_base(), uid(), str(item["id"]).uri_encode()]
	var r: Dictionary = await _http(HTTPClient.METHOD_PATCH, url, _campos(campos))
	if r["ok"]:
		return "ok"
	if int(r["codigo"]) == 409 or JSON.stringify(r["dados"]).contains("ALREADY_EXISTS"):
		ultimo_erro = ""
		return "duplicada"
	return "falhou"

## O jogador voltou para o jogo (trocou de app/aba): confere a nuvem, no máximo a cada 15 s.
static var _voltou_em := 0
static func sincronizar_ao_voltar() -> void:
	var agora := int(Time.get_unix_time_from_system())
	if agora - _voltou_em < 15:
		return
	_voltou_em = agora
	sincronizar(true)

## Top 50 do campo. Devolve {"ok", "lista": [docs], "posicao": minha posição (0 se não sei)}.
static func ranking(campo: String) -> Dictionary:
	if not await sincronizar(true):
		return {"ok": false, "lista": [], "posicao": 0}
	var q := {"structuredQuery": {"from": [{"collectionId": "jogadores"}],
		"orderBy": [{"field": {"fieldPath": campo}, "direction": "DESCENDING"}], "limit": 50}}
	var r: Dictionary = await _http(HTTPClient.METHOD_POST, _base() + ":runQuery", q)
	if not r["ok"]:
		return {"ok": false, "lista": [], "posicao": 0}
	var lista: Array = []
	for item in r["dados"]:
		if item is Dictionary and item.has("document"):
			lista.append(_ler_doc(item["document"]))
	var meus: int = int(pontos()[campo])
	var c := {"structuredAggregationQuery": {"structuredQuery": {"from": [{"collectionId": "jogadores"}],
		"where": {"fieldFilter": {"field": {"fieldPath": campo}, "op": "GREATER_THAN", "value": _valor(meus)}}},
		"aggregations": [{"alias": "n", "count": {}}]}}
	var rc: Dictionary = await _http(HTTPClient.METHOD_POST, _base() + ":runAggregationQuery", c)
	var pos := 0
	if rc["ok"] and rc["dados"] is Array and not (rc["dados"] as Array).is_empty():
		var agg: Dictionary = rc["dados"][0].get("result", {}).get("aggregateFields", {})
		if agg.has("n"):
			pos = int(_ler_valor(agg["n"])) + 1
	return {"ok": true, "lista": lista, "posicao": pos}

# ------------------------------------------------------------ ranking do QR (por inimigo, por dia)
static func dia_local() -> String:
	return Time.get_date_string_from_unix_time(Vidas.agora() + int(Time.get_time_zone_from_system()["bias"]) * 60)

## Vitória num QR Inimigo: entra no ranking do dia daquele código (quem vence primeiro fica em cima).
static func registrar_qr(numero: int) -> void:
	if not configurado():
		return
	if not await entrar():
		return
	var doc := "%s/qr/%d_%s/vitorias/%s" % [_base(), numero, dia_local(), uid()]
	await _http(HTTPClient.METHOD_PATCH, doc + "?currentDocument.exists=false",
		_campos({"nome": Jogo.nome_heroi(), "hora": Vidas.agora(), "elemento": str(Jogo.dados.get("elemento", ""))}))

static func ranking_qr(numero: int, dia: String) -> Dictionary:
	if not configurado() or not await entrar():
		return {"ok": false, "lista": []}
	var pai := "%s/qr/%d_%s" % [_base(), numero, dia]
	var q := {"structuredQuery": {"from": [{"collectionId": "vitorias"}],
		"orderBy": [{"field": {"fieldPath": "hora"}, "direction": "ASCENDING"}], "limit": 50}}
	var r: Dictionary = await _http(HTTPClient.METHOD_POST, pai + ":runQuery", q)
	if not r["ok"]:
		return {"ok": false, "lista": []}
	var lista: Array = []
	for item in r["dados"]:
		if item is Dictionary and item.has("document"):
			lista.append(_ler_doc(item["document"]))
	return {"ok": true, "lista": lista}

# ------------------------------------------------------------ login com Google
## Troca o token do Google por uma conta do Firebase (signInWithIdp).
## Visitante com conta anônima: o Google é LIGADO nela (o ID, o ranking e o progresso continuam os mesmos).
## Se essa conta Google já pertence a outro jogador, entra nela (o progresso de lá é resolvido pela Conta).
## Devolve {"ok", "erro", "uid", "email", "nome", "ligou"}.
static func entrar_google(id_token: String) -> Dictionary:
	if not configurado():
		return {"ok": false, "erro": ultimo_erro}
	var url := "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=" + str(_cfg["api_key"])
	var corpo := {"postBody": "id_token=%s&providerId=google.com" % id_token, "requestUri": "http://localhost",
		"returnSecureToken": true, "returnIdpCredential": true}
	var ligar := false
	if uid() != "" and not Conta.google() and await entrar():
		corpo["idToken"] = _token
		ligar = true
	var r: Dictionary = await _http(HTTPClient.METHOD_POST, url, corpo, false)
	var d = r["dados"]
	if ligar and (not r["ok"] or (d is Dictionary and (d as Dictionary).has("errorMessage"))):
		# FEDERATED_USER_ID_ALREADY_LINKED / EMAIL_EXISTS: a conta Google já tem outro jogador; entra nela
		corpo.erase("idToken")
		ligar = false
		r = await _http(HTTPClient.METHOD_POST, url, corpo, false)
		d = r["dados"]
	if not r["ok"] or not (d is Dictionary) or not (d as Dictionary).has("idToken"):
		var msg := ultimo_erro
		if d is Dictionary and (d as Dictionary).has("errorMessage"):
			msg = str(d["errorMessage"])
		return {"ok": false, "erro": msg}
	_token = str(d["idToken"])
	_token_ate = int(Time.get_unix_time_from_system()) + int(d.get("expiresIn", 3600))
	_enviado_em = 0
	Jogo.dados["online"] = {"uid": str(d["localId"]), "refresh": str(d["refreshToken"])}
	return {"ok": true, "erro": "", "uid": str(d["localId"]), "email": str(d.get("email", "")),
		"nome": str(d.get("displayName", "")), "ligou": ligar}

# ------------------------------------------------------------ progresso na nuvem (só contas Google)
## O save inteiro vai como texto JSON num documento saves/{uid} (só o dono lê e escreve; ver firestore.rules).
## Sem o "online" (o token de acesso não sai do aparelho), sem a "conta" e sem as marcas da sincronização.
##
## Sincronização entre aparelhos (2026-11-22, o João viu Safari, Chrome e o atalho da tela inicial com saves
## diferentes: antes cada aparelho só MANDAVA o seu save e nunca conferia a nuvem, então o último a mandar ganhava).
## Agora, antes de mandar, o jogo lê a nuvem e decide:
##   - ninguém mexeu na nuvem desde a última vez que este aparelho sincronizou → manda o daqui;
##   - outro aparelho mandou depois, e aqui nada mudou → baixa o da nuvem (o mais recente);
##   - os dois mudaram (jogou nos dois sem sincronizar) → fica o MAIS AVANÇADO (nível e XP); empate → o mais recente.
## O lado que perde é guardado em user://save_conflito.json (nada some de vez).
## "nuvem_rev" = updateTime do documento que este save conhece; "nuvem_hash" = como o save estava naquela hora.
## Saves antigos sem essas marcas contam como "os dois mudaram" e caem na regra do mais avançado.
## O envio usa a pré-condição do Firestore (currentDocument.updateTime): se outro aparelho mandou no meio, o envio
## falha e a conferência roda de novo na próxima sincronização, em vez de apagar o progresso dele.

const ARQUIVO_CONFLITO := "user://save_conflito.json"
## Campos que não são progresso: não vão para a nuvem ou mudam sozinhos (vidas pelo relógio, hora do save).
const _FORA_DO_HASH := ["online", "conta", "nuvem_em", "nuvem_rev", "nuvem_hash", "salvo_em", "relogio_dif",
	"vidas", "vidas_desde", "idioma", "config"]

static var _sincronizando_nuvem := false
static var _nuvem_vista := ""          # updateTime do último documento baixado (Conta.usar_nuvem usa)

## Cópia do save que vai para a nuvem.
static func _copia_para_nuvem(d: Dictionary) -> Dictionary:
	var copia: Dictionary = d.duplicate(true)
	for k in ["online", "conta", "nuvem_em", "nuvem_rev", "nuvem_hash", "relogio_dif"]:
		copia.erase(k)
	return copia

## Impressão do progresso (sem os campos que mudam sozinhos). Passa pelo JSON duas vezes para os números
## ficarem iguais (o save lido do arquivo tem 5.0 onde o jogo escreve 5).
static func _hash(d: Dictionary) -> String:
	var c: Dictionary = d.duplicate(true)
	for k in _FORA_DO_HASH:
		c.erase(k)
	var ida = JSON.parse_string(JSON.stringify(c))
	return JSON.stringify(ida).sha256_text()

## Quanto o save avançou: criação terminada, depois nível, depois XP.
static func avanco(d: Dictionary) -> int:
	var pronto := 1 if str(d.get("etapa", "")) == "pronto" else 0
	return pronto * 1000000000000 + int(d.get("nivel", 1)) * 10000000 + mini(int(d.get("xp", 0)), 9999999)

## Marca o save daqui como igual ao documento rev da nuvem.
static func marcar_sincronizado(rev: String) -> void:
	Jogo.dados["nuvem_rev"] = rev
	Jogo.dados["nuvem_hash"] = _hash(Jogo.dados)
	Jogo.dados["nuvem_em"] = int(Time.get_unix_time_from_system())

## Chamado pelo Conta.usar_nuvem (login): o save novo é o documento que acabou de ser baixado.
static func marcar_baixado() -> void:
	marcar_sincronizado(_nuvem_vista)

static func _guardar_conflito(d: Dictionary, lado: String) -> void:
	var f := FileAccess.open(ARQUIVO_CONFLITO, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"lado": lado, "em": int(Time.get_unix_time_from_system()), "dados": d}, "\t"))
		f.close()

## Confere a nuvem e manda ou baixa conforme a regra acima. Devolve true se no fim os dois estão iguais.
## (O nome ficou o mesmo de antes para quem já chamava: Configurações "Salvar na nuvem agora", sair da conta.)
## manter_aqui = true: o jogador escolheu ficar com o progresso deste aparelho (login nas Configurações);
## aí o daqui vai para a nuvem de qualquer jeito (o da nuvem fica guardado em save_conflito.json).
static func enviar_save(manter_aqui := false) -> bool:
	if not configurado() or _sincronizando_nuvem:
		return false
	_sincronizando_nuvem = true
	var ok: bool = await _sincronizar_nuvem(manter_aqui)
	_sincronizando_nuvem = false
	return ok

static func _sincronizar_nuvem(manter_aqui: bool) -> bool:
	var b: Dictionary = await baixar_save()
	if not b["ok"]:
		return false
	var remoto: Dictionary = b["dados"]
	var rev := str(b.get("rev", ""))
	if remoto.is_empty():
		return await _subir(rev)                      # nuvem vazia: manda o daqui
	if manter_aqui:
		_guardar_conflito(remoto, "nuvem")
		return await _subir(rev)
	var base := str(Jogo.dados.get("nuvem_rev", ""))
	var mudou_aqui: bool = str(Jogo.dados.get("nuvem_hash", "")) != _hash(Jogo.dados)
	if base != "" and base == rev:
		# ninguém mandou nada desde a última sincronização deste aparelho
		if mudou_aqui:
			return await _subir(rev)
		return true
	if not mudou_aqui:
		return _baixar(remoto, rev)                   # outro aparelho jogou depois; aqui está igual
	# os dois mudaram: fica o mais avançado; empate, o mais recente
	var a_local := avanco(Jogo.dados)
	var a_remoto := avanco(remoto)
	var local_ganha := a_local > a_remoto or (a_local == a_remoto
		and int(Jogo.dados.get("salvo_em", 0)) >= int(remoto.get("salvo_em", 0)))
	if local_ganha:
		_guardar_conflito(remoto, "nuvem")
		return await _subir(rev)
	return _baixar(remoto, rev)

## Manda o save daqui. rev = documento que ele substitui ("" = o documento ainda não existe).
static func _subir(rev: String) -> bool:
	if not Conta.google():
		return false                                  # saiu da conta no meio da sincronização
	var copia := _copia_para_nuvem(Jogo.dados)
	var campos := _campos({"salvo_em": int(Time.get_unix_time_from_system()), "nivel": int(Jogo.dados["nivel"]),
		"versao": int(Jogo.dados.get("versao", 1))})
	campos["fields"]["dados"] = {"stringValue": empacotar(JSON.stringify(copia))}
	var cond := "?currentDocument.updateTime=" + rev.uri_encode() if rev != "" else "?currentDocument.exists=false"
	var r: Dictionary = await _http(HTTPClient.METHOD_PATCH, _base() + "/saves/" + uid() + cond, campos)
	if not r["ok"]:
		return false                                  # outro aparelho mandou no meio: confere de novo depois
	var nova := str(r["dados"].get("updateTime", "")) if r["dados"] is Dictionary else ""
	marcar_sincronizado(nova)
	Jogo.salvar()
	return true

## Troca o progresso daqui pelo da nuvem. Não troca no meio de um combate (tenta de novo depois).
static func _baixar(remoto: Dictionary, rev: String) -> bool:
	if not Conta.google():
		return false              # saiu da conta no meio: não traz de volta o progresso da conta antiga
	var p = Jogo.get_tree().get_first_node_in_group("principal")
	var tela = p.get("tela_cheia") if p else null
	if tela and is_instance_valid(tela) and (tela as Object).has_method("pedir_saida"):
		return false
	if str(Jogo.dados.get("etapa", "")) == "pronto":
		_guardar_conflito(_copia_para_nuvem(Jogo.dados), "aparelho")
	_nuvem_vista = rev
	# idioma e configurações (som, vibração...) são de cada aparelho: ficam os daqui
	var novo: Dictionary = remoto.duplicate(true)
	novo["idioma"] = Jogo.dados.get("idioma", novo.get("idioma", "pt"))
	if Jogo.dados.has("config"):
		novo["config"] = Jogo.dados["config"]
	Conta.usar_nuvem(novo, Jogo.dados.get("conta", {}))   # marca o save como sincronizado e salva
	if p and p.get("conteudo") and str(Jogo.dados.get("etapa", "")) == "pronto":
		# as telas abertas mostravam o progresso antigo: volta para a aba atual já com o novo
		# (as Configurações ficam abertas: é delas o botão "Salvar na nuvem agora" que pode ter trazido isto)
		var aberta = p.get("tela_cheia")
		if aberta and is_instance_valid(aberta) \
				and not str((aberta as Node).get_script().resource_path).ends_with("configuracoes.gd"):
			p.call("fechar_tela_cheia")
		p.call("abrir_aba", str(p.get("aba_atual")) if str(p.get("aba_atual")) != "" else "inicio")
	return true

## Tamanho do save na nuvem (2026-11-24): o JSON vai comprimido (gzip + base64, com o prefixo "z1:"), o que
## deixa o documento de 4 a 8 vezes menor (menos dados baixados a cada conferência; o limite do Firestore é
## 1 MiB por documento). Saves antigos, em JSON puro, continuam sendo lidos.
const PREFIXO_ZIP := "z1:"
static func empacotar(json: String) -> String:
	var bruto := json.to_utf8_buffer()
	return PREFIXO_ZIP + str(bruto.size()) + ":" + Marshalls.raw_to_base64(bruto.compress(FileAccess.COMPRESSION_GZIP))

static func desempacotar(texto: String) -> String:
	if not texto.begins_with(PREFIXO_ZIP):
		return texto
	var resto := texto.substr(PREFIXO_ZIP.length())
	var tam := int(resto.get_slice(":", 0))
	var dados := Marshalls.base64_to_raw(resto.substr(resto.find(":") + 1))
	return dados.decompress(tam, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()

## Progresso guardado na nuvem para o jogador atual. Devolve {"ok", "dados", "rev"}; "dados" vazio = não tem.
## rev = updateTime do documento (a versão dele no servidor).
static func baixar_save() -> Dictionary:
	if not configurado() or not await entrar():
		return {"ok": false, "dados": {}, "rev": ""}
	var r: Dictionary = await _http(HTTPClient.METHOD_GET, _base() + "/saves/" + uid())
	if int(r["codigo"]) == 404:
		conectado = true
		ultimo_erro = ""
		_nuvem_vista = ""
		return {"ok": true, "dados": {}, "rev": ""}
	if not r["ok"] or not (r["dados"] is Dictionary):
		return {"ok": false, "dados": {}, "rev": ""}
	var texto := desempacotar(str(r["dados"].get("fields", {}).get("dados", {}).get("stringValue", "")))
	var lido = JSON.parse_string(texto) if texto != "" else null
	_nuvem_vista = str(r["dados"].get("updateTime", ""))
	return {"ok": true, "dados": lido if lido is Dictionary else {}, "rev": _nuvem_vista}
