class_name Vidas
extends RefCounted
## Vidas (DEFINIDO): no máximo 5; volta 1 a cada 40 min, contando pelo relógio do aparelho, mesmo com o jogo
## fechado; só a derrota gasta; com zero vidas, fases e QR ficam bloqueados.
## Recarga com cristais (DEFINIDO): só quando as vidas zeram, recarga completa de 5 vidas por 80 cristais.
## O servidor confere o relógio ao reconectar (etapa 10). Se o relógio voltar para trás, a contagem recomeça
## do horário atual, para não dar vidas a mais.

const MAX := 5
const RECARGA := 40 * 60
const RECARGA_TESTE := 40          # "recarga rápida (teste)": 1 vida a cada 40 segundos
const PRECO_RECARGA := 80

## Relógio do aparelho corrigido pela diferença do servidor (guardada na última conexão; 0 se nunca conectou).
static func agora() -> int:
	return int(Time.get_unix_time_from_system()) + int(Jogo.dados.get("relogio_dif", 0))

static func intervalo() -> int:
	return RECARGA_TESTE if Jogo.adm() and bool(Jogo.dados.get("vidas_teste_rapido", false)) else RECARGA

static func qtd() -> int:
	return int(Jogo.dados["vidas"])

## Soma as vidas que voltaram desde a última conta. Devolve quantas voltaram.
static func atualizar() -> int:
	var v := qtd()
	if v >= MAX:
		Jogo.dados["vidas_desde"] = 0
		return 0
	var desde := int(Jogo.dados.get("vidas_desde", 0))
	var t := agora()
	if desde <= 0 or desde > t:
		Jogo.dados["vidas_desde"] = t       # sem marca ou relógio voltou: recomeça daqui
		return 0
	var ganhas := (t - desde) / intervalo()
	if ganhas <= 0:
		return 0
	ganhas = mini(ganhas, MAX - v)
	Jogo.dados["vidas"] = v + ganhas
	if v + ganhas >= MAX:
		Jogo.dados["vidas_desde"] = 0
	else:
		Jogo.dados["vidas_desde"] = desde + ganhas * intervalo()
	return ganhas

## Segundos até a próxima vida (0 se está cheio).
static func faltam() -> int:
	if qtd() >= MAX:
		return 0
	var desde := int(Jogo.dados.get("vidas_desde", 0))
	if desde <= 0:
		return intervalo()
	return clampi(desde + intervalo() - agora(), 0, intervalo())

static func texto_faltam() -> String:
	var s := faltam()
	return "%d:%02d" % [s / 60, s % 60]

## Derrota: gasta 1 vida. Se estava cheio, a contagem da próxima começa agora.
static func gastar() -> void:
	atualizar()
	var v := qtd()
	if v <= 0:
		return
	if v >= MAX:
		Jogo.dados["vidas_desde"] = agora()
	Jogo.dados["vidas"] = v - 1
	Jogo.salvar()

static func pode_recarregar() -> bool:
	return qtd() <= 0 and int(Jogo.dados["cristais"]) >= PRECO_RECARGA

## Recarga completa com cristais (só com zero vidas). Funciona offline.
static func recarregar() -> bool:
	if not pode_recarregar():
		return false
	Jogo.dados["cristais"] = int(Jogo.dados["cristais"]) - PRECO_RECARGA
	Jogo.dados["vidas"] = MAX
	Jogo.dados["vidas_desde"] = 0
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	return true

## +n vidas (vídeo com prêmio, ou a vida devolvida ao continuar uma luta). Não passa do máximo.
static func ganhar(n := 1) -> void:
	atualizar()
	var v := mini(qtd() + n, MAX)
	Jogo.dados["vidas"] = v
	if v >= MAX:
		Jogo.dados["vidas_desde"] = 0
	elif int(Jogo.dados.get("vidas_desde", 0)) <= 0:
		Jogo.dados["vidas_desde"] = agora()
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
