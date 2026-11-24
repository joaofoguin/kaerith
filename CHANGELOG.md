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

## 0.8.4 — 24/11/2026
**Ranking sem ADM** (pedido do João: "remover os adms do ranking com os players")
- Conta ADM (editor, presets ADM ou conta com `adm/{uid}`) não manda pontos: ao sincronizar, apaga o próprio documento em `jogadores` (uma vez por abertura) e não entra no ranking do QR. Ela ainda vê o Ranking, sem posição.
- Regras do Firestore: quem tem `adm/{uid}` não pode criar nem atualizar `jogadores/{uid}` nem `qr/.../vitorias/{uid}` (publicar com `firebase deploy --only firestore:rules`). Vitórias de QR antigas de contas ADM ficam até o dia virar (o ranking do QR é por dia).

## 0.8.3 — 24/11/2026
**Missões** (pedido do João: a missão do Tobin não concluiu pelo QR do Corvo Elite)
- As missões de Bestiário (Tobin/Corvo, Renn/Cervo, Maren/Rastreador, Tobias/Eco Mudo) agora fecham também ao vencer no QR ou no Evento. A ficha já completava lá, mas a missão só era conferida na vitória de uma fase do mapa. Quem já tinha a ficha completa recebe a missão concluída ao abrir o jogo (`HISTORIA.conferir_bestiario`). As missões de "derrotar" continuam contando só nas fases do mapa.
- Diário: a missão de Bestiário em andamento mostra o que falta na ficha: "Vitórias 2/3 · Veterano: Sim · Elite: Não" (`MIS_PROG_BESTIARIO`).

## 0.8.2 — 24/11/2026
**Peças das fases especiais** (pedido do João: "a fase final do ato está sempre dando item épico")
- Chefe de ato: a peça Épica do elemento do chefe só é garantida na 1ª vitória (como os 50 cristais). Ao rejogar, sai uma peça sorteada: Épico 5%, Raro 15%, Incomum 40%, Comum 40% (PROVISÓRIO, `Catalogo.PECA_REJOGAR`).
- Elite Suprema (fases 25 e 50 de cada ato): tinha o mesmo problema (Rara sempre). Agora a Rara é garantida só na 1ª vitória; ao rejogar, Raro 8%, Incomum 37%, Comum 55% (PROVISÓRIO).
- Raro e Épico continuam do elemento do líder; Comum e Incomum não têm elemento. A fase de Elite não mudou (20% de Incomum, também ao rejogar). O popup da fase mostra "Épico · só na 1ª vitória" ou, ao rejogar, "Comum a Épico (5%)".

**Evento do QR** (pedido do João: "as mesmas regras para os QR codes, na primeira vez no dia")
- O prêmio final do Evento (peça Rara; Épica no Evento raro) só é garantido na 1ª vez do dia com aquele QR (dia no fuso do QR, `dados.qr_evento_premio`). Depois, a peça sai pelo mesmo sorteio de rejogar a Suprema (ou o chefe, no raro). Fragmentos e cristais não mudam. Baú, Recurso e Inimigo já não garantiam peça alta.

**Missões dão XP** (pedido do João)
- Ao coletar, a missão dá XP de 2 Elites do nível da fase em que apareceu, com a mesma regra de diferença de nível (PROVISÓRIO, `XP_MISSAO_ELITES` em historia.gd). O popup mostra a barra de XP e abre o de nível se subir.

**Bestiário** (pedido do João)
- Veteranos fixos nas fases 127 (Javali-Raiz), 202 (Javali de Ferro), 277 (Tecelão da Geada) e 278 (Lebre da Neve), que não saíam em fase nenhuma (`Encontros.FIXOS`). Os Elites que não saem no mapa vêm pelos QR 302–316 (e 301, Corvo).

## 0.8.1 — 24/11/2026
**ADM** (pedido do João)
- Na ADM (editor, presets ADM ou conta ADM) todos os atos ficam abertos, sem esperar a data (`ConfigRemota.ato_aberto`). As fases à frente da atual continuam travadas. A versão pública não muda.
- **ADM pela conta** na versão pública (Web e APK, conta Google ou visitante): a conta que tiver o documento `adm/{uid}` no Firestore (criado à mão no console; o nome do documento é o ID do jogador, Configurações › Conta › Copiar) vira ADM ao entrar, com o mesmo save e o mesmo ranking. `Online.conferir_adm` confere uma vez por abertura, depois do login; sem internet fica como jogador comum. Regras: `adm/{uid}` só pode ser lido pelo próprio dono e ninguém grava pelo jogo (publicar com `firebase deploy --only firestore:rules`). Para tirar o ADM, apague o documento. (Substitui o modo por chave, que não chegou a ser publicado.)

**Missões de Bestiário** (pedido do João)
- O Eco Mudo Veterano não aparecia em nenhuma fase, então a missão do Tobias (Ato 4) não fechava. Agora a fase 280 tem um Eco Mudo Veterano fixo (`Encontros.FIXOS`); o resto do sorteio da fase não muda.
- O Corvo Elite (missão do Tobin, Ato 1) também não aparece no mapa. Ele vem pelo QR 301 (Inimigo `corvo_elite`, a Rainha do Bando).

**Login com Google no APK** (pedido do João)
- Sem plugin: o botão do Google (tela de entrada e Configurações › Conta) abre no navegador do celular `SITE/entrar_app.html#c=<código>&id=<client ID>` (página nova em `hospedagem/paginas/`). Ela faz o login no Google e grava o token no Firestore em `login_app/<código>`; o jogo espera (popup com Cancelar), lê o token pelo código, apaga o documento e segue igual à Web (`Conta.esperar_app`, `Online.pegar_login_app`). O código tem 32 letras aleatórias e ninguém lista a coleção.
- Passos do João: em Google Cloud › APIs e serviços › Credenciais › client da Web, adicionar `https://kaerith-d9bef.web.app/entrar_app.html` em "URIs de redirecionamento autorizados"; publicar as regras e o site; exportar o APK com a mesma keystore de depuração.
- Novidades: entrada 0.8.1 para os jogadores.

## 0.8.0 — 24/11/2026
**Rebalanceamento e popup de nível** (pedido do João: "muito fácil avançar sem comprar itens e equipamentos"; números PROVISÓRIOS, medidos no simulador `ferramentas/simulador_combate/sim2.py`)
- **Popup de subida de nível:** ao subir de nível, abre por cima do resultado um popup no mesmo estilo (faixa vinho, raios) com a Vida e os 5 atributos antes › depois e o ganho, o que o nível libera (Orbe novo, evolução dos Orbes) e quanto XP falta para o próximo. Os botões do resultado aparecem depois do Continuar.
- **Habilidades de elemento mais fortes ficaram mais fracas** (valem para o herói e para os inimigos que as usam): Explosão de Chamas 250→210%, Chuva de Cinzas 160→115%, Detonação 300→240% (+50→+40% com Queimadura), Onda Partida 150→115%, Tremor 140→110%, Ciclone 140→110%, Nevasca 130→105%, Trovão Cativo 280→230%, Lança Polar 240→210%, Olho da Tempestade 3×90→3×75%, Corrente em Cadeia 180→160%.
- **XP pela diferença de nível:** com o herói até 1 nível acima do inimigo, XP cheio; a cada nível a mais, −20% (mínimo 20%). Abaixo do inimigo, +10% por nível (máximo +50%). Vale na 1ª vez e ao rejogar. O tutorial não muda.
- **XP das fases altas corrigido** (teste de um amigo do João: fases altas davam menos XP que as iniciais). O XP de cada inimigo agora cresce com o nível dele, (nível + 1) ÷ 3 (NV2 = ×1, NV8 = ×3, NV21 = ×7,3), em vez de só +5% por nível. Antes, o começo de cada ato dava menos XP que o fim do anterior e o herói terminava a temporada no NV18 contra inimigos NV21; agora fica 2 a 3 níveis acima dos inimigos o tempo todo (NV24 na fase 300).
- **Lutas de 1 inimigo só no começo do Ato 1:** os Atos 2 a 4 já começam com grupos de 1 a 3 e com 3 ondas nas fases de ondas.
- **Dificuldade:** começa em ×1,10 na fase 11 (era ×1,20, deixa a 1ª Suprema mais justa), chega a ×1,35 na fase 40 e continua subindo +0,003 por fase (fase 75 ≈ ×1,46, 150 ≈ ×1,68, 300 ≈ ×2,13), porque as peças que caem e os Orbes deixavam o herói forte sem comprar nada.
- **Supremas mais fortes e chefes mais justos:** Suprema 1,2/0,75 → 1,3/0,8 (Vida/dano); chefe 1,1/0,65 → 0,85/0,55 (as duas ondas antes do chefe continuam).
- **Excluir conta / personagem** (Configurações › Conta, botão vermelho): pede confirmação ("Excluir para sempre" ou Cancelar), apaga do servidor o ranking, o save da nuvem e a conta do Firebase, apaga o progresso do aparelho (idioma e configurações ficam) e volta para a tela de entrada. Sem internet, oferece apagar só do aparelho. As regras do Firestore ganharam permissão de apagar o próprio documento em `jogadores` e `saves` (publicar com `firebase deploy --only firestore:rules`).
- **Novidades** (Configurações › Novidades › Ver novidades): lista do que mudou para o jogador em cada versão, da mais nova para a mais antiga. A lista fica em `scripts/novidades.gd` (`LISTA`) e os textos em `NOV_<versão>_1..` no `textos.csv`. **A cada atualização, ponha a versão nova no começo da lista.**
- **Aviso das missões secundárias:** quem já tinha começado a jornada vê uma vez, ao abrir o jogo, o popup "Missões secundárias!" (Ver missões abre o Diário na aba Missões; OK fecha). Quem já tinha passado das fases dos moradores recebe esses pedidos de uma vez (sem a cena de diálogo), para o "!" aparecer no mapa. Herói novo não vê o aviso. Fica gravado em `avisos_vistos` no save. Para um aviso numa versão futura, use `"aviso": "<id>"` na `LISTA` e os textos `AVISO_<id>_T` e `AVISO_<id>`.
- **Removidos** o quadro "Rede e sincronização" das Configurações (testes da apresentação de Sistemas Distribuídos), a linha "Online: Conectado", o texto de erro do servidor e o aviso no topo da tela (OFFLINE / SINCRONIZANDO / ONLINE). O ranking e a nuvem continuam sincronizando ao abrir o jogo, ao voltar para ele e a cada mudança de progresso.

## 0.7.0 — 24/11/2026
**História e missões da Temporada 1**
- **Missões dos NPCs (33):** as 17 aprovadas e 16 dos tipos novos (desafio dentro da fase, ficha do Bestiário, vencer de novo uma Elite e a 2ª parte depois do chefe). O NPC aparece na cena de diálogo no fim da fase, a missão entra no Diário e conta também ao rejogar e no automático (nunca no QR). Quantidades ajustadas (Lebres 5, Abutres 3, Atiradores 3, Soldados 4, Cervos 4, Lobos 4).
- **Diário:** aba Missões (progresso, pedido, fala de conclusão e botão Coletar com a recompensa definida); capítulos da S1 na aba História, que crescem com o que o jogador já viu; fichas dos NPCs na aba Personagens (retrato, elemento, onde apareceu e o que já disse). Selo "!" na aba Missões quando há recompensa para coletar.
- **Mapa:** pergaminho com "!" (na cor do elemento do NPC) nas fases já vencidas que ajudam numa missão em andamento; o popup da fase mostra a missão.
- **Personagens e diálogo (refeitos depois do teste do João):** os 17 NPCs foram redesenhados no mesmo modelo do herói (quadro 48×64, cabeça grande, formas arredondadas e contorno escuro, na linha de Sea of Stars e Chrono Trigger), com respiração de 4 quadros. Os inimigos e os chefes continuam como estavam. O diálogo virou uma cena: o fundo animado da arena do ato, o herói à esquerda e quem fala à direita, no mesmo tamanho, da coxa para cima e cortados no topo da caixa. Quem fala acende e sobe um pouco; quem ouve fica na sombra. Quando outro NPC entra, ele desliza da direita. A Voz é uma luz que pulsa no alto. A caixa de diálogo é a mesma dos popups, com as fontes do jogo (sem a moldura de retrato da primeira versão). Os personagens aparecem grandes (×4), um pouco cortados pela caixa, e o fundo usa a arena do ato sem as sombras redondas dos lutadores (artes/arenas/dialogo/, gerador ferramentas/montar_arenas_dialogo.py).
- **Falas da história:** 12 momentos de NPC por ato, a Voz nas fases 25, 50 e 75, as falas dos chefes (ao entrar, aos 50% e ao cair) e o fechamento de cada capítulo com o título. Textos longos são divididos em várias caixas.
- **Cutscene do fim do Ato 1:** a criança na Mata dos Ecos Velados (cena nova pintada em camadas, luzes, olhos de feras e geada). Passa uma vez, depois do resultado do chefe, e pode ser pulada.
- **Retratos 48×48** dos 17 NPCs (`artes/personagens/`, gerados por `ferramentas/montar_retratos.py`).
- **Lobo da Geada** passa a aparecer no Ato 3 a partir da fase 41 (missão do Brokk).

**Firebase: menos acessos e save menor**
- Os pontos do ranking só são gravados quando mudam; o save da nuvem só é conferido quando o progresso mudou, a cada 3 minutos ou quando forçado (abrir o jogo, voltar ao app, Configurações). O vigia da rede, sem nada para mandar, consulta `ping.txt` do site (Hosting), que não gasta leitura nem gravação do Firestore. Antes eram cerca de 180 gravações e 180 leituras por hora por jogador com o jogo aberto.
- O save vai para a nuvem comprimido (gzip + base64): um save de fim de temporada com 600 peças cai de ~75 KB para ~12 KB. Saves antigos continuam sendo lidos. **Atenção:** aparelhos com versão anterior à 0.7.0 não leem o save novo; atualize todos os aparelhos da mesma conta.

## 0.6.2 — 23/11/2026
**Correções do som**
- **Web sem som nenhum (causa principal):** os canais de áudio Música e Efeitos eram criados pelo jogo durante a execução, e na Web o Godot ligava a saída do canal Master dentro desses canais novos, fechando um laço sem saída para o alto-falante. Agora os canais vêm prontos em `default_bus_layout.tres` e o som sai (conferido no Chromium medindo a saída de áudio).
- Web: o som parava de vez quando o navegador suspendia o áudio (trocar de app ou de aba, bloquear a tela e, no iPhone, depois de ligar a câmera do QR). Agora a página guarda o áudio do jogo e o religa a cada toque e ao voltar para o jogo (`KaerithAudio` em `web/kaerith_shell.html`), e a música recomeça se tiver parado.
- A música volta a tocar se o laço terminar (garantia para a Web).

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
