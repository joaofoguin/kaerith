class_name Lutador
extends RefCounted
## Um participante do combate (jogador ou inimigo): atributos, Vida, condições, usos e marcas de turno.

var id := 0
var nome := ""
var eh_jogador := false
var sprite := ""            # chave em dados/inimigos.json (inimigos)
var tipo := ""              # chave em Catalogo.TIPOS (inimigos)
var familia := ""
var categoria := "comum"    # comum/veterano/elite/suprema/chefe
var elemento := ""
var nivel := 3
var fator := 1.0
var tamanho := 48

# atributos já com o fator de nível
var forca := 0.0
var percepcao := 0.0
var agilidade := 0.0
var resistencia := 0.0
var ressonancia := 0.0
var vida_max := 1
var vida := 1
var mult_dano := 1.0
var mult_crit := 1.5        # equipamentos sobem até 2,5
var bonus_el := {}          # elemento → % a mais nas habilidades desse elemento (peças Raras ou melhores)

var habilidades: Array = []
var usos := {}              # id → usos restantes (-1 = sem limite)
var conds := {}             # id → {"turnos", "valor", "fonte", "reflexo", "esquiva"}

# marcas que duram "até o próximo turno" de quem usou
var guarda := false
var exposto := false
var contragolpe := false
var agiu := false
var perde_acao := false
var rodada_entrada := 1
var frenesi_usado := false
var fase2 := false
var vez_propria := 0        # contagem de rodadas para a habilidade própria dos chefes

static func fator_de(nv: int) -> float:
	return 1.0 + 0.05 * (nv - 1)

## Condições e marcas de turno que aparecem como ícone (marcas primeiro).
func icones_condicao() -> Array:
	var lista: Array = []
	if guarda:
		lista.append("guarda")
	if contragolpe:
		lista.append("contragolpe")
	if exposto:
		lista.append("exposto")
	lista.append_array(conds.keys())
	return lista

func vivo() -> bool:
	return vida > 0

func definir_atributos(modelo: Array) -> void:
	fator = fator_de(nivel)
	forca = modelo[0] * fator
	percepcao = modelo[1] * fator
	agilidade = modelo[2] * fator
	resistencia = modelo[3] * fator
	ressonancia = modelo[4] * fator

## Ponto base = atributo ÷ fator (usado em crítico, erro e esquiva).
func base(valor: float) -> float:
	return valor / fator

func tem(c: String) -> bool:
	return conds.has(c)

func agilidade_efetiva() -> float:
	var a := agilidade
	if tem("lentidao"):
		a *= 0.5
	if tem("impeto"):
		a *= 1.5
	if tem("p_reflexo"):
		a *= 1.5
	return a

func resistencia_efetiva() -> float:
	var r := resistencia
	if tem("fortificado"):
		r *= 1.4
	if tem("p_granito"):
		r *= 1.4
	if tem("encharcado"):
		r *= 0.8
	return r

func ressonancia_efetiva() -> float:
	return ressonancia * (1.3 if tem("p_ressonancia") else 1.0)

func contar(positivas: bool) -> int:
	var n := 0
	for c in conds:
		if Catalogo.CONDICOES[c]["pos"] == positivas:
			n += 1
	return n

## Tenta aplicar uma condição (3 turnos; não reaplica; máx. 2 positivas + 2 negativas; Firmeza barra negativas).
func aplicar(c: String, dados := {}) -> bool:
	if not vivo() or tem(c):
		return false
	var pos: bool = Catalogo.CONDICOES[c]["pos"]
	if not pos and tem("firmeza"):
		return false
	if contar(pos) >= 2:
		return false
	var d := {"turnos": 4}      # pedido do João: 3 turnos DEPOIS da rodada em que foi aplicada (o fim desta rodada já desconta 1)
	d.merge(dados)
	conds[c] = d
	return true

func negativas() -> Array:
	return conds.keys().filter(func(c): return not Catalogo.CONDICOES[c]["pos"])

func positivas() -> Array:
	return conds.keys().filter(func(c): return Catalogo.CONDICOES[c]["pos"])

func usos_de(h: String) -> int:
	return int(usos.get(h, -1))

func pode_usar(h: String) -> bool:
	var u := usos_de(h)
	if u == 0:
		return false
	if tem("congelado") and Catalogo.HAB[h]["cat"] != "comum":
		return false
	return true

func preparar_usos(bonus := 0) -> void:
	usos.clear()
	for h in habilidades:
		var cat: String = Catalogo.HAB[h]["cat"]
		usos[h] = Catalogo.USOS[cat] + bonus if Catalogo.USOS.has(cat) else -1
