class_name Encontros
extends RefCounted
## Monta os inimigos de cada fase. Sorteio com semente = número da fase, então a fase é sempre igual
## (atributos "fixos na 1ª vez"). Distribuição por família e por ato: aba Mobile · Inimigos (DEFINIDA).
## PROVISÓRIO (delegação): nível por fase, quantidade de inimigos, número de ondas e quando entra Veterano.

const POOL := {
	1: {"bandidos": ["batedor", "brutamontes", "contrabandista", "incendiaria", "curandeiro"], "locais": ["javali", "lebre", "corvo"],
		"anomalas": ["cervo", "lodo", "abutre", "brotado", "galgo", "mariposa"], "gelo": []},
	2: {"bandidos": ["batedor", "brutamontes", "contrabandista", "incendiaria", "curandeiro"], "locais": ["javali_raiz", "lebre_orvalho", "corvo", "cobra"],
		"anomalas": ["cervo", "lodo", "abutre", "brotado", "galgo", "mariposa"], "gelo": []},
	3: {"bandidos": ["batedor", "brutamontes", "contrabandista", "incendiaria", "curandeiro", "rastreador", "rastreador"], "locais": ["javali_ferro", "lebre_faisca", "corvo", "cobra"],
		"anomalas": ["cervo", "lodo", "abutre", "brotado", "galgo", "mariposa"], "gelo": ["soldado_geada", "escudeiro_gelo", "atirador_geada"]},
	4: {"bandidos": ["batedor", "brutamontes", "contrabandista", "incendiaria", "curandeiro", "rastreador"], "locais": ["javali_neve", "lebre_neve", "corvo"],
		"anomalas": ["cervo", "lodo", "abutre", "brotado", "galgo", "mariposa"],
		"gelo": ["soldado_geada", "escudeiro_gelo", "atirador_geada", "tecelao_geada", "arminho_geada", "lobo_geada", "verme_geada", "mamute_glacial", "eco_mudo"]},
}
const PESOS := {1: [50, 45, 5, 0], 2: [25, 30, 45, 0], 3: [30, 15, 30, 25], 4: [10, 15, 25, 50]}
const FAMILIAS := ["bandidos", "locais", "anomalas", "gelo"]
const ESTREIA := {"rastreador": 3, "javali_raiz": 2, "javali_ferro": 3, "javali_neve": 4, "lebre_orvalho": 2, "lebre_faisca": 3, "lebre_neve": 4,
	"cobra": 2, "cervo": 2, "lodo": 2, "abutre": 2, "brotado": 2, "galgo": 2, "mariposa": 2,
	"soldado_geada": 3, "escudeiro_gelo": 3, "atirador_geada": 3, "tecelao_geada": 4, "arminho_geada": 4, "lobo_geada": 4,
	"verme_geada": 4, "mamute_glacial": 4, "eco_mudo": 4}
const SUPREMA := {1: ["presa_mestra", "capitao_de_estrada"], 2: ["rei_da_galhada", "besta_sem_nome"], 3: ["cacador_de_recompensas", "olho_de_ysmera"], 4: ["alfa_da_ultima_geada", "bastiao_do_selo"]}
const CHEFE := {1: "mestre_calder", 2: "semeadora_velada", 3: "thessa_vurn", 4: "ysmera"}

static func tipo_da_fase(fase: int) -> String:
	var k := (fase - 1) % 75 + 1
	if k == 75:
		return "chefe"
	if k == 25 or k == 50:
		return "suprema"
	if k % 10 == 0:
		return "elite"
	if k % 10 == 5:
		return "ondas"
	return "combate"

## Nível dos inimigos (pedido do João, 2026-11-23): sobe 1 a cada 15 fases do mapa.
## Fases 1–15 = NV2, 16–30 = NV3, 31–45 = NV4 ... fase 300 = NV21.
## Pedido do João (2026-11-22): do 2º combate do tutorial em diante, os inimigos têm pelo menos nível 2.
const NIVEL_MINIMO := 2
const FASES_POR_NIVEL := 15
static func nivel_da_fase(fase: int) -> int:
	return NIVEL_MINIMO + int((maxi(fase, 1) - 1) / FASES_POR_NIVEL)

static func arena_da_fase(fase: int) -> int:
	var ato := int((fase - 1) / 75) + 1
	var k := (fase - 1) % 75 + 1
	if ato == 3:
		return 1 if k <= 25 else (0 if k <= 50 else 2)
	return (fase - 1) % 3

static func gerar(fase: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * fase + 13
	var ato := clampi(int((fase - 1) / 75) + 1, 1, 4)
	var k := (fase - 1) % 75 + 1
	var nv := nivel_da_fase(fase)
	var tipo := tipo_da_fase(fase)
	var ondas: Array = []
	match tipo:
		"combate":
			# só o comecinho do Ato 1 tem luta de 1 inimigo; os outros atos já começam com grupos
			# (correção de 2026-11-24: o começo de cada ato dava menos XP que o fim do anterior)
			var n := 1
			if fase > 3:
				n = 1 + int(rng.randf() < 0.45)
			if fase > 10:
				var r := rng.randf()
				n = 1 if r < 0.30 else (2 if r < 0.75 else 3)
			ondas.append(_grupo(rng, ato, k, nv, n))
		"ondas":
			var total := 2 if fase < 40 else 3
			for i in total:
				ondas.append(_grupo(rng, ato, k, nv, 1 + int(rng.randf() < 0.5)))
		"elite":
			var lider := _sorteia_tipo(rng, ato, k)
			var chave := lider + "_elite"
			if k == 40:
				chave = "urso_de_barranco"       # Elite especial, uma vez por ato no fim de um bloco
			var g: Array = [{"sprite": chave, "categoria": "elite", "nivel": nv}]
			g.append_array(_grupo(rng, ato, k, nv, 1 + int(rng.randf() < 0.5)))
			ondas.append(g)
		"suprema":
			ondas.append(_grupo(rng, ato, k, nv, 2))
			ondas.append([{"sprite": SUPREMA[ato][0 if k == 25 else 1], "categoria": "suprema", "nivel": nv}])
		"chefe":
			ondas.append(_grupo(rng, ato, k, nv, 2))
			ondas.append(_grupo(rng, ato, k, nv, 2))
			ondas.append([{"sprite": CHEFE[ato], "categoria": "chefe", "nivel": nv}])
	return {"fase": fase, "ato": ato, "tipo": tipo, "arena": arena_da_fase(fase), "ondas": ondas}

static func _sorteia_tipo(rng: RandomNumberGenerator, ato: int, k: int) -> String:
	var pesos: Array = PESOS[ato].duplicate()
	if ato == 1 and k < 61:
		pesos[2] = 0                     # no Ato 1 a anômala só aparece no fim
	var soma := 0
	for p in pesos:
		soma += p
	var r := rng.randi_range(1, soma)
	var fam := 0
	while r > pesos[fam]:
		r -= pesos[fam]
		fam += 1
	var lista: Array = POOL[ato][FAMILIAS[fam]]
	if ato == 3 and fam == 3 and k >= 41:
		lista = lista + ["lobo_geada"]   # o Lobo da Geada desce ao sul antes da hora (missão 14 do Brokk), só Comum
	return lista[rng.randi_range(0, lista.size() - 1)]

static func _grupo(rng: RandomNumberGenerator, ato: int, k: int, nv: int, n: int) -> Array:
	var g: Array = []
	while g.size() < n:
		var t := _sorteia_tipo(rng, ato, k)
		var cat := "comum"
		if ato > int(ESTREIA.get(t, 1)) or (k > 50 and rng.randf() < 0.25):
			cat = "veterano"
		var e := {"sprite": "%s_%s" % [t, cat], "categoria": cat, "nivel": nv}
		if t == "arminho_geada":           # os arminhos andam em bandos de 3
			g = [e, e.duplicate(), e.duplicate()]
			break
		g.append(e)
	return g

## Fase do Evento do QR (caminho lateral): inimigos da região da fase atual do jogador.
## etapa 1–5; tipo "combate", "ondas" ou "elite" (Elite final com escolta).
static func gerar_evento(fase_base: int, etapa: int, tipo: String, semente: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente + 104729 * etapa
	var ato := clampi(int((fase_base - 1) / 75) + 1, 1, 4)
	var k := (fase_base - 1) % 75 + 1
	var nv := nivel_da_fase(fase_base)
	var ondas: Array = []
	match tipo:
		"ondas":
			for i in 2:
				ondas.append(_grupo(rng, ato, k, nv, 1 + int(rng.randf() < 0.5)))
		"elite":
			var g: Array = [{"sprite": _sorteia_tipo(rng, ato, k) + "_elite", "categoria": "elite", "nivel": nv}]
			g.append_array(_grupo(rng, ato, k, nv, 1 + int(rng.randf() < 0.5)))
			ondas.append(g)
		_:
			var n := 1 + int(rng.randf() < 0.5)
			if k > 10 and rng.randf() < 0.3:
				n = 3
			ondas.append(_grupo(rng, ato, k, nv, n))
	return {"fase": 0, "ato": ato, "tipo": "evento", "arena": arena_da_fase(fase_base + etapa), "ondas": ondas, "etapa": etapa}
