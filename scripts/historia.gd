extends RefCounted
## História da Temporada 1 e missões secundárias (2026-11-23). Use por preload:
##   const HISTORIA := preload("res://scripts/historia.gd")
## (sem class_name: script novo com class_name não é reconhecido no F6 até o editor reescanear).
##
## O que é DEFINIDO e o que é PROVISÓRIO está no doc "Mapa das versões", aba
## "Temporada 1 · História e missões por ato". Resumo:
##   - DEFINIDO: as falas da Voz (25, 50, 75), as falas dos chefes, os fechamentos dos capítulos, as 17 missões
##     de NPC, as 12 falas de NPC por ato, a cutscene da criança no fim do Ato 1 (o formato é rascunho meu),
##     os tipos novos de missão (desafio, Bestiário, Elite e, opcional, a 2ª parte depois do chefe).
##   - PROVISÓRIO: as falas de conclusão de cada missão, os textos das missões novas, as quantidades
##     ajustadas (A + B), as regras de contagem.
## Tudo de história aparece só na 1ª vitória da fase. As missões contam também ao rejogar e no automático,
## e nunca no QR (o João tirou o QR das missões).
##
## Save (compacto, porque o save inteiro vai para a nuvem):
##   dados["missoes"] = {"m1": [estado, progresso], ...}   estado 0 = em andamento, 1 = concluída (falta
##                      coletar), 2 = recompensa coletada
##   dados["hist"]    = ["h14", "v1_25", ...]               falas já vistas (chaves curtas, na ordem)

const ESTADO_ATIVA := 0
const ESTADO_CONCLUIDA := 1
const ESTADO_COLETADA := 2

## NPC → elemento (DEFINIDO na aba de missões). Retrato: res://artes/personagens/<id>.png (48×48).
const NPCS := {
	"mirela": "agua", "tobin": "ar", "aldo": "raio", "hal": "fogo",
	"ione": "agua", "bram": "terra", "ottilie": "ar", "renn": "raio", "nia": "fogo",
	"maren": "gelo", "oskar": "ar", "brokk": "terra", "ruvo": "raio",
	"tobias": "fogo", "ilsa": "gelo", "durgan": "agua", "garrick": "terra",
}

## Cores dos elementos nas falas, na moldura do retrato e no ícone de missão do mapa ("voz" e "capitulo" também).
const COR_EL := {
	"fogo": Color("#f08a3c"), "agua": Color("#4fa3eb"), "terra": Color("#a8864f"), "ar": Color("#9fe0c8"),
	"raio": Color("#ffe04f"), "gelo": Color("#bfe6ff"), "voz": Color("#d8c8ff"), "capitulo": Color("#ffd66b"),
}

static func cor_do_elemento(el: String) -> Color:
	return COR_EL.get(el, Color("#ffd66b"))

## Fase da temporada (1–300) a partir do ato e da fase dentro dele (1–75).
static func f(ato: int, k: int) -> int:
	return (ato - 1) * 75 + k

## Missões. "aparece": fase (da temporada) cuja 1ª vitória entrega a missão; "apos": missão (ou "chefe_N")
## que libera esta. tipo: derrotar (alvo = espécie, qtd), rejogar (fase), desafio (fase + cond), bestiario
## (alvo = espécie, ficha completa), elite (fase), depois_chefe (fase).
static var MISSOES := {
	# --- Ato 1 · Campos de Auren (DEFINIDAS; quantidades da opção B)
	"m1": {"ato": 1, "npc": "mirela", "aparece": f(1, 8), "tipo": "derrotar", "alvo": "batedor", "qtd": 10},
	"m2": {"ato": 1, "npc": "tobin", "aparece": f(1, 17), "tipo": "rejogar", "fase": f(1, 12)},
	"m3": {"ato": 1, "npc": "aldo", "aparece": f(1, 33), "tipo": "derrotar", "alvo": "contrabandista", "qtd": 8},
	"m5": {"ato": 1, "npc": "hal", "aparece": f(1, 62), "tipo": "derrotar", "alvo": "lebre", "qtd": 5},
	# --- Ato 2 · Mata dos Ecos Velados
	"m6": {"ato": 2, "npc": "ione", "aparece": f(2, 6), "tipo": "derrotar", "alvo": "lodo", "qtd": 8},
	"m7": {"ato": 2, "npc": "bram", "aparece": f(2, 19), "tipo": "derrotar", "alvo": "brotado", "qtd": 10},
	"m8": {"ato": 2, "npc": "ottilie", "aparece": f(2, 34), "tipo": "rejogar", "fase": f(2, 27)},
	"m9": {"ato": 2, "npc": "renn", "aparece": f(2, 48), "tipo": "derrotar", "alvo": "cervo", "qtd": 4},
	"m10": {"ato": 2, "npc": "nia", "aparece": f(2, 63), "tipo": "derrotar", "alvo": "abutre", "qtd": 3},
	# --- Ato 3 · Fronteira de Durnak
	"m11": {"ato": 3, "npc": "maren", "aparece": f(3, 7), "tipo": "derrotar", "alvo": "rastreador", "qtd": 10},
	"m12": {"ato": 3, "npc": "oskar", "aparece": f(3, 18), "tipo": "rejogar", "fase": f(3, 14)},
	"m14": {"ato": 3, "npc": "brokk", "aparece": f(3, 44), "tipo": "derrotar", "alvo": "lobo_geada", "qtd": 4},
	"m15": {"ato": 3, "npc": "ruvo", "aparece": f(3, 61), "tipo": "derrotar", "alvo": "atirador_geada", "qtd": 3},
	# --- Ato 4 · Vale do Último Silêncio
	"m16": {"ato": 4, "npc": "tobias", "aparece": f(4, 5), "tipo": "derrotar", "alvo": "arminho_geada", "qtd": 12},
	"m17": {"ato": 4, "npc": "ilsa", "aparece": f(4, 16), "tipo": "rejogar", "fase": f(4, 11)},
	"m18": {"ato": 4, "npc": "durgan", "aparece": f(4, 32), "tipo": "derrotar", "alvo": "mamute_glacial", "qtd": 6},
	"m20": {"ato": 4, "npc": "garrick", "aparece": f(4, 64), "tipo": "derrotar", "alvo": "soldado_geada", "qtd": 4},
	# --- Tipos novos (aprovados em 2026-11-23; quem dá, fases e limites são PROVISÓRIOS)
	"m21": {"ato": 1, "npc": "mirela", "apos": "m1", "tipo": "desafio", "fase": f(1, 20), "cond": "sem_pocao"},
	"m22": {"ato": 1, "npc": "tobin", "apos": "m2", "tipo": "bestiario", "alvo": "corvo"},
	"m23": {"ato": 1, "npc": "hal", "apos": "m5", "tipo": "elite", "fase": f(1, 70)},
	"m24": {"ato": 1, "npc": "aldo", "apos": "chefe_1", "tipo": "depois_chefe", "fase": f(1, 75)},
	"m25": {"ato": 2, "npc": "ione", "apos": "m6", "tipo": "desafio", "fase": f(2, 35), "cond": "turnos", "valor": 8},
	"m26": {"ato": 2, "npc": "renn", "apos": "m9", "tipo": "bestiario", "alvo": "cervo"},
	"m27": {"ato": 2, "npc": "bram", "apos": "m7", "tipo": "elite", "fase": f(2, 60)},
	"m28": {"ato": 2, "npc": "ottilie", "apos": "chefe_2", "tipo": "depois_chefe", "fase": f(2, 75)},
	"m29": {"ato": 3, "npc": "brokk", "apos": "m14", "tipo": "desafio", "fase": f(3, 45), "cond": "vida", "valor": 50},
	"m30": {"ato": 3, "npc": "maren", "apos": "m11", "tipo": "bestiario", "alvo": "rastreador"},
	"m31": {"ato": 3, "npc": "oskar", "apos": "m12", "tipo": "elite", "fase": f(3, 70)},
	"m32": {"ato": 3, "npc": "maren", "apos": "chefe_3", "tipo": "depois_chefe", "fase": f(3, 75)},
	"m33": {"ato": 4, "npc": "durgan", "apos": "m18", "tipo": "desafio", "fase": f(4, 35), "cond": "sem_pocao"},
	"m34": {"ato": 4, "npc": "tobias", "apos": "m16", "tipo": "bestiario", "alvo": "eco_mudo"},
	"m35": {"ato": 4, "npc": "garrick", "apos": "m20", "tipo": "elite", "fase": f(4, 60)},
	# a 2ª parte da Ilsa (depois de Ysmera) está EM ABERTO: vem depois do fim da temporada
}

## Momentos de história com NPCs (APROVADOS em 2026-11-23): fase → quem fala. Texto: HIST_<fase>.
static var MOMENTOS := {
	f(1, 14): "mirela", f(1, 42): "aldo", f(1, 68): "tobin",
	f(2, 13): "ione", f(2, 38): "ottilie", f(2, 67): "renn",
	f(3, 12): "maren", f(3, 38): "thessa_vurn", f(3, 66): "oskar",
	f(4, 12): "tobias", f(4, 40): "ilsa", f(4, 66): "garrick",
}

const CHEFES := {1: "mestre_calder", 2: "semeadora_velada", 3: "thessa_vurn", 4: "ysmera"}

# ------------------------------------------------------------ save
static func _missoes() -> Dictionary:
	if not Jogo.dados.has("missoes") or not (Jogo.dados["missoes"] is Dictionary):
		Jogo.dados["missoes"] = {}
	return Jogo.dados["missoes"]

static func _hist() -> Array:
	if not Jogo.dados.has("hist") or not (Jogo.dados["hist"] is Array):
		Jogo.dados["hist"] = []
	return Jogo.dados["hist"]

static func viu(chave: String) -> bool:
	return _hist().has(chave)

static func marcar(chave: String) -> void:
	if not viu(chave):
		_hist().append(chave)

static func estado(id: String) -> int:
	var m: Dictionary = _missoes()
	return int(m[id][0]) if m.has(id) else -1

static func progresso(id: String) -> int:
	var m: Dictionary = _missoes()
	return int(m[id][1]) if m.has(id) else 0

static func _por(id: String, est: int, prog: int) -> void:
	_missoes()[id] = [est, prog]

## Missões já recebidas, na ordem do jogo: [id, ...]
static func recebidas() -> Array:
	var r: Array = []
	for id: String in MISSOES:
		if _missoes().has(id):
			r.append(id)
	return r

static func ativas() -> Array:
	return recebidas().filter(func(id): return estado(id) == ESTADO_ATIVA)

static func tem_para_coletar() -> bool:
	for id in recebidas():
		if estado(id) == ESTADO_CONCLUIDA:
			return true
	return false

# ------------------------------------------------------------ textos
static func nome_npc(npc: String) -> String:
	if npc == "thessa_vurn":
		return TranslationServer.translate("NPC_THESSA")
	if npc in Bestiario.CHEFES:          # chefes: o nome curto da ficha ("Mestre Calder, o Receptador" → "Mestre Calder")
		return str(Bestiario.ficha(npc).get("nome", npc)).get_slice(",", 0)
	return TranslationServer.translate("NPC_" + npc.to_upper())

## Primeiro quadro do sprite (a tira tem 4 quadros de 48×64, respiração [0,0,1,1]).
static func retrato(npc: String) -> Texture2D:
	var caminho := "res://artes/personagens/%s.png" % npc
	if ResourceLoader.exists(caminho):
		var t := AtlasTexture.new()
		t.atlas = load(caminho)
		t.region = Rect2(0, 0, 48, 64)
		return t
	if Bestiario.CHEFES.has(npc):
		return Bestiario.miniatura(npc)
	return null

## Objetivo curto da missão (com o progresso, se houver contagem).
static func objetivo(id: String) -> String:
	var m: Dictionary = MISSOES[id]
	var t := TranslationServer.translate("MIS_%s_OBJ" % id.substr(1))
	if str(m["tipo"]) == "derrotar":
		t += " (%d/%d)" % [mini(progresso(id), int(m["qtd"])), int(m["qtd"])]
	return t

## "3/8" nas missões de contagem; "Em andamento" nas outras.
static func progresso_texto(id: String) -> String:
	var m: Dictionary = MISSOES[id]
	if str(m["tipo"]) == "derrotar":
		return "%d/%d" % [mini(progresso(id), int(m["qtd"])), int(m["qtd"])]
	if str(m["tipo"]) == "bestiario":
		# 0.8.3: mostra o que falta na ficha (vitórias, Veterano e Elite)
		var r: Dictionary = Bestiario.registro(str(m["alvo"]))
		var vs: Dictionary = r.get("versoes", {})
		var sim := TranslationServer.translate("SIM")
		var nao := TranslationServer.translate("NAO")
		return TranslationServer.translate("MIS_PROG_BESTIARIO") % [mini(int(r.get("vit", 0)), Bestiario.VITORIAS_REVELA),
			Bestiario.VITORIAS_REVELA, sim if vs.has("veterano") else nao, sim if vs.has("elite") else nao]
	return TranslationServer.translate("MIS_ATIVA")

## Fases que ajudam numa missão em andamento (para o ícone do mapa). Só as já vencidas.
static func fases_da_missao(id: String) -> Array:
	var m: Dictionary = MISSOES[id]
	var r: Array = []
	match str(m["tipo"]):
		"derrotar":
			var ate := mini(int(Jogo.dados.get("fase_atual", 1)) - 1, f(int(m["ato"]), 75))
			for fase in range(f(int(m["ato"]), 1), ate + 1):
				if _fase_tem(fase, str(m["alvo"])):
					r.append(fase)
		"rejogar", "desafio", "elite", "depois_chefe":
			r.append(int(m["fase"]))
	return r

static var _cache_fases := {}
static func _fase_tem(fase: int, especie: String) -> bool:
	var k := "%d_%s" % [fase, especie]
	if _cache_fases.has(k):
		return _cache_fases[k]
	var achou := false
	var enc: Dictionary = Encontros.gerar(fase)
	for onda: Array in enc["ondas"]:
		for spec: Dictionary in onda:
			if _especie(str(spec["sprite"])) == especie:
				achou = true
	_cache_fases[k] = achou
	return achou

static func _especie(sprite: String) -> String:
	return str(Bestiario.ficha(sprite).get("id", sprite))

## Missões em andamento ligadas a esta fase (para o popup da fase): [id, ...]
static func missoes_na_fase(fase: int) -> Array:
	var r: Array = []
	for id in ativas():
		if fase in fases_da_missao(id):
			r.append(id)
	return r

# ------------------------------------------------------------ fim de luta
## Uma fala para a DialogoHistoria: {"npc", "quem", "partes": [chaves ou textos], "el"}.
static func fala(npc: String, partes: Array) -> Dictionary:
	return {"npc": npc, "quem": nome_npc(npc), "partes": partes, "el": str(NPCS.get(npc, ""))}

static func fala_voz(partes: Array) -> Dictionary:
	return {"npc": "", "quem": "???", "partes": partes, "el": "voz"}

## Conta os inimigos derrotados nas missões de "derrotar" (vitória ou derrota, só nas fases do mapa).
static func contar(derrotados: Array) -> Array:
	var concluidas: Array = []
	for id in ativas():
		var m: Dictionary = MISSOES[id]
		if str(m["tipo"]) != "derrotar":
			continue
		var n := progresso(id)
		for l in derrotados:
			if _especie(str(l.sprite)) == str(m["alvo"]):
				n += 1
		if n >= int(m["qtd"]):
			_por(id, ESTADO_CONCLUIDA, int(m["qtd"]))
			concluidas.append(id)
		else:
			_por(id, ESTADO_ATIVA, n)
	return concluidas

## Fim de uma VITÓRIA numa fase do mapa. ctx: {"primeira": bool, "pocoes": int, "rodadas": int,
## "vida": 0–100, "derrotados": [Lutador]}. Atualiza as missões e devolve as falas, na ordem em que aparecem.
static func vitoria(fase: int, ctx: Dictionary) -> Array:
	var falas: Array = []
	var primeira: bool = ctx.get("primeira", false)
	var ato := clampi(int((fase - 1) / 75) + 1, 1, 4)
	var k := (fase - 1) % 75 + 1
	# 1) missões concluídas nesta luta (contagem, rejogar, desafio, Bestiário, Elite)
	var concluidas: Array = contar(ctx.get("derrotados", []))
	for id in ativas():
		var m: Dictionary = MISSOES[id]
		var ok := false
		match str(m["tipo"]):
			"rejogar", "elite", "depois_chefe":
				ok = fase == int(m["fase"])
			"desafio":
				ok = fase == int(m["fase"]) and _cumpriu(m, ctx)
			"bestiario":
				ok = ficha_completa(str(m["alvo"]))
		if ok:
			_por(id, ESTADO_CONCLUIDA, 1)
			concluidas.append(id)
	# 2) momento de história desta fase (1ª vitória)
	if primeira and MOMENTOS.has(fase) and not viu("h%d" % fase):
		marcar("h%d" % fase)
		falas.append(fala(MOMENTOS[fase], ["HIST_%d" % fase]))
	# 3) quem concluiu fala (e, se houver, já pede a próxima)
	falas.append_array(falas_de_conclusao(concluidas))
	# 4) missão que aparece nesta fase
	if primeira:
		for id: String in MISSOES:
			if int(MISSOES[id].get("aparece", 0)) == fase and estado(id) < 0:
				_por(id, ESTADO_ATIVA, 0)
				falas.append(_pedido(id))
	# 5) a Voz depois das Elites Supremas e do chefe; 6) fechamento do capítulo e a 2ª parte do NPC
	if primeira and k in [25, 50, 75] and not viu("v%d_%d" % [ato, k]):
		marcar("v%d_%d" % [ato, k])
		if not (ato == 4 and k == 75):       # no fim da temporada a Voz não fala: vem o fechamento do Cap. 4
			falas.append(fala_voz(["VOZ_%d_%d" % [ato, k]]))
		if k == 75:
			marcar("c%d" % ato)
			falas.append({"npc": "", "quem": "", "partes": ["FECH_%d" % ato], "el": "capitulo",
				"titulo": TranslationServer.translate("DIARIO_CAPITULO_N") % ato + " · " + TranslationServer.translate("DIARIO_CAP_%d" % ato)})
			for prox: String in MISSOES:
				if str(MISSOES[prox].get("apos", "")) == "chefe_%d" % ato and estado(prox) < 0:
					_por(prox, ESTADO_ATIVA, 0)
					falas.append(_pedido(prox))
			if ato == 1 and not viu("cena1"):
				Jogo.dados["cena_pendente"] = "crianca"     # a cutscene passa ao sair do resultado
	return falas

## Missões de Bestiário com a ficha já completa (0.8.3, pedido do João: a do Tobin não fechava pelo QR do Corvo Elite).
## A ficha também completa no QR e no Evento (o Elite de várias espécies só sai pelo QR), mas antes a missão só era
## conferida na vitória de uma fase do mapa. Chamado no fim da luta do QR/Evento e ao abrir o jogo. Devolve os ids concluídos.
static func conferir_bestiario() -> Array:
	var concluidas: Array = []
	for id in ativas():
		var m: Dictionary = MISSOES[id]
		if str(m["tipo"]) == "bestiario" and ficha_completa(str(m["alvo"])):
			_por(id, ESTADO_CONCLUIDA, 1)
			concluidas.append(id)
	return concluidas

## Fala de quem teve a missão concluída e, se houver, o pedido da próxima missão do mesmo NPC.
static func falas_de_conclusao(concluidas: Array) -> Array:
	var falas: Array = []
	for id in concluidas:
		var m: Dictionary = MISSOES[id]
		falas.append(fala(str(m["npc"]), ["MIS_%s_FIM" % id.substr(1), "MIS_CONCLUIDA"]))
		for prox: String in MISSOES:
			if str(MISSOES[prox].get("apos", "")) == id and estado(prox) < 0:
				_por(prox, ESTADO_ATIVA, 0)
				falas.append(_pedido(prox))
	return falas

static func _pedido(id: String) -> Dictionary:
	var m: Dictionary = MISSOES[id]
	return fala(str(m["npc"]), ["MIS_%s_PEDIDO" % id.substr(1), TranslationServer.translate("MIS_NOVA") % objetivo(id)])

static func _cumpriu(m: Dictionary, ctx: Dictionary) -> bool:
	match str(m.get("cond", "")):
		"sem_pocao":
			return int(ctx.get("pocoes", 0)) == 0
		"turnos":
			return int(ctx.get("rodadas", 999)) <= int(m.get("valor", 8))
		"vida":
			return int(ctx.get("vida", 0)) > int(m.get("valor", 50))
	return true

## Ficha do Bestiário completa (DEFINIDO): 3 vitórias, Veterano e Elite vencidos.
static func ficha_completa(especie: String) -> bool:
	var r: Dictionary = Bestiario.registro(especie)
	if r.is_empty():
		return false
	var vs: Dictionary = r.get("versoes", {})
	return int(r.get("vit", 0)) >= Bestiario.VITORIAS_REVELA and vs.has("veterano") and vs.has("elite")

const XP_MISSAO_ELITES := 2.0
static var ultima_barra: Dictionary = {}

## Recompensa (DEFINIDA): 150 moedas × fator, 5 a 10 fragmentos do elemento do NPC e 30% de chance de uma
## Poção de Vida I ou II. O fator é o do nível da fase onde a missão apareceu. Devolve as linhas do popup.
static func coletar(id: String) -> Array:
	if estado(id) != ESTADO_CONCLUIDA:
		return []
	var m: Dictionary = MISSOES[id]
	var base := int(m.get("aparece", m.get("fase", f(int(m["ato"]), 1))))
	var fat := Lutador.fator_de(Encontros.nivel_da_fase(base))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var moedas := int(round(150.0 * fat))
	var frag := rng.randi_range(5, 10)
	var el := str(NPCS.get(str(m["npc"]), "fogo"))
	Jogo.dados["moedas"] = int(Jogo.dados["moedas"]) + moedas
	# pedido do João (2026-11-24): a missão também dá XP. PROVISÓRIO: o de 2 Elites do nível da fase onde ela apareceu
	# (com a mesma regra de diferença de nível dos inimigos). ultima_barra guarda a barra para o popup.
	var nv := Encontros.nivel_da_fase(base)
	var xp := int(round(XP_MISSAO_ELITES * Catalogo.xp_de("elite", fat, nv, int(Jogo.dados["nivel"]))))
	var de := float(Jogo.dados["xp"]) / maxf(1.0, float(Jogo.xp_para(int(Jogo.dados["nivel"]))))
	var subiu := Jogo.ganhar_xp(xp)
	ultima_barra = {"nivel": int(Jogo.dados["nivel"]), "de": de, "subiu": subiu,
		"para": float(Jogo.dados["xp"]) / maxf(1.0, float(Jogo.xp_para(int(Jogo.dados["nivel"]))))}
	var fr: Dictionary = Jogo.dados["fragmentos"]
	fr[el] = int(fr.get(el, 0)) + frag
	var linhas: Array = [
		{"icone": PopupResultado.icone("xp"), "nome": TranslationServer.translate("RES_L_XP"), "valor": xp},
		{"icone": PopupResultado.icone("moeda"), "nome": TranslationServer.translate("RES_L_MOEDAS"), "valor": moedas},
		{"icone": PopupResultado.icone("fragmento"), "nome": TranslationServer.translate("RES_L_FRAG") % TranslationServer.translate("EL_" + el.to_upper()), "valor": frag},
	]
	if rng.randf() < 0.3:
		var p := "pocao_de_vida_i" if rng.randf() < 0.7 else "pocao_de_vida_ii"
		var pc: Dictionary = Jogo.dados["pocoes"]
		pc[p] = int(pc.get(p, 0)) + 1
		var nome_chave := "QR_POCAO_I" if p == "pocao_de_vida_i" else "QR_POCAO_II"
		linhas.append({"icone": CodigoQR._icone_pocao(p), "nome": TranslationServer.translate(nome_chave), "valor": 1, "pre": "x"})
	_por(id, ESTADO_COLETADA, progresso(id))
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	return linhas

# ------------------------------------------------------------ chefes (durante a luta)
## Fala do chefe ao entrar, aos 50% de Vida e ao cair (só na 1ª vez de cada uma). momento: entra|fase2|cai.
static func fala_chefe(chefe: String, momento: String) -> Dictionary:
	var chave := "b%s_%s" % [chefe.left(3), momento]
	if viu(chave):
		return {}
	marcar(chave)
	if chefe == "ysmera" and momento == "cai":
		return fala(chefe, ["CHEFE_YSMERA_CAI"])
	return fala(chefe, ["CHEFE_%s_%s" % [chefe.to_upper(), momento.to_upper()]])

# ------------------------------------------------------------ Diário
## Entradas do capítulo do ato (na ordem em que foram vistas): [texto, ...]
static func entradas_do_capitulo(ato: int) -> Array:
	var r: Array = []
	for chave: String in _hist():
		var t := _texto_da_entrada(chave, ato)
		if t != "":
			r.append(t)
	return r

static func _texto_da_entrada(chave: String, ato: int) -> String:
	var tr_ := func(k: String) -> String: return TranslationServer.translate(k)
	if chave.begins_with("h"):
		var fase := int(chave.substr(1))
		if clampi(int((fase - 1) / 75) + 1, 1, 4) != ato:
			return ""
		return nome_npc(MOMENTOS.get(fase, "")) + ": " + tr_.call("HIST_%d" % fase)
	if chave.begins_with("v%d_" % ato) and chave != "v4_75":
		return tr_.call("VOZ_%s" % chave.substr(1))
	if chave == "c%d" % ato:
		return tr_.call("FECH_%d" % ato)
	if chave == "cena1" and ato == 1:
		return tr_.call("CENA_CRIANCA_DIARIO")
	return ""

## O capítulo do ato está liberado quando o jogador chegou a ele.
static func capitulo_liberado(ato: int) -> bool:
	return int(Jogo.dados.get("fase_atual", 1)) > f(ato, 0) or viu("v%d_25" % ato)

## NPCs já conhecidos (para a aba Personagens): [npc, ...] na ordem do jogo.
static func npcs_conhecidos() -> Array:
	var r: Array = []
	for fase: int in MOMENTOS:
		var npc: String = MOMENTOS[fase]
		if viu("h%d" % fase) and NPCS.has(npc) and not r.has(npc):
			r.append(npc)
	for id in recebidas():
		var npc := str(MISSOES[id]["npc"])
		if not r.has(npc):
			r.append(npc)
	var ordem := NPCS.keys()
	r.sort_custom(func(a, b): return ordem.find(a) < ordem.find(b))
	return r

## O que o NPC já disse (linhas da ficha). Cresce a cada momento importante.
static func falas_do_npc(npc: String) -> Array:
	var r: Array = []
	for fase: int in MOMENTOS:
		if MOMENTOS[fase] == npc and viu("h%d" % fase):
			r.append(TranslationServer.translate("HIST_%d" % fase))
	for id in recebidas():
		if str(MISSOES[id]["npc"]) == npc and estado(id) >= ESTADO_CONCLUIDA:
			r.append(TranslationServer.translate("MIS_%s_FIM" % id.substr(1)))
	return r

## Onde o NPC apareceu pela primeira vez (fase da temporada).
static func onde_npc(npc: String) -> int:
	var menor := 999
	for fase: int in MOMENTOS:
		if MOMENTOS[fase] == npc and viu("h%d" % fase):
			menor = mini(menor, fase)
	for id in recebidas():
		var m: Dictionary = MISSOES[id]
		if str(m["npc"]) == npc and m.has("aparece"):
			menor = mini(menor, int(m["aparece"]))
	return menor if menor < 999 else 0
