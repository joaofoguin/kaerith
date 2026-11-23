extends RefCounted
## Configurações do jogador (tela Configurações), guardadas no save em dados["config"].
## Uso: const CONFIG := preload("res://scripts/config.gd"); CONFIG.valor("musica"); CONFIG.mudar("musica", 80)
## PROVISÓRIO (meu): o jogo ainda não tem áudio, notificações nem vibração; os ajustes já ficam salvos e
## os volumes já vão para os canais de áudio "Musica" e "Efeitos" (criados aqui), para quando o som chegar.

const PADRAO := {
	"musica": 80,             # 0 a 100
	"efeitos": 100,           # 0 a 100
	"vibracao": true,
	"economia": false,        # economia de bateria: 30 quadros por segundo
	"tremor": true,           # tremor de tela nos golpes fortes
	"notif_vidas": true,      # avisar quando as vidas encherem
	"notif_eventos": true,    # avisar de eventos e promoções
}

static func dados() -> Dictionary:
	if not Jogo.dados.has("config") or typeof(Jogo.dados["config"]) != TYPE_DICTIONARY:
		Jogo.dados["config"] = {}
	var c: Dictionary = Jogo.dados["config"]
	for k in PADRAO:
		if not c.has(k):
			c[k] = PADRAO[k]
	return c

static func valor(chave: String):
	return dados().get(chave, PADRAO.get(chave))

static func mudar(chave: String, v) -> void:
	dados()[chave] = v
	aplicar()
	Jogo.salvar()

## Põe as configurações em efeito (chamado ao abrir o jogo e a cada mudança).
static func aplicar() -> void:
	_volume("Musica", float(valor("musica")))
	_volume("Efeitos", float(valor("efeitos")))
	Engine.max_fps = 30 if bool(valor("economia")) else 60

static func _volume(canal: String, v: float) -> void:
	var i := AudioServer.get_bus_index(canal)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, canal)
		AudioServer.set_bus_send(i, "Master")
	AudioServer.set_bus_mute(i, v <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001) / 100.0))

## Vibração curta (respeita a configuração). Para usar quando o combate tiver vibração.
static func vibrar(ms := 40) -> void:
	if bool(valor("vibracao")):
		Input.vibrate_handheld(ms)

## ID curto para o suporte: o do servidor quando houver, senão um gerado no aparelho.
static func id_jogador() -> String:
	var u := str(Jogo.dados.get("online", {}).get("uid", ""))
	if u != "":
		return u
	if not Jogo.dados.has("id_local"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var letras := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
		var s := ""
		for i in 10:
			s += letras[rng.randi_range(0, letras.length() - 1)]
		Jogo.dados["id_local"] = s
		Jogo.salvar()
	return str(Jogo.dados["id_local"])
