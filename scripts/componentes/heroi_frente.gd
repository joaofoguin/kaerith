class_name HeroiFrente
extends Control
## Herói de frente, montado pelas camadas escolhidas, com a respiração aprovada (idle5.py):
## 4 quadros com deslocamento [0, 0, 1, 1]; braço, arma, cabelo, capacete e barba descem inteiros,
## corpo/roupa/armadura descem só da linha 48 para cima (as pernas ficam paradas).

const RIGIDAS := ["braco", "arma", "cabelo", "capacete", "barba"]
const DESLOCA := [0, 0, 1, 1]

var escala := 2
var _camadas: Array = []      # [{"peca": {"tex","rect"}, "rigida": bool}]
var _q := 0
var _tempo := 0.0

func vestir(nomes: Array) -> void:
	_camadas.clear()
	for n in nomes:
		var p := Artes.heroi_frente(n)
		if p.is_empty():
			continue
		var rig := false
		var tipo := str(n).split("@")[0]
		if not tipo.begins_with("armadura"):        # "armadura" também começa com "arma"
			for r in RIGIDAS:
				if tipo.begins_with(r):
					rig = true
		_camadas.append({"peca": p, "rigida": rig})
	queue_redraw()

func _process(delta: float) -> void:
	_tempo += delta
	if _tempo >= 0.125:
		_tempo = 0.0
		_q = (_q + 1) % 4
		queue_redraw()

func _draw() -> void:
	var d: int = DESLOCA[_q]
	var origem := Vector2(floor(size.x / 2.0 - 24 * escala), size.y - 64 * escala)
	for c in _camadas:
		var r: Rect2 = c["peca"]["rect"]
		var tex: Texture2D = c["peca"]["tex"]
		if c["rigida"]:
			draw_texture_rect_region(tex, Rect2(origem + Vector2(0, d * escala), Vector2(48, 64) * escala), r)
		else:
			# pernas (linhas 48–63) paradas, depois o tronco (0–47) deslocado por cima
			draw_texture_rect_region(tex, Rect2(origem + Vector2(0, 48 * escala), Vector2(48, 16) * escala), Rect2(r.position + Vector2(0, 48), Vector2(48, 16)))
			draw_texture_rect_region(tex, Rect2(origem + Vector2(0, d * escala), Vector2(48, 48) * escala), Rect2(r.position, Vector2(48, 48)))
