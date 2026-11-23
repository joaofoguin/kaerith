# Histórico de versões — Kaerith: O Despertar

Como numeramos: **MAIOR.MENOR.CORREÇÃO** (ex.: 0.3.0).
- **MAIOR**: 1 quando o jogo for lançado nas lojas. Até lá fica 0.
- **MENOR**: sobe a cada leva de novidades (sistemas, telas, regras).
- **CORREÇÃO**: sobe quando a versão só conserta erros.

Onde o número fica (mude os três juntos):
1. `project.godot` → `config/version` (Projeto > Configurações do Projeto > Aplicação > Config > Versão). É o que aparece no jogo (Configurações > Ajuda e sobre).
2. `export_presets.cfg` → `version/name` dos presets **Android** e **Android ADM**.
3. `export_presets.cfg` → `version/code` dos dois presets Android: MAIOR×10000 + MENOR×100 + CORREÇÃO (0.3.0 = 300, 0.3.1 = 301, 1.0.0 = 10000). A Play Store exige que esse número sempre suba.

Versões de distribuição (desde a 0.3.0):
- **Pública** (presets `Android` e `Web`): para os jogadores, sem nenhum botão de teste.
- **ADM** (presets `Android ADM` e `Web ADM`, e o jogo rodando pelo editor): com os botões de teste e "ADM" ao lado do número da versão. O APK ADM tem outro pacote (`com.kaerith.despertar.adm`), então instala ao lado do público com save separado.

---

## 0.6.1 — 23/11/2026
**Correções**
- Sair da conta (Configurações > Conta > Sair) agora volta para a tela de entrada (Entrar com Google / Jogar como visitante). Antes caía no Início: duas transições de tela se cruzavam e a segunda fechava a tela de entrada logo depois de abrir. O botão de teste "Reiniciar" (ADM) tinha o mesmo problema e também foi corrigido.
- Se uma sincronização com a nuvem ainda estava em andamento na hora de sair, ela não traz mais de volta o progresso da conta antiga nem manda o progresso zerado para o ranking.

## 0.6.0 — 23/11/2026
**Som (primeira versão, PROVISÓRIA)**
- Músicas de fundo em chiptune 16 bits, em laço: tema (Início, mapa, Loja e demais telas), combate, chefe de ato e história (Prólogo, Chegada, criação do herói e Despertar). Troca suave entre elas.
- Efeitos: toque em todo botão, bips do diálogo (sem vozes), ataque, habilidade elemental, dano, crítico, errou, cura, poção, queda, nova onda, vitória, derrota, subiu de nível, QR lido, QR inválido, baú aberto, prêmio e o Despertar.
- Tudo é gerado por código (`audio/fonte/montar_audio.py`, Python + numpy + ffmpeg), sem nenhuma música ou som de outro jogo. Para mudar, edite o script e rode de novo.
- Configurações > Som: os controles de Música e Efeitos já existentes agora valem (0 = mudo).
- Web: o navegador só libera o som depois do primeiro toque na tela; a música começa nesse toque. Os sons vão dentro do `index.pck`, que o service worker já guarda para jogar offline.
- Código: `scripts/som.gd` (fica em `Jogo.som`).

**Habilidades**
- No Despertar, o herói só fica com a habilidade elemental que escolheu. As outras 2 iniciais do elemento não aparecem mais liberadas no Inventário; elas podem ser aprendidas depois pelos Orbes, como as demais.

## 0.5.2 — 23/11/2026
**Combate**
- Nível dos inimigos: sobe 1 a cada 15 fases do mapa. Fases 1–15 = NV2, 16–30 = NV3, 31–45 = NV4, e assim por diante até NV21 na fase 300 (antes ia até NV23, num passo irregular de ~14 fases). O mínimo de NV2 a partir do 2º combate do tutorial continua. Vale também para o Evento do QR, que usa o nível da fase atual do jogador.

## 0.5.1 — 22/11/2026
**Correções da versão Web e da conta Google**
- Progresso na nuvem sincroniza entre aparelhos: antes de enviar, o jogo confere a nuvem. Se outro aparelho salvou depois e aqui nada mudou, baixa o mais recente; se os dois mudaram, fica o mais avançado (nível e XP) e o outro vira cópia no aparelho (`save_conflito.json`). Confere ao abrir e ao voltar para o jogo.
- Service worker próprio (`hospedagem/paginas/index.service.worker.js`): a versão nova é baixada inteira em segundo plano (inclusive o motor e o pacote), então o jogo abre offline depois de atualizar. Aviso "Nova versão do jogo. Toque para atualizar"; sem tocar, troca na próxima abertura. Na primeira troca (vindo do service worker do Godot) assume sozinho.
- `publicar.bat` marca a versão do service worker a cada publicação.
- Tela de carregamento do jogo (Web): procura atualização (baixa com porcentagem e recarrega antes do Início) e, na conta Google, sincroniza o progresso antes de montar as telas. O aviso "Nova versão" só aparece se a versão chegar com o jogo já aberto.

## 0.5.0 — 22/11/2026
**Eventos e atos pelo Firebase**
- Temporada 1 começa em 22/11/2026, à 00h de Brasília. Os atos abrem em 22/11, 12/12, 06/01/2027 e 31/01/2027, e a temporada acaba em 20/02/2027.
- O botão Evento do Início é ligado pelo Firebase (`config/inicio.evento`) e vem escondido.
- Cada ato tem data de abertura (`config/temporada.ato_2` a `ato_4`; sem o campo, vale o calendário). Quem vence o chefe antes da data espera na névoa, com a data na placa, e o popup da fase fica sem "Jogar" enquanto o ato está fechado.
- O ato acaba quando o próximo abre (pela data do Firebase ou pelo calendário). O aviso de ato novo usa o começo do ato.
- Promoções livres: modelo "livre" no Firestore, com ícone, cena e vitrine (PNG em `hospedagem/site/promocoes/`, baixado e guardado no aparelho), até 3 itens de conteúdo e cor própria.
- Ao abrir o jogo, depois do login, a tela de carregamento tem o passo "novidades": baixa a config e as artes das promoções (até 6 s) antes do Início.

**QR Code**
- QR de Recurso: espera de 3 h por QR e por jogador antes de ler o mesmo de novo.

**Correções**
- Promoções: o popup quebrava a abertura do jogo (texto traduzido dentro de função estática).

## 0.4.0 — 22/11/2026
**Firebase (sem precisar exportar o jogo de novo)**
- Promoções e eventos ligados, desligados e criados pelo Firestore (coleção `promocoes`), guardados no save para funcionar offline. As compras com dinheiro real continuam bloqueadas.
- QR Codes podem ser bloqueados pelo Firestore (coleção `qr_bloqueados`). O passo a passo está em `hospedagem/FIREBASE_PROMOCOES_E_QR.md`.

**QR Code**
- O QR é um link do site: lido pela câmera comum do celular, abre o jogo e já faz a ação.
- A hora do QR é conferida no servidor.
- Baú do QR só 1 vez por dia.
- As opções de teste do QR foram removidas.

**Correções**
- Aviso "Cannot convert argument 1 from Object to Object" (`_liberar_rolagem`) no console.

## 0.3.0 — 22/11/2026
**Combate e tutorial**
- Varredura causa 100% da Força em todos os inimigos (era 120%).
- Do 2º combate do tutorial em diante, os inimigos têm pelo menos nível 2 (as fases 1–14 do mapa também).
- Tutorial 2: os inimigos podem cair antes do Despertar; só o último de pé espera o herói cair. Depois do Despertar o herói pode morrer normalmente.
- Despertar: as 3 habilidades viraram cartões na cor do elemento (ícone, nome, tipo, usos e efeito). Na troca, a habilidade nova fica numa caixa no topo; segurar um ataque comum mostra o balão com o que ele faz; tocar escolhe qual sai. Botão "Escolher outra habilidade".

**Inventário e Orbes**
- Tocar nos ícones de atributo (e na Vida) abre o balão explicativo, igual à ficha do personagem.
- Orbes mais fáceis de obter e evoluir (PROVISÓRIO): evoluir custa 120/200/320/480/680/920/1200/1520/1880 fragmentos (níveis 2–10) e pede o nível 5 + 5 por nível do Orbe; Orbes novos custam 60/100/160/240/340 e pedem os níveis 5/10/15/20/25.
- Mais fragmentos nas fases (PROVISÓRIO): 60% de chance de 2–4 em qualquer fase (75% com bandido de elemento); Elite 8–14, Suprema 12–18, chefe 25–35.
- Testes (ADM): "Acumular Orbes" (+1 nível em todos os Orbes) e "Evoluir agora sem custo" no popup do Orbe.

**Loja e anúncios**
- Pacotes de cristais e promoções (dinheiro real) bloqueados, com cadeado e "Em breve".
- Vídeos com prêmio: AdMob no Android (plugin da Poing Studios) e H5 Games Ads do AdSense na Web, ligados por `dados/anuncios.json`. Sem anúncio disponível, a espera de 5 s continua (na pública, sem a palavra "teste").

**Conta, suporte e versões**
- Botão "Sair da conta" para quem entrou com o Google: salva na nuvem e volta para a tela de entrada.
- Página de suporte (`suporte.html`, com contato e perguntas frequentes) e termos de uso (`termos.html`) no site. Os botões Suporte, Privacidade, Termos e "Sobre o jogo" das Configurações abrem as páginas.
- Política de privacidade atualizada com os anúncios.
- Versão ADM e versão pública; número da versão nas Configurações; este histórico.

## 0.2 — 13/11 a 22/11/2026
- APK Android, online pelo Firebase (ranking, relógio do servidor), rebalanceamento do combate, Orbes, toques (segurar para ver), balões, Bestiário novo.
- Versão Web/PWA com QR pela câmera do navegador, hospedagem no Firebase, login com Google e save na nuvem.

## 0.1 — 04/11 a 12/11/2026
- Etapas 1 a 9: esqueleto, artes, mapa, combate, criação e tutorial com o Despertar, inventário e equipamentos, QR Code com assinatura, save offline e vidas, Loja, Diário e Bestiário.
