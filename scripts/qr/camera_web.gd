class_name CameraWeb
extends RefCounted
## Câmera e leitura de QR na versão Web (navegador, PWA ou webview).
## Quem faz o trabalho é o KaerithWeb, um JavaScript embutido na página (web/kaerith_shell.html): ele abre a câmera do
## navegador e procura o QR (BarcodeDetector ou jsQR, sem internet). Daqui só chega o TEXTO do código; a assinatura
## continua sendo conferida pelo CodigoQR, no próprio aparelho. No Android nativo nada disto é usado.

## Lado da prévia que o JavaScript entrega (RGBA, LADO × LADO).
const LADO := 300

## Estamos no navegador e a página tem o KaerithWeb?
static func ativo() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("typeof window.KaerithWeb", true)) == "object"

static func _js(codigo: String):
	return JavaScriptBridge.eval("window.KaerithWeb." + codigo, true)

static func ligar() -> void:
	_js("ligar()")

static func desligar() -> void:
	_js("desligar()")

## parada | pedindo | ligada | negada | sem_camera | inseguro (página sem HTTPS)
static func estado() -> String:
	var e = _js("estado()")
	return str(e) if e is String else "sem_camera"

## Quadro atual da câmera (recorte quadrado do meio, RGBA). Vazio se ainda não há imagem.
static func quadro() -> PackedByteArray:
	var q = _js("quadro()")
	return q if q is PackedByteArray else PackedByteArray()

## Texto do último QR que a câmera achou ("" se nenhum). Cada leitura é entregue uma vez só.
static func lido() -> String:
	var t = _js("pegarLido()")
	return str(t) if t is String else ""

## Abre o seletor de imagem do navegador (no celular também deixa tirar foto).
static func escolher_imagem() -> void:
	_js("escolherImagem()")

## Resultado do seletor: "" (ainda nada), o texto do QR, "!nada" (imagem sem QR) ou "!erro" (não abriu).
static func resultado_imagem() -> String:
	var t = _js("pegarImagem()")
	return str(t) if t is String else ""

static func vibrar(ms: int) -> void:
	_js("vibrar(%d)" % ms)
