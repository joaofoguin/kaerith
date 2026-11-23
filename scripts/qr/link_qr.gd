class_name LinkQR
extends RefCounted
## QR lido pela câmera comum do celular (fora do jogo).
## O QR guarda um link do site: https://kaerith-d9bef.web.app/#qr=KAE1.<número>.<tipo>.<Elite>.<fuso>.<assinatura>
## A câmera do celular abre o site; o jogo pega o código do endereço e faz a ação (Recurso, Baú, Inimigo, Evento).
## O que vale é a assinatura (CodigoQR), não o endereço: um link editado é recusado como qualquer QR falso.
## O código fica guardado no navegador (localStorage) até o jogador chegar ao Início (ex.: novo jogador no tutorial).

const SITE := "https://kaerith-d9bef.web.app/"
const CHAVE := "kaerith_qr_link"

## Na Web: tira o "#qr=..." do endereço e guarda. Devolve o código guardado ("" se não há).
static func capturar() -> String:
	if not OS.has_feature("web"):
		return ""
	var js := """(function () {
		var k = '%s';
		try {
			var h = location.hash || '';
			if (h.indexOf('#qr=') === 0) {
				localStorage.setItem(k, decodeURIComponent(h.slice(4)));
				history.replaceState(null, '', location.pathname + location.search);
			}
			return localStorage.getItem(k) || '';
		} catch (e) { return ''; }
	}())""" % CHAVE
	return str(JavaScriptBridge.eval(js, true))

static func _esquecer() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { localStorage.removeItem('%s'); } catch (e) {} ''" % CHAVE, true)

## Chamar quando o jogo mostra o Início: se o site foi aberto por um QR, abre a tela do QR já com o código.
## Antes do Início (Prólogo, criação, tutorial) só guarda. Devolve true se abriu.
static func abrir_pendente(principal: Node) -> bool:
	var t := capturar()
	if t == "" or str(Jogo.dados.get("etapa", "")) != "pronto":
		return false
	_esquecer()
	var tela = load("res://scripts/telas/ler_qr.gd").new()
	tela.texto_inicial = t
	principal.abrir_tela_cheia(tela)
	return true

## Texto do QR → formato interno "KAE1|...|assinatura". Aceita o link do site e o formato antigo (impresso antes).
static func normalizar(texto: String) -> String:
	var t := texto.strip_edges()
	var i := t.find("qr=")
	if t.begins_with("http") and i >= 0:
		t = t.substr(i + 3)
		var fim := t.find("&")
		if fim >= 0:
			t = t.substr(0, fim)
		t = t.uri_decode().replace(".", "|")
	return t
