class_name Historico
extends RefCounted
## Histórico das partidas no servidor (trabalho de Sistemas Distribuídos, 2026-11-23).
##
## Cada combate terminado vira um REGISTRO com um ID único criado no próprio aparelho (hora + bytes aleatórios).
## O registro entra primeiro numa FILA LOCAL (user://partidas_fila.json, padrão "caixa de saída") e só sai dela
## quando o servidor confirma. Assim:
##   - offline: a partida fica na fila, persistente (fechar e abrir o jogo não perde nada);
##   - a conexão volta: o vigia da rede (Online.vigiar) manda a fila sozinho, sem reiniciar nada;
##   - falha no meio do envio: o que já foi confirmado saiu da fila; o resto continua lá e vai na próxima vez;
##   - reenvio (a resposta se perdeu e o aparelho manda de novo): o documento tem o MESMO ID e vai com a
##     pré-condição "currentDocument.exists=false"; o Firestore responde 409 ALREADY_EXISTS, o jogo entende que
##     o servidor já tinha esse registro e só tira da fila. Nada é contado duas vezes (idempotência).
## No servidor: partidas/{uid}/lista/{id} (ver hospedagem/firestore.rules).

const ARQUIVO := "user://partidas_fila.json"
const MAX_FILA := 500                   # proteção: aparelho offline por muito tempo não cresce sem limite

static var _d := {}
static var _lido := false
static var _enviando := false
## Teste da apresentação: no próximo envio, o servidor grava mas a resposta "se perde" (o aparelho acha que falhou).
static var teste_perder_confirmacao := false
static var ultimo_aviso := ""

static func _ler() -> void:
	if _lido:
		return
	_lido = true
	_d = {"fila": [], "enviadas": 0, "duplicadas": 0, "ultima": {}}
	for arq in [ARQUIVO, ARQUIVO + ".tmp"]:
		if FileAccess.file_exists(arq):
			var x = JSON.parse_string(FileAccess.get_file_as_string(arq))
			if x is Dictionary:
				for k in x:
					_d[k] = x[k]
				return

## Grava sem risco: escreve no .tmp e só então troca (se cair no meio, o .tmp é lido na próxima vez).
static func _gravar() -> void:
	var tmp := ARQUIVO + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Historico: não consegui gravar a fila")
		return
	f.store_string(JSON.stringify(_d))
	f.close()
	if FileAccess.file_exists(ARQUIVO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(ARQUIVO))

## Um combate terminou. tipo = "fase" | "qr" | "evento"; onde = número da fase, do QR ou da etapa do Evento.
## Chamado ANTES do Jogo.salvar() do resultado: o registro fica no disco junto com o progresso.
static func registrar(tipo: String, onde: int, vitoria: bool, xp: int, moedas: int) -> void:
	_ler()
	var agora := int(Time.get_unix_time_from_system())
	var item := {
		"id": "%d_%s" % [agora, Crypto.new().generate_random_bytes(6).hex_encode()],
		"tipo": tipo, "onde": onde, "vitoria": vitoria, "xp": xp, "moedas": moedas,
		"nivel": int(Jogo.dados.get("nivel", 1)), "em": agora, "aparelho": OS.get_name(),
	}
	var fila: Array = _d["fila"]
	fila.append(item)
	while fila.size() > MAX_FILA:
		fila.pop_front()
	_gravar()

static func pendentes() -> int:
	_ler()
	return (_d["fila"] as Array).size()

static func enviadas() -> int:
	_ler()
	return int(_d.get("enviadas", 0))

static func duplicadas() -> int:
	_ler()
	return int(_d.get("duplicadas", 0))

## Manda a fila, uma partida por vez, na ordem. Para no primeiro erro (o resto fica para a próxima).
## Devolve true se a fila ficou vazia.
static func enviar() -> bool:
	_ler()
	if _enviando:
		return false
	if (_d["fila"] as Array).is_empty():
		return true
	_enviando = true
	var ok := true
	while not (_d["fila"] as Array).is_empty():
		var item: Dictionary = _d["fila"][0]
		var r: String = await Online.gravar_partida(item)
		if r == "falhou":
			ok = false
			break
		if r == "ok" and teste_perder_confirmacao:
			# o servidor GRAVOU, mas o aparelho não recebeu a confirmação: a partida continua na fila
			teste_perder_confirmacao = false
			Online.simular_queda("TESTE: a conexão caiu antes da confirmação do servidor")
			ultimo_aviso = "falha no meio: a partida %s ficou na fila e vai de novo" % str(item["id"])
			ok = false
			break
		(_d["fila"] as Array).pop_front()
		if r == "ok":
			_d["enviadas"] = int(_d.get("enviadas", 0)) + 1
		else:
			_d["duplicadas"] = int(_d.get("duplicadas", 0)) + 1
			ultimo_aviso = "reenvio da partida %s: o servidor já tinha, nada foi duplicado" % str(item["id"])
		_d["ultima"] = item
		_gravar()
	_enviando = false
	return ok
