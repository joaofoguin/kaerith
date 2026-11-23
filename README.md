# Kaerith: O Despertar

**Criadores:** Gabriel Rocha, Ruan Tirabassi e João Pedro Lima.

Trabalho Prático de Sistemas Distribuídos: um jogo para celular que funciona **online e offline**, com servidor remoto, armazenamento local persistente, sincronização automática, resolução de conflitos e tolerância a falhas.

- **Jogar (Web/PWA):** https://kaerith-d9bef.web.app
- **Android:** APK exportado pelo Godot (preset `Android`)
- Histórico das versões: [CHANGELOG.md](CHANGELOG.md). Notas de desenvolvimento por etapa: [LEIA-ME.md](LEIA-ME.md).

---

## 1. Descrição do jogo

Kaerith é um RPG em pixel art para celular, jogado em pé com toques na tela. O jogador cria um herói, escolhe um elemento (Fogo, Gelo, Raio, Terra, Vento ou Água) e avança por um mapa com 300 fases de combate por turnos. As vitórias dão XP, moedas, fragmentos e equipamentos.

O jogo também conecta o mundo físico: **QR Codes** espalhados pelo local podem conter um inimigo, um baú, um recurso ou um evento. Cada QR tem um ranking do dia (quem vence primeiro fica no topo). Há rankings gerais por nível, por QR e por Bestiário (espécies descobertas).

## 2. Tecnologias e protocolos

| Parte | Tecnologia |
|---|---|
| Cliente | **Godot 4.7** (GDScript), exportado para **Android (APK)** e **Web/PWA** (WebAssembly), interface 360×640 com toque |
| Servidor | **Firebase** (plano gratuito): **Authentication** (convidado anônimo e Google) e **Cloud Firestore** (banco de documentos NoSQL) |
| Comunicação | **HTTPS + REST/JSON** direto nas APIs do Firebase (`identitytoolkit`, `securetoken`, `firestore.googleapis.com/v1`), sem SDK. Autenticação com token **JWT** (`Authorization: Bearer`) |
| Hospedagem Web | Firebase Hosting, com **service worker** próprio para o jogo abrir offline |
| Segurança | Regras do Firestore (`hospedagem/firestore.rules`): cada jogador só lê e escreve os próprios dados. QR Codes com assinatura digital ECDSA P-256 (SHA-256), conferidos offline com a chave pública; a chave privada fica fora do jogo |

### Arquitetura

```
┌──────────────── CLIENTE (celular) ────────────────┐        ┌──────── SERVIDOR (Firebase) ────────┐
│ Jogo (telas, combate, toque)                       │        │ Authentication                       │
│   │                                                │        │   convidado anônimo / Google         │
│   ▼                                                │        │                                      │
│ Armazenamento local (user://)                      │  HTTPS │ Firestore                            │
│   save.json (+ .bak, .tmp, sha256)                 │  REST  │   jogadores/{uid}   pontos, nível    │
│   partidas_fila.json (caixa de saída)              │◄──────►│   saves/{uid}       progresso        │
│   save_conflito.json (lado que perdeu)             │  JSON  │   partidas/{uid}/lista/{id} histórico│
│   ▲                                                │        │   qr/{codigo_dia}/vitorias/{uid}     │
│   │                                                │        │   config, promocoes (só leitura)     │
│ Camada de sincronização: scripts/online.gd,        │        └──────────────────────────────────────┘
│   scripts/historico.gd, componentes/aviso_rede.gd  │
└────────────────────────────────────────────────────┘
```

- **Cliente:** executa o jogo, a interação com o jogador e o armazenamento local (`scripts/jogo.gd`).
- **Servidor:** recebe, guarda e devolve os dados sincronizados (Firebase Auth e Firestore).
- **Camada de comunicação e sincronização:** `scripts/online.gd` (HTTP, login, envio e conferência do progresso, conflitos), `scripts/historico.gd` (fila de partidas) e `scripts/componentes/aviso_rede.gd` (vigia da rede e aviso na tela).

### O que fica no servidor

| Requisito | Onde |
|---|---|
| Identificação do jogador | Firebase Auth (`uid`), conta de convidado ou Google |
| Estado e progresso | `saves/{uid}`: o save inteiro, para recuperar em outro aparelho (conta Google) |
| Pontuações e resultados | `jogadores/{uid}`: nível, XP, pontos dos rankings. `qr/.../vitorias`: resultado de cada QR |
| Histórico das partidas | `partidas/{uid}/lista/{id}`: um documento por combate (tipo, fase, vitória, XP, moedas, nível, hora, aparelho) |

## 3. Armazenamento local

Todo o jogo roda no aparelho. O servidor nunca é necessário para jogar: o mapa, os combates, a loja, o inventário, as vidas e a leitura de QR (assinatura conferida offline) funcionam sem internet.

- **Onde:** pasta `user://` do Godot (no Android, a pasta interna do app; na Web, o IndexedDB do navegador).
- **`save.json`:** o progresso inteiro, salvo a cada ação importante e também quando o app é minimizado, perde o foco ou é fechado.
- **Gravação segura:** escreve primeiro em `save.tmp`, guarda o anterior como `save.bak` e só então troca. A primeira linha tem o **sha256** do conteúdo. Ao abrir, o jogo tenta `save` → `bak` → `tmp` e descarta um arquivo cortado ou alterado. Uma queda de energia no meio do salvamento não perde o progresso.
- **`partidas_fila.json`:** a "caixa de saída" das partidas ainda não confirmadas pelo servidor (gravação também via `.tmp`).
- **Web offline:** o service worker guarda o jogo inteiro (motor, pacote, página) no cache do navegador. O jogo abre sem internet depois da primeira visita, inclusive pelo atalho da tela inicial (PWA).

## 4. Mecanismo de sincronização

1. **Detecção da rede:** o vigia (`Online.vigiar`, chamado a cada 1 s) tenta falar com o servidor a cada **5 s quando está offline** e a cada **20 s quando está online**. Na Web, o evento do navegador (`navigator.onLine`) avisa na hora quando a internet cai ou volta. O estado aparece sempre no topo da tela:
   - vermelho: **OFFLINE · SALVO NO APARELHO · N A ENVIAR**
   - amarelo: **SINCRONIZANDO N PARTIDAS**
   - verde: **ONLINE · SINCRONIZADO** (por 4 s quando a conexão volta)
2. **Volta da conexão:** a primeira resposta do servidor dispara a sincronização na hora, com o jogo aberto e sem reiniciar a partida. Também sincroniza ao abrir o jogo, ao voltar para o app e depois de cada combate.
3. **O que é enviado, nesta ordem:**
   1. pontos e nível (`jogadores/{uid}`);
   2. a fila de partidas, uma por vez, em ordem (`partidas/...`);
   3. o progresso inteiro (`saves/{uid}`, conta Google), com a conferência de conflito abaixo.
4. **Sem perda:** uma partida só sai da fila depois que o servidor confirma (resposta 2xx). Se a conexão cair no meio, o que já foi confirmado saiu da fila, o resto fica guardado no disco e vai na próxima tentativa.
5. **Sem duplicados (idempotência):** cada partida recebe um **ID único criado no aparelho** (hora + 6 bytes aleatórios) e é gravada com a pré-condição `currentDocument.exists=false`. Se o mesmo registro chegar de novo (a resposta se perdeu e o aparelho reenviou), o Firestore responde **409 ALREADY_EXISTS**. O jogo entende que o servidor já tinha esse registro e só tira da fila. Nada é contado duas vezes. O progresso é um documento por jogador, substituído inteiro, então reenviar o mesmo save também não muda nada.
6. **Outro aparelho:** com a conta Google, o jogo baixa `saves/{uid}` ao entrar e a cada sincronização. O progresso aparece no outro aparelho sem passo manual.

## 5. Política de resolução de conflitos

Cada aparelho guarda duas marcas da última sincronização: **`nuvem_rev`** (a versão do documento no servidor, o `updateTime` do Firestore) e **`nuvem_hash`** (um sha256 do progresso naquele momento). Antes de enviar, o jogo lê a nuvem e compara:

| Situação | O que acontece |
|---|---|
| A nuvem não mudou desde a última sincronização (`rev` igual) e o aparelho mudou | Envia o daqui |
| A nuvem mudou (outro aparelho enviou) e o aparelho **não** mudou | Baixa o da nuvem |
| **Os dois mudaram** (jogou em dois aparelhos offline) | **Conflito:** fica o **mais avançado** (criação concluída, depois nível, depois XP). No empate, fica o **salvo mais recente** |

- **Nada some:** o lado que perdeu é guardado em `save_conflito.json` no aparelho, e as Configurações mostram "Último conflito: perdeu X (nível N), cópia guardada".
- **Sem corrida entre aparelhos:** o envio usa a pré-condição `currentDocument.updateTime=<rev>`. Se outro aparelho enviou entre a leitura e a escrita, o servidor recusa, e a conferência roda de novo na próxima sincronização, em vez de apagar o progresso do outro.
- Idioma e configurações (som, vibração) são de cada aparelho e nunca são sobrescritos.

**Por que o mais avançado:** num RPG, o valor do jogador está no tempo investido. Num conflito real (dois aparelhos offline), escolher pelo relógio ("último a escrever vence") pode apagar horas de jogo só porque o aparelho com menos progresso sincronizou por último, ou porque o relógio dele estava adiantado. Nível e XP só sobem jogando, então são um critério objetivo, que não depende do relógio, e preservam o maior esforço. O relógio só desempata. Uma mesclagem campo a campo foi descartada porque poderia criar estados impossíveis (por exemplo, o mesmo item gasto num aparelho e equipado no outro).

## 6. Tratamento de falhas de comunicação

| Falha | Como o jogo reage |
|---|---|
| **Perda de conexão durante a partida** | O combate continua normalmente (tudo é local). O resultado vai para o save e para a fila. O aviso vermelho aparece em até 5 s (na hora, na Web) |
| **Servidor indisponível** | Cada requisição tem tempo limite de 12 s e a tela de carregamento não espera mais que alguns segundos. O jogo segue offline e o vigia tenta de novo a cada 5 s. Uma falha no meio da renovação do login nunca cria outra conta |
| **Falha durante a sincronização** | A fila só perde um item depois da confirmação. O save só ganha a marca de sincronizado depois da resposta do servidor. A próxima tentativa continua de onde parou |
| **Reenvio do que já foi transmitido** | O ID único e o `exists=false` fazem o servidor responder 409. O jogo conta como "reenvio ignorado" e segue |
| **Sincronização no meio de um combate** | O progresso que vem da nuvem nunca é aplicado durante um combate (espera terminar) |
| **Arquivo local corrompido** | sha256 + `.bak` + `.tmp` (seção 3) |

### Testes pela própria tela (Configurações → Rede e sincronização)

- **Servidor fora do ar (teste):** faz o cliente agir como se o servidor não respondesse, sem desligar a internet.
- **Falha no meio da sync (teste):** o servidor grava a próxima partida, mas a "resposta se perde". A partida fica na fila, é reenviada sozinha, o servidor responde 409 e o contador "Reenvios ignorados" sobe.
- **Sincronizar agora:** força a sincronização e mostra o resultado.
- A tela mostra as partidas a enviar, as enviadas, os reenvios ignorados, a hora da última sincronização com a nuvem e o último conflito resolvido.

## Como rodar

1. Instale o **Godot 4.7** (padrão, não .NET) e abra `project.godot`.
2. Crie `dados/online.json` com `{"api_key": "...", "projeto": "...", "google_client_id": "..."}` do seu projeto Firebase. Sem esse arquivo o jogo roda 100% offline.
3. Publique as regras do banco: `cd hospedagem` e depois `firebase deploy --only firestore:rules`.
4. **Web:** Projeto → Exportar → `Web` e depois `hospedagem\publicar.bat` (publica no Firebase Hosting).
5. **Android:** Projeto → Exportar → `Android` (precisa do Android SDK e do JDK configurados no Godot).

Dependências: Godot 4.7 (export templates Web e Android) e Firebase CLI (`npm i -g firebase-tools`) para publicar. O jogo não usa nenhum plugin nem biblioteca externa.
