# Promoções e QR pelo Firebase

Tudo aqui se muda no **console do Firebase**, sem exportar o jogo de novo.
O jogo baixa as mudanças quando abre e depois a cada 10 minutos, e guarda a última versão para usar offline.

Console: https://console.firebase.google.com, projeto **kaerith-d9bef**, menu **Firestore Database > Dados**.

## 0. Uma vez só: publicar as regras

1. Em **Firestore Database > Regras**, apague o que estiver lá e cole o arquivo `hospedagem/firestore.rules`.
2. Clique em **Publicar**.

Sem essa etapa, o jogo não consegue ler as promoções, então elas não mudam. Também não somem: fica valendo a última versão baixada.

## 1. Criar as promoções (faça antes de publicar o site)

**Atenção:** depois que o jogo baixa a coleção `promocoes`, só aparece o que estiver lá. Se a coleção estiver vazia, nenhuma promoção aparece.

1. Clique em **Iniciar coleção** e use o ID `promocoes`.
2. Crie um documento por promoção. O **ID do documento** é o nome interno da promoção, sem espaço. Exemplos: `bolsa`, `conjunto`, `bolsa_natal`.

Campos (use o tipo indicado):

| Campo | Tipo | Exemplo | Para que serve |
|---|---|---|---|
| `modelo` | string | `bolsa`, `conjunto` ou `livre` | Qual arte e conteúdo usar. `livre` é para promoção nova com arte própria (veja abaixo) |
| `ativo` | boolean | `true` | `false` esconde a promoção sem apagar |
| `inicio` | timestamp | 23/11/2026 10:00 | Quando começa a aparecer (opcional) |
| `fim` | timestamp | 30/11/2026 23:59 | Quando some. Sem `fim`, vai até o próximo ato abrir |
| `preco` | string | `R$ 9,90` | Preço mostrado (a compra continua bloqueada) |
| `nome_pt` / `nome_en` | string | `Bolsa de Natal` | Nome (opcional; sem ele usa o do modelo) |
| `desc_pt` / `desc_en` | string | `200 fragmentos + 80 cristais.` | Descrição (opcional) |
| `fragmentos` | number | `200` | Só no modelo bolsa (padrão 100) |
| `cristais` | number | `80` | Só no modelo bolsa (padrão 50) |
| `ordem` | number | `1` | Ordem. O Início mostra as 2 primeiras e a Loja mostra todas |

Para manter as duas promoções de hoje, crie:

- `bolsa`: `modelo` = `bolsa`, `ativo` = `true`, `preco` = `R$ 9,90`, `ordem` = `1`
- `conjunto`: `modelo` = `conjunto`, `ativo` = `true`, `preco` = `R$ 19,90`, `ordem` = `2`

### Promoção nova, com arte e conteúdo próprios (modelo `livre`)

1. Desenhe as artes em PNG e ponha na pasta `hospedagem/site/promocoes/` do projeto:
   - **ícone** do botão do Início: 72×72
   - **cena** do popup: 164×260 (o jogo mostra em dobro). Deixe os 3 pedestais mais ou menos onde estão na `cena_bolsa.png`, porque os itens aparecem em cima deles
   - **vitrine** da Loja: 320×160
   Use nomes sem espaço nem acento, como `natal_icone.png`.
2. Rode o `publicar.bat`. Não precisa exportar o jogo de novo.
3. No Firebase, crie o documento da promoção com `modelo` = `livre` e estes campos (todos string):

| Campo | Exemplo | Para que serve |
|---|---|---|
| `icone` | `natal_icone.png` | Botão do Início |
| `cena` | `natal_cena.png` | Fundo do popup |
| `vitrine` | `natal_vitrine.png` | Faixa na Loja |
| `conteudo` | `cristais:80, vidas:3, pocao_de_vida_i:2` | Até 3 itens, um em cada pedestal |
| `cor` | `#c8283a` | Cor da faixa do título e do brilho (opcional) |

Mais `nome_pt`, `desc_pt`, `preco`, `fim`, `ordem` e `ativo`, como nas outras.

No `conteudo` valem: `cristais`, `fragmentos`, `moedas`, `vidas`, o id de uma poção (ex.: `pocao_de_vida_i`) ou o id de uma peça (ex.: `espada_de_ferro`). O número depois dos dois pontos é a quantidade. Item que o jogo não conhece é ignorado.

Os campos `icone`, `cena` e `vitrine` também funcionam nas promoções `bolsa` e `conjunto`, para trocar só a arte. Se uma arte não chegar (nome errado ou sem internet na primeira vez), o jogo usa a do modelo. Depois de baixada, a arte fica guardada no aparelho e aparece offline.

**Adicionar:** crie um documento novo. **Tirar:** mude `ativo` para `false`, ou apague o documento. **Mudar prazo ou preço:** edite o campo.

## 2. Desligar um QR Code

- **Um QR específico:** crie a coleção `qr_bloqueados` e um documento com o **número do QR como ID** (ex.: `110`). O campo `motivo` (string) é opcional e só serve para você lembrar. Quem ler esse QR vê "Este QR Code foi desativado". Para religar, apague o documento.
- **Um tipo inteiro:** crie a coleção `config` e um documento `qr` com campos boolean `recurso`, `bau`, `inimigo` e `evento`. Com `evento` = `false`, nenhum QR de Evento funciona ("Este tipo de QR Code está desligado no momento"). Campo ausente conta como ligado.

## 3. Criar um QR novo

Não precisa mudar nada no Firebase. Gere o código com `criar_qr.py`, por exemplo `python criar_qr.py 110 e`, e imprima.

## 4. Botão Evento do Início

Na coleção `config`, crie o documento `inicio` com o campo `evento` (boolean).

- `false`, ou sem o documento: o botão Evento some e as promoções sobem para o lugar dele.
- `true`: o botão aparece (por enquanto ele só mostra "Em breve").

## 5. Quando cada ato abre

Sem nada no Firebase, vale o calendário da temporada (começa em 22/11/2026, 00h de Brasília):

| Ato | Abre em | Duração |
|---|---|---|
| I | 22/11/2026 | 20 dias |
| II | 12/12/2026 | 25 dias |
| III | 06/01/2027 | 25 dias |
| IV | 31/01/2027 | 20 dias (a temporada acaba em 20/02/2027) |

Para mudar, crie na coleção `config` o documento `temporada` com os campos `ato_2`, `ato_3` e `ato_4` (tipo **timestamp**). Só precisa criar o campo do ato que quiser mudar. Campo ausente usa a data da tabela.

- **Segurar um ato:** ponha uma data no futuro. Quem vencer o chefe do ato anterior antes disso vê no mapa a placa "Abre em 3d 04h" e a fase fica sem o botão Jogar.
- **Abrir agora:** ponha uma data no passado.
- Os atos abrem em ordem: se o Ato II estiver fechado, o III e o IV também ficam, mesmo com data passada.

## 6. Stories do Instagram (QR do dia e código para digitar)

Cada story tem um QR que só vale no dia da postagem e um código de 6 letras que o jogador digita em Ler QR > "Digitar código".
O Claude gera os dois com a ferramenta (fica fora do jogo, junto da chave secreta) e atualiza `hospedagem/paginas/codigos.json`.
Você só precisa rodar o `publicar.bat` antes do dia do story. Sem isso o código não é encontrado, mas o QR funciona no dia mesmo assim.
Não precisa mexer no Firebase.

## Observações

- Um aparelho que ficou offline continua com a última lista que baixou até conectar de novo.
- Os eventos do botão Evento (Login, Mercador...) ainda não foram programados. Por enquanto, os eventos controlados por aqui são os QR de Evento.
