class_name LeitorQR
extends RefCounted
## Leitor de QR Code feito em GDScript (sem plugin): acha os 3 quadrados dos cantos, corrige a
## perspectiva pelo quadradinho de alinhamento, lê a grade e corrige erros (Reed-Solomon).
## Aceita códigos girados, inclinados ou espelhados (versões 1 a 20). Testado antes em Python com fotos tortas.

const RS := [[1, 26, 19], [1, 26, 16], [1, 26, 13], [1, 26, 9], [1, 44, 34], [1, 44, 28], [1, 44, 22], [1, 44, 16], [1, 70, 55], [1, 70, 44], [2, 35, 17], [2, 35, 13], [1, 100, 80], [2, 50, 32], [2, 50, 24], [4, 25, 9], [1, 134, 108], [2, 67, 43], [2, 33, 15, 2, 34, 16], [2, 33, 11, 2, 34, 12], [2, 86, 68], [4, 43, 27], [4, 43, 19], [4, 43, 15], [2, 98, 78], [4, 49, 31], [2, 32, 14, 4, 33, 15], [4, 39, 13, 1, 40, 14], [2, 121, 97], [2, 60, 38, 2, 61, 39], [4, 40, 18, 2, 41, 19], [4, 40, 14, 2, 41, 15], [2, 146, 116], [3, 58, 36, 2, 59, 37], [4, 36, 16, 4, 37, 17], [4, 36, 12, 4, 37, 13], [2, 86, 68, 2, 87, 69], [4, 69, 43, 1, 70, 44], [6, 43, 19, 2, 44, 20], [6, 43, 15, 2, 44, 16], [4, 101, 81], [1, 80, 50, 4, 81, 51], [4, 50, 22, 4, 51, 23], [3, 36, 12, 8, 37, 13], [2, 116, 92, 2, 117, 93], [6, 58, 36, 2, 59, 37], [4, 46, 20, 6, 47, 21], [7, 42, 14, 4, 43, 15], [4, 133, 107], [8, 59, 37, 1, 60, 38], [8, 44, 20, 4, 45, 21], [12, 33, 11, 4, 34, 12], [3, 145, 115, 1, 146, 116], [4, 64, 40, 5, 65, 41], [11, 36, 16, 5, 37, 17], [11, 36, 12, 5, 37, 13], [5, 109, 87, 1, 110, 88], [5, 65, 41, 5, 66, 42], [5, 54, 24, 7, 55, 25], [11, 36, 12, 7, 37, 13], [5, 122, 98, 1, 123, 99], [7, 73, 45, 3, 74, 46], [15, 43, 19, 2, 44, 20], [3, 45, 15, 13, 46, 16], [1, 135, 107, 5, 136, 108], [10, 74, 46, 1, 75, 47], [1, 50, 22, 15, 51, 23], [2, 42, 14, 17, 43, 15], [5, 150, 120, 1, 151, 121], [9, 69, 43, 4, 70, 44], [17, 50, 22, 1, 51, 23], [2, 42, 14, 19, 43, 15], [3, 141, 113, 4, 142, 114], [3, 70, 44, 11, 71, 45], [17, 47, 21, 4, 48, 22], [9, 39, 13, 16, 40, 14], [3, 135, 107, 5, 136, 108], [3, 67, 41, 13, 68, 42], [15, 54, 24, 5, 55, 25], [15, 43, 15, 10, 44, 16]]
const ALINHAMENTO := [[], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34], [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50], [6, 30, 54], [6, 32, 58], [6, 34, 62], [6, 26, 46, 66], [6, 26, 48, 70], [6, 26, 50, 74], [6, 30, 54, 78], [6, 30, 56, 82], [6, 30, 58, 86], [6, 34, 62, 90]]

const ALNUM := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
const LADO_MAX := 480          # a imagem é reduzida até este lado maior antes da leitura

static var _exp := PackedInt32Array()
static var _log := PackedInt32Array()
static var _formatos := PackedInt32Array()

static func _preparar() -> void:
	if _exp.size() > 0:
		return
	_exp.resize(512)
	_log.resize(256)
	var x := 1
	for i in 255:
		_exp[i] = x
		_log[x] = i
		x <<= 1
		if x & 0x100:
			x ^= 0x11D
	for i in range(255, 512):
		_exp[i] = _exp[i - 255]
	_formatos.resize(32)
	for d in 32:
		_formatos[d] = ((d << 10) | _bch(d, 0x537, 10)) ^ 0x5412

static func _bits(v: int) -> int:
	var n := 0
	while v > 0:
		n += 1
		v >>= 1
	return n

static func _bch(valor: int, poli: int, grau: int) -> int:
	var v := valor << grau
	var pd := _bits(poli) - 1
	while v != 0 and _bits(v) - 1 >= pd:
		v ^= poli << (_bits(v) - 1 - pd)
	return v

# ------------------------------------------------------------ entrada
## Lê um QR numa imagem qualquer. Devolve o texto, ou "" se não achou.
static func ler(img: Image) -> String:
	_preparar()
	if img == null or img.is_empty():
		return ""
	var im := img.duplicate() as Image
	if im.is_compressed():
		im.decompress()
	var maior := maxi(im.get_width(), im.get_height())
	if maior > LADO_MAX:
		var f := float(LADO_MAX) / float(maior)
		im.resize(maxi(1, int(im.get_width() * f)), maxi(1, int(im.get_height() * f)), Image.INTERPOLATE_BILINEAR)
	im.convert(Image.FORMAT_L8)
	return ler_cinza(im.get_data(), im.get_width(), im.get_height())

## Lê a partir dos tons de cinza (1 byte por pixel).
static func ler_cinza(g: PackedByteArray, w: int, h: int) -> String:
	_preparar()
	var b := _binarizar(g, w, h)
	var t := _tentar(b, w, h)
	if t == "":
		b = _otsu(g, w, h)
		t = _tentar(b, w, h)
	return t

# ------------------------------------------------------------ preto e branco
static func _binarizar(g: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var w1 := w + 1
	var integ := PackedInt32Array()
	integ.resize(w1 * (h + 1))
	for y in h:
		var s := 0
		var linha := y * w
		var base := (y + 1) * w1
		var antes := y * w1
		for x in w:
			s += g[linha + x]
			integ[base + x + 1] = integ[antes + x + 1] + s
	var r := maxi(8, mini(w, h) / 16)
	var saida := PackedByteArray()
	saida.resize(w * h)
	for y in h:
		var y0 := maxi(0, y - r)
		var y1 := mini(h, y + r + 1)
		for x in w:
			var x0 := maxi(0, x - r)
			var x1 := mini(w, x + r + 1)
			var area := (x1 - x0) * (y1 - y0)
			var soma := integ[y1 * w1 + x1] - integ[y0 * w1 + x1] - integ[y1 * w1 + x0] + integ[y0 * w1 + x0]
			if g[y * w + x] * area * 100 < soma * 90:
				saida[y * w + x] = 1
	return saida

static func _otsu(g: PackedByteArray, w: int, h: int) -> PackedByteArray:
	var hist := PackedInt32Array()
	hist.resize(256)
	for v in g:
		hist[v] += 1
	var total := w * h
	var soma := 0.0
	for i in 256:
		soma += i * hist[i]
	var sb := 0.0
	var wb := 0
	var melhor := 0.0
	var lim := 127
	for t in 256:
		wb += hist[t]
		if wb == 0:
			continue
		var wf := total - wb
		if wf == 0:
			break
		sb += t * hist[t]
		var mb := sb / wb
		var mf := (soma - sb) / wf
		var v := float(wb) * float(wf) * (mb - mf) * (mb - mf)
		if v > melhor:
			melhor = v
			lim = t
	var saida := PackedByteArray()
	saida.resize(w * h)
	for i in w * h:
		if g[i] <= lim:
			saida[i] = 1
	return saida

# ------------------------------------------------------------ quadrados dos cantos (finders)
static func _razao_ok(c: Array) -> bool:
	var total: int = c[0] + c[1] + c[2] + c[3] + c[4]
	if total < 7:
		return false
	var m := total / 7.0
	var v := m / 2.0
	return absf(m - c[0]) < v and absf(m - c[1]) < v and absf(3.0 * m - c[2]) < 3.0 * v and absf(m - c[3]) < v and absf(m - c[4]) < v

## Confere na vertical (eixo = 1) ou na horizontal (eixo = 0). Devolve [centro, módulo] ou [-1, 0].
static func _checar(b: PackedByteArray, w: int, h: int, cx: int, cy: int, max_c: int, total_h: int, vertical: bool) -> Array:
	var c := [0, 0, 0, 0, 0]
	var lim := h if vertical else w
	var p := cy if vertical else cx
	var passo := w if vertical else 1
	var origem := cx if vertical else cy * w
	var i := p
	while i >= 0 and b[origem + i * passo] == 1:
		c[2] += 1
		i -= 1
	if i < 0:
		return [-1.0, 0.0]
	while i >= 0 and b[origem + i * passo] == 0 and c[1] <= max_c:
		c[1] += 1
		i -= 1
	if i < 0 or c[1] > max_c:
		return [-1.0, 0.0]
	while i >= 0 and b[origem + i * passo] == 1 and c[0] <= max_c:
		c[0] += 1
		i -= 1
	if c[0] > max_c:
		return [-1.0, 0.0]
	i = p + 1
	while i < lim and b[origem + i * passo] == 1:
		c[2] += 1
		i += 1
	if i == lim:
		return [-1.0, 0.0]
	while i < lim and b[origem + i * passo] == 0 and c[3] < max_c:
		c[3] += 1
		i += 1
	if i == lim or c[3] >= max_c:
		return [-1.0, 0.0]
	while i < lim and b[origem + i * passo] == 1 and c[4] < max_c:
		c[4] += 1
		i += 1
	if c[4] >= max_c:
		return [-1.0, 0.0]
	var tot: int = c[0] + c[1] + c[2] + c[3] + c[4]
	if vertical:
		if 5 * absi(tot - total_h) >= 2 * total_h:
			return [-1.0, 0.0]
	elif 5 * absi(tot - total_h) >= total_h:
		return [-1.0, 0.0]
	if not _razao_ok(c):
		return [-1.0, 0.0]
	return [float(i - c[4] - c[3]) - c[2] / 2.0, tot / 7.0]

static func _achar_finders(b: PackedByteArray, w: int, h: int) -> Array:
	var cands: Array = []
	for y in h:
		var c := [0, 0, 0, 0, 0]
		var st := 0
		var linha := y * w
		for x in w:
			if b[linha + x] == 1:
				if st & 1 == 1:
					st += 1
				c[st] += 1
			else:
				if st & 1 == 0:
					if st == 4:
						if _razao_ok(c):
							_candidato(b, w, h, cands, float(x - c[4] - c[3]) - c[2] / 2.0, y, c[2], c[0] + c[1] + c[2] + c[3] + c[4])
						c = [c[2], c[3], c[4], 1, 0]
						st = 3
					elif st == 0 and c[0] == 0:
						pass
					else:
						st += 1
						c[st] += 1
				else:
					c[st] += 1
		if st == 4 and _razao_ok(c):
			_candidato(b, w, h, cands, float(w - c[4] - c[3]) - c[2] / 2.0, y, c[2], c[0] + c[1] + c[2] + c[3] + c[4])
	return cands

static func _candidato(b: PackedByteArray, w: int, h: int, cands: Array, cx: float, y: int, max_c: int, total: int) -> void:
	var v := _checar(b, w, h, int(cx), y, max_c, total, true)
	if v[0] < 0:
		return
	var hz := _checar(b, w, h, int(cx), int(v[0]), max_c, total, false)
	if hz[0] < 0:
		return
	var vy: float = v[0]
	var hx: float = hz[0]
	var ms: float = (float(v[1]) + float(hz[1])) / 2.0
	for k in cands:
		if absf(k[0] - hx) <= ms * 2.0 and absf(k[1] - vy) <= ms * 2.0 and absf(k[2] - ms) <= maxf(1.0, k[2] * 0.6):
			var n: int = k[3]
			k[0] = (k[0] * n + hx) / (n + 1)
			k[1] = (k[1] * n + vy) / (n + 1)
			k[2] = (k[2] * n + ms) / (n + 1)
			k[3] = n + 1
			return
	cands.append([hx, vy, ms, 1])

static func _dist(a: Array, c: Array) -> float:
	return Vector2(a[0] - c[0], a[1] - c[1]).length()

## Os 3 quadrados mais coerentes, na ordem [canto de cima à esquerda, de cima à direita, de baixo à esquerda].
static func _escolher_trio(cands: Array) -> Array:
	var lista: Array = cands.filter(func(k): return k[3] >= 2)
	lista.sort_custom(func(a, c): return a[3] > c[3])
	if lista.size() > 10:
		lista.resize(10)
	var melhor: Array = []
	var erro_min := 1e9
	var n := lista.size()
	for i in n:
		for j in range(i + 1, n):
			for k in range(j + 1, n):
				var a: Array = lista[i]
				var bb: Array = lista[j]
				var c: Array = lista[k]
				var mmax := maxf(a[2], maxf(bb[2], c[2]))
				var mmin := minf(a[2], minf(bb[2], c[2]))
				if mmax > mmin * 1.6:
					continue
				var d := [_dist(a, bb), _dist(bb, c), _dist(a, c)]
				d.sort()
				if d[0] < mmin * 7.0:
					continue
				var e: float = absf(d[0] - d[1]) / d[1] + absf(d[2] - sqrt(d[0] * d[0] + d[1] * d[1])) / d[2] + (mmax - mmin) / mmax
				if e < erro_min:
					erro_min = e
					melhor = [a, bb, c]
	if melhor.is_empty() or erro_min > 0.6:
		return []
	var a: Array = melhor[0]
	var bb: Array = melhor[1]
	var c: Array = melhor[2]
	var dab := _dist(a, bb)
	var dbc := _dist(bb, c)
	var dac := _dist(a, c)
	var tl: Array
	var p: Array
	var q: Array
	if dbc >= dab and dbc >= dac:
		tl = a
		p = bb
		q = c
	elif dac >= dab and dac >= dbc:
		tl = bb
		p = a
		q = c
	else:
		tl = c
		p = a
		q = bb
	var cruz: float = (p[0] - tl[0]) * (q[1] - tl[1]) - (p[1] - tl[1]) * (q[0] - tl[0])
	if cruz < 0:
		var tmp := p
		p = q
		q = tmp
	return [tl, p, q]

# ------------------------------------------------------------ tamanho do módulo
static func _px(b: PackedByteArray, w: int, h: int, x: float, y: float) -> int:
	var xi := int(floor(x))
	var yi := int(floor(y))
	if xi < 0 or yi < 0 or xi >= w or yi >= h:
		return 0
	return b[yi * w + xi]

static func _corrida(b: PackedByteArray, w: int, h: int, x0: float, y0: float, dx: float, dy: float) -> float:
	var st := 0
	var t := 0.0
	while t < 200.0:
		var x := x0 + dx * t
		var y := y0 + dy * t
		if x < 0 or y < 0 or x >= w or y >= h:
			return -1.0
		var v := _px(b, w, h, x, y)
		if st == 0 and v == 0:
			st = 1
		elif st == 1 and v == 1:
			st = 2
		elif st == 2 and v == 0:
			return t
		t += 0.5
	return -1.0

static func _modulo(b: PackedByteArray, w: int, h: int, tl: Array, tr: Array, bl: Array) -> float:
	var soma := 0.0
	var n := 0
	for par in [[tl, tr], [tr, tl], [tl, bl], [bl, tl]]:
		var a: Array = par[0]
		var c: Array = par[1]
		var d := _dist(a, c)
		if d < 1.0:
			continue
		var dx: float = (c[0] - a[0]) / d
		var dy: float = (c[1] - a[1]) / d
		var r1 := _corrida(b, w, h, a[0], a[1], dx, dy)
		var r2 := _corrida(b, w, h, a[0], a[1], -dx, -dy)
		if r1 > 0 and r2 > 0:
			soma += (r1 + r2) / 7.0
			n += 1
	if n == 0:
		return (float(tl[2]) + float(tr[2]) + float(bl[2])) / 3.0
	return soma / n

static func _dim_de(tl: Array, tr: Array, bl: Array, ms: float) -> int:
	var d1 := _dist(tl, tr) / ms
	var d2 := _dist(tl, bl) / ms
	var dim := int(round((d1 + d2) / 2.0)) + 7
	var r4 := dim & 3
	if r4 == 0:
		dim += 1
	elif r4 == 2:
		dim -= 1
	elif r4 == 3:
		dim -= 2
	return dim

# ------------------------------------------------------------ perspectiva
static func _homografia(src: Array, dst: Array) -> PackedFloat64Array:
	var m: Array = []
	for i in 4:
		var x: float = src[i].x
		var y: float = src[i].y
		var u: float = dst[i].x
		var v: float = dst[i].y
		m.append([x, y, 1.0, 0.0, 0.0, 0.0, -u * x, -u * y, u])
		m.append([0.0, 0.0, 0.0, x, y, 1.0, -v * x, -v * y, v])
	for col in 8:
		var piv := col
		for r in range(col + 1, 8):
			if absf(m[r][col]) > absf(m[piv][col]):
				piv = r
		if absf(m[piv][col]) < 1e-12:
			return PackedFloat64Array()
		var tmp: Array = m[col]
		m[col] = m[piv]
		m[piv] = tmp
		for r in 8:
			if r != col:
				var f: float = m[r][col] / m[col][col]
				if f != 0.0:
					for c2 in range(col, 9):
						m[r][c2] -= f * m[col][c2]
	var hm := PackedFloat64Array()
	hm.resize(8)
	for i in 8:
		hm[i] = m[i][8] / m[i][i]
	return hm

static func _aplicar(hm: PackedFloat64Array, x: float, y: float) -> Vector2:
	var d := hm[6] * x + hm[7] * y + 1.0
	return Vector2((hm[0] * x + hm[1] * y + hm[2]) / d, (hm[3] * x + hm[4] * y + hm[5]) / d)

const VIZINHOS := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]

## Procura o quadradinho de alinhamento perto da posição estimada (u e v = um módulo em cada eixo do código).
static func _achar_alinhamento(b: PackedByteArray, w: int, h: int, est: Vector2, ms: float, raio: float, u: Vector2, v: Vector2) -> Vector2:
	var melhor := -1
	var pts: Array = []
	var passo := maxi(1, int(ms / 3.0))
	var r := int(raio)
	var cx := int(est.x)
	var cy := int(est.y)
	var yy := cy - r
	while yy <= cy + r:
		var xx := cx - r
		while xx <= cx + r:
			var sc := 0
			if _px(b, w, h, xx, yy) == 1:
				sc += 2
			for d in VIZINHOS:
				var o: Vector2 = u * d.x + v * d.y
				if _px(b, w, h, xx + o.x, yy + o.y) == 0:
					sc += 1
				if _px(b, w, h, xx + o.x * 2.0, yy + o.y * 2.0) == 1:
					sc += 1
			if sc > melhor:
				melhor = sc
				pts = [Vector2(xx, yy)]
			elif sc == melhor:
				pts.append(Vector2(xx, yy))
			xx += passo
		yy += passo
	if melhor < 17:
		return Vector2(-1, -1)
	pts.sort_custom(func(a, c): return a.distance_squared_to(est) < c.distance_squared_to(est))
	var p0: Vector2 = pts[0]
	var soma := Vector2.ZERO
	var n := 0
	for p in pts:
		if absf(p.x - p0.x) <= ms * 1.5 and absf(p.y - p0.y) <= ms * 1.5:
			soma += p
			n += 1
	return soma / n

static func _tentar(b: PackedByteArray, w: int, h: int) -> String:
	var cands := _achar_finders(b, w, h)
	var trio := _escolher_trio(cands)
	if trio.is_empty():
		return ""
	var tl: Array = trio[0]
	var tr: Array = trio[1]
	var bl: Array = trio[2]
	var ms1 := _modulo(b, w, h, tl, tr, bl)
	var ms2 := (float(tl[2]) + float(tr[2]) + float(bl[2])) / 3.0
	var dims: Array = []
	for d0 in [_dim_de(tl, tr, bl, ms1), _dim_de(tl, tr, bl, ms2)]:
		for dd in [d0, d0 + 4, d0 - 4]:
			if dd >= 21 and dd <= 97 and not dims.has(dd):
				dims.append(dd)
	var p_tl := Vector2(tl[0], tl[1])
	var p_tr := Vector2(tr[0], tr[1])
	var p_bl := Vector2(bl[0], bl[1])
	var p_br := p_tr - p_tl + p_bl
	for dd in dims:
		var fd := float(dd)
		var ms := (p_tl.distance_to(p_tr) + p_tl.distance_to(p_bl)) / 2.0 / (fd - 7.0)
		var src := [Vector2(3.5, 3.5), Vector2(fd - 3.5, 3.5), Vector2(fd - 3.5, fd - 3.5), Vector2(3.5, fd - 3.5)]
		var hm0 := _homografia(src, [p_tl, p_tr, p_br, p_bl])
		if hm0.is_empty():
			continue
		var tentativas: Array = []
		if (dd - 17) / 4 >= 2:
			var est := _aplicar(hm0, fd - 6.5, fd - 6.5)
			var u := _aplicar(hm0, fd - 6.0, fd - 6.5) - _aplicar(hm0, fd - 7.0, fd - 6.5)
			var v := _aplicar(hm0, fd - 6.5, fd - 6.0) - _aplicar(hm0, fd - 6.5, fd - 7.0)
			var al := Vector2(-1, -1)
			for raio in [4.0, 8.0, 14.0]:
				al = _achar_alinhamento(b, w, h, est, ms, raio * ms, u, v)
				if al.x >= 0:
					break
			if al.x >= 0:
				var src2 := [Vector2(3.5, 3.5), Vector2(fd - 3.5, 3.5), Vector2(fd - 6.5, fd - 6.5), Vector2(3.5, fd - 3.5)]
				var hm := _homografia(src2, [p_tl, p_tr, al, p_bl])
				if not hm.is_empty():
					tentativas.append(hm)
		tentativas.append(hm0)
		for hm in tentativas:
			var grade := _amostrar(b, w, h, hm, dd)
			var t := _decodificar_grade(grade, dd)
			if t == "":
				var tg := PackedByteArray()
				tg.resize(dd * dd)
				for y in dd:
					for x in dd:
						tg[y * dd + x] = grade[x * dd + y]
				t = _decodificar_grade(tg, dd)
			if t != "":
				return t
	return ""

static func _amostrar(b: PackedByteArray, w: int, h: int, hm: PackedFloat64Array, dim: int) -> PackedByteArray:
	var g := PackedByteArray()
	g.resize(dim * dim)
	for y in dim:
		for x in dim:
			var p := _aplicar(hm, x + 0.5, y + 0.5)
			g[y * dim + x] = _px(b, w, h, p.x, p.y)
	return g

# ------------------------------------------------------------ leitura da grade
static func _pop(v: int) -> int:
	var c := 0
	while v > 0:
		c += v & 1
		v >>= 1
	return c

static func _funcao(dim: int, ver: int) -> PackedByteArray:
	var f := PackedByteArray()
	f.resize(dim * dim)
	var regioes: Array = [[0, 0, 9, 9], [dim - 8, 0, 8, 9], [0, dim - 8, 9, 8], [6, 9, 1, dim - 17], [9, 6, dim - 17, 1]]
	var pos: Array = ALINHAMENTO[ver - 1]
	var m := pos.size()
	for i in m:
		for j in m:
			if (i == 0 and (j == 0 or j == m - 1)) or (i == m - 1 and j == 0):
				continue
			regioes.append([pos[i] - 2, pos[j] - 2, 5, 5])
	if ver > 6:
		regioes.append([dim - 11, 0, 3, 6])
		regioes.append([0, dim - 11, 6, 3])
	for r in regioes:
		for yy in range(r[1], r[1] + r[3]):
			for xx in range(r[0], r[0] + r[2]):
				f[yy * dim + xx] = 1
	return f

static func _mascara(m: int, i: int, j: int) -> bool:
	match m:
		0:
			return (i + j) % 2 == 0
		1:
			return i % 2 == 0
		2:
			return j % 3 == 0
		3:
			return (i + j) % 3 == 0
		4:
			return ((i / 2) + (j / 3)) % 2 == 0
		5:
			return (i * j) % 2 + (i * j) % 3 == 0
		6:
			return ((i * j) % 2 + (i * j) % 3) % 2 == 0
	return ((i + j) % 2 + (i * j) % 3) % 2 == 0

static func _decodificar_grade(g: PackedByteArray, dim: int) -> String:
	var f1 := 0
	for i in 6:
		f1 = (f1 << 1) | g[8 * dim + i]
	f1 = (f1 << 1) | g[8 * dim + 7]
	f1 = (f1 << 1) | g[8 * dim + 8]
	f1 = (f1 << 1) | g[7 * dim + 8]
	for j in range(5, -1, -1):
		f1 = (f1 << 1) | g[j * dim + 8]
	var f2 := 0
	for j in range(dim - 1, dim - 8, -1):
		f2 = (f2 << 1) | g[j * dim + 8]
	for i in range(dim - 8, dim):
		f2 = (f2 << 1) | g[8 * dim + i]
	var fmt := -1
	var melhor := 99
	for bits in [f1, f2]:
		for d in 32:
			var dif := _pop(bits ^ _formatos[d])
			if dif < melhor:
				melhor = dif
				fmt = d
	if melhor > 3:
		return ""
	var nivel: int = {1: 0, 0: 1, 3: 2, 2: 3}[fmt >> 3]      # L M Q H
	var mask := fmt & 7
	var ver := (dim - 17) / 4
	if ver < 1 or ver > 20:
		return ""
	var f := _funcao(dim, ver)
	var cods := PackedInt32Array()
	var atual := 0
	var nb := 0
	var subindo := true
	var j := dim - 1
	while j > 0:
		if j == 6:
			j -= 1
		for cnt in dim:
			var i := dim - 1 - cnt if subindo else cnt
			for col in 2:
				var x := j - col
				if f[i * dim + x] == 0:
					var v: int = g[i * dim + x]
					if _mascara(mask, i, x):
						v ^= 1
					atual = (atual << 1) | v
					nb += 1
					if nb == 8:
						cods.append(atual)
						atual = 0
						nb = 0
		subindo = not subindo
		j -= 2
	# blocos de correção de erros
	var tab: Array = RS[(ver - 1) * 4 + nivel]
	var blocos: Array = []
	var k := 0
	while k < tab.size():
		for _n in tab[k]:
			blocos.append([tab[k + 1], tab[k + 2]])
		k += 3
	var ec: int = blocos[0][0] - blocos[0][1]
	var nbl := blocos.size()
	var arr: Array = []
	for bl in blocos:
		var a: Array = []
		a.resize(bl[0])
		a.fill(0)
		arr.append(a)
	var curto: int = blocos[0][0]
	var longo_ini := nbl
	for bi in nbl:
		if blocos[bi][0] != curto:
			longo_ini = bi
			break
	var curto_dados := curto - ec
	var off := 0
	var total_cods := cods.size()
	for i in curto_dados:
		for bi in nbl:
			if off >= total_cods:
				return ""
			arr[bi][i] = cods[off]
			off += 1
	for bi in range(longo_ini, nbl):
		if off >= total_cods:
			return ""
		arr[bi][curto_dados] = cods[off]
		off += 1
	var maxl: int = blocos[nbl - 1][0]
	for i in range(curto_dados, maxl):
		for bi in nbl:
			var io := i if bi < longo_ini else i + 1
			if io < arr[bi].size():
				if off >= total_cods:
					return ""
				arr[bi][io] = cods[off]
				off += 1
	var dados := PackedInt32Array()
	for bi in nbl:
		var bloco := _rs_corrigir(PackedInt32Array(arr[bi]), ec)
		if bloco.is_empty():
			return ""
		for i in int(blocos[bi][1]):
			dados.append(bloco[i])
	return _ler_bits(dados, ver)

static func _ler_bits(dados: PackedInt32Array, ver: int) -> String:
	var leitor := {"pos": 0, "dados": dados, "total": dados.size() * 8}
	var saida := PackedByteArray()
	while int(leitor["pos"]) + 4 <= int(leitor["total"]):
		var modo := _ler(leitor, 4)
		if modo <= 0:
			break
		if modo == 4:
			var n := _ler(leitor, 8 if ver < 10 else 16)
			for _i in n:
				saida.append(_ler(leitor, 8) & 0xFF)
		elif modo == 2:
			var n := _ler(leitor, 9 if ver < 10 else 11)
			while n >= 2:
				var v := _ler(leitor, 11)
				saida.append(ALNUM.unicode_at(clampi(v / 45, 0, 44)))
				saida.append(ALNUM.unicode_at(clampi(v % 45, 0, 44)))
				n -= 2
			if n == 1:
				saida.append(ALNUM.unicode_at(clampi(_ler(leitor, 6), 0, 44)))
		elif modo == 1:
			var n := _ler(leitor, 10 if ver < 10 else 12)
			while n >= 3:
				saida.append_array(("%03d" % _ler(leitor, 10)).to_ascii_buffer())
				n -= 3
			if n == 2:
				saida.append_array(("%02d" % _ler(leitor, 7)).to_ascii_buffer())
			elif n == 1:
				saida.append_array(("%d" % _ler(leitor, 4)).to_ascii_buffer())
		elif modo == 7:
			_ler(leitor, 8)
		else:
			return ""
	return saida.get_string_from_utf8()

static func _ler(leitor: Dictionary, n: int) -> int:
	var v := 0
	var dados: PackedInt32Array = leitor["dados"]
	for _i in n:
		var p: int = leitor["pos"]
		if p >= int(leitor["total"]):
			return -1
		v = (v << 1) | ((dados[p >> 3] >> (7 - (p & 7))) & 1)
		leitor["pos"] = p + 1
	return v

# ------------------------------------------------------------ Reed-Solomon em GF(256)
static func _mul(a: int, b: int) -> int:
	if a == 0 or b == 0:
		return 0
	return _exp[_log[a] + _log[b]]

static func _inv(a: int) -> int:
	return _exp[255 - _log[a]]

## Polinômios: maior grau primeiro, sem zeros à esquerda.
static func _p_norm(c: PackedInt32Array) -> PackedInt32Array:
	var i := 0
	while i < c.size() - 1 and c[i] == 0:
		i += 1
	return c.slice(i)

static func _p_grau(p: PackedInt32Array) -> int:
	return p.size() - 1

static func _p_coef(p: PackedInt32Array, d: int) -> int:
	return p[p.size() - 1 - d]

static func _p_zero(p: PackedInt32Array) -> bool:
	return p[0] == 0

static func _p_valor(p: PackedInt32Array, a: int) -> int:
	if a == 0:
		return _p_coef(p, 0)
	var r := 0
	for c in p:
		r = _mul(a, r) ^ c
	return r

static func _p_soma(a: PackedInt32Array, b: PackedInt32Array) -> PackedInt32Array:
	if _p_zero(a):
		return b
	if _p_zero(b):
		return a
	var maior := a
	var menor := b
	if a.size() < b.size():
		maior = b
		menor = a
	var r := maior.duplicate()
	var off := maior.size() - menor.size()
	for i in menor.size():
		r[off + i] ^= menor[i]
	return _p_norm(r)

static func _p_vezes(a: PackedInt32Array, b: PackedInt32Array) -> PackedInt32Array:
	if _p_zero(a) or _p_zero(b):
		return PackedInt32Array([0])
	var r := PackedInt32Array()
	r.resize(a.size() + b.size() - 1)
	for i in a.size():
		for j in b.size():
			r[i + j] ^= _mul(a[i], b[j])
	return _p_norm(r)

static func _p_escala(a: PackedInt32Array, s: int) -> PackedInt32Array:
	if s == 0:
		return PackedInt32Array([0])
	var r := PackedInt32Array()
	for c in a:
		r.append(_mul(c, s))
	return _p_norm(r)

static func _p_mono(d: int, c: int) -> PackedInt32Array:
	if c == 0:
		return PackedInt32Array([0])
	var r := PackedInt32Array([c])
	r.resize(d + 1)
	return r

static func _p_vezes_mono(a: PackedInt32Array, d: int, c: int) -> PackedInt32Array:
	if c == 0:
		return PackedInt32Array([0])
	var r := PackedInt32Array()
	for x in a:
		r.append(_mul(x, c))
	r.resize(a.size() + d)
	return _p_norm(r)

## Devolve o bloco corrigido, ou vazio se os erros passam do que o código aguenta.
static func _rs_corrigir(entrada: PackedInt32Array, ec: int) -> PackedInt32Array:
	var dados := entrada.duplicate()
	var falha := PackedInt32Array()
	var sind := PackedInt32Array()
	sind.resize(ec)
	var ok := true
	for i in ec:
		var v := _p_valor(dados, _exp[i])
		sind[ec - 1 - i] = v
		if v != 0:
			ok = false
	if ok:
		return dados
	var a := _p_mono(ec, 1)
	var b := _p_norm(sind)
	if _p_grau(a) < _p_grau(b):
		var tmp := a
		a = b
		b = tmp
	var r_ant := a
	var r := b
	var t_ant := PackedInt32Array([0])
	var t := PackedInt32Array([1])
	while 2 * _p_grau(r) >= ec:
		var r_aa := r_ant
		var t_aa := t_ant
		r_ant = r
		t_ant = t
		if _p_zero(r_ant):
			return falha
		r = r_aa
		var q := PackedInt32Array([0])
		var dlt := _inv(_p_coef(r_ant, _p_grau(r_ant)))
		while _p_grau(r) >= _p_grau(r_ant) and not _p_zero(r):
			var dd := _p_grau(r) - _p_grau(r_ant)
			var sc := _mul(_p_coef(r, _p_grau(r)), dlt)
			q = _p_soma(q, _p_mono(dd, sc))
			r = _p_soma(r, _p_vezes_mono(r_ant, dd, sc))
		t = _p_soma(_p_vezes(q, t_ant), t_aa)
		if _p_grau(r) >= _p_grau(r_ant):
			return falha
	var s0 := _p_coef(t, 0)
	if s0 == 0:
		return falha
	var inv := _inv(s0)
	var sigma := _p_escala(t, inv)
	var omega := _p_escala(r, inv)
	var ne := _p_grau(sigma)
	var locs := PackedInt32Array()
	if ne == 1:
		locs.append(_p_coef(sigma, 1))
	else:
		for i in range(1, 256):
			if locs.size() >= ne:
				break
			if _p_valor(sigma, i) == 0:
				locs.append(_inv(i))
		if locs.size() != ne:
			return falha
	for i in locs.size():
		var xi := _inv(locs[i])
		var den := 1
		for j in locs.size():
			if i != j:
				var termo := _mul(locs[j], xi)
				var tp := (termo | 1) if (termo & 1) == 0 else (termo & ~1)
				den = _mul(den, tp)
		var mag := _mul(_p_valor(omega, xi), _inv(den))
		var pos := dados.size() - 1 - _log[locs[i]]
		if pos < 0:
			return falha
		dados[pos] ^= mag
	return dados
