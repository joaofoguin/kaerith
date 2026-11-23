class_name Catalogo
extends RefCounted
## Dados fixos do combate: habilidades, condições, modelos de atributos, tipos de inimigos e chefes.
## Nomes e efeitos vêm das abas aprovadas (Mobile · Habilidades / Inimigos / Poções / Chefes de ato).
## O que está marcado PROVISÓRIO foi decisão minha (delegação de números) e pode mudar.

const ELEMENTOS := ["fogo", "agua", "terra", "ar", "raio", "gelo"]

## Vantagem elemental (+25% para quem ataca, −25% no sentido contrário).
## Fogo→Gelo→Água→Fogo; Raio→Ar→Terra→Raio; Fogo→Raio.
const VANTAGEM := {"fogo": ["gelo", "raio"], "gelo": ["agua"], "agua": ["fogo"], "raio": ["ar"], "ar": ["terra"], "terra": ["raio"]}

## Modelos do jogador (F/P/A/Res/Ress, total 50) — APROVADOS.
const MODELO_JOGADOR := {
	"fogo": [12, 10, 7, 6, 15], "agua": [6, 10, 10, 11, 13], "terra": [11, 7, 7, 15, 10],
	"ar": [8, 10, 15, 6, 11], "raio": [10, 12, 12, 5, 11], "gelo": [8, 14, 7, 9, 12],
	"": [10, 10, 10, 10, 10],   # antes do Despertar (tutorial): PROVISÓRIO, modelo neutro
}
## Habilidades de elemento do Despertar (ofensiva, defensiva, utilitária).
const DESPERTAR := {
	"fogo": ["explosao_de_chamas", "manto_de_brasas", "centelha_teimosa"],
	"agua": ["lamina_de_mare", "veu_da_correnteza", "fluxo_restaurador"],
	"terra": ["punho_de_rocha", "pele_de_granito", "raizes_firmes"],
	"ar": ["corte_de_vento", "passo_de_pluma", "rajada_desviante"],
	"raio": ["faisca_veloz", "campo_estatico", "interrupcao"],
	"gelo": ["estilhaco_gelido", "carapaca_de_geada", "sopro_do_inverno"],
}

## PROVISÓRIO (delegação): modelo de 50 pontos de cada papel de inimigo (F/P/A/Res/Ress).
const MODELO_PAPEL := {
	"rapido": [9, 11, 15, 6, 9], "resistente": [12, 6, 5, 16, 11], "controle": [8, 11, 12, 8, 11],
	"atacante": [11, 10, 10, 8, 11], "suporte": [6, 10, 9, 11, 14], "pressionador": [10, 14, 11, 5, 10],
	"fragil": [9, 11, 16, 4, 10], "restricao": [8, 12, 10, 9, 11], "enfraquecimento": [7, 12, 9, 9, 13],
	"chefe": [11, 11, 10, 8, 10],
}

## Multiplicadores de Vida / dano por categoria. Rebalanceados em 2026-11-13 (pedido do João) com o simulador
## (ferramentas/simulador_combate): comuns dão dano sem matar; Elite/Suprema/chefe podem levar ao vídeo de continuar.
## PROVISÓRIOS. Antes: comum 1/1, veterano 1,5/1,1, Elite 2/1,25, Suprema 2,5/1,3, chefe 3/1,4.
const MULT := {"comum": [0.65, 0.85], "veterano": [0.975, 0.935], "elite": [1.0, 0.8], "suprema": [1.2, 0.75], "chefe": [1.1, 0.65]}
## XP e moedas por inimigo (× fator). Suprema: PROVISÓRIO (entre Elite e Chefe).
const XP := {"comum": 40, "veterano": 60, "elite": 100, "suprema": 150, "chefe": 250}
const MOEDAS := {"comum": 10, "veterano": 15, "elite": 25, "suprema": 40, "chefe": 60}

const USOS := {"ofensiva": 3, "defensiva": 2, "utilitaria": 2, "combinada": 2}

## Condições. pos = positiva (limite de 2 positivas + 2 negativas por alvo; não reaplica).
const CONDICOES := {
	"queimadura": {"pos": false, "icone": "res://artes/interface/condicao16_queimadura.png"},
	"encharcado": {"pos": false, "icone": "res://artes/combate/condicao16_encharcado.png"},
	"lentidao": {"pos": false, "icone": "res://artes/interface/condicao16_lentidao.png"},
	"enfraquecido": {"pos": false, "icone": "res://artes/combate/condicao16_enfraquecido.png"},
	"atordoado": {"pos": false, "icone": "res://artes/interface/condicao16_atordoado.png"},
	"congelado": {"pos": false, "icone": "res://artes/combate/condicao16_congelado.png"},
	"marcado": {"pos": false, "icone": "res://artes/combate/condicao16_marcado.png"},
	"escudo": {"pos": true, "icone": "res://artes/interface/condicao16_escudo.png"},
	"furia": {"pos": true, "icone": "res://artes/combate/condicao16_furia.png"},
	"fortificado": {"pos": true, "icone": "res://artes/combate/condicao16_fortificado.png"},
	"impeto": {"pos": true, "icone": "res://artes/combate/condicao16_impeto.png"},
	"regeneracao": {"pos": true, "icone": "res://artes/interface/condicao16_regenera.png"},
	"firmeza": {"pos": true, "icone": "res://artes/combate/condicao16_firmeza.png"},
	"campo": {"pos": true, "icone": "res://artes/combate/condicao16_campo.png"},
	"sobrecarga": {"pos": true, "icone": "res://artes/combate/condicao16_sobrecarga.png"},
	# marcas de turno (não contam no limite; só aparecem como ícone)
	"guarda": {"pos": true, "icone": "res://artes/combate/condicao16_guarda.png"},
	"contragolpe": {"pos": true, "icone": "res://artes/combate/condicao16_contragolpe.png"},
	"exposto": {"pos": false, "icone": "res://artes/combate/condicao16_exposto.png"},
	# temporárias das poções (contam no limite de positivas)
	"p_reflexo": {"pos": true, "icone": "res://artes/combate/condicao16_impeto.png"},
	"p_sangue": {"pos": true, "icone": "res://artes/combate/condicao16_furia.png"},
	"p_granito": {"pos": true, "icone": "res://artes/combate/condicao16_fortificado.png"},
	"p_falcao": {"pos": true, "icone": "res://artes/interface/condicao16_forca_mais.png"},
	"p_ressonancia": {"pos": true, "icone": "res://artes/interface/condicao16_forca_mais.png"},
}

## Habilidades. cat: comum/ofensiva/defensiva/utilitaria/especial. alvo: inimigo/inimigos/si/aliado/aliados.
## base: F (Força) ou R (Ressonância). poder em %. Campos opcionais: golpes, prio, certeiro, crit, dreno,
## cond (no alvo), cond_si, escudo (% da Ress.), reflexo, cura (% Vida máx.), bonus {cond: +%}, consome, extra.
const HAB := {
	# --- ataques comuns
	"golpe": {"nome": "Golpe", "cat": "comum", "el": "", "alvo": "inimigo", "base": "F", "poder": 200},
	"golpe_rapido": {"nome": "Golpe Rápido", "cat": "comum", "el": "", "alvo": "inimigo", "base": "F", "poder": 140, "prio": true},
	"varredura": {"nome": "Varredura", "cat": "comum", "el": "", "alvo": "inimigos", "base": "F", "poder": 100},   # João (2026-11-22): era 120%
	"guarda": {"nome": "Guarda", "cat": "comum", "el": "", "alvo": "si", "extra": "guarda"},
	"golpe_duplo": {"nome": "Golpe Duplo", "cat": "comum", "el": "", "alvo": "inimigo", "base": "F", "poder": 110, "golpes": 2},
	"investida": {"nome": "Investida", "cat": "comum", "el": "", "alvo": "inimigo", "base": "F", "poder": 220, "extra": "exposto"},
	"contragolpe": {"nome": "Contragolpe", "cat": "comum", "el": "", "alvo": "si", "extra": "contragolpe"},
	"golpe_certeiro": {"nome": "Golpe Certeiro", "cat": "comum", "el": "", "alvo": "inimigo", "base": "F", "poder": 170, "certeiro": true, "crit": 0.20},
	"golpe_drenante": {"nome": "Golpe Drenante", "cat": "comum", "el": "", "alvo": "inimigo", "base": "F", "poder": 130, "dreno": 0.30},
	"rasteira": {"nome": "Rasteira", "cat": "comum", "el": "", "alvo": "inimigo", "base": "F", "poder": 100, "cond": "lentidao"},
	# --- Fogo
	"explosao_de_chamas": {"nome": "Explosão de Chamas", "cat": "ofensiva", "el": "fogo", "alvo": "inimigo", "base": "R", "poder": 250},
	"manto_de_brasas": {"nome": "Manto de Brasas", "cat": "defensiva", "el": "fogo", "alvo": "si", "escudo": 150, "reflexo": "queimadura"},
	"centelha_teimosa": {"nome": "Centelha Teimosa", "cat": "utilitaria", "el": "fogo", "alvo": "inimigo", "base": "R", "poder": 100, "cond": "queimadura"},
	"chuva_de_cinzas": {"nome": "Chuva de Cinzas", "cat": "ofensiva", "el": "fogo", "alvo": "inimigos", "base": "R", "poder": 160},
	"coracao_em_brasa": {"nome": "Coração em Brasa", "cat": "utilitaria", "el": "fogo", "alvo": "si", "cond_si": "furia"},
	"detonacao": {"nome": "Detonação", "cat": "ofensiva", "el": "fogo", "alvo": "inimigo", "base": "R", "poder": 300, "bonus": {"queimadura": 50}, "consome": "queimadura"},
	# --- Água
	"lamina_de_mare": {"nome": "Lâmina de Maré", "cat": "ofensiva", "el": "agua", "alvo": "inimigo", "base": "R", "poder": 220, "cond": "encharcado"},
	"veu_da_correnteza": {"nome": "Véu da Correnteza", "cat": "defensiva", "el": "agua", "alvo": "si", "cura": 35, "cond_si": "regeneracao"},
	"fluxo_restaurador": {"nome": "Fluxo Restaurador", "cat": "utilitaria", "el": "agua", "alvo": "aliado", "extra": "purifica1", "cond_si": "fortificado"},
	"onda_partida": {"nome": "Onda Partida", "cat": "ofensiva", "el": "agua", "alvo": "inimigos", "base": "R", "poder": 150, "bonus": {"encharcado": 25}},
	"fonte_serena": {"nome": "Fonte Serena", "cat": "utilitaria", "el": "agua", "alvo": "aliados", "cura": 25},
	"redemoinho": {"nome": "Redemoinho", "cat": "utilitaria", "el": "agua", "alvo": "inimigo", "base": "R", "poder": 120, "cond": "lentidao"},
	# --- Terra
	"punho_de_rocha": {"nome": "Punho de Rocha", "cat": "ofensiva", "el": "terra", "alvo": "inimigo", "base": "R", "poder": 230, "extra": "punho"},
	"pele_de_granito": {"nome": "Pele de Granito", "cat": "defensiva", "el": "terra", "alvo": "si", "cond_si": "fortificado"},
	"raizes_firmes": {"nome": "Raízes Firmes", "cat": "utilitaria", "el": "terra", "alvo": "si", "cond_si": "firmeza"},
	"tremor": {"nome": "Tremor", "cat": "ofensiva", "el": "terra", "alvo": "inimigos", "base": "R", "poder": 140, "cond": "atordoado"},
	"muralha_viva": {"nome": "Muralha Viva", "cat": "defensiva", "el": "terra", "alvo": "aliados", "escudo": 120},
	"sentenca_da_montanha": {"nome": "Sentença da Montanha", "cat": "ofensiva", "el": "terra", "alvo": "inimigo", "base": "R", "poder": 150, "extra": "sentenca"},
	# --- Ar
	"corte_de_vento": {"nome": "Corte de Vento", "cat": "ofensiva", "el": "ar", "alvo": "inimigo", "base": "R", "poder": 200, "prio": true},
	"passo_de_pluma": {"nome": "Passo de Pluma", "cat": "defensiva", "el": "ar", "alvo": "si", "cond_si": "impeto", "extra": "pluma"},
	"rajada_desviante": {"nome": "Rajada Desviante", "cat": "utilitaria", "el": "ar", "alvo": "inimigo", "base": "R", "poder": 80, "cond": "lentidao"},
	"ciclone": {"nome": "Ciclone", "cat": "ofensiva", "el": "ar", "alvo": "inimigos", "base": "R", "poder": 140, "extra": "tira_positivo"},
	"sopro_renovador": {"nome": "Sopro Renovador", "cat": "utilitaria", "el": "ar", "alvo": "si", "extra": "devolve_uso"},
	"olho_da_tempestade": {"nome": "Olho da Tempestade", "cat": "ofensiva", "el": "ar", "alvo": "inimigo", "base": "R", "poder": 90, "golpes": 3},
	# --- Raio
	"faisca_veloz": {"nome": "Faísca Veloz", "cat": "ofensiva", "el": "raio", "alvo": "inimigo", "base": "R", "poder": 210, "crit": 0.15},
	"campo_estatico": {"nome": "Campo Estático", "cat": "defensiva", "el": "raio", "alvo": "si", "cond_si": "campo"},
	"interrupcao": {"nome": "Interrupção", "cat": "utilitaria", "el": "raio", "alvo": "inimigo", "base": "R", "poder": 100, "extra": "interrompe"},
	"corrente_em_cadeia": {"nome": "Corrente em Cadeia", "cat": "ofensiva", "el": "raio", "alvo": "inimigo", "base": "R", "poder": 180, "extra": "cadeia"},
	"sobrecarga": {"nome": "Sobrecarga", "cat": "utilitaria", "el": "raio", "alvo": "si", "cond_si": "sobrecarga"},
	"trovao_cativo": {"nome": "Trovão Cativo", "cat": "ofensiva", "el": "raio", "alvo": "inimigo", "base": "R", "poder": 280, "extra": "crit_atordoa"},
	# --- Gelo
	"estilhaco_gelido": {"nome": "Estilhaço Gélido", "cat": "ofensiva", "el": "gelo", "alvo": "inimigo", "base": "R", "poder": 210, "cond": "lentidao"},
	"carapaca_de_geada": {"nome": "Carapaça de Geada", "cat": "defensiva", "el": "gelo", "alvo": "si", "escudo": 130, "reflexo": "lentidao"},
	"sopro_do_inverno": {"nome": "Sopro do Inverno", "cat": "utilitaria", "el": "gelo", "alvo": "inimigo", "base": "R", "poder": 80, "cond": "enfraquecido"},
	"nevasca": {"nome": "Nevasca", "cat": "ofensiva", "el": "gelo", "alvo": "inimigos", "base": "R", "poder": 130, "cond": "lentidao"},
	"prisao_de_cristal": {"nome": "Prisão de Cristal", "cat": "utilitaria", "el": "gelo", "alvo": "inimigo", "cond": "congelado"},
	"lanca_polar": {"nome": "Lança Polar", "cat": "ofensiva", "el": "gelo", "alvo": "inimigo", "base": "R", "poder": 240, "bonus": {"lentidao": 40, "congelado": 40}},
	# --- próprias dos chefes (aba Temporada 1 · Chefes de ato)
	"chamado_do_bando": {"nome": "Chamado do Bando", "cat": "especial", "el": "ar", "alvo": "si", "extra": "invoca", "invoca": "batedor_comum"},
	"brotar": {"nome": "Brotar", "cat": "especial", "el": "terra", "alvo": "si", "extra": "invoca", "invoca": "brotado_comum"},
	"marca_de_caca": {"nome": "Marca de Caça", "cat": "especial", "el": "raio", "alvo": "inimigo", "cond": "marcado"},
	"chamar_atirador": {"nome": "Contrato de Gelo", "cat": "especial", "el": "raio", "alvo": "si", "extra": "invoca", "invoca": "atirador_geada_comum"},
	"ecos_mudos": {"nome": "Ecos Mudos", "cat": "especial", "el": "gelo", "alvo": "si", "extra": "invoca", "invoca": "eco_mudo_comum"},
	"silencio_absoluto": {"nome": "Silêncio Absoluto", "cat": "especial", "el": "gelo", "alvo": "inimigos", "cond": "congelado"},
	# PROVISÓRIO: o efeito do Coração de Inverno não estava definido (Fortificado + Regeneração).
	"coracao_de_inverno": {"nome": "Coração de Inverno", "cat": "especial", "el": "gelo", "alvo": "si", "cond_si": "fortificado", "cond_si2": "regeneracao"},
}

## Lebre: "Golpe Rápido + 1 habilidade do elemento da variante" — PROVISÓRIO (a de cada variante).
const HAB_LEBRE := {"fogo": "centelha_teimosa", "agua": "redemoinho", "raio": "faisca_veloz", "gelo": "estilhaco_gelido"}

## Tipos de inimigo: família, papel e habilidades [Comum (2), + Veterano, + Elite] — aba Mobile · Inimigos.
const TIPOS := {
	"batedor": {"fam": "bandidos", "papel": "rapido", "hab": ["golpe_rapido", "rasteira", "golpe_certeiro", "golpe_duplo"]},
	"brutamontes": {"fam": "bandidos", "papel": "resistente", "hab": ["investida", "guarda", "contragolpe", "golpe_drenante"]},
	"contrabandista": {"fam": "bandidos", "papel": "controle", "hab": ["golpe", "rajada_desviante", "passo_de_pluma", "ciclone"]},
	"incendiaria": {"fam": "bandidos", "papel": "atacante", "hab": ["golpe", "centelha_teimosa", "chuva_de_cinzas", "detonacao"]},
	"curandeiro": {"fam": "bandidos", "papel": "suporte", "hab": ["golpe_drenante", "fonte_serena", "fluxo_restaurador", "veu_da_correnteza"]},
	"rastreador": {"fam": "bandidos", "papel": "pressionador", "hab": ["golpe_certeiro", "interrupcao", "sobrecarga", "trovao_cativo"]},
	"javali": {"fam": "locais", "papel": "atacante", "hab": ["investida", "punho_de_rocha", "tremor", "pele_de_granito"]},
	"lebre": {"fam": "locais", "papel": "fragil", "hab": ["golpe_rapido", "*lebre", "golpe_duplo", "passo_de_pluma"]},
	"corvo": {"fam": "locais", "papel": "controle", "hab": ["golpe", "rajada_desviante", "corte_de_vento", "ciclone"]},
	"cobra": {"fam": "locais", "papel": "restricao", "hab": ["rasteira", "redemoinho", "lamina_de_mare", "onda_partida"]},
	"urso_de_barranco": {"fam": "locais", "papel": "resistente", "hab": ["investida", "pele_de_granito", "muralha_viva", "sentenca_da_montanha"]},
	"cervo": {"fam": "anomalas", "papel": "atacante", "hab": ["golpe_certeiro", "faisca_veloz", "corrente_em_cadeia", "trovao_cativo"]},
	"lodo": {"fam": "anomalas", "papel": "suporte", "hab": ["golpe_drenante", "lamina_de_mare", "redemoinho", "onda_partida"]},
	"abutre": {"fam": "anomalas", "papel": "atacante", "hab": ["golpe", "centelha_teimosa", "chuva_de_cinzas", "detonacao"]},
	"brotado": {"fam": "anomalas", "papel": "resistente", "hab": ["guarda", "pele_de_granito", "raizes_firmes", "sentenca_da_montanha"]},
	"galgo": {"fam": "anomalas", "papel": "fragil", "hab": ["golpe_rapido", "corte_de_vento", "rajada_desviante", "olho_da_tempestade"]},
	"mariposa": {"fam": "anomalas", "papel": "controle", "hab": ["golpe", "interrupcao", "campo_estatico", "sobrecarga"]},
	"besta_sem_nome": {"fam": "anomalas", "papel": "resistente", "hab": ["investida", "tremor", "muralha_viva", "sentenca_da_montanha"]},
	"arminho_geada": {"fam": "glaciais", "papel": "fragil", "hab": ["golpe_rapido", "sopro_do_inverno", "estilhaco_gelido", "nevasca"]},
	"lobo_geada": {"fam": "glaciais", "papel": "restricao", "hab": ["golpe_rapido", "estilhaco_gelido", "carapaca_de_geada", "lanca_polar"]},
	"verme_geada": {"fam": "glaciais", "papel": "atacante", "hab": ["investida", "estilhaco_gelido", "nevasca", "lanca_polar"]},
	"mamute_glacial": {"fam": "glaciais", "papel": "resistente", "hab": ["guarda", "carapaca_de_geada", "contragolpe", "prisao_de_cristal"]},
	"eco_mudo": {"fam": "glaciais", "papel": "enfraquecimento", "hab": ["golpe", "sopro_do_inverno", "prisao_de_cristal", "nevasca"]},
	"soldado_geada": {"fam": "soldados", "papel": "atacante", "hab": ["golpe", "estilhaco_gelido", "golpe_duplo", "lanca_polar"]},
	"escudeiro_gelo": {"fam": "soldados", "papel": "resistente", "hab": ["guarda", "carapaca_de_geada", "contragolpe", "prisao_de_cristal"]},
	"atirador_geada": {"fam": "soldados", "papel": "pressionador", "hab": ["golpe_certeiro", "estilhaco_gelido", "interrupcao", "lanca_polar"]},
	"tecelao_geada": {"fam": "soldados", "papel": "controle", "hab": ["golpe", "sopro_do_inverno", "prisao_de_cristal", "nevasca"]},
	# --- chefes de ato (Chefe ×3 / ×1,4)
	"mestre_calder": {"fam": "chefe", "papel": "chefe", "hab": ["golpe_certeiro", "rajada_desviante", "ciclone"], "fase2": ["passo_de_pluma"], "propria": "chamado_do_bando", "a_cada": 3},
	"semeadora_velada": {"fam": "chefe", "papel": "chefe", "hab": ["raizes_firmes", "muralha_viva", "sentenca_da_montanha"], "fase2": ["tremor"], "propria": "brotar", "a_cada": 2},
	"thessa_vurn": {"fam": "chefe", "papel": "chefe", "hab": ["faisca_veloz", "interrupcao", "trovao_cativo"], "propria": "marca_de_caca", "a_cada": 3},
	"ysmera": {"fam": "chefe", "papel": "chefe", "hab": ["estilhaco_gelido", "nevasca"], "fase2": ["lanca_polar", "coracao_de_inverno"], "propria": "ecos_mudos", "a_cada": 3},
}

## Supremas: versão Elite reforçada de um tipo (sprite próprio).
const SUPREMAS := {
	"presa_mestra": "javali", "capitao_de_estrada": "batedor", "rei_da_galhada": "cervo", "besta_sem_nome": "besta_sem_nome",
	"cacador_de_recompensas": "rastreador", "olho_de_ysmera": "atirador_geada", "alfa_da_ultima_geada": "lobo_geada", "bastiao_do_selo": "escudeiro_gelo",
}

## Sprite → tipo (variantes regionais das feras locais usam o mesmo tipo).
static func tipo_do_sprite(prefixo: String) -> String:
	for t in ["javali", "lebre"]:
		if prefixo.begins_with(t):
			return t
	return prefixo

static func nome_hab(id: String) -> String:
	return HAB.get(id, {}).get("nome", id)

static func vantagem(atacante: String, defensor: String) -> float:
	if atacante == "" or defensor == "":
		return 1.0
	if defensor in VANTAGEM.get(atacante, []):
		return 1.25
	if atacante in VANTAGEM.get(defensor, []):
		return 0.75
	return 1.0

## Descrição curta da habilidade montada a partir dos dados (PT/EN pelas chaves DESC_*).
static func descrever(id: String) -> String:
	var h: Dictionary = HAB[id]
	var partes: Array = []
	if h.has("poder"):
		var attr := _t("ATR_FORCA" if h.get("base", "F") == "F" else "ATR_RESSONANCIA")
		var alvo := _t("DESC_TODOS" if h["alvo"] == "inimigos" else "DESC_UM")
		if int(h.get("golpes", 1)) > 1:
			partes.append(_t("DESC_GOLPES") % [int(h["golpes"]), int(h["poder"]), attr, alvo])
		else:
			partes.append(_t("DESC_DANO") % [int(h["poder"]), attr, alvo])
	if h.get("prio", false):
		partes.append(_t("DESC_PRIO"))
	if h.get("certeiro", false):
		partes.append(_t("DESC_CERTEIRO"))
	if h.has("crit"):
		partes.append(_t("DESC_CRIT") % int(round(float(h["crit"]) * 100)))
	if h.has("dreno"):
		partes.append(_t("DESC_DRENO") % int(round(float(h["dreno"]) * 100)))
	if h.has("cond"):
		partes.append(_t("DESC_COND") % _t("COND_" + str(h["cond"]).to_upper()))
	if h.has("escudo"):
		partes.append(_t("DESC_ESCUDO") % int(h["escudo"]))
	if h.has("cura"):
		partes.append(_t("DESC_CURA") % int(h["cura"]))
	if h.has("cond_si"):
		partes.append(_t("DESC_COND_SI") % _t("COND_" + str(h["cond_si"]).to_upper()))
	if h.has("reflexo"):
		partes.append(_t("DESC_REFLEXO") % _t("COND_" + str(h["reflexo"]).to_upper()))
	for c in h.get("bonus", {}):
		partes.append(_t("DESC_BONUS") % [int(h["bonus"][c]), _t("COND_" + str(c).to_upper())])
	if h.has("extra") and h["extra"] != "invoca":
		partes.append(_t("DESC_X_" + str(h["extra"]).to_upper()))
	if h["alvo"] == "aliados" and not h.has("poder"):
		partes.append(_t("DESC_ALIADOS"))
	var t := ", ".join(partes)
	return t.substr(0, 1).to_upper() + t.substr(1) + "."

## Função de cada elemento (aba Mobile · Habilidades), para a escolha no Despertar.
static func funcao_elemento(e: String) -> String:
	return _t("FUNCAO_" + e.to_upper())

static func _t(chave: String) -> String:
	return String(TranslationServer.translate(chave))
