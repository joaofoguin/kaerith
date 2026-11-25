class_name CodigoQR
extends RefCounted
## Regras do QR Code (Pontos de Ressonância), tudo offline.
## Texto do código: KAE1|<número>|<tipo>|<Elite ou ->|<fuso em minutos>|<assinatura>
## QR de story (2026-11-24, pedido do João): KAE1|<número>|<tipo>|<Elite ou ->|<fuso>|<AAAAMMDD>|<assinatura>.
##   O dia entra na assinatura e o QR só vale nesse dia (no fuso do QR), com as mesmas regras dos outros.
##   Faixa 401+ = stories do Instagram. Também vale digitando o código curto do story (buscar_codigo).
## Desde 2026-11-22 o QR impresso é um link do site (LinkQR): https://kaerith-d9bef.web.app/#qr=KAE1.<número>...
## com "." no lugar de "|". O formato antigo continua valendo.
## A assinatura (ECDSA P-256 + SHA-256, base64url de r||s) é conferida com a chave pública abaixo.
## A chave secreta fica só na ferramenta de criação (pasta jogo/qr do projeto), nunca no jogo.
##
## DEFINIDO: sem espera entre leituras (João, 2026-11-12); QR das 10h às 23h no horário local de onde o QR está;
## zero vidas bloqueia; 5% de chance da versão rara; Baú: moedas 40% (100–200×fator), Poção de Vida I/II 25%,
## fragmentos 20% (5–10), equipamento 15% (Comum 70 / Incomum 25 / Raro 5); "Agora não" perde o baú.
## PROVISÓRIO (meu): Recurso = 50–100 moedas × fator + 50% de chance de 3–6 fragmentos (raro: 3× e garantido);
## Baú dourado = equipamento garantido com a mesma tabela de raridade; Poção I 70% / II 30%.
##
## Segurança (revisada em 2026-11-22):
## - QR falso ou editado: a assinatura cobre o texto todo (número, tipo, Elite e fuso); mudar 1 letra é recusado.
## - Limite de uso (DEFINIDO pelo João, 2026-11-22): o Baú abre 1 vez por dia para cada jogador (dia no fuso do QR;
##   ler já gasta, porque "Agora não" perde o baú). O Recurso vale de novo 3 h depois da última leitura daquele QR
##   (João, 2026-11-22 17h20; Jogo.dados.qr_recursos {numero: hora}). Inimigo e Evento seguem sem limite.
## - Relógio do horário 10h–23h (contra quem muda a hora do celular):
##   1. com internet, cada leitura pergunta a hora ao servidor antes de aceitar (conferir_hora);
##   2. depois de uma hora confirmada, conta o tempo pelo cronômetro interno (ticks), que não muda com o relógio;
##      mudar a hora com o jogo aberto, mesmo offline, não adianta;
##   3. relógio que voltou para trás da maior hora já vista: recusa até conectar (QR_RELOGIO);
##   4. sem nenhuma hora confiável (offline e jogo reaberto), usa o relógio do aparelho + a última correção do servidor.
## - Desligar pelo Firebase (ConfigRemota): coleção qr_bloqueados (um QR) e config/qr (um tipo inteiro).
## - Sem opções de teste no QR (João tirou "Sem horário" e "Forçar raro" em 2026-11-22), nem na versão ADM.

const CHAVE_PUBLICA := """-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAElMqWTbc2I7Lk4ByFcAsqMXeXrKtD
qfvkHveDPpQkEZsttpARpR0aaO2iSk3fiKE5DOxuQNr0s7dLyBPmtkKuHA==
-----END PUBLIC KEY-----"""

const ABRE := 10
const FECHA := 23
const CHANCE_RARO := 0.05
const TIPOS := {"r": "recurso", "b": "bau", "i": "inimigo", "e": "evento"}
const DURACAO_EVENTO := 24 * 3600

static var _chave: CryptoKey = null

## Lê o texto do código. Devolve {"ok": true, "numero", "tipo", "elite", "fuso"} ou {"ok": false, "erro": chave do texto}.
static func interpretar(texto: String) -> Dictionary:
	var partes := LinkQR.normalizar(texto).split("|")
	if (partes.size() != 6 and partes.size() != 7) or partes[0] != "KAE1":
		return {"ok": false, "erro": "QR_ERRO_OUTRO"}
	var n := partes.size()
	var corpo := "|".join(partes.slice(0, n - 1))
	if not _assinatura_ok(corpo, partes[n - 1]):
		return {"ok": false, "erro": "QR_ERRO_FALSO"}
	if not TIPOS.has(partes[2]) or not partes[1].is_valid_int() or not partes[4].is_valid_int():
		return {"ok": false, "erro": "QR_ERRO_FALSO"}
	var dia := partes[5] if n == 7 else ""          # QR de story: só vale neste dia
	if dia != "" and (dia.length() != 8 or not dia.is_valid_int()):
		return {"ok": false, "erro": "QR_ERRO_FALSO"}
	var tipo: String = TIPOS[partes[2]]
	var elite := partes[3]
	if tipo == "inimigo" and not Artes.dados_inimigos()["inimigos"].has(elite):
		return {"ok": false, "erro": "QR_ERRO_VERSAO"}
	# desligado pelo Firebase (ConfigRemota): QR específico ou o tipo inteiro
	var bloq := ConfigRemota.bloqueio_qr(partes[1].to_int(), tipo)
	if bloq != "":
		return {"ok": false, "erro": bloq}
	return {"ok": true, "numero": partes[1].to_int(), "tipo": tipo, "elite": elite, "fuso": partes[4].to_int(), "dia": dia}

## QR de story fora do dia: texto pronto do motivo ("" se vale hoje). Usa o relógio do jogo (hora do servidor).
static func bloqueio_dia(c: Dictionary) -> String:
	var dia := str(c.get("dia", ""))
	if dia == "":
		return ""
	var hoje := dia_do_qr(int(c["fuso"])).replace("-", "")
	if hoje == dia:
		return ""
	var data := "%s/%s/%s" % [dia.substr(6, 2), dia.substr(4, 2), dia.substr(0, 4)]
	return TranslationServer.translate("QR_STORY_AINDA" if hoje < dia else "QR_STORY_PASSOU") % data

## Código curto do story → texto do QR. Os códigos ficam em codigos.json no site (hospedagem/paginas/codigos.json,
## gerado pela ferramenta criar_story.py). O código é só um atalho: o que vale é a assinatura do texto (o dia
## também), então publicar os códigos antes do dia não deixa ninguém usar antes. Precisa de internet.
## Devolve {"ok": true, "texto"} ou {"ok": false, "erro": chave}.
static func buscar_codigo(codigo: String) -> Dictionary:
	var cod := codigo.strip_edges().to_upper().replace(" ", "").replace("-", "")
	if cod.length() < 4 or cod.length() > 12:
		return {"ok": false, "erro": "QR_CODIGO_INVALIDO"}
	var r := HTTPRequest.new()
	r.timeout = 10.0
	r.accept_gzip = not OS.has_feature("web")
	Jogo.add_child(r)
	if r.request(ConfigRemota._endereco_site() + "/codigos.json?t=%d" % Time.get_ticks_msec()) != OK:
		r.queue_free()
		return {"ok": false, "erro": "QR_CODIGO_SEM_INTERNET"}
	var res: Array = await r.request_completed
	r.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return {"ok": false, "erro": "QR_CODIGO_SEM_INTERNET"}
	var d: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if not (d is Dictionary) or not (d as Dictionary).has(cod):
		return {"ok": false, "erro": "QR_CODIGO_INVALIDO"}
	return {"ok": true, "texto": str(d[cod])}

static func _assinatura_ok(corpo: String, assinatura: String) -> bool:
	if _chave == null:
		_chave = CryptoKey.new()
		if _chave.load_from_string(CHAVE_PUBLICA, true) != OK:
			push_error("QR: chave pública inválida")
			_chave = null
			return false
	var b64 := assinatura.replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var bruto := Marshalls.base64_to_raw(b64)
	if bruto.size() != 64:
		return false
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(corpo.to_utf8_buffer())
	var resumo := ctx.finish()
	return Crypto.new().verify(HashingContext.HASH_SHA256, resumo, _der(bruto), _chave)

## r||s (32 + 32 bytes) → SEQUENCE { INTEGER r, INTEGER s } em DER, que é o que o Godot confere.
static func _der(bruto: PackedByteArray) -> PackedByteArray:
	var r := _inteiro_der(bruto.slice(0, 32))
	var s := _inteiro_der(bruto.slice(32, 64))
	var saida := PackedByteArray([0x30, r.size() + s.size()])
	saida.append_array(r)
	saida.append_array(s)
	return saida

static func _inteiro_der(v: PackedByteArray) -> PackedByteArray:
	var i := 0
	while i < v.size() - 1 and v[i] == 0:
		i += 1
	var corpo := v.slice(i)
	if corpo[0] & 0x80:
		var com_zero := PackedByteArray([0])
		com_zero.append_array(corpo)
		corpo = com_zero
	var saida := PackedByteArray([0x02, corpo.size()])
	saida.append_array(corpo)
	return saida

# ------------------------------------------------------------ quando pode ler
static var _ancora_srv := 0       # hora do servidor confirmada nesta sessão (0 = nenhuma)
static var _ancora_ticks := 0

static func agora() -> int:
	if _ancora_srv > 0:
		return _ancora_srv + int((Time.get_ticks_msec() - _ancora_ticks) / 1000)
	return Vidas.agora()

## Pergunta a hora ao servidor (Firestore devolve readTime). Devolve true se confirmou. Sem internet, false rápido.
static func conferir_hora() -> bool:
	if not Online.configurado() or not await Online.entrar():
		return false
	var q := {"structuredQuery": {"from": [{"collectionId": "jogadores"}], "limit": 1}}
	var r: Dictionary = await Online._http(HTTPClient.METHOD_POST, Online._base() + ":runQuery", q)
	var srv := int(r.get("data", 0))
	if srv <= 0:
		return false
	_ancora_srv = srv
	_ancora_ticks = Time.get_ticks_msec()
	Jogo.dados["qr_maior_hora"] = srv      # hora confiável: zera qualquer hora adiantada de antes
	return true

## O relógio voltou para trás da maior hora já vista (10 min de folga)?
static func relogio_voltou() -> bool:
	return agora() < int(Jogo.dados.get("qr_maior_hora", 0)) - 600

static func _guardar_maior_hora() -> void:
	Jogo.dados["qr_maior_hora"] = maxi(int(Jogo.dados.get("qr_maior_hora", 0)), agora())

## Dia no lugar do QR ("2026-11-23"), para o limite do Baú.
static func dia_do_qr(fuso: int) -> String:
	return Time.get_date_string_from_unix_time(agora() + fuso * 60)

## Este Baú já foi aberto hoje por este jogador?
static func bau_usado_hoje(c: Dictionary) -> bool:
	return str(Jogo.dados.get("qr_baus", {}).get(str(c["numero"]), "")) == dia_do_qr(int(c["fuso"]))

## Recurso: o mesmo QR vale de novo só 3 h depois (relógio do jogo, que confere a hora no servidor).
const ESPERA_RECURSO := 3 * 3600

## Segundos até este QR de Recurso valer de novo (0 = já pode).
static func recurso_falta(c: Dictionary) -> int:
	var ultima := int(Jogo.dados.get("qr_recursos", {}).get(str(c["numero"]), 0))
	return maxi(0, ultima + ESPERA_RECURSO - agora()) if ultima > 0 else 0

## Hora no lugar do QR (fuso em minutos).
static func hora_local(fuso: int) -> int:
	return int(posmod(agora() + fuso * 60, 86400) / 3600)

## Motivo que impede a leitura agora (chave de texto), ou "" se pode.
static func bloqueio(fuso := 0, olhar_janela := false) -> String:
	if int(Jogo.dados["vidas"]) <= 0:
		return "QR_SEM_VIDAS"
	if olhar_janela and relogio_voltou():
		return "QR_RELOGIO"
	if olhar_janela:
		var h := hora_local(fuso)
		if h < ABRE or h >= FECHA:
			return "QR_FORA_HORARIO"
	return ""

static func registrar_leitura(c: Dictionary) -> void:
	Jogo.dados["qr_ultima"] = agora()
	var lidos: Dictionary = Jogo.dados.get("qr_lidos", {})
	var k := str(c["numero"])
	lidos[k] = int(lidos.get(k, 0)) + 1
	Jogo.dados["qr_lidos"] = lidos
	_guardar_maior_hora()
	if c["tipo"] == "bau":
		var baus: Dictionary = Jogo.dados.get("qr_baus", {})
		baus[k] = dia_do_qr(int(c["fuso"]))
		Jogo.dados["qr_baus"] = baus
	elif c["tipo"] == "recurso":
		var recs: Dictionary = Jogo.dados.get("qr_recursos", {})
		recs[k] = agora()
		Jogo.dados["qr_recursos"] = recs
	Jogo.salvar()

static func sortear_raro() -> bool:
	return randf() < CHANCE_RARO

static func fator() -> float:
	return Lutador.fator_de(int(Jogo.dados["nivel"]))

# ------------------------------------------------------------ recompensas (já entram no save)
static func _somar(chave: String, qtd: int) -> void:
	Jogo.dados[chave] = int(Jogo.dados[chave]) + qtd

static func _dar_fragmentos(qtd: int) -> Dictionary:
	var el: String = Catalogo.ELEMENTOS[randi() % Catalogo.ELEMENTOS.size()]
	var f: Dictionary = Jogo.dados["fragmentos"]
	f[el] = int(f.get(el, 0)) + qtd
	return {"icone": PopupResultado.icone("fragmento"), "nome": TranslationServer.translate("RES_L_FRAG") % TranslationServer.translate("EL_" + el.to_upper()), "valor": qtd}

static func _icone_pocao(id: String) -> Texture2D:
	var p := Artes.icone("pocao32_" + id)
	if p.is_empty():
		return null
	var at := AtlasTexture.new()
	at.atlas = p["tex"]
	at.region = p["rect"]
	return at

static func _linha_peca(id: String) -> Dictionary:
	return {"icone": Equipamento.icone(id), "nome": str(Equipamento.ficha(id)["nome"]),
		"texto": TranslationServer.translate("RAR_" + Equipamento.raridade_de(id).to_upper())}

## Recurso: moedas e às vezes fragmentos. Devolve as linhas do popup.
static func dar_recurso(raro: bool) -> Array:
	var linhas: Array = []
	var moedas := int(round(randi_range(50, 100) * fator()))
	_somar("moedas", moedas)
	linhas.append({"icone": PopupResultado.icone("moeda"), "nome": TranslationServer.translate("RES_L_MOEDAS"), "valor": moedas})
	if raro or randf() < 0.5:
		var qtd := randi_range(3, 6) * (3 if raro else 1)
		linhas.append(_dar_fragmentos(qtd))
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	return linhas

static func _raridade_bau() -> String:
	var r := randf()
	if r < 0.70:
		return "comum"
	if r < 0.95:
		return "incomum"
	return "raro"

## Baú: um prêmio sorteado (o dourado sempre dá equipamento).
static func dar_bau(dourado: bool) -> Array:
	var r := randf()
	if dourado:
		r = 0.99
	var linhas: Array = []
	if r < 0.40:
		var moedas := int(round(randi_range(100, 200) * fator()))
		_somar("moedas", moedas)
		linhas.append({"icone": PopupResultado.icone("moeda"), "nome": TranslationServer.translate("RES_L_MOEDAS"), "valor": moedas})
	elif r < 0.65:
		var id := "pocao_de_vida_i" if randf() < 0.7 else "pocao_de_vida_ii"
		var p: Dictionary = Jogo.dados["pocoes"]
		p[id] = int(p.get(id, 0)) + 1
		var nome_chave := "QR_POCAO_I" if id == "pocao_de_vida_i" else "QR_POCAO_II"
		linhas.append({"icone": _icone_pocao(id), "nome": TranslationServer.translate(nome_chave), "valor": 1, "pre": "x"})
	elif r < 0.85:
		linhas.append(_dar_fragmentos(randi_range(5, 10)))
	else:
		var id := Equipamento.sortear(_raridade_bau())
		if id != "":
			Equipamento.dar(id)
			linhas.append(_linha_peca(id))
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	return linhas

# ------------------------------------------------------------ Inimigo
## Ato da Elite (para a arena): a família da Elite estreia num ato.
static func ato_da_elite(elite: String) -> int:
	var tipo := elite.trim_suffix("_elite")
	var ato := int(Encontros.ESTREIA.get(tipo, 1))
	if tipo.ends_with("_geada") or tipo in ["escudeiro_gelo", "mamute_glacial", "eco_mudo"]:
		ato = maxi(ato, 3)
	return ato

## Luta do QR Inimigo: a Elite do código, sozinha, no nível do jogador. Rara = reforçada como Elite Suprema.
static func encontro_inimigo(c: Dictionary, raro: bool) -> Dictionary:
	var ato := ato_da_elite(str(c["elite"]))
	var spec := {"sprite": c["elite"], "categoria": "elite", "nivel": int(Jogo.dados["nivel"])}
	if raro:
		spec["reforcado"] = true
	return {"fase": 0, "ato": ato, "tipo": "qr", "arena": int(c["numero"]) % 3, "ondas": [[spec]],
		"qr": int(c["numero"]), "raro": raro}

## Vitória no QR Inimigo: guarda a hora (o ranking do dia fecha no servidor, etapa 10).
static func registrar_vitoria(numero: int) -> void:
	var v: Dictionary = Jogo.dados.get("qr_vitorias", {})
	var k := str(numero)
	var lista: Array = v.get(k, [])
	lista.append(agora())
	v[k] = lista
	Jogo.dados["qr_vitorias"] = v

# ------------------------------------------------------------ Evento (caminho lateral no mapa)
## DEFINIDO: 5 fases (3 de combate único, 1 de ondas, 1 de Elite final), aberto 24 h, 1 por vez,
## inimigos da região; prêmio final 1 peça Rara de elemento sorteado + 15 fragmentos + 20 cristais
## (raro: peça Épica no lugar da Rara).
static func abrir_evento(c: Dictionary, raro: bool) -> void:
	var fase := int(Jogo.dados["fase_atual"])
	Jogo.dados["evento_qr"] = {"numero": int(c["numero"]), "inicio": agora(), "fase": fase, "vencidas": 0, "raro": raro,
		"semente": randi(), "fuso": int(c.get("fuso", -180))}
	Jogo.salvar()
	Jogo.progresso_mudou.emit()

## O Evento ativo (ou vazio se não há ou já passou o prazo).
static func evento_ativo() -> Dictionary:
	var e: Dictionary = Jogo.dados.get("evento_qr", {})
	if e.is_empty():
		return {}
	if agora() - int(e["inicio"]) >= DURACAO_EVENTO or int(e["vencidas"]) >= 5:
		return {}
	return e

static func evento_restante() -> int:
	var e := evento_ativo()
	if e.is_empty():
		return 0
	return maxi(0, int(e["inicio"]) + DURACAO_EVENTO - agora())

const TIPOS_EVENTO := ["combate", "combate", "combate", "ondas", "elite"]

static func encontro_evento(etapa: int) -> Dictionary:
	var e: Dictionary = Jogo.dados["evento_qr"]
	return Encontros.gerar_evento(int(e["fase"]), etapa, TIPOS_EVENTO[etapa - 1], int(e["semente"]))

## Prêmio do fim do Evento.
static func dar_premio_evento() -> Array:
	var e: Dictionary = Jogo.dados["evento_qr"]
	var linhas: Array = []
	# pedido do João (2026-11-24): a peça Rara (Épica no raro) só é garantida na 1ª vez do dia com este QR
	# (dia no fuso do QR, dados.qr_evento_premio {número: dia}); depois, sorteio como ao rejogar Suprema/chefe
	var premios: Dictionary = Jogo.dados.get("qr_evento_premio", {})
	var k := str(e.get("numero", 0))
	var hoje := dia_do_qr(int(e.get("fuso", -180)))
	var rar := "epico" if bool(e.get("raro", false)) else "raro"
	if str(premios.get(k, "")) == hoje:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		rar = Catalogo.sortear_raridade(Catalogo.PECA_REJOGAR["chefe" if rar == "epico" else "suprema"], rng)
	premios[k] = hoje
	Jogo.dados["qr_evento_premio"] = premios
	var id := Equipamento.sortear(rar, Catalogo.ELEMENTOS[randi() % 6] if rar in ["raro", "epico"] else "")
	if id != "":
		Equipamento.dar(id)
		linhas.append(_linha_peca(id))
	linhas.append(_dar_fragmentos(15))
	_somar("cristais", 20)
	linhas.append({"icone": PopupResultado.icone("cristal"), "nome": TranslationServer.translate("RES_L_CRISTAIS"), "valor": 20})
	return linhas
