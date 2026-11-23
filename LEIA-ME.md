# Kaerith: O Despertar — projeto Godot 4

Etapa 1 (esqueleto). Como abrir:
1. Abra o Godot 4 → **Importar** → escolha o arquivo `project.godot` desta pasta.
2. Na primeira abertura o Godot importa as artes e os textos (leva alguns segundos).
3. Aperte **F5** (ou o botão ▶ no canto superior direito) para rodar.

O que já funciona:
- Tela 360×640 em pé, escala inteira, pixel art nítido (filtro Nearest).
- Fontes Pixelify Sans (textos) e Silkscreen (números/HUD).
- Barra de baixo: Loja, Diário, Início, Inventário, Ranking (só o Início tem conteúdo).
- Início: HUD, caixa da temporada, herói animado (8 fps), ícones laterais e "Jogar fase n".
- "Jogar fase n" abre o mapa de fases provisório; "Voltar" (ou Esc / voltar do Android) fecha.
- Engrenagem no canto do Início troca o idioma PT ↔ EN e salva.
- Salvamento local em `user://save.json`.

Pastas:
- `artes/` cópias das artes aprovadas usadas pelo jogo
- `cenas/` cenas (.tscn)
- `scripts/` código; `scripts/telas/` uma tela por arquivo
- `idiomas/textos.csv` todos os textos em PT e EN

## Etapa 2 — artes importadas
- `artes/atlas/` folhas-atlas geradas a partir de `/artes` do projeto (herói costas/frente, inimigos, itens).
- `dados/heroi.json`, `dados/inimigos.json`, `dados/itens.json`: onde cada imagem está na folha + fichas (nome, raridade, quadros, fps).
- `scripts/artes.gd` (autoload Artes) lê as folhas; `scripts/componentes/sprite_camadas.gd` desenha camadas animadas.
- Botão "Galeria (teste)" no Início: herói com troca de arma/armadura e animações, os 106 inimigos com todas as ações, os 312 itens e poções.
- Para gerar de novo as folhas: `python3 ferramentas/montar_artes.py` (na pasta compartilhada do projeto).

## Etapa 7 — QR Code
- Início → ícone **Ler QR** abre a leitura: câmera (quando o aparelho tem) ou **Escolher imagem** (foto do QR também vale).
- O leitor é do próprio jogo, sem plugin: `scripts/qr/leitor_qr.gd`. As regras ficam em `scripts/qr/codigo_qr.gd`.
- Cada código leva uma assinatura digital (ECDSA P-256). O jogo só tem a chave pública e recusa QR falsos ou alterados, sem internet.
- Tipos: Recurso (prêmio na hora), Baú (abrir ou perder), Inimigo (luta contra a Elite do código) e Evento (caminho de 5 fases no mapa por 24 h).
- Não há espera entre leituras. Teste: na tela do QR há "Sem horário (teste)", que ignora o horário 10h–23h, e "Forçar raro (teste)".
- Códigos de teste: pasta `qr_teste/`. Lá fica a `folha_qr_teste.pdf` para imprimir e um QR falso, para ver a recusa.
- Para criar novos códigos: `jogo/qr/criar_qr.py` na pasta do projeto, com a chave secreta. A chave secreta nunca vai para o jogo.

## Etapa 8 — salvamento offline e vidas
- Vidas (`scripts/vidas.gd`): no máximo 5, e volta 1 a cada 40 min pelo relógio do aparelho, mesmo com o jogo fechado. Só a derrota gasta vida.
- Com zero vidas, dá para recarregar as 5 por 80 cristais, e isso funciona sem internet.
- Se o relógio do aparelho voltar para trás, a contagem recomeça do horário atual.
- No Início aparece o relógio da próxima vida. Tocar nas vidas abre o popup, com as opções "-1 vida (teste)" e "1 vida a cada 40 s (teste)".
- Salvamento (`scripts/jogo.gd`): o jogo grava primeiro um arquivo temporário e guarda o save anterior em `save.bak`. Cada save leva uma conferência (SHA-256).
- Se o save principal estragar, o jogo usa a cópia de segurança. Ele também salva sozinho ao minimizar, trocar de app ou fechar.

## Etapa 9 — Loja, Diário e Bestiário
- Loja (`scripts/loja.gd` e `scripts/telas/loja.gd`): abre depois da fase 5. Antes disso, a aba mostra o botão "Abrir a Loja (teste)".
- Todo dia a vitrine sorteia 8 itens (a Poção de Vida I sai grátis) e 3 equipamentos de Comum a Raro. Cada um tem 1 unidade e sai ao ser comprado.
- Cristais compram a Essência de Eco e o Frasco de Ressonância e trocam por moedas (6 pacotes × fator do nível).
- Promoções e pacotes de cristais usam dinheiro real, então por enquanto só aparecem. Elas chegam na etapa 10.
- Peças da Loja: `artes/loja/`, geradas do kit aprovado por `ferramentas/montar_loja.py`.
- Diário (`scripts/telas/diario.gd`) tem quatro abas:
  - História: Prólogo, Campos de Auren e Despertar para reler. Os 4 capítulos da S1 ficam com cadeado.
  - Missões: vazia por enquanto.
  - Personagens: A Voz e os chefes já vistos.
  - Bestiário: as 40 espécies, com "?" nas que você ainda não viu.
- Bestiário (`scripts/bestiario.gd`): toda luta registra os inimigos. Com 3 vitórias revela habilidades e fraquezas; vencer o Veterano e a Elite revela uma frase da história cada.

## Etapa 10 — online, anúncios e APK
- Vídeos com prêmio (`scripts/anuncios.gd`): AdMob no Android e AdSense na Web desde a 0.3.0 (veja "Vídeos com prêmio" no fim). Sem configurar, é uma espera de 5 s.
  - +1 vida por vídeo, no popup das vidas quando elas zeram.
  - "Continuar com vídeo" na derrota do modo história: 1 vez por tentativa, volta com 50% da Vida e devolve a vida e as moedas perdidas.
- Online (`scripts/online.gd`): login de convidado e rankings no Firestore, tudo por REST, sem plugin. Ele também confere o relógio do servidor para as vidas.
  - Fica desligado até existir `dados/online.json`.
- Ranking (`scripts/telas/ranking.gd`): abas Nível, Caçador, Bestiário e Geral (trancado até o fechamento). O botão "Ranking do QR (por inimigo)" fica na aba Caçador.

### Ligar o Firebase (grátis, plano Spark)
1. Entre em https://console.firebase.google.com, clique em "Adicionar projeto" e não ative o Google Analytics.
2. Em Authentication → Método de login, ative "Anônimo".
3. Em Firestore Database → Criar banco de dados, escolha o modo de produção e a região `southamerica-east1`.
4. Na aba Regras do Firestore, cole o conteúdo de `jogo/firebase/firestore.rules` (pasta do projeto) e publique.
5. Em Configurações do projeto → Geral → Seus apps, adicione um app da Web. Anote a `apiKey` e o `projectId`.
6. Crie o arquivo `dados/online.json` na pasta do jogo com esta linha: `{"api_key": "SUA_API_KEY", "projeto": "SEU_PROJECT_ID"}`.

### Gerar o APK (Android)
1. Instale o Android Studio, que já traz o SDK, e o JDK 17.
2. No Godot, abra Editor → Gerenciar modelos de exportação e baixe os modelos da 4.7.
3. Em Editor → Configurações do editor → Exportar → Android, aponte o caminho do SDK e do JDK.
4. Em Projeto → Exportar, adicione "Android" e marque as permissões `INTERNET`, `CAMERA` e `VIBRATE`.
5. Clique em "Exportar projeto" e salve `kaerith.apk`. A versão de depuração já assina sozinha.

## Versão Web (navegador, PWA e webview)
O mesmo projeto exporta para a Web. O APK continua igual (no Android nativo o leitor de QR é o de sempre).

O que muda na Web:
- **Leitor de QR**: a câmera é a do navegador. O JavaScript embutido na página (`web/kaerith_shell.html`) abre a câmera e acha o QR com o leitor do próprio navegador (Android/Chrome) ou com o jsQR (iPhone e PC). As duas formas funcionam sem internet.
  - Só o texto do QR vai para o jogo. A assinatura continua sendo conferida em `scripts/qr/codigo_qr.gd`, no aparelho, então um QR falso continua recusado offline.
  - A ponte com o jogo fica em `scripts/qr/camera_web.gd` (CameraWeb). A tela `scripts/telas/ler_qr.gd` escolhe sozinha entre a câmera nativa e a da Web.
  - "Escolher imagem" abre o seletor do navegador. No celular, ele também deixa tirar uma foto na hora.
- **Salvamento**: `user://` vira o armazenamento do navegador (IndexedDB). A página pede ao navegador para não apagar esses dados.
- **Online**: o Firebase por REST funciona igual. Na Web, a hora do servidor vem da resposta do Firestore, porque o navegador esconde o cabeçalho Date.
- **PWA**: depois do primeiro acesso, o jogo abre sem internet e pode ser instalado na tela inicial. A tela fica em pé e o ícone é provisório (`web/icone_512.png`, feito do logo).

### Exportar
1. No Godot, abra Editor → Gerenciar modelos de exportação e confira se os modelos da 4.7 estão baixados. Eles são os mesmos do APK e já trazem a Web.
2. Abra Projeto → Exportar. O preset **Web** já está criado: sem threads, PWA ligada e o modelo de página `res://web/kaerith_shell.html`.
3. Clique em "Exportar projeto" e salve em `../Kareith_builds/web/index.html`. Essa pasta inteira é o jogo e pode ser publicada como site.

### Testar no PC (câmera do notebook)
1. Com o preset Web criado, aparece um botão de navegador (HTML5) no canto de cima do Godot, ao lado do ▶. Clique em "Executar no navegador".
2. O Godot abre `http://localhost:8060/...`. Como é **localhost**, o navegador libera a câmera sem https.
3. Na tela Ler QR, aceite a permissão da câmera e mostre um QR da `qr_teste/folha_qr_teste.pdf` (aberta no celular, por exemplo).

### Testar no celular (precisa de https)
A câmera do navegador só abre em **https** ou em **localhost**. Pelo IP do PC na rede (`http://192.168...`) ela não abre. Nesse caso o jogo mostra um aviso, e só o "Escolher imagem" funciona.
- **Jeito mais fácil**: entre em https://app.netlify.com/drop e arraste a pasta `Kareith_builds/web`. Você recebe um endereço `https://...netlify.app`. Abra no Chrome do Android ou no Safari do iPhone.
- **Pelo cabo USB (Android)**: com a depuração USB ligada, rode `adb reverse tcp:8060 tcp:8060` e use "Executar no navegador" no Godot. Depois abra `http://localhost:8060/index.html` no Chrome do celular.
- **Instalar como app (PWA)**: no Chrome, use o menu ⋮ → "Instalar app" (ou "Adicionar à tela inicial"). No Safari, use Compartilhar → "Adicionar à Tela de Início".
- **Testar offline**: abra o jogo uma vez com internet e espere carregar. Depois ligue o modo avião e abra de novo. O QR, as lutas e o salvamento funcionam sem internet. Só o Ranking precisa de rede.

### Firebase na Web
- Se a API key do Firebase estiver restrita só a apps Android, o navegador é recusado. Em console.cloud.google.com → APIs e serviços → Credenciais, deixe a chave sem restrição de aplicativo ou acrescente o endereço do site em "Referenciadores HTTP".
- O `dados/online.json` vai dentro do jogo exportado, então qualquer um pode ver a chave. No Firebase isso é normal: quem protege os dados são as regras do Firestore.

### Dentro de um app (webview)
A pasta exportada também pode ser aberta numa webview. A webview precisa abrir o jogo por https e liberar a câmera:
- No Android, carregue o jogo pelo `WebViewAssetLoader` ou por um endereço https. Também é preciso pedir a permissão CAMERA e aceitar o `onPermissionRequest` no WebChromeClient.
- No iOS (WKWebView), coloque `NSCameraUsageDescription` no Info.plist.

### Atualizar a versão publicada
A cada exportação o Godot muda a versão do cache. Quem já instalou recebe o jogo novo na próxima vez que abrir com internet. Às vezes é preciso fechar e abrir duas vezes.

## Conta: Google ou visitante
- Depois do Prólogo aparece a tela de entrada (`scripts/telas/entrada.gd`), com "Entrar com Google" e "Jogar como visitante". Depois dela vem a criação do personagem.
- **Visitante**: o progresso fica só neste aparelho. Ele pode entrar com o Google depois, em Configurações → Conta → "Salvar progresso com Google". O Google é ligado à conta de visitante, então o ID e o ranking continuam os mesmos.
- **Google**: o save inteiro também vai para o Firestore (`saves/{uid}`), junto com o envio do ranking (no máximo a cada 60 s) ou pelo botão "Salvar na nuvem agora".
  - Ao entrar com uma conta que já tem progresso, a tela de entrada carrega esse progresso.
  - Nas Configurações, o jogo pergunta qual progresso fica: o da conta ou o deste aparelho.
- Código: `scripts/conta.gd` (Conta), `Online.entrar_google`, `Online.enviar_save` e `Online.baixar_save`. Na página, `KaerithWeb.googleEntrar` leva ao Google, e a volta chega pelo endereço (`#id_token=...`).
- Por enquanto o login funciona só na **versão Web**. No APK o botão avisa, porque o Android precisa de um plugin do Google Sign-In.

### Ligar o login com Google (uma vez só)
1. **Endereço fixo do site**: o Google só aceita endereços cadastrados. No Netlify, atualize sempre o mesmo site (aba Deploys), em vez de criar outro pelo Drop.
2. **Firebase** → Authentication → Método de login → Adicionar novo provedor → **Google** → Ativar. Escolha o e-mail de suporte e salve.
   - Abra o Google de novo e copie o **ID do cliente da Web**, que fica em "Configuração do SDK da Web". Ele termina em `.apps.googleusercontent.com`.
3. **Firebase** → Authentication → Configurações → Domínios autorizados → adicione `SEU-SITE.netlify.app`.
4. **Google Cloud** (https://console.cloud.google.com, mesmo projeto) → APIs e serviços → Credenciais → abra "Web client (auto created by Google Service)":
   - Origens JavaScript autorizadas: `https://SEU-SITE.netlify.app`
   - URIs de redirecionamento autorizados: `https://SEU-SITE.netlify.app/index.html`, exatamente assim, com o `/index.html`.
   - Salve. Pode levar alguns minutos para valer.
5. **Google Cloud** → APIs e serviços → Tela de consentimento OAuth: se estiver em "Teste", só os e-mails da lista de testadores conseguem entrar. Adicione o seu, ou clique em "Publicar app".
6. **Jogo**: em `dados/online.json`, acrescente o ID do cliente:
   `{"api_key": "...", "projeto": "...", "google_client_id": "XXXX.apps.googleusercontent.com"}`
7. **Regras do Firestore**: cole de novo o `jogo/firebase/firestore.rules` (ganhou o bloco `saves`) e publique. Sem isso, o save na nuvem é recusado.
8. Exporte, suba no mesmo site e teste.

Atenção no iPhone: o app instalado pela Tela de Início pode abrir o Google numa janela separada e não voltar para o app. Se acontecer, faça o login pelo Safari. O progresso fica na conta Google e aparece no app quando você entrar lá também.

## Versões (0.3.0 em diante)
O número da versão e as regras estão no `CHANGELOG.md`. A cada leva de mudanças, o número sobe nos três lugares que o histórico lista.

### Versão ADM e versão pública
- **Pública** (presets `Android` e `Web`): para os jogadores. Nenhum botão de teste aparece.
- **ADM** (presets `Android ADM` e `Web ADM`, e o jogo rodando pelo editor): com todos os botões de teste e "ADM" ao lado da versão. O APK ADM (`Kaerith_ADM.apk`) instala ao lado do público, com save separado.
- O código decide pelo `Jogo.adm()`. Botão de teste novo deve ficar dentro de `if Jogo.adm():`.
- "Executar no navegador" do editor usa o `Web ADM`. Publique no site só a `Web` pública (`hospedagem/site`); a `site_adm` fica só no PC.

### Páginas do site
`hospedagem/paginas/` tem `privacidade.html`, `suporte.html` e `termos.html`. O `publicar.bat` copia para o site. Em `suporte.html`, preencha `var EMAIL = ""` com o e-mail de suporte; enquanto estiver vazio, o botão mostra "em breve".

## Vídeos com prêmio (anúncios)
Tudo é ligado por `dados/anuncios.json`. Sem configurar nada, o jogo usa a espera de 5 s (como antes).

### Android: AdMob (é o que mais paga para vídeo com prêmio)
1. Crie a conta em admob.google.com, adicione o app (Android, "não publicado ainda") e crie um bloco **Premiado** (Rewarded). Anote o **ID do app** (`ca-app-pub-...~...`) e o **ID do bloco** (`ca-app-pub-.../...`).
2. No Godot (4.5 ou mais novo): AssetLib > procure **AdMob** (Poing Studios) > instale e ative em Projeto > Configurações > Plugins.
3. Siga o README do plugin para baixar a parte Android dele e para colocar o **ID do app**. Ele também pede Projeto > Instalar modelo de build Android e "Use Gradle Build" ligado nos presets Android.
4. Cole o **ID do bloco** em `dados/anuncios.json` no campo `admob_recompensa_android`.
5. O APK ADM sempre usa o bloco de teste do Google, então pode testar à vontade. Nunca toque nos seus próprios anúncios reais: o Google pode suspender a conta.

### Web: H5 Games Ads (Google AdSense)
O AdMob não funciona no navegador. Na Web é o AdSense, que exige conta aprovada e normalmente um domínio próprio (o `web.app` do Firebase pode não ser aceito).
1. Crie a conta em adsense.google.com com o site e espere a aprovação.
2. Peça o acesso ao **H5 Games Ads** (Ad Placement API).
3. Cole o código do editor (`ca-pub-...`) em `adsense_cliente`. Deixe `adsense_teste` em `true` até o Google liberar e depois mude para `false`.
