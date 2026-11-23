class_name Temporada
extends RefCounted
## Calendário da Temporada 1 e os dados de cada ato usados no Início (popup do ato).
## DEFINIDO (doc): a S1 dura 90 dias em 4 atos: dias 1–20, 21–45, 46–70 e 71–90.
## DEFINIDO pelo João (2026-11-22): a temporada começa em 22/11/2026 às 00h de Brasília (INICIO_UTC abaixo).
## Atos: I 22/11, II 12/12, III 06/01/2027, IV 31/01/2027; fim em 20/02/2027. O relógio é o mesmo das vidas
## (Vidas.agora, que já corrige pelo servidor quando há internet). Cada abertura pode ser adiada ou antecipada
## pelo Firebase (config/temporada, ConfigRemota.abertura_do_ato).

const INICIO_UTC := "2026-11-22T03:00:00"        # 00h00 em Brasília (UTC−3)
const DIAS_ATO := [20, 25, 25, 20]
const ROMANOS := ["I", "II", "III", "IV"]
const DIA := 86400

## Cores de cada ato (tiradas dos mapas): fundo do cartão, borda/destaque, texto claro, sombra.
const CORES := {
	1: {"fundo": Color("#1d3320"), "acento": Color("#e8b33a"), "claro": Color("#c8e89a"), "escuro": Color("#0f1c12")},
	2: {"fundo": Color("#16241f"), "acento": Color("#a99ad0"), "claro": Color("#9fe0c0"), "escuro": Color("#0b1411")},
	3: {"fundo": Color("#33281f"), "acento": Color("#e09a5a"), "claro": Color("#d8e6ee"), "escuro": Color("#1a130e")},
	4: {"fundo": Color("#1a2a3e"), "acento": Color("#a8e8ff"), "claro": Color("#f5fcff"), "escuro": Color("#0c1520")},
}

static func inicio() -> int:
	return int(Time.get_unix_time_from_datetime_string(INICIO_UTC))

static func agora() -> int:
	return Vidas.agora()

## Início (unix) do ato pelo calendário.
static func inicio_do_ato(ato: int) -> int:
	var dias := 0
	for i in clampi(ato, 1, 4) - 1:
		dias += int(DIAS_ATO[i])
	return inicio() + dias * DIA

## Fim do ato: quando o próximo abre (data do Firebase ou, sem ela, o calendário). O Ato IV acaba no fim da temporada.
## Assim, se o João adia um ato pelo Firebase, o anterior continua "em curso" (e as promoções sem fim também).
static func fim_do_ato(ato: int) -> int:
	var a := clampi(ato, 1, 4)
	if a < 4:
		return ConfigRemota.abertura_do_ato(a + 1)
	return inicio_do_ato(4) + int(DIAS_ATO[3]) * DIA

## Começo de fato do ato (a abertura, que pode ter sido mudada no Firebase).
static func comeco_do_ato(ato: int) -> int:
	return inicio() if ato <= 1 else ConfigRemota.abertura_do_ato(ato)

## Ato em curso pelo calendário (1 antes do início, 4 depois do fim), sem passar do último ato já aberto
## (a abertura de cada ato pode ser adiada pelo Firebase: ConfigRemota.abertura_do_ato).
static func ato_em_curso() -> int:
	var t := agora()
	var n := 4
	for ato in range(1, 5):
		if t < fim_do_ato(ato):
			n = ato
			break
	return mini(n, ConfigRemota.ultimo_ato_aberto())

static func restante(ato: int) -> int:
	return maxi(0, fim_do_ato(ato) - agora())

## Fração do ato que já passou (0 a 1), para a barra do tempo.
static func passado(ato: int) -> float:
	var total := maxf(1.0, float(fim_do_ato(ato) - comeco_do_ato(ato)))
	return clampf(float(agora() - comeco_do_ato(ato)) / total, 0.0, 1.0)

## "7d 04h", "5h 12min" ou "12min".
static func texto_tempo(s: int) -> String:
	var d := s / DIA
	var h := (s % DIA) / 3600
	var m := (s % 3600) / 60
	if d > 0:
		return "%dd %02dh" % [d, h]
	if h > 0:
		return "%dh %02dmin" % [h, m]
	return "%dmin" % maxi(m, 1)

static func romano(ato: int) -> String:
	return ROMANOS[clampi(ato, 1, 4) - 1]

static func cores(ato: int) -> Dictionary:
	return CORES[clampi(ato, 1, 4)]

static func nome(ato: int) -> String:
	var d = JSON.parse_string(FileAccess.get_file_as_string("res://dados/mapa.json"))
	return str(d["nomes"][str(ato)]) if d is Dictionary else ""

## Ato do jogador pela fase em que ele está.
static func ato_do_jogador() -> int:
	return clampi(int((int(Jogo.dados["fase_atual"]) - 1) / 75) + 1, 1, 4)

## Fases vencidas dentro do ato (0 a 75).
static func vencidas_no_ato(ato: int) -> int:
	var feitas := int(Jogo.dados["fase_atual"]) - 1
	return clampi(feitas - (ato - 1) * 75, 0, 75)

## Espécies que aparecem no ato (as famílias com peso > 0 no sorteio), na ordem do Bestiário,
## mais as duas Elites Supremas. Cada item: {id, chave, visto}.
static func criaturas(ato: int) -> Array:
	var ids: Array = []
	var pesos: Array = Encontros.PESOS[ato]
	for i in Encontros.FAMILIAS.size():
		if int(pesos[i]) <= 0:
			continue
		for id in Encontros.POOL[ato][Encontros.FAMILIAS[i]]:
			var estreia := int(Encontros.ESTREIA.get(id, 1))
			if estreia <= ato and not (id in ids):
				ids.append(id)
	for s in Encontros.SUPREMA[ato]:
		if not (s in ids):
			ids.append(s)
	var lista: Array = []
	for e in Bestiario.especies():
		if str(e["id"]) in ids:
			lista.append({"id": str(e["id"]), "chave": str(e["chave"]), "visto": not Bestiario.registro(str(e["id"])).is_empty()})
	return lista

## Chefe do ato: {id, chave, nome, visto}.
static func chefe(ato: int) -> Dictionary:
	var id: String = Encontros.CHEFE[ato]
	var chave := ""
	var nome_chefe := ""
	for k: String in Artes.lista_inimigos():
		var f: Dictionary = Artes.dados_inimigos()["inimigos"][k]
		if str(f["id"]) == id:
			chave = k
			nome_chefe = str(f.get("nome", id))
			break
	return {"id": id, "chave": chave, "nome": nome_chefe, "visto": Bestiario.personagens().has(id)}
