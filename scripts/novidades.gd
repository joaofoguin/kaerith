## Novidades de cada versão, para os jogadores (pedido do João, 2026-11-24): a lista aparece em
## Configurações › Ajuda e sobre › Novidades, e uma versão pode ter um aviso que abre uma vez ao entrar no jogo
## para quem já tinha começado a jornada.
## A cada atualização: ponha a versão nova no começo de LISTA e escreva os textos NOV_<versão>_1.. em
## idiomas/textos.csv (PT e EN). Para um aviso, use "aviso": "<id>" e os textos AVISO_<id>_T e AVISO_<id>.
## O id do aviso fica gravado em Jogo.dados["avisos_vistos"].

const LISTA := [
	{"versao": "0.8.2", "data": "24/11/2026", "itens": 2},
	{"versao": "0.8.1", "data": "24/11/2026", "itens": 1},
	{"versao": "0.8.0", "data": "24/11/2026", "itens": 5, "aviso": "missoes"},
	{"versao": "0.7.0", "data": "24/11/2026", "itens": 4},
	{"versao": "0.6.0", "data": "23/11/2026", "itens": 3},
	{"versao": "0.5.0", "data": "22/11/2026", "itens": 3},
]

## Texto de uma versão: um item por parágrafo, com marcador.
static func texto(v: Dictionary) -> String:
	var chave := "NOV_" + str(v["versao"]).replace(".", "")
	var partes: Array = []
	for i in int(v["itens"]):
		partes.append("• " + TranslationServer.translate("%s_%d" % [chave, i + 1]))
	return "\n\n".join(partes)

## O aviso que ainda não foi visto (ou {}), só para quem já terminou a criação do herói.
static func aviso_pendente() -> Dictionary:
	var vistos: Array = Jogo.dados.get("avisos_vistos", [])
	for v in LISTA:
		if v.has("aviso") and not vistos.has(v["aviso"]):
			return v
	return {}

## Marca como visto. Sem `id`, marca todos (jogador novo: as novidades já fazem parte do jogo dele).
static func marcar_visto(id := "") -> void:
	var vistos: Array = Jogo.dados.get("avisos_vistos", [])
	for v in LISTA:
		if v.has("aviso") and (id == "" or v["aviso"] == id) and not vistos.has(v["aviso"]):
			vistos.append(v["aviso"])
	Jogo.dados["avisos_vistos"] = vistos
	Jogo.salvar()

## 0.8.0: quem já tinha passado das fases onde os moradores aparecem (save de antes das missões) recebe
## esses pedidos de uma vez, sem a cena de diálogo; ficam no Diário, aba Missões, e o "!" aparece no mapa.
## Missões que vêm depois de outra missão continuam chegando ao coletar a anterior.
static func entregar_missoes_antigas() -> int:
	var hist := preload("res://scripts/historia.gd")
	var vencidas := int(Jogo.dados.get("fase_atual", 1)) - 1     # fases 1..fase_atual-1 já foram vencidas
	var n := 0
	for id: String in hist.MISSOES:
		var m: Dictionary = hist.MISSOES[id]
		if hist.estado(id) >= 0:
			continue
		var ok := false
		if m.has("aparece"):
			ok = int(m["aparece"]) <= vencidas
		elif str(m.get("apos", "")).begins_with("chefe_"):
			ok = int(str(m["apos"]).trim_prefix("chefe_")) * 75 <= vencidas
		if ok:
			hist._por(id, hist.ESTADO_ATIVA, 0)
			n += 1
	return n
