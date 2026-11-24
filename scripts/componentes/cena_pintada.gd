class_name CenaPintada
extends Control
## Cena pintada em camadas (artes/cenas/<cena>_<camada>.png, 220×320 mostradas em ×2) com parallax lento,
## camadas que respiram (brilho, aurora) e partículas desenhadas por cima. Usada no Prólogo e na chegada.

const CENAS := {
	"silencio": {"camadas": ["ceu", "nucleo", "poeira"], "particulas": ["estrelas", "ecos"], "pulsa": ["nucleo"]},
	"eras": {"camadas": ["ceu", "longe", "ruinas", "perto"], "particulas": ["poeira", "ecos"], "pulsa": []},
	"ouvinte": {"camadas": ["ceu", "aurora", "longe", "colina", "perto"], "particulas": ["estrelas", "vagalumes"], "pulsa": ["aurora"]},
	"aviso": {"camadas": ["ceu", "longe", "campo", "perto"], "particulas": ["neve", "ecos"], "pulsa": []},
	"auren": {"camadas": ["ceu", "longe", "campo", "perto"], "particulas": ["polen"], "pulsa": []},
	# cutscene do fim do Ato 1 (a criança na Mata dos Ecos Velados): ferramentas/montar_cena_mata.py
	"mata": {"camadas": ["ceu", "longe", "arvores", "clareira", "perto"], "particulas": ["vagalumes"], "pulsa": []},
}
const COR := {
	"estrelas": Color(0.9, 0.95, 1.0), "ecos": Color(0.6, 0.9, 1.0), "poeira": Color(1.0, 0.8, 0.5),
	"vagalumes": Color(0.6, 1.0, 0.7), "neve": Color(0.85, 0.93, 1.0), "polen": Color(1.0, 0.92, 0.6),
}

var nome := ""
var duracao := 16.0            # tempo do movimento das camadas (s)
var _camadas: Array = []       # [TextureRect, distância do movimento]
var _pulsam: Array = []
var _part: Array = []          # [tipo, posição, velocidade, fase, tamanho]
var _tempo := 0.0
var _rng := RandomNumberGenerator.new()
var _fx: Control              # partículas por cima das camadas (o _draw do pai fica atrás dos filhos)

func _init(cena := "") -> void:
	nome = cena

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rng.seed = hash(nome)
	var dados: Dictionary = CENAS[nome]
	var lista: Array = dados["camadas"]
	for i in lista.size():
		var tr_ := TextureRect.new()
		tr_.texture = load("res://artes/cenas/%s_%s.png" % [nome, lista[i]])
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_SCALE
		tr_.size = Vector2(220, 320)
		tr_.scale = Vector2(2, 2)
		tr_.name = lista[i]
		tr_.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr_.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(tr_)
		# camadas de trás andam pouco; as da frente andam mais (falso 3D)
		var dist := 12.0 + 68.0 * float(i) / maxi(1, lista.size() - 1)
		_camadas.append([tr_, dist])
		if lista[i] in dados["pulsa"]:
			_pulsam.append(tr_)
	_fx = Control.new()
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_desenhar)
	add_child(_fx)
	for tipo in dados["particulas"]:
		var qtd: int = {"estrelas": 40, "ecos": 26, "poeira": 34, "vagalumes": 22, "neve": 60, "polen": 36}[tipo]
		for k in qtd:
			_part.append(_nova(tipo, true))

func _nova(tipo: String, espalhar: bool) -> Array:
	var p := Vector2(_rng.randf_range(0, 360), _rng.randf_range(0, 640))
	var v := Vector2.ZERO
	match tipo:
		"ecos":
			v = Vector2(_rng.randf_range(-4, 4), -_rng.randf_range(8, 22))
			if not espalhar:
				p.y = 650
		"poeira", "polen":
			v = Vector2(_rng.randf_range(4, 14), _rng.randf_range(-5, 3))
		"vagalumes":
			p.y = _rng.randf_range(420, 620)
			v = Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
		"neve":
			v = Vector2(_rng.randf_range(6, 16), _rng.randf_range(20, 46))
			if not espalhar:
				p.y = -6
		"estrelas":
			p.y = _rng.randf_range(0, 420)
	return [tipo, p, v, _rng.randf() * TAU, 2 if _rng.randf() < 0.7 else 4]

func _process(delta: float) -> void:
	_tempo += delta
	var t := clampf(_tempo / duracao, 0.0, 1.0)
	var suave := t * t * (3.0 - 2.0 * t)
	for c in _camadas:
		var tr_: TextureRect = c[0]
		tr_.position.x = round(-float(c[1]) * suave / 2.0) * 2.0      # passo de 2 px (pixel da arte)
	for tr_ in _pulsam:
		tr_.modulate.a = 0.75 + 0.25 * sin(_tempo * 1.3)
	for p in _part:
		p[1] += p[2] * delta
		if p[0] == "vagalumes":
			p[2] = p[2].rotated(sin(_tempo + p[3]) * delta * 1.5)
		if p[1].y < -8 or p[1].y > 652 or p[1].x > 368 or p[1].x < -8:
			var n := _nova(p[0], false)
			if p[0] in ["poeira", "polen"]:
				n[1].x = -4
			for i in 5:
				p[i] = n[i]
	_fx.queue_redraw()

func _desenhar() -> void:
	for p in _part:
		var tipo: String = p[0]
		var b := 0.5 + 0.5 * sin(_tempo * (3.0 if tipo == "estrelas" else 1.6) + p[3])
		var cor: Color = COR[tipo]
		var pos := Vector2(floor(p[1].x / 2) * 2, floor(p[1].y / 2) * 2)
		var s: int = p[4]
		match tipo:
			"estrelas":
				if b > 0.82:
					cor.a = (b - 0.82) * 5.0
					_fx.draw_rect(Rect2(pos, Vector2(2, 2)), cor)
					_fx.draw_rect(Rect2(pos - Vector2(2, 0), Vector2(6, 2)), Color(cor, cor.a * 0.35))
					_fx.draw_rect(Rect2(pos - Vector2(0, 2), Vector2(2, 6)), Color(cor, cor.a * 0.35))
			"ecos", "vagalumes":
				cor.a = 0.35 + 0.6 * b
				_fx.draw_rect(Rect2(pos - Vector2(2, 2), Vector2(s + 4, s + 4)), Color(cor, cor.a * 0.18))
				_fx.draw_rect(Rect2(pos, Vector2(s, s)), cor)
				if tipo == "ecos":
					_fx.draw_rect(Rect2(pos + Vector2(0, s + 2), Vector2(s, 4)), Color(cor, cor.a * 0.3))
			_:
				cor.a = 0.25 + 0.5 * b
				_fx.draw_rect(Rect2(pos, Vector2(2, 2)), cor)

## Onde um ponto da pintura (coordenadas da arte 220×320) está agora na tela, com o parallax da camada.
func ponto(camada: String, na_arte: Vector2) -> Vector2:
	for c in _camadas:
		var tr_: TextureRect = c[0]
		if tr_.name == camada:
			return tr_.position + na_arte * 2.0
	return na_arte * 2.0
