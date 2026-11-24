class_name ConfigRemota
extends RefCounted
## Promoções e QR controlados pelo Firebase (pedido do João, 2026-11-22): ligar, desligar e criar sem exportar
## o jogo de novo. O João edita no console do Firebase (Firestore); o jogo baixa sozinho e guarda no save para
## funcionar offline. Passo a passo no LEIA-ME ("Promoções e QR pelo Firebase").
##
## Coleção "promocoes" (um documento por promoção; o nome do documento é o id):
##   modelo      "bolsa", "conjunto" ou "livre"  arte e conteúdo usados ("livre": o conteúdo vem de "conteudo")
##   ativo       booleano                false esconde sem apagar
##   inicio, fim carimbo de data/hora    quando aparece e quando some (sem fim = até o fim do ato em curso)
##   preco       texto                   ex.: "R$ 9,90"
##   nome_pt, nome_en, desc_pt, desc_en  textos (sem eles, usa os do modelo)
##   cristais, fragmentos  número        só no modelo "bolsa" (padrão 50 e 100)
##   ordem       número                  ordem na Loja; o Início mostra as 2 primeiras
##   icone, cena, vitrine  texto        artes novas (pedido do João, 2026-11-22): nome do PNG na pasta promocoes/ do
##                                       site (hospedagem/site/promocoes/). icone 72×72 (Início), cena 164×260 (popup,
##                                       aparece ×2), vitrine 320×160 (Loja). Sem o campo, ou sem internet na 1ª vez,
##                                       usa a arte do modelo. Valem em qualquer modelo.
##   conteudo    texto                   só no "livre": até 3 itens, ex. "cristais:80, fragmentos:200, vidas:3",
##                                       "moedas:500", id de poção ou de peça ("pocao_de_vida_i:2", "espada_de_ferro:1")
##   cor         texto                   cor do brilho e da faixa do popup, ex. "#c8283a" (opcional)
## Coleção "qr_bloqueados": o nome do documento é o número do QR (ex.: "110"); campo opcional "motivo".
## Documento "config/qr": recurso, bau, inimigo, evento (booleanos; false desliga todos os QR daquele tipo).
## Documento "config/inicio": evento (booleano). true mostra o botão Evento do Início; sem ele, o botão fica escondido.
## Documento "config/temporada": ato_2, ato_3, ato_4 (carimbo de data/hora). Quando cada ato abre. Sem o campo, vale o
##   calendário da temporada (Temporada.inicio_do_ato). Pedido do João (2026-11-22): quem termina um ato antes da data
##   espera o próximo abrir, em vez de seguir direto.
##
## Sem nada baixado ainda (primeira vez offline), valem as promoções do jogo (Loja.PROMOS) até o fim do ato.
## Comprar continua bloqueado enquanto Loja.PAGOS_LIBERADOS for false.

const INTERVALO := 600                 # baixa de novo a cada 10 min (quando alguém consulta)
const MODELOS := ["bolsa", "conjunto", "livre"]
const PASTA_ARTES := "promocoes/"     # pasta do site com as artes novas das promoções
const CACHE_ARTES := "user://promocoes/"
const TIPOS_QR := ["recurso", "bau", "inimigo", "evento"]

static var versao := 0                 # sobe quando chega config nova (as telas refazem os botões)
static var _baixando := false
static var _artes := {}                # nome do arquivo → Texture2D (baixada ou do cache do aparelho)
static var _artes_pedidas := {}        # nome → true (já tentou baixar nesta sessão)
static var _artes_pendentes := 0       # downloads de arte em andamento
static var _baixado_em := -INTERVALO * 1000

static func _cache() -> Dictionary:
	return Jogo.dados.get("config_remota", {})

static func agora() -> int:
	return Vidas.agora()

## Tela de carregamento (pedido do João, 2026-11-22): baixa a config e as artes das promoções ANTES de o jogo
## abrir, para nada aparecer e sumir depois. Espera no máximo `limite` segundos; sem internet, segue com o guardado.
static func preparar(limite: float) -> bool:
	var fim := Time.get_ticks_msec() + int(limite * 1000)
	var arvore := Jogo.get_tree()
	while _baixando and Time.get_ticks_msec() < fim:     # já estava baixando: espera essa terminar
		await arvore.process_frame
	var estado := {"feito": false, "ok": false}
	var tarefa := func():
		estado["ok"] = await baixar()
		estado["feito"] = true
	tarefa.call()
	while not estado["feito"] and Time.get_ticks_msec() < fim:
		await arvore.process_frame
	for p: Dictionary in promocoes():                    # artes das promoções no ar
		for campo in ["icone", "cena", "vitrine"]:
			arte(str(p.get(campo, "")))
	while _artes_pendentes > 0 and Time.get_ticks_msec() < fim:
		await arvore.process_frame
	return bool(estado["ok"])

## Baixa em segundo plano se passou o intervalo. Pode chamar à vontade (não espera).
static func talvez_baixar() -> void:
	if _baixando or Time.get_ticks_msec() - _baixado_em < INTERVALO * 1000:
		return
	baixar()

static func baixar() -> bool:
	if _baixando or not Online.configurado():
		return false
	_baixando = true
	_baixado_em = Time.get_ticks_msec()
	var ok: bool = await Online.entrar()
	var novo := {}
	if ok:
		var promos: Variant = await _lista("promocoes")
		var bloq: Variant = await _lista("qr_bloqueados")
		var conf: Variant = await _lista("config")
		ok = promos != null and bloq != null and conf != null
		if ok:
			var docs := {}
			for d: Dictionary in conf:
				docs[str(d["_id"])] = d
			var tipos := {}
			var f: Dictionary = docs.get("qr", {})
			for t in TIPOS_QR:
				if f.get(t) is bool:
					tipos[t] = bool(f[t])
			var ini: Dictionary = docs.get("inicio", {})
			var inicio := {"evento": bool(ini["evento"]) if ini.get("evento") is bool else false}
			var atos := {}
			var temp: Dictionary = docs.get("temporada", {})
			for ato in range(2, 5):
				if temp.get("ato_%d" % ato) is int:
					atos[str(ato)] = int(temp["ato_%d" % ato])
			var numeros: Array = []
			for d: Dictionary in bloq:
				numeros.append(str(d["_id"]))
			novo = {"promocoes": promos, "qr_bloqueados": numeros, "qr_tipos": tipos, "inicio": inicio, "atos": atos,
				"baixado": agora()}
	_baixando = false
	if not ok:
		return false
	for p: Dictionary in novo["promocoes"]:          # já busca as artes novas, para o popup abrir com elas
		for campo in ["icone", "cena", "vitrine"]:
			arte(str(p.get(campo, "")))
	if JSON.stringify(novo.duplicate().merged({"baixado": 0}, true)) != JSON.stringify(_cache().duplicate().merged({"baixado": 0}, true)):
		Jogo.dados["config_remota"] = novo
		Jogo.salvar()
		versao += 1
		Jogo.progresso_mudou.emit()
	else:
		Jogo.dados["config_remota"] = novo
	return true

## Todos os documentos de uma coleção (null se falhou; coleção vazia = []).
static func _lista(colecao: String) -> Variant:
	var r: Dictionary = await Online._http(HTTPClient.METHOD_GET, Online._base() + "/" + colecao + "?pageSize=100")
	if not r["ok"]:
		return null
	var lista: Array = []
	if r["dados"] is Dictionary:
		for doc in r["dados"].get("documents", []):
			var d := _ler_campos(doc)
			d["_id"] = str(doc.get("name", "")).get_file()
			lista.append(d)
	return lista

static func _ler_campos(doc: Dictionary) -> Dictionary:
	var r := {}
	var f: Dictionary = doc.get("fields", {})
	for k in f:
		r[k] = _valor(f[k])
	return r

static func _valor(v: Dictionary) -> Variant:
	if v.has("timestampValue"):
		return int(Time.get_unix_time_from_datetime_string(str(v["timestampValue"]).left(19)))
	if v.has("integerValue"):
		return int(v["integerValue"])
	if v.has("doubleValue"):
		return float(v["doubleValue"])
	if v.has("booleanValue"):
		return bool(v["booleanValue"])
	if v.has("stringValue"):
		return str(v["stringValue"])
	return null

# ------------------------------------------------------------ promoções
static func _ingles() -> bool:
	return TranslationServer.get_locale().begins_with("en")

## Promoções no ar agora, na ordem. Cada uma: {id, modelo, nome, desc, preco, fim, cristais, fragmentos}.
static func promocoes() -> Array:
	talvez_baixar()
	var t := agora()
	var fim_ato := Temporada.fim_do_ato(Temporada.ato_em_curso())
	var c := _cache()
	var lista: Array = []
	if not c.has("promocoes"):
		for p in Loja.PROMOS:          # nunca baixou: as do jogo, até o fim do ato
			lista.append({"id": p["id"], "modelo": p["id"], "nome": tr_(p["nome"]), "desc": tr_(p["desc"]),
				"preco": p["preco"], "fim": fim_ato, "cristais": 50, "fragmentos": 100, "ordem": 0})
		return lista
	for d: Dictionary in c["promocoes"]:
		var modelo := str(d.get("modelo", d["_id"]))
		if not (modelo in MODELOS) or not bool(d.get("ativo", true)):
			continue
		if d.get("inicio") is int and t < int(d["inicio"]):
			continue
		var fim := int(d["fim"]) if d.get("fim") is int else fim_ato
		if t >= fim:
			continue
		var base: Dictionary = Loja.PROMOS[1] if modelo == "conjunto" else Loja.PROMOS[0]
		var sufixo := "_en" if _ingles() else "_pt"
		var conteudo: Array = ler_conteudo(str(d.get("conteudo", ""))) if modelo == "livre" else []
		lista.append({"id": str(d["_id"]), "modelo": modelo,
			"nome": str(d.get("nome" + sufixo, d.get("nome_pt", tr_(base["nome"])))),
			"desc": str(d.get("desc" + sufixo, d.get("desc_pt", "" if modelo == "livre" else tr_(base["desc"])))),
			"preco": str(d.get("preco", base["preco"])), "fim": fim,
			"cristais": int(d.get("cristais", 50)), "fragmentos": int(d.get("fragmentos", 100)),
			"ordem": int(d.get("ordem", 0)), "conteudo": conteudo, "cor": str(d.get("cor", "")),
			"icone": str(d.get("icone", "")), "cena": str(d.get("cena", "")), "vitrine": str(d.get("vitrine", ""))})
	lista.sort_custom(func(a, b): return int(a["ordem"]) < int(b["ordem"]) or (int(a["ordem"]) == int(b["ordem"]) and str(a["id"]) < str(b["id"])))
	return lista

static func promocao(id: String) -> Dictionary:
	for p in promocoes():
		if str(p["id"]) == id:
			return p
	return {}

static func tr_(chave: String) -> String:
	return TranslationServer.translate(chave)

# ------------------------------------------------------------ QR
## Motivo de recusa vindo do Firebase ("" se o QR pode ser usado). Usa a última config guardada (offline também).
static func bloqueio_qr(numero: int, tipo: String) -> String:
	talvez_baixar()
	var c := _cache()
	if str(numero) in c.get("qr_bloqueados", []):
		return "QR_DESATIVADO"
	if not bool(c.get("qr_tipos", {}).get(tipo, true)):
		return "QR_TIPO_DESATIVADO"
	return ""

# ------------------------------------------------------------ Início e atos
## Botão Evento do Início: só aparece com config/inicio.evento = true (sem nada baixado, fica escondido).
static func evento_ligado() -> bool:
	talvez_baixar()
	return bool(_cache().get("inicio", {}).get("evento", false))

## Quando o ato abre (unix): a data do Firebase (config/temporada.ato_N) ou, sem ela, a do calendário.
static func abertura_do_ato(ato: int) -> int:
	if ato <= 1:
		return 0
	var atos: Dictionary = _cache().get("atos", {})
	if atos.get(str(ato)) is int:
		return int(atos[str(ato)])
	return Temporada.inicio_do_ato(ato)

static func ato_aberto(ato: int) -> bool:
	if Jogo.adm():                   # ADM: todos os atos abertos, sem esperar a data (pedido do João, 2026-11-24)
		return true
	talvez_baixar()
	return agora() >= abertura_do_ato(ato)

## Maior ato já aberto (os atos abrem em ordem: um ato fechado segura os seguintes).
static func ultimo_ato_aberto() -> int:
	var n := 1
	for ato in range(2, 5):
		if not ato_aberto(ato):
			break
		n = ato
	return n

# ------------------------------------------------------------ conteúdo das promoções livres
const TIPOS_FIXOS := ["cristais", "fragmentos", "moedas", "vidas"]

## "cristais:80, fragmentos:200, pocao_de_vida_i:2" → [{tipo, id, qtd}], no máximo 3 (os pedestais da cena).
## tipo: cristais, fragmentos, moedas, vidas, pocao ou peca. Item que o jogo não conhece fica de fora.
static func ler_conteudo(texto: String) -> Array:
	var r: Array = []
	for parte in texto.replace(";", ",").split(",", false):
		var kv := parte.strip_edges().split(":", false)
		if kv.is_empty():
			continue
		var id := kv[0].strip_edges().to_lower()
		var qtd := maxi(1, kv[1].strip_edges().to_int()) if kv.size() > 1 else 1
		var tipo := ""
		if id in TIPOS_FIXOS:
			tipo = id
		elif Loja.consumiveis().has(id):
			tipo = "pocao"
		elif not Equipamento.ficha(id).is_empty():
			tipo = "peca"
		if tipo != "" and r.size() < 3:
			r.append({"tipo": tipo, "id": id, "qtd": qtd})
	return r

# ------------------------------------------------------------ artes novas (pasta promocoes/ do site)
## Textura de uma arte da pasta promocoes/ do site, ou null enquanto não chegou (quem chama usa a do modelo).
## Baixa uma vez por sessão e guarda no aparelho (user://promocoes/) para funcionar offline. Quando chega,
## sobe a versão e as telas refazem os botões.
static func arte(nome: String) -> Texture2D:
	nome = nome.strip_edges()
	if not _nome_valido(nome):
		return null
	if not _artes.has(nome):
		var guardada := _textura(FileAccess.get_file_as_bytes(CACHE_ARTES + nome), nome)
		if guardada:
			_artes[nome] = guardada
	if not _artes_pedidas.has(nome):
		_artes_pedidas[nome] = true
		_baixar_arte(nome)
	return _artes.get(nome)

static func _nome_valido(nome: String) -> bool:
	if nome == "" or nome.length() > 80:
		return false
	var ext := nome.get_extension().to_lower()
	if not ext in ["png", "webp", "jpg", "jpeg"]:
		return false
	for ch in nome:
		if not (ch in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-."):
			return false
	return not nome.begins_with(".")

static func _endereco_site() -> String:
	if OS.has_feature("web"):
		var o: Variant = JavaScriptBridge.eval("String(window.location.origin)")
		if o is String and str(o).begins_with("http"):
			return str(o)
	return Jogo.SITE

static func _baixar_arte(nome: String) -> void:
	var r := HTTPRequest.new()
	r.timeout = 20.0
	r.accept_gzip = not OS.has_feature("web")
	Jogo.add_child(r)
	if r.request(_endereco_site() + "/" + PASTA_ARTES + nome) != OK:
		r.queue_free()
		return
	_artes_pendentes += 1
	var res: Array = await r.request_completed
	_artes_pendentes -= 1
	r.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return
	var bytes: PackedByteArray = res[3]
	var tex := _textura(bytes, nome)
	if tex == null:
		return
	DirAccess.make_dir_recursive_absolute(CACHE_ARTES)
	var f := FileAccess.open(CACHE_ARTES + nome, FileAccess.WRITE)
	if f:
		f.store_buffer(bytes)
		f.close()
	_artes[nome] = tex
	versao += 1
	Jogo.progresso_mudou.emit()

static func _textura(bytes: PackedByteArray, nome: String) -> Texture2D:
	if bytes.is_empty():
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	match nome.get_extension().to_lower():
		"png":
			err = img.load_png_from_buffer(bytes)
		"webp":
			err = img.load_webp_from_buffer(bytes)
		_:
			err = img.load_jpg_from_buffer(bytes)
	if err != OK or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
