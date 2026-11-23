extends Node
## Estado global do jogo e salvamento local (offline).
## Por enquanto guarda só o básico; cada etapa vai acrescentando campos.

const ARQUIVO_SAVE := "user://save.json"
const ARQUIVO_TEMP := "user://save.tmp"
const ARQUIVO_BACKUP := "user://save.bak"
const VERSAO_SAVE := 3

signal idioma_mudou
signal progresso_mudou
signal tique                       # a cada segundo (relógios das vidas, do Evento etc.)

var dados := {
	"versao": 1,
	"idioma": "pt",
	"fase_atual": 1,
	"nivel": 1,
	"xp": 0,
	"moedas": 0,
	"cristais": 0,
	"vidas": 5,
	# criação: prologo → login → criacao → chegada → tutorial1 → tutorial2 → pronto
	"etapa": "prologo",
	"nome": "",
	"visual": {"corpo": 1, "pele": 3, "cabelo": "curto", "barba": "", "pelos": "Castanho"},
	"elemento": "",
	"habilidades": [],
	"pocoes": {},
	"fragmentos": {},
	"orbes": {},                   # elemento → nível do Orbe (o do elemento base vem no Despertar)
	"melhorias": {},               # habilidade → quantas vezes foi melhorada pelos Orbes
	"orbe_pendente": "",           # elemento com escolha de habilidade em aberto
	"vitorias": {},
	"equipamentos": [],
	"equipado": {},
	"prox_uid": 1,
	"vidas_desde": 0,              # quando começou a contar a próxima vida (0 = vidas cheias)
	"bestiario": {},               # espécie → {"vit", "versoes": {categoria: vitórias}, "novo"}
	"personagens": {},             # chefe → {"onde", "novo"}
}

var _padrao := {}

const COMUNS_INICIAIS := ["golpe", "guarda", "golpe_rapido", "varredura"]

## Versão ADM (com todos os botões de teste) ou pública (para os jogadores, sem nenhum botão de teste).
## Pedido do João (2026-11-22). É ADM: o jogo rodando pelo editor do Godot (F5/F6) e as exportações pelos presets
## com o recurso personalizado "adm" ("Android ADM" e "Web ADM" em export_presets.cfg). Os presets "Android" e
## "Web" (públicos) não têm o recurso, então lá adm() é falso.
func adm() -> bool:
	return OS.has_feature("editor") or OS.has_feature("adm")

## Site do jogo (Firebase Hosting): suporte, privacidade e termos ficam em hospedagem/paginas/.
const SITE := "https://kaerith-d9bef.web.app"

## Abre uma página do site (no navegador; na Web, numa aba nova).
func abrir_site(pagina: String) -> void:
	OS.shell_open(SITE + "/" + pagina)

## Número da versão para mostrar (Projeto > Configurações > Aplicação > Config > Versão), com "ADM" na de testes.
## Histórico das versões: CHANGELOG.md na pasta do projeto.
func versao() -> String:
	var v := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	return v + (" ADM" if adm() else "")

func _ready() -> void:
	if OS.has_feature("web"):
		# no navegador a área da página quase nunca é múltiplo exato de 360×640; com a escala inteira o que
		# sobrava virava borda preta em volta do jogo. Na Web a escala pode ser quebrada (no APK continua inteira).
		get_tree().root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	_padrao = dados.duplicate(true)
	carregar()
	TranslationServer.set_locale(dados["idioma"])
	preload("res://scripts/config.gd").aplicar()
	Vidas.atualizar()                # vidas que voltaram com o jogo fechado
	var relogio := Timer.new()
	relogio.wait_time = 1.0
	relogio.autostart = true
	relogio.timeout.connect(_tique)
	add_child(relogio)

func _tique() -> void:
	if Vidas.atualizar() > 0:
		salvar()
		progresso_mudou.emit()
	tique.emit()

## Salva ao sair, ao minimizar ou ao trocar de app (no celular o sistema pode fechar o jogo sem aviso).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if not _padrao.is_empty():
				salvar()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if not _padrao.is_empty():
				_tique()

## Lê o save. Se o arquivo principal estiver estragado (falta de energia no meio do salvamento etc.),
## usa a cópia de segurança. Saves antigos, sem conferência, continuam valendo.
func carregar() -> void:
	var lido := {}
	for arq in [ARQUIVO_SAVE, ARQUIVO_BACKUP, ARQUIVO_TEMP]:
		lido = _ler_arquivo(arq)
		if not lido.is_empty():
			if arq != ARQUIVO_SAVE:
				push_warning("Save principal estragado; usando " + arq)
			break
	_usar(lido)

## Põe um save lido (do arquivo ou da nuvem) por cima dos valores padrão e ajusta o que for antigo.
func _usar(lido: Dictionary) -> void:
	for k in lido:
		dados[k] = lido[k]
	_migrar()
	# enquanto a criação não terminou, o herói não tem elemento (saves de teste antigos tinham)
	if str(dados.get("etapa", "prologo")) != "pronto":
		dados["elemento"] = ""
		dados["habilidades"] = []

	if int(dados["nivel"]) < 1:
		dados["nivel"] = 1           # o jogo começa no nível 1 (o tutorial leva ao 2)

## Arquivo: 1ª linha "#<sha256 do resto>", depois o JSON. Devolve {} se faltar, estiver incompleto ou alterado.
func _ler_arquivo(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):
		return {}
	var f := FileAccess.open(caminho, FileAccess.READ)
	if f == null:
		return {}
	var texto := f.get_as_text()
	f.close()
	if texto.begins_with("#"):
		var quebra := texto.find("\n")
		if quebra < 0:
			return {}
		var conferir := texto.substr(1, quebra - 1)
		texto = texto.substr(quebra + 1)
		if texto.sha256_text() != conferir:
			return {}
	var lido = JSON.parse_string(texto)
	if typeof(lido) != TYPE_DICTIONARY:
		return {}
	return lido

## Ajusta saves de versões antigas.
func _migrar() -> void:
	if int(dados.get("versao", 1)) < 2:
		# versão 2 (etapa 8): relógio das vidas; quem tinha menos de 5 começa a contar agora
		if int(dados["vidas"]) < Vidas.MAX:
			dados["vidas_desde"] = int(Time.get_unix_time_from_system())
	if int(dados.get("versao", 1)) < 3:
		# versão 3 (2026-11-13): o jogo passou a começar no nível 1 em vez do 3; a curva é a mesma,
		# só os números descem 2 (o XP guardado continua valendo para o mesmo trecho da curva)
		dados["nivel"] = maxi(1, int(dados.get("nivel", 3)) - 2)
	dados["versao"] = VERSAO_SAVE

## Salva sem risco de perder tudo: escreve num arquivo temporário, guarda o anterior como cópia
## de segurança e só então troca.
func salvar() -> void:
	dados["versao"] = VERSAO_SAVE
	dados["salvo_em"] = int(Time.get_unix_time_from_system())
	var json := JSON.stringify(dados, "\t")
	var f := FileAccess.open(ARQUIVO_TEMP, FileAccess.WRITE)
	if f == null:
		push_error("Não consegui salvar: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string("#" + json.sha256_text() + "\n" + json)
	f.close()
	var temp := ProjectSettings.globalize_path(ARQUIVO_TEMP)
	var principal := ProjectSettings.globalize_path(ARQUIVO_SAVE)
	var copia := ProjectSettings.globalize_path(ARQUIVO_BACKUP)
	if FileAccess.file_exists(ARQUIVO_SAVE):
		if FileAccess.file_exists(ARQUIVO_BACKUP):
			DirAccess.remove_absolute(copia)
		DirAccess.rename_absolute(principal, copia)
	if DirAccess.rename_absolute(temp, principal) != OK:
		push_error("Não consegui trocar o save; ele continua em save.tmp")

## Troca todo o progresso pelo que veio da nuvem (login com Google em outro aparelho).
func aplicar_save(lido: Dictionary) -> void:
	dados = _padrao.duplicate(true)
	_usar(lido)
	TranslationServer.set_locale(str(dados["idioma"]))
	Vidas.atualizar()

func trocar_idioma(codigo: String) -> void:
	dados["idioma"] = codigo
	TranslationServer.set_locale(codigo)
	salvar()
	idioma_mudou.emit()

## Habilidades equipadas (4 espaços). Padrão de teste: 3 comuns + a ofensiva do elemento.
func habilidades() -> Array:
	var h: Array = dados.get("habilidades", [])
	if h.size() == 4:
		return h
	if str(dados["elemento"]) == "":
		return COMUNS_INICIAIS.duplicate()   # os 4 comuns do tutorial
	return ["golpe", "golpe_rapido", "varredura", Catalogo.DESPERTAR[dados["elemento"]][0]]

## Habilidades que o herói conhece: os 4 comuns do tutorial, as equipadas e as guardadas
## (DEFINIDO: a habilidade substituída vai para o inventário de habilidades; a combinada substituída se perde).
func habilidades_conhecidas() -> Array:
	var r: Array = []
	var despertar: Array = Catalogo.DESPERTAR.get(str(dados["elemento"]), [])
	for h in COMUNS_INICIAIS + habilidades() + despertar + Array(dados.get("hab_guardadas", [])):
		if not r.has(h) and Catalogo.HAB.has(h):
			r.append(h)
	return r

## DEFINIDO: nos 4 espaços, no máximo 1 habilidade do 2º elemento ou combinada.
func _de_fora(h: String) -> bool:
	var H: Dictionary = Catalogo.HAB.get(h, {})
	var el := str(H.get("el", ""))
	return str(H.get("cat", "")) == "combinada" or (el != "" and el != str(dados["elemento"]))

## Põe a habilidade "nova" no espaço i (0–3). Se ela já estava equipada, as duas trocam de lugar.
## Devolve "" se deu certo ou a chave do aviso.
func trocar_habilidade(i: int, nova: String) -> String:
	var h: Array = habilidades().duplicate()
	var antiga: String = h[i]
	if antiga == nova:
		return ""
	var j := h.find(nova)
	if j >= 0:
		h[j] = antiga
		h[i] = nova
	else:
		var fora := 0
		for k in h.size():
			if k != i and _de_fora(h[k]):
				fora += 1
		if _de_fora(nova) and fora >= 1:
			return "HAB_LIMITE_FORA"
		h[i] = nova
		var g: Array = dados.get("hab_guardadas", [])
		g.erase(nova)
		if str(Catalogo.HAB[antiga].get("cat", "")) != "combinada" and not g.has(antiga):
			g.append(antiga)
		dados["hab_guardadas"] = g
	dados["habilidades"] = h
	salvar()
	progresso_mudou.emit()
	return ""

## XP para ir do nível n ao n+1 = 100 × n^1,5 (PROVISÓRIO: a curva antiga com os níveis 2 abaixo).
static func xp_para(n: int) -> int:
	return int(round(100.0 * pow(n, 1.5)))

## Soma XP e sobe de nível; devolve quantos níveis subiu.
func ganhar_xp(qtd: int) -> int:
	dados["xp"] = int(dados["xp"]) + qtd
	var subiu := 0
	while int(dados["xp"]) >= xp_para(int(dados["nivel"])) and int(dados["nivel"]) < 100:
		dados["xp"] = int(dados["xp"]) - xp_para(int(dados["nivel"]))
		dados["nivel"] = int(dados["nivel"]) + 1
		subiu += 1
	return subiu

## Só para testes: volta ao começo (fase 1, nível 1, vidas cheias), mantendo o idioma.
func reiniciar() -> void:
	var idioma: String = dados["idioma"]
	dados = _padrao.duplicate(true)
	dados["idioma"] = idioma
	salvar()
	progresso_mudou.emit()

## Nomes das camadas do herói (pose "costas" ou "frente") na ordem de desenho.
func camadas_heroi(arma := "arma_espada_Comum_-") -> Array:
	var v: Dictionary = dados["visual"]
	var corpo := int(v["corpo"])
	var pele := "Pele-%d" % int(v["pele"])
	var eq := Equipamento.visual()
	var n: Array = ["corpo_%d_%s" % [corpo, pele], "roupa_%d" % corpo]
	if eq.has("armadura"):
		n.append("armadura@" + str(eq["armadura"]))
	if str(v["barba"]) != "":
		n.append("barba_%s_%s" % [v["barba"], v["pelos"]])
	if not eq["esconde_cabelo"]:
		n.append("cabelo_%s_%s%s" % [v["cabelo"], v["pelos"], "_chapeu" if eq["corta_cabelo"] else ""])
	if eq.has("cabeca"):
		n.append("capacete@" + str(eq["cabeca"]))
	n.append("braco_" + pele)
	if eq.has("armadura"):
		n.append("braco_armadura@" + str(eq["armadura"]))
	if arma != "":
		n.append("arma@" + str(eq["arma"]) if eq.has("arma") else arma)
	return n

## Nome que aparece no jogo (o do jogador, ou "Você" enquanto não escolheu).
func nome_heroi() -> String:
	var n := str(dados.get("nome", ""))
	return n if n != "" else tr("VOCE")

## Presente de boas-vindas (DEFINIDO): 500 moedas + 20 cristais + 3 Poções de Vida I.
func dar_presente() -> void:
	dados["moedas"] = int(dados["moedas"]) + 500
	dados["cristais"] = int(dados["cristais"]) + 20
	var p: Dictionary = dados["pocoes"]
	p["pocao_de_vida_i"] = int(p.get("pocao_de_vida_i", 0)) + 3
