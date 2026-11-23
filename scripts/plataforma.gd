class_name Plataforma
extends RefCounted
## Onde o jogo está rodando. Na Web, OS.has_feature("mobile") é sempre falso, mesmo no navegador do celular.

static func web() -> bool:
	return OS.has_feature("web")

## Celular ou tablet: app nativo ou navegador do Android/iPhone.
static func celular() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
