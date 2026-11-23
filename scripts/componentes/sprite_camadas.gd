class_name SpriteCamadas
extends Control
## Desenha uma ou mais camadas (tiras de quadros) empilhadas, animadas e em escala inteira.
## Ancorado embaixo e no centro, então quadros mais largos (ataques) ficam alinhados com o parado.

signal terminou

var camadas: Array = []          # cada uma: {"tex", "rect"} vinda de Artes
var largura_quadro := 48
var altura_quadro := 64
var sequencia: Array = [0]       # índices dos quadros dentro da tira
var fps := 8.0
var repetir := true
var escala := 2
## x (dentro do quadro) que fica no centro do controle; -1 = metade do quadro
var ancora_x := -1.0

var _pos := 0
var _tempo := 0.0
var _ativo := true

func tocar(nova_sequencia: Array, novo_fps: float, em_loop: bool) -> void:
	sequencia = nova_sequencia
	fps = novo_fps
	repetir = em_loop
	_pos = 0
	_tempo = 0.0
	_ativo = true
	queue_redraw()

func _process(delta: float) -> void:
	if not _ativo or sequencia.size() <= 1:
		return
	_tempo += delta
	var passo := 1.0 / fps
	while _tempo >= passo:
		_tempo -= passo
		_pos += 1
		if _pos >= sequencia.size():
			if repetir:
				_pos = 0
			else:
				_pos = sequencia.size() - 1
				_ativo = false
				queue_redraw()
				terminou.emit()
				return
		queue_redraw()

func _draw() -> void:
	var q := int(sequencia[min(_pos, sequencia.size() - 1)])
	var w := largura_quadro * escala
	var h := altura_quadro * escala
	var ax := ancora_x if ancora_x >= 0.0 else largura_quadro / 2.0
	var destino := Rect2(Vector2(floor(size.x / 2.0 - ax * escala), size.y - h), Vector2(w, h))
	for c in camadas:
		if c.is_empty():
			continue
		var r: Rect2 = c["rect"]
		var origem := Rect2(r.position.x + q * largura_quadro, r.position.y, largura_quadro, altura_quadro)
		draw_texture_rect_region(c["tex"], destino, origem)
