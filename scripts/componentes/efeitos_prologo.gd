class_name EfeitosPrologo
extends Control
## Animação que acompanha o texto do Prólogo, desenhada por cima das cenas pintadas.
## Cada trecho acende os seus efeitos e apaga os do trecho anterior aos poucos (nada some de repente):
##  0-1 a Voz: uma luz viva no escuro, com ondas de som que se abrem e poeira que vem até ela
##  1-3 cometas riscando o céu antigo
##  2   as eras: lampejos atrás das ruínas (o tempo passando)
##  3   o Eco: uma luz nasce entre as ruínas, sobe deixando rastro e pulsa
##  4   quem escuta: vaga-lumes e poeira de luz correm até a figura na colina
##  5   os Ecos respondem: seis luzes nas cores dos elementos giram em volta da figura
##  6-7 o aviso: fiapos de sombra vêm das bordas, olhos piscam no escuro e a luz da Voz treme
##  8   os Ecos despertam: dezenas de luzes sobem do chão em todas as cores

const COR_EL := [Color("#ff7a3a"), Color("#4ab0ff"), Color("#c8964e"), Color("#6ee0b0"), Color("#ffe04a"), Color("#a8e8ff")]
const ATIVOS := {
	0: ["voz"], 1: ["voz", "cometas"], 2: ["cometas", "eras"], 3: ["cometas", "eco"],
	4: ["convergir"], 5: ["convergir", "ecos6"], 6: ["sombra"], 7: ["sombra", "voz_fraca"], 8: ["despertar"],
}

var cena: CenaPintada
var forca := {"voz": 0.0, "voz_fraca": 0.0, "cometas": 0.0, "eras": 0.0, "eco": 0.0, "convergir": 0.0, "ecos6": 0.0, "sombra": 0.0, "despertar": 0.0}
var alvo := {}
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _poeira: Array = []      # [pos, vel, fase]
var _cometas: Array = []     # [pos, vel, vida]
var _lampejos: Array = []    # [pos, vida, raio]
var _eco_inicio := -1.0
var _rastro: Array = []
var _convergem: Array = []   # [pos, fase, vel]
var _fiapos: Array = []      # [lado, y, fase, comprimento]
var _olhos: Array = []       # [pos, fase]
var _sobem: Array = []       # [pos, vel, cor, fase]
var _momento := -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7
	for k in forca:
		alvo[k] = 0.0
	for i in 40:
		_poeira.append([Vector2(_rng.randf_range(0, 360), _rng.randf_range(0, 640)), Vector2.ZERO, _rng.randf() * TAU])
	for i in 36:
		_convergem.append([Vector2(_rng.randf_range(-20, 380), _rng.randf_range(300, 660)), _rng.randf() * TAU, _rng.randf_range(0.4, 1.0)])
	for i in 10:
		_fiapos.append([i % 2, _rng.randf_range(60, 560), _rng.randf() * TAU, _rng.randf_range(60, 140)])
	for i in 4:
		_olhos.append([Vector2(_rng.randf_range(30, 330), _rng.randf_range(330, 480)), _rng.randf() * 6.0])
	for i in 70:
		_sobem.append(_nova_sobe(true))

func mostrar(momento: int) -> void:
	_momento = momento
	for k in alvo:
		alvo[k] = 0.0
	for k in ATIVOS.get(momento, []):
		alvo[k] = 1.0
	if momento == 3:
		_eco_inicio = _t
		_rastro.clear()

func _nova_sobe(espalhar: bool) -> Array:
	var p := Vector2(_rng.randf_range(0, 360), _rng.randf_range(200, 660) if espalhar else _rng.randf_range(560, 660))
	return [p, Vector2(_rng.randf_range(-6, 6), -_rng.randf_range(20, 60)), COR_EL[_rng.randi_range(0, 5)], _rng.randf() * TAU]

## Ponto da Voz (centro de luz) e da figura que escuta, acompanhando o parallax das camadas.
func _voz() -> Vector2:
	return Vector2(180, 250) + Vector2(sin(_t * 0.4) * 6.0, cos(_t * 0.3) * 4.0)

func _figura() -> Vector2:
	if cena and cena.nome == "ouvinte":
		return cena.ponto("colina", Vector2(119, 204))
	return Vector2(236, 410)

func _ruinas() -> Vector2:
	if cena and cena.nome == "eras":
		return cena.ponto("ruinas", Vector2(98, 262))
	return Vector2(190, 520)

func _process(delta: float) -> void:
	_t += delta
	for k in forca:
		forca[k] = move_toward(forca[k], alvo[k], delta * (0.7 if alvo[k] > forca[k] else 0.5))
	var voz := _voz()
	for p in _poeira:      # poeira que flutua e é puxada de leve para a Voz
		var para: Vector2 = voz - p[0]
		p[1] = p[1].lerp(para.normalized() * 10.0 + Vector2(sin(_t + p[2]) * 6.0, 0), delta)
		p[0] += p[1] * delta
		if para.length() < 12.0:
			p[0] = Vector2(_rng.randf_range(0, 360), [0.0, 640.0][_rng.randi_range(0, 1)])
	if forca["cometas"] > 0.05 and _rng.randf() < delta * 0.9:
		_cometas.append([Vector2(_rng.randf_range(60, 420), _rng.randf_range(-20, 200)), Vector2(-_rng.randf_range(160, 260), _rng.randf_range(60, 120)), 1.0])
	for c in _cometas:
		c[0] += c[1] * delta
		c[2] -= delta * 0.9
	_cometas = _cometas.filter(_vivo)
	if forca["eras"] > 0.05 and _rng.randf() < delta * 1.6:
		_lampejos.append([Vector2(_rng.randf_range(20, 340), _rng.randf_range(280, 420)), 1.0, _rng.randf_range(30, 70)])
	for l in _lampejos:
		l[1] -= delta * 1.2
	_lampejos = _lampejos.filter(_vivo_l)
	if _eco_inicio >= 0.0:
		_rastro.push_front(_eco_pos())
		if _rastro.size() > 26:
			_rastro.pop_back()
	var fig := _figura()
	for c in _convergem:       # correm em espiral até a figura e renascem nas bordas
		var para: Vector2 = fig - c[0]
		var giro := para.orthogonal().normalized() * 26.0
		c[0] += (para.normalized() * 34.0 * c[2] + giro) * delta
		if para.length() < 10.0:
			c[0] = Vector2([-10.0, 370.0][_rng.randi_range(0, 1)], _rng.randf_range(300, 660))
	for s in _sobem:
		s[0] += s[1] * delta
		s[0] = s[0] + Vector2(sin(_t * 1.4 + float(s[3])) * delta * 8.0, 0)
		if s[0].y < -10:
			var n := _nova_sobe(false)
			for i in 4:
				s[i] = n[i]
	queue_redraw()

func _vivo(c: Array) -> bool:
	return float(c[2]) > 0.0

func _vivo_l(l: Array) -> bool:
	return float(l[1]) > 0.0

func _eco_pos() -> Vector2:
	var k := clampf((_t - _eco_inicio) / 4.0, 0.0, 1.0)
	var suave := 1.0 - pow(1.0 - k, 3.0)
	var base := _ruinas()
	return base + Vector2(sin(_t * 1.7) * 14.0 * suave, -170.0 * suave)

func _brilho(p: Vector2, raio: float, cor: Color, a: float) -> void:
	for i in 4:
		draw_circle(p, raio * (1.0 + i * 0.7), Color(cor, a * 0.16 / (i + 1)))
	draw_circle(p, raio * 0.45, Color(cor.lightened(0.5), a))

func _px(p: Vector2, s: float, cor: Color) -> void:
	draw_rect(Rect2((p / 2.0).floor() * 2.0, Vector2(s, s)), cor)

func _draw() -> void:
	var voz := _voz()
	# --- a Voz: luz viva, ondas que se abrem e poeira chegando
	var fv: float = forca["voz"] + forca["voz_fraca"] * 0.45
	if fv > 0.01:
		var trem := 1.0 if forca["voz_fraca"] < 0.5 else (0.6 + 0.4 * absf(sin(_t * 11.0)) * absf(sin(_t * 3.3)))
		_brilho(voz, 16.0 + 3.0 * sin(_t * 2.2), Color("#b9a6ff"), fv * trem)
		for i in 3:
			var k := fposmod(_t * 0.35 + i / 3.0, 1.0)
			draw_arc(voz, 20.0 + k * 150.0, 0, TAU, 64, Color(0.75, 0.7, 1.0, (1.0 - k) * 0.35 * fv), 2.0)
		for p in _poeira:
			var b := 0.5 + 0.5 * sin(_t * 2.0 + float(p[2]))
			_px(p[0], 2, Color(0.85, 0.8, 1.0, (0.25 + 0.5 * b) * fv))
	# --- cometas com cauda
	for c in _cometas:
		var a: float = clampf(float(c[2]), 0.0, 1.0) * forca["cometas"]
		var dir: Vector2 = (c[1] as Vector2).normalized()
		for i in 18:
			_px(c[0] - dir * i * 3.0, 2, Color(1, 0.95, 0.85, a * (1.0 - i / 18.0)))
		_brilho(c[0], 3.0, Color(1, 0.95, 0.8), a)
	# --- as eras: lampejos que passam atrás das ruínas
	for l in _lampejos:
		var a: float = sin(float(l[1]) * PI) * forca["eras"]
		_brilho(l[0], float(l[2]) * 0.3, Color(1.0, 0.75, 0.45), a * 0.6)
	# --- o Eco nascendo das ruínas
	if forca["eco"] > 0.01 and _eco_inicio >= 0.0:
		var f: float = forca["eco"]
		for i in _rastro.size():
			var q: float = 1.0 - float(i) / _rastro.size()
			_px(_rastro[i] + Vector2(sin(i * 0.9 + _t * 4.0) * 3.0, 0), 2 if i % 3 else 4, Color(0.6, 0.95, 1.0, q * 0.8 * f))
		var p := _eco_pos()
		_brilho(p, 10.0 + 2.0 * sin(_t * 5.0), Color("#7fe8ff"), f)
		var k := fposmod(_t * 0.6, 1.0)
		draw_arc(p, 14.0 + k * 60.0, 0, TAU, 48, Color(0.5, 0.95, 1.0, (1.0 - k) * 0.5 * f), 2.0)
		var base := _ruinas()
		_brilho(base, 22.0, Color("#7fe8ff"), f * 0.35 * clampf(1.0 - (_t - _eco_inicio) / 3.0, 0.0, 1.0))
	# --- luzes correndo até quem escuta
	var fig := _figura()
	if forca["convergir"] > 0.01:
		var f: float = forca["convergir"]
		_brilho(fig + Vector2(0, -6), 9.0 + 2.0 * sin(_t * 3.0), Color("#6ad6c0"), f * 0.8)
		for c in _convergem:
			var b := 0.5 + 0.5 * sin(_t * 3.0 + float(c[1]))
			_px(c[0], 2, Color(0.55, 1.0, 0.8, (0.3 + 0.6 * b) * f))
			_px(c[0] + Vector2(-2, -2), 6, Color(0.55, 1.0, 0.8, 0.08 * f))
	# --- os seis Ecos respondem, girando em volta da figura
	if forca["ecos6"] > 0.01:
		var f: float = forca["ecos6"]
		for i in 6:
			var a := _t * 0.9 + i * TAU / 6.0
			var r := 34.0 + 6.0 * sin(_t * 1.3 + i)
			var p := fig + Vector2(cos(a) * r, -14.0 + sin(a) * r * 0.45)
			_brilho(p, 5.0, COR_EL[i], f)
			for j in 6:
				var aa := a - j * 0.09
				_px(fig + Vector2(cos(aa) * r, -14.0 + sin(aa) * r * 0.45), 2, Color(COR_EL[i], f * 0.5 * (1.0 - j / 6.0)))
	# --- o aviso: sombra vindo das bordas e olhos no escuro
	if forca["sombra"] > 0.01:
		var f: float = forca["sombra"]
		for e in 8:       # moldura escura que respira
			var m := e * 10.0 + 6.0 * sin(_t * 0.8)
			draw_rect(Rect2(m, m, 360 - m * 2, 640 - m * 2), Color(0.03, 0.0, 0.06, 0.09 * f), false, 12.0)
		for w in _fiapos:
			var lado: int = w[0]
			var y: float = w[1] + sin(_t * 0.5 + float(w[2])) * 20.0
			var comp: float = w[3] * (0.6 + 0.4 * sin(_t * 0.7 + float(w[2])))
			for i in int(comp / 4.0):
				var x := i * 4.0
				var yy := y + sin(_t * 1.5 + i * 0.35 + float(w[2])) * 6.0
				var px := x if lado == 0 else 360.0 - x
				_px(Vector2(px, yy), 4, Color(0.12, 0.02, 0.18, f * 0.55 * (1.0 - x / comp)))
		for o in _olhos:
			var ciclo := fposmod(_t + float(o[1]), 6.0)
			if ciclo < 2.2:
				var a := sin(ciclo / 2.2 * PI) * f
				var p: Vector2 = o[0]
				_px(p, 2, Color(1.0, 0.25, 0.3, a))
				_px(p + Vector2(8, 0), 2, Color(1.0, 0.25, 0.3, a))
				draw_circle(p + Vector2(5, 1), 9.0, Color(1.0, 0.2, 0.3, a * 0.08))
	# --- os Ecos despertam por toda parte
	if forca["despertar"] > 0.01:
		var f: float = forca["despertar"]
		for s in _sobem:
			var b := 0.5 + 0.5 * sin(_t * 4.0 + float(s[3]))
			var c: Color = s[2]
			_px(s[0] - Vector2(2, 2), 6, Color(c, 0.12 * f))
			_px(s[0], 2, Color(c.lightened(0.3), (0.4 + 0.6 * b) * f))
			_px(s[0] + Vector2(0, 4), 2, Color(c, 0.3 * f))
