class_name Loja
extends RefCounted
## Regras da Loja (DEFINIDO): renova todo dia; 8 itens do dia (1 Comum grátis), 3 equipamentos do dia de Comum
## a Raro, 1 unidade de cada (sai da vitrine ao comprar); preços pela raridade; Essência de Eco e Frasco de
## Ressonância custam cristais; troca de cristais por moedas × fator; libera depois da fase 5.
## Promoções e pacotes de cristais são compras com dinheiro real (lojas oficiais, etapa 10): por enquanto só aparecem.
## PROVISÓRIO (meu): raridade dos equipamentos do dia = Comum 60% / Incomum 30% / Raro 10%;
## a vitrine renova à meia-noite do horário do aparelho.

## Pedido do João (2026-11-22): itens pagos com dinheiro real (pacotes de cristais e promoções) ficam BLOQUEADOS
## até o jogo estar nas lojas oficiais com o pagamento ligado. Para liberar, mude para true.
const PAGOS_LIBERADOS := false
const FASE_LIBERA := 6                 # loja e login semanal depois da fase 5
const PRECO_ITEM := {"comum": 50, "incomum": 100, "raro": 200}
const PRECO_CRISTAL := {"essencia_de_eco": 30, "frasco_de_ressonancia": 60}
const PRECO_EQUIP := {"comum": 300, "incomum": 600, "raro": 1500}
const GRATIS := "pocao_de_vida_i"      # o único consumível Comum
const MOEDAS := [[20, 500], [50, 1400], [100, 3000], [250, 8000], [500, 17000], [1000, 36000]]
const CRISTAIS := [[100, "R$ 4,90"], [220, "R$ 9,90"], [480, "R$ 19,90"], [1300, "R$ 49,90"], [2800, "R$ 99,90"], [6000, "R$ 199,90"]]
## Modelos das promoções (arte e textos padrão). As promoções NO AR vêm do Firebase (ConfigRemota.promocoes):
## lá cada uma escolhe o modelo e tem nome, preço, prazo e quantidades próprios. Estas duas só valem antes do
## primeiro download (primeira vez offline).
const PROMOS := [
	{"id": "bolsa", "nome": "PROMO_BOLSA", "desc": "PROMO_BOLSA_DESC", "preco": "R$ 9,90"},
	{"id": "conjunto", "nome": "PROMO_CONJUNTO", "desc": "PROMO_CONJUNTO_DESC", "preco": "R$ 19,90"},
]

static func liberada() -> bool:
	return int(Jogo.dados["fase_atual"]) >= FASE_LIBERA or (Jogo.adm() and bool(Jogo.dados.get("loja_teste", false)))

static func hoje() -> String:
	return Time.get_date_string_from_system()

static func segundos_para_renovar() -> int:
	var t := Time.get_time_dict_from_system()
	return 86400 - (int(t["hour"]) * 3600 + int(t["minute"]) * 60 + int(t["second"]))

static func texto_renova() -> String:
	var s := segundos_para_renovar()
	return "%02d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]

static func consumiveis() -> Dictionary:
	var r := {}
	for it in Artes.dados_itens()["itens"]:
		if str(it["icone"]).begins_with("pocao32_"):
			r[it["id"]] = it
	return r

## Vitrine do dia (sorteada uma vez por dia e guardada no save).
static func vitrine() -> Dictionary:
	var v: Dictionary = Jogo.dados.get("loja", {})
	if str(v.get("dia", "")) == hoje():
		return v
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pocoes := consumiveis()
	var outros: Array = pocoes.keys().filter(func(id): return id != GRATIS)
	outros.shuffle()
	var itens: Array = [{"id": GRATIS, "gratis": true, "vendido": false}]
	for id in outros.slice(0, 7):
		itens.append({"id": id, "gratis": false, "vendido": false})
	itens.shuffle()
	var equips: Array = []
	for i in 3:
		var r := rng.randf()
		var rar := "comum" if r < 0.6 else ("incomum" if r < 0.9 else "raro")
		var id := Equipamento.sortear(rar)
		if id != "":
			equips.append({"id": id, "vendido": false})
	v = {"dia": hoje(), "itens": itens, "equips": equips}
	Jogo.dados["loja"] = v
	Jogo.salvar()
	return v

## [valor, "moeda" ou "cristal"] do item do dia.
static func preco_item(id: String) -> Array:
	if PRECO_CRISTAL.has(id):
		return [PRECO_CRISTAL[id], "cristal"]
	var it: Dictionary = consumiveis().get(id, {})
	return [PRECO_ITEM.get(str(it.get("raridade", "comum")), 100), "moeda"]

static func preco_equip(id: String) -> int:
	return PRECO_EQUIP.get(Equipamento.raridade_de(id), 300)

static func tem(valor: int, moeda: String) -> bool:
	return int(Jogo.dados["cristais" if moeda == "cristal" else "moedas"]) >= valor

static func _pagar(valor: int, moeda: String) -> bool:
	var chave := "cristais" if moeda == "cristal" else "moedas"
	if int(Jogo.dados[chave]) < valor:
		return false
	Jogo.dados[chave] = int(Jogo.dados[chave]) - valor
	return true

## Compra o item i dos itens do dia. Devolve "" ou a chave do erro.
static func comprar_item(i: int) -> String:
	var v := vitrine()
	var e: Dictionary = v["itens"][i]
	if bool(e["vendido"]):
		return "LOJA_VENDIDO"
	if not bool(e["gratis"]):
		var p := preco_item(str(e["id"]))
		if not _pagar(int(p[0]), str(p[1])):
			return "LOJA_SEM_SALDO"
	var pocoes: Dictionary = Jogo.dados["pocoes"]
	pocoes[e["id"]] = int(pocoes.get(e["id"], 0)) + 1
	e["vendido"] = true
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	return ""

static func comprar_equip(i: int) -> String:
	var v := vitrine()
	var e: Dictionary = v["equips"][i]
	if bool(e["vendido"]):
		return "LOJA_VENDIDO"
	if not _pagar(preco_equip(str(e["id"])), "moeda"):
		return "LOJA_SEM_SALDO"
	Equipamento.dar(str(e["id"]))
	e["vendido"] = true
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	return ""

## Moedas do pacote k (× fator do nível do jogador).
static func moedas_do_pacote(k: int) -> int:
	return int(round(MOEDAS[k][1] * Lutador.fator_de(int(Jogo.dados["nivel"]))))

static func trocar_moedas(k: int) -> String:
	if not _pagar(int(MOEDAS[k][0]), "cristal"):
		return "LOJA_SEM_SALDO"
	Jogo.dados["moedas"] = int(Jogo.dados["moedas"]) + moedas_do_pacote(k)
	Jogo.salvar()
	Jogo.progresso_mudou.emit()
	return ""
