extends Node
## Som do jogo (2026-11-23): músicas de fundo e efeitos curtos, todos gerados por código em
## audio/fonte/montar_audio.py (chiptune 16 bits; diálogo com bips, sem vozes — DEFINIDO).
## Fica como filho do Jogo (Jogo.som). Uso: Jogo.som.efeito("ataque"); Jogo.som.bip()
##
## Música: a tela escolhe entrando num grupo. Quem estiver na árvore manda, nesta ordem:
##   "som_historia" (Prólogo, Chegada, criação, Despertar) > "som_chefe" > "som_combate" > tema (o resto).
## Volume: canais "Musica" e "Efeitos" (criados e ajustados por scripts/config.gd, tela Configurações).
## Web: o navegador suspende o áudio (antes do 1º toque, ao trocar de app, tela bloqueada, câmera do QR no
## iPhone). O KaerithAudio do web/kaerith_shell.html religa a cada toque; aqui a música recomeça se tiver parado.
## PROVISÓRIOS (meus): as 4 músicas, o volume de cada efeito e quais momentos têm som.

const PASTA_EF := "res://audio/efeitos/"
const PASTA_MU := "res://audio/musica/"
const VOZES := 8                      # efeitos ao mesmo tempo
const TROCA_S := 0.6                  # tempo da troca de música (some e entra)
const VOLUME_MUSICA_DB := -5.0

## volume próprio de cada efeito (dB); o resto fica em 0
const AJUSTE := {"toque": -9.0, "voltar": -9.0, "bip_1": -12.0, "bip_2": -12.0, "bip_3": -12.0,
	"ataque": -3.0, "condicao": -6.0, "moeda": -4.0}

var _efeitos := {}                    # nome → AudioStream
var _vozes: Array[AudioStreamPlayer] = []
var _prox_voz := 0
var _musica: AudioStreamPlayer
var _faixa := ""                      # música tocando (ou indo tocar)
var _dono := 0                        # tela que pediu a música (outra luta igual = recomeça a música)
var _calada := false                  # vinheta de vitória/derrota: a música fica muda até trocar de tela
var _tween: Tween
var _bip_i := 0
var _bip_ultimo := 0
var _ultimo_toque := 0
var _web_liberado := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOZES:
		var p := AudioStreamPlayer.new()
		p.bus = "Efeitos"
		add_child(p)
		_vozes.append(p)
	_musica = AudioStreamPlayer.new()
	_musica.bus = "Musica"
	_musica.volume_db = VOLUME_MUSICA_DB
	add_child(_musica)
	_musica.finished.connect(_musica_acabou)      # garantia do laço (na Web o som toca como "sample")
	var vigia := Timer.new()
	vigia.wait_time = 0.25
	vigia.autostart = true
	vigia.timeout.connect(_conferir_musica)
	add_child(vigia)

## Toca um efeito (nome do arquivo em audio/efeitos, sem .wav). Som que falta é ignorado.
func efeito(nome: String, tom := 1.0) -> void:
	var s := _carregar_efeito(nome)
	if s == null:
		return
	var p := _vozes[_prox_voz]
	_prox_voz = (_prox_voz + 1) % _vozes.size()
	p.stream = s
	p.volume_db = float(AJUSTE.get(nome, 0.0))
	p.pitch_scale = tom
	p.play()

## Toque de botão (chamado pelo Tema em todo botão). Dois toques colados viram um som só.
func toque() -> void:
	var agora := Time.get_ticks_msec()
	if agora - _ultimo_toque < 60:
		return
	_ultimo_toque = agora
	efeito("toque")

## Bip do diálogo: um a cada 2 letras (no máximo ~18 por segundo), alternando 3 alturas.
func bip() -> void:
	var agora := Time.get_ticks_msec()
	if agora - _bip_ultimo < 55:
		return
	_bip_ultimo = agora
	_bip_i = (_bip_i + 1) % 3
	efeito("bip_%d" % (_bip_i + 1))

## Vinheta de fim de luta: cala a música da luta e toca a vinheta (a música volta ao sair da tela).
func vinheta(nome: String) -> void:
	_calada = true
	_sumir_musica(0.25)
	efeito(nome)

func _carregar_efeito(nome: String) -> AudioStream:
	if _efeitos.has(nome):
		return _efeitos[nome]
	var caminho := PASTA_EF + nome + ".wav"
	var s: AudioStream = null
	if ResourceLoader.exists(caminho):
		s = load(caminho) as AudioStream
	_efeitos[nome] = s
	return s

# ------------------------------------------------------------ música
func _conferir_musica() -> void:
	var quer := "tema"
	var dono := 0
	for par: Array in [["som_historia", "historia"], ["som_chefe", "chefe"], ["som_combate", "combate"]]:
		var n := get_tree().get_first_node_in_group(par[0])
		if n != null:
			quer = par[1]
			dono = n.get_instance_id()
			break
	if quer != _faixa or (_calada and dono != _dono):
		_calada = false
		_dono = dono
		_trocar(quer)
	_dono = dono

func _trocar(nome: String) -> void:
	_faixa = nome
	var caminho := PASTA_MU + nome + ".ogg"
	if not ResourceLoader.exists(caminho):
		_musica.stop()
		return
	var s := load(caminho) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	if _tween:
		_tween.kill()
	if not _musica.playing or _calada:
		_entrar(s)
		return
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(_musica, "volume_db", -40.0, TROCA_S * 0.5)
	_tween.tween_callback(_entrar.bind(s))

func _entrar(s: AudioStream) -> void:
	_musica.stream = s
	_musica.volume_db = -30.0
	_musica.play()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(_musica, "volume_db", VOLUME_MUSICA_DB, TROCA_S)

func _sumir_musica(tempo: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_ignore_time_scale(true)
	_tween.tween_property(_musica, "volume_db", -60.0, tempo)
	_tween.tween_callback(_musica.stop)

func _musica_acabou() -> void:
	if not _calada and _musica.stream != null:
		_musica.play()

## A música devia estar tocando e não está (áudio suspenso pelo navegador ou pelo sistema): recomeça.
func _religar_musica() -> void:
	if _calada or _musica.stream == null:
		return
	if not _musica.playing:
		_musica.volume_db = VOLUME_MUSICA_DB
		_musica.play()

# ------------------------------------------------------------ Web: religar o áudio
func _input(evento: InputEvent) -> void:
	if not OS.has_feature("web"):
		return
	if (evento is InputEventMouseButton or evento is InputEventScreenTouch) and evento.is_pressed():
		_acordar_web()
		if not _web_liberado:
			_web_liberado = true
			# a música pedida antes do 1º toque ficou presa com o áudio suspenso: recomeça agora
			if not _calada and _musica.stream != null:
				_musica.play.call_deferred()
		else:
			_religar_musica.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_acordar_web()
		_religar_musica.call_deferred()

func _acordar_web() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.KaerithAudio ? String(window.KaerithAudio.acordar()) : ''", true)

## Estado do áudio do navegador (para conferir no console/Configurações): "running", "suspended"...
func estado_web() -> String:
	if not OS.has_feature("web"):
		return "nativo"
	return str(JavaScriptBridge.eval("window.KaerithAudio ? window.KaerithAudio.estado() : 'sem_shell'", true))
