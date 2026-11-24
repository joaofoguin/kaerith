class_name MapaDesenho
extends Control
const TEMPORADA := preload("res://scripts/temporada.gd")
const HISTORIA := preload("res://scripts/historia.gd")
## Mapa da TEMPORADA INTEIRA numa rolagem só (pedido do João): os 4 atos empilhados, o Ato 1 embaixo e o
## Ato 4 em cima, a estrada seguindo de um ato para o outro (todos entram e saem em x=180). Cada ato tem
## 3 trechos e 75 fases; cenário animado (4 quadros), pegadas, nós, plaquinhas e névoa.
## Névoa: cobre os atos bloqueados inteiros (com a placa do ato e o cadeado) e, no ato atual, o caminho a partir
## de 7 fases à frente (kit aprovado). Entre dois atos liberados, uma faixa de bruma suaviza a troca de região.

signal fase_tocada(fase: int)
signal evento_tocado(etapa: int)       # fase 1–5 do Evento do QR (caminho lateral)

const ATOS := 4
const ALTURA_ATO := 4200.0

var dados: Dictionary            # dados/mapa.json
var atual := 1                   # fase atual do jogador (numeração da temporada)
var _quadros := {}               # ato → [4 texturas]
var _nevoa := {}                 # ato → textura da névoa
var _nos_tex: Texture2D
var _q := 0
var _tempo := 0.0
var _fases: Array = []           # todas as 300 fases, com x/y já na posição da temporada
var _estrada: Array = []         # estrada inteira, do começo do Ato 1 ao fim do Ato 4
var _ato_atual := 1
var _missao := {}                # fase → cor do elemento do NPC (fases que ajudam numa missão em andamento)

## Topo (y) do ato no mapa da temporada: o Ato 4 começa em 0, o Ato 1 é o de baixo.
static func y_do_ato(ato: int) -> float:
	return (ATOS - ato) * ALTURA_ATO

func preparar(d: Dictionary, fase_atual: int) -> void:
	dados = d
	atual = fase_atual
	# o ato do jogador, sem passar do último ato já aberto (quem venceu o chefe antes da data espera na névoa)
	_ato_atual = mini(clampi(int((atual - 1) / 75) + 1, 1, ATOS), ConfigRemota.ultimo_ato_aberto())
	_nos_tex = load("res://artes/atlas/mapa_nos_0.png")
	_fases.clear()
	_estrada.clear()
	for ato in range(1, ATOS + 1):
		var qs: Array = []
		for q in 4:
			qs.append(load("res://artes/mapa/ato%d_q%d.png" % [ato, q]))
		_quadros[ato] = qs
		_nevoa[ato] = load("res://artes/mapa/nevoa_ato%d.png" % ato)
		var dy := y_do_ato(ato)
		var a: Dictionary = dados["atos"][str(ato)]
		for f in a["fases"]:
			_fases.append({"fase": int(f["fase"]), "tipo": f["tipo"], "x": int(f["x"]), "y": int(f["y"]) + int(dy), "ato": ato})
		for p in a["estrada"]:
			_estrada.append([float(p[0]), float(p[1]) + dy])
	custom_minimum_size = Vector2(360, ATOS * ALTURA_ATO)
	marcar_missoes()
	queue_redraw()

## Ícone da missão nas fases já vencidas que ajudam numa missão em andamento (DEFINIDO, opção A).
func marcar_missoes() -> void:
	_missao.clear()
	for id: String in HISTORIA.ativas():
		var el := str(HISTORIA.NPCS.get(str(HISTORIA.MISSOES[id]["npc"]), ""))
		for fase: int in HISTORIA.fases_da_missao(id):
			_missao[fase] = HISTORIA.cor_do_elemento(el)
	queue_redraw()

func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= 0.25:
		_tempo = 0.0
		_q = (_q + 1) % 4
		queue_redraw()

func primeira_fase() -> int:
	return 1

func ultima_fase() -> int:
	return 300

## Ato que está no meio da tela (para o título do topo acompanhar a rolagem).
func ato_em(y: float) -> int:
	return clampi(ATOS - int(y / ALTURA_ATO), 1, ATOS)

## y (em pixels do mapa) da fase, para rolar até ela.
func y_da_fase(fase: int) -> float:
	for f in _fases:
		if int(f["fase"]) == fase:
			return float(f["y"])
	return size.y

func tipo_da_fase(fase: int) -> String:
	for f in _fases:
		if int(f["fase"]) == fase:
			return f["tipo"]
	return "bloqueada"

func estado(fase: int, tipo: String) -> String:
	if fase < atual:
		return "vencida"
	if fase == atual:
		return "atual"
	return tipo

func _chave_no(fase: int, est: String) -> String:
	match est:
		"vencida":
			return "vencida_%d" % fase
		"atual":
			return "atual_%d_%d" % [fase, _q % 2]
		"bloqueada", "ondas":
			return est
	return "%s_%d" % [est, fase]

func _peca(chave: String) -> Rect2:
	var r: Array = dados["nos"]["imagens"][chave]
	return Rect2(r[1], r[2], r[3], r[4])

## Só o que aparece na tela é desenhado (o mapa tem 16.800 px de altura).
func _visivel() -> Rect2:
	var r := get_parent() as ScrollContainer
	if r == null:
		return Rect2(Vector2.ZERO, size)
	return Rect2(0, r.scroll_vertical - 80, 360, r.size.y + 160)

func _draw() -> void:
	if _quadros.is_empty():
		return
	var vis := _visivel()
	for ato in range(1, ATOS + 1):
		var area := Rect2(0, y_do_ato(ato), 360, ALTURA_ATO)
		if area.intersects(vis):
			var fundo: Texture2D = _quadros[ato][_q]
			draw_texture_rect(fundo, Rect2(area.position, fundo.get_size() * 2), false)
	_desenhar_pegadas(vis)
	# nós, dos de cima para os de baixo (os de baixo ficam na frente)
	for f in _fases:
		if absf(float(f["y"]) - vis.get_center().y) > vis.size.y / 2.0 + 60.0:
			continue
		var n := int(f["fase"])
		var r := _peca(_chave_no(n, estado(n, f["tipo"])))
		draw_texture_rect_region(_nos_tex, Rect2(Vector2(int(f["x"]) - int(r.size.x / 2), int(f["y"]) - r.size.y + 18), r.size), r)
	for f in _fases:
		var n := int(f["fase"])
		if n < atual or absf(float(f["y"]) - vis.get_center().y) > vis.size.y / 2.0 + 60.0:
			continue
		var t: String = f["tipo"]
		var desloc := {"elite": 46, "suprema": 50, "chefe": 54}
		if desloc.has(t):
			var r := _peca("rotulo_" + t)
			var x: int = clampi(int(f["x"]) - int(r.size.x / 2), 4, 356 - int(r.size.x))
			draw_texture_rect_region(_nos_tex, Rect2(Vector2(x, int(f["y"]) - desloc[t]), r.size), r)
	for f in _fases:
		var n := int(f["fase"])
		if _missao.has(n) and absf(float(f["y"]) - vis.get_center().y) < vis.size.y / 2.0 + 60.0:
			_selo_missao(Vector2(int(f["x"]) + 13, int(f["y"]) - 34), _missao[n])
	_desenhar_brumas(vis)
	_desenhar_nevoa(vis)
	_desenhar_evento()

## Pergaminho pequeno com "!" na cor do elemento do NPC, que sobe e desce 1 px (pixel art desenhada).
func _selo_missao(c: Vector2, cor: Color) -> void:
	var p := (c + Vector2(0, -1 if _q < 2 else 0)).floor()
	var esc := Color("#2a1a10")
	draw_rect(Rect2(p + Vector2(-6, 1), Vector2(14, 16)), Color(0, 0, 0, 0.35))         # sombra
	draw_rect(Rect2(p + Vector2(-7, -1), Vector2(14, 16)), esc)                         # contorno
	draw_rect(Rect2(p + Vector2(-6, 0), Vector2(12, 14)), Color("#efe0b8"))             # papel
	draw_rect(Rect2(p + Vector2(-6, 0), Vector2(12, 2)), Color("#c9a76a"))              # rolo de cima
	draw_rect(Rect2(p + Vector2(-6, 12), Vector2(12, 2)), Color("#c9a76a"))             # rolo de baixo
	draw_rect(Rect2(p + Vector2(-6, 0), Vector2(12, 1)), Color("#fff4d6"))              # brilho
	draw_rect(Rect2(p + Vector2(4, 2), Vector2(2, 10)), Color(0.55, 0.42, 0.25, 0.35))  # dobra
	draw_rect(Rect2(p + Vector2(-2, 3), Vector2(3, 6)), esc)                            # "!" contornado
	draw_rect(Rect2(p + Vector2(-1, 3), Vector2(1, 5)), cor)
	draw_rect(Rect2(p + Vector2(-2, 10), Vector2(3, 2)), esc)
	draw_rect(Rect2(p + Vector2(-1, 10), Vector2(1, 1)), cor)

# ------------------------------------------------------------ Evento do QR
## Posições das 5 fases do Evento: saem da fase onde o jogador estava quando leu o QR,
## em diagonal para o lado com mais espaço. Vazio se não há Evento neste ato.
func pontos_evento() -> Array:
	var e := CodigoQR.evento_ativo()
	if e.is_empty():
		return []
	var origem := int(e["fase"])
	var base := Vector2(-1, -1)
	for f in _fases:
		if int(f["fase"]) == origem:
			base = Vector2(f["x"], f["y"])
	if base.x < 0:
		return []
	var lado := 1.0 if base.x < 180 else -1.0
	var pts: Array = []
	for i in range(1, 6):
		pts.append((base + Vector2(lado * 30.0 * i, -34.0 * i)).round())
	return pts

func _desenhar_evento() -> void:
	var pts := pontos_evento()
	if pts.is_empty():
		return
	var e := CodigoQR.evento_ativo()
	var vencidas := int(e["vencidas"])
	var amarelo := Color("#ffd66b")
	var escuro := Color("#7a5a14")
	# trilha pontilhada amarela desde a fase de origem
	var ant: Vector2 = Vector2.ZERO
	for f in _fases:
		if int(f["fase"]) == int(e["fase"]):
			ant = Vector2(f["x"], f["y"])
	for p in pts:
		var a: Vector2 = ant
		var b: Vector2 = p
		var n := int(a.distance_to(b) / 7.0)
		for k in range(1, n):
			var q := a.lerp(b, float(k) / n).round()
			draw_rect(Rect2(q - Vector2(1, 1), Vector2(3, 3)), escuro)
			draw_rect(Rect2(q - Vector2(1, 2), Vector2(3, 2)), amarelo)
		ant = p
	var r := _peca("evento")
	for i in range(pts.size() - 1, -1, -1):
		var p: Vector2 = pts[i]
		var cor := Color.WHITE
		var desloc := 0.0
		if i < vencidas:
			cor = Color(0.55, 0.55, 0.6)
		elif i == vencidas:
			desloc = -2.0 if _q % 2 == 0 else 0.0          # a próxima pula de leve
		else:
			cor = Color(0.85, 0.85, 0.9, 0.9)
		var pos := Vector2(p.x - int(r.size.x / 2), p.y - r.size.y + 18 + desloc)
		draw_texture_rect_region(_nos_tex, Rect2(pos, r.size), r, cor)
		draw_string(Tema.fonte_numeros, Vector2(p.x - 3, p.y - r.size.y + 30 + desloc), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#3a2a08"))
	# placa com o tempo que falta, ao lado da 1ª fase
	var s := CodigoQR.evento_restante()
	var txt := "%s %dh%02d" % [tr("EVENTO_CURTO"), s / 3600, (s % 3600) / 60]
	var larg := Tema.fonte_numeros.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 10
	var p0: Vector2 = pts[0]
	var x := clampf(p0.x - larg / 2.0, 4, 356 - larg)
	var caixa := Rect2(x, p0.y + 22, larg, 14)
	draw_rect(caixa, Color("#3a2a08"))
	draw_rect(caixa.grow(-1), Color("#ffd66b"))
	draw_string(Tema.fonte_numeros, Vector2(x + 5, p0.y + 33), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#3a2a08"))

func _indice_pegadas() -> int:
	# até onde vão as pegadas: o ponto da estrada mais perto da fase atual
	if atual > 300:
		return _estrada.size()
	var alvo := Vector2(-1, -1)
	for f in _fases:
		if int(f["fase"]) == atual:
			alvo = Vector2(f["x"], f["y"])
	if alvo.x < 0:
		return 0
	var melhor := 0
	var dist := INF
	for i in _estrada.size():
		var d := alvo.distance_squared_to(Vector2(_estrada[i][0], _estrada[i][1]))
		if d < dist:
			dist = d
			melhor = i
	return melhor

var _pegadas_ate := -1
var _pegadas_de := -1

func _desenhar_pegadas(vis: Rect2) -> void:
	if _pegadas_de != atual:
		_pegadas_de = atual
		_pegadas_ate = _indice_pegadas()
	var cor := Color8(dados["pegada"][0][0], dados["pegada"][0][1], dados["pegada"][0][2])
	var escura := Color8(dados["pegada"][1][0], dados["pegada"][1][1], dados["pegada"][1][2])
	var ultimo := Vector2(-99, -99)
	for i in _pegadas_ate:
		var p := Vector2(round(_estrada[i][0]), round(_estrada[i][1]))
		if p.distance_to(ultimo) < 9.0:
			continue
		ultimo = p
		if not vis.has_point(p):
			continue
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), cor)
		draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 1)), escura)

## Faixa de bruma na emenda entre dois atos já liberados (a troca de região fica suave).
func _desenhar_brumas(vis: Rect2) -> void:
	for ato in range(1, ATOS):
		if ato + 1 > _ato_atual:
			continue
		var emenda := y_do_ato(ato)              # topo do ato = base do ato seguinte
		if absf(emenda - vis.get_center().y) > vis.size.y:
			continue
		var tex: Texture2D = _nevoa[ato + 1]
		var h := 96.0
		draw_texture_rect(tex, Rect2(0, emenda - h, 360, h), false, Color(1, 1, 1, 0.55))
		draw_texture_rect(tex, Rect2(0, emenda + h, 360, -h), false, Color(1, 1, 1, 0.45))

func _desenhar_nevoa(vis: Rect2) -> void:
	# névoa sobre o que ainda não foi liberado: os atos bloqueados inteiros e, no ato atual,
	# o caminho a partir de 7 fases à frente
	var fim := y_do_ato(_ato_atual)              # topo do ato atual = fim dos atos bloqueados
	var ultima_do_ato := _ato_atual * 75
	if atual + 7 <= ultima_do_ato:
		fim = y_da_fase(atual + 7)
	if _ato_atual >= ATOS and atual + 7 > ultima_do_ato:
		return
	var tex: Texture2D = _nevoa[mini(_ato_atual + 1, ATOS)]
	var w := tex.get_width() * 2
	var h := tex.get_height() * 2
	var faixa_y := fim - h
	var cheia := Rect2(0, 0, tex.get_width(), 4)
	var topo := maxf(vis.position.y, 0.0)
	if faixa_y > topo:
		draw_texture_rect_region(tex, Rect2(0, topo, w, faixa_y - topo + 1), cheia)
	draw_texture_rect(tex, Rect2(0, faixa_y, w, h), false)
	# placa de cada ato bloqueado, no começo dele (onde o jogador chega rolando para cima)
	for ato in range(_ato_atual + 1, ATOS + 1):
		var base := y_do_ato(ato) + ALTURA_ATO - 420.0
		if absf(base - vis.get_center().y) > vis.size.y:
			continue
		_placa_bloqueada(ato, base)

func _placa_bloqueada(ato: int, y: float) -> void:
	var cores := TEMPORADA.cores(ato)
	var acento: Color = cores["acento"]
	var caixa := Rect2(32, y, 296, 144)
	draw_rect(caixa.grow(2), Color("#12131c"))
	draw_rect(caixa, Color(cores["fundo"], 0.95))
	draw_rect(caixa.grow(-4), Color(acento, 0.45), false, 1.0)
	draw_rect(Rect2(caixa.position + Vector2(4, 4), Vector2(caixa.size.x - 8, 1)), acento)
	draw_rect(Rect2(caixa.position + Vector2(4, caixa.size.y - 5), Vector2(caixa.size.x - 8, 1)), acento)
	# medalhão desenhado (sem arquivo de imagem): disco com o numeral do ato e um cadeado preso embaixo
	var c := Vector2(180, y + 40)
	_medalhao(c, 20.0, acento, cores["escuro"], TEMPORADA.romano(ato))
	_cadeado(c + Vector2(0, 18), acento)
	var f := Tema.fonte_texto
	var t1 := (tr("TEMPORADA_ATO") % ato)
	var t2 := str(dados["nomes"][str(ato)])
	var t3 := tr("MAPA_ATO_BLOQUEADO") % (ato - 1)
	if not ConfigRemota.ato_aberto(ato):        # ainda não chegou a data: mostra quanto falta
		t3 = tr("MAPA_ATO_ABRE") % TEMPORADA.texto_tempo(maxi(0, ConfigRemota.abertura_do_ato(ato) - ConfigRemota.agora()))
	for par in [[t1, 12, y + 94, cores["claro"]], [t2, 16, y + 114, Tema.COR_TEXTO], [t3, 12, y + 130, Color("#a8acc0")]]:
		var largura := f.get_string_size(par[0], HORIZONTAL_ALIGNMENT_LEFT, -1, par[1]).x
		draw_string(f, Vector2(floorf(180.0 - largura / 2.0), par[2]), par[0], HORIZONTAL_ALIGNMENT_LEFT, -1, par[1], par[3])

## Disco com borda dupla, raios curtos em volta e o numeral romano no meio.
func _medalhao(c: Vector2, raio: float, acento: Color, escuro: Color, numeral: String) -> void:
	for i in 12:
		var a := i * TAU / 12.0
		draw_line(c + Vector2.from_angle(a) * (raio + 2), c + Vector2.from_angle(a) * (raio + 6), Color(acento, 0.6), 2.0)
	draw_circle(c, raio + 1, Color("#12131c"))
	draw_circle(c, raio, acento)
	draw_circle(c, raio - 3, escuro)
	draw_arc(c, raio - 5, 0, TAU, 32, Color(acento, 0.5), 1.0)
	var fn := Tema.fonte_numeros
	var w := fn.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(fn, Vector2(floorf(c.x - w / 2.0), c.y + 6), numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, acento.lightened(0.3))

## Cadeado de pixels: argola e corpo com fechadura.
func _cadeado(c: Vector2, acento: Color) -> void:
	var p := c.floor()
	draw_rect(Rect2(p + Vector2(-5, -9), Vector2(10, 2)), Color("#c9ccd8"))
	draw_rect(Rect2(p + Vector2(-5, -9), Vector2(2, 7)), Color("#c9ccd8"))
	draw_rect(Rect2(p + Vector2(3, -9), Vector2(2, 7)), Color("#c9ccd8"))
	draw_rect(Rect2(p + Vector2(-8, -3), Vector2(16, 12)), Color("#12131c"))
	draw_rect(Rect2(p + Vector2(-7, -2), Vector2(14, 10)), acento)
	draw_rect(Rect2(p + Vector2(-7, -2), Vector2(14, 2)), acento.lightened(0.35))
	draw_rect(Rect2(p + Vector2(-1, 1), Vector2(2, 4)), Color("#12131c"))

var _toque := Vector2(-999, -999)

func _gui_input(evento: InputEvent) -> void:
	# no PC, arrastar com o mouse rola o mapa (no celular, app ou navegador, o ScrollContainer já faz isso com o dedo)
	if evento is InputEventMouseMotion and (evento.button_mask & MOUSE_BUTTON_MASK_LEFT) and not Plataforma.celular():
		var r := get_parent() as ScrollContainer
		if r:
			r.scroll_vertical -= int(evento.relative.y)
		return
	# toque = apertar e soltar quase no mesmo lugar (arrastar rola o mapa)
	if evento is InputEventMouseButton and evento.button_index == MOUSE_BUTTON_LEFT:
		if evento.pressed:
			_toque = evento.position
			return
		if evento.position.distance_to(_toque) > 10:
			return
		var p: Vector2 = evento.position
		var pts := pontos_evento()
		for i in pts.size():
			if p.distance_to(pts[i] - Vector2(0, 8)) < 22:
				evento_tocado.emit(i + 1)
				accept_event()
				return
		for f in _fases:
			var c := Vector2(f["x"], int(f["y"]) - 8)
			if p.distance_to(c) < 26:
				fase_tocada.emit(int(f["fase"]))
				accept_event()
				return
