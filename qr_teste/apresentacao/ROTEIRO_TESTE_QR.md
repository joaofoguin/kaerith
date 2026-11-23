# Roteiro de teste dos QR Codes · Kaerith: O Despertar

Folha para imprimir: `kaerith_qr_apresentacao.pdf` (A4, tamanho real, sem "ajustar à página").
A página 1 tem os QR válidos e a página 2 os inválidos.

## Antes de testar (uma vez)

1. Recarregue no Godot os arquivos novos. Se o editor perguntar, escolha **Recarregar** e não salve por cima:
   `scripts/qr/codigo_qr.gd`, `scripts/qr/link_qr.gd` (novo), `scripts/telas/ler_qr.gd` e `idiomas/textos.csv`.
2. Exporte a Web e rode o `publicar.bat`. Sem isso, a câmera comum do celular abre o site antigo, que ainda não entende o link.
3. **Horário:** os QR válidos funcionam das **10h às 23h (Brasília)**. Não há mais opção de teste para ignorar o horário, então apresente dentro dessa janela.
4. **Baú e Recurso:** cada jogador abre o mesmo Baú 1 vez por dia e coleta o mesmo Recurso 1 vez a cada 3 horas. Para mostrar os dois funcionando, não gaste os QR 101 e 102 pouco antes da apresentação no mesmo aparelho (ou use outro aparelho/navegador).
5. (Opcional) Publique as regras novas do Firestore: copie `jogo/firebase/firestore.rules` no console do Firebase, em Firestore > Regras > Publicar.

## A. Câmera do jogo (Início > Ler QR)

| QR | Esperado |
|---|---|
| 101 Recurso | Popup "Recurso encontrado!" com moedas (e às vezes fragmentos) |
| 102 Baú | Baú balançando. "Abrir baú" dá 1 prêmio. "Agora não" perde o baú |
| Ler 102 de novo no mesmo dia | Recusado: "Você já abriu este baú hoje. Volte amanhã!" |
| 103 / 104 / 105 Inimigo | Mostra a Elite (Capitão de Estrada / Rei da Galhada / Alfa da Última Geada) no seu nível. "Lutar" abre o combate |
| 106 Evento | "Um caminho se abriu!" e uma trilha amarela no mapa por 24 h. Um segundo Evento é recusado enquanto o primeiro está aberto |
| Ler 101 de novo | Recusado: "Você já coletou este recurso. Ele volta em 2h 59min." O mesmo Recurso vale de novo 3 h depois |

## B. Câmera comum do celular (fora do jogo)

1. Abra a câmera do celular, aponte para o **QR 102 Baú** e toque no link que aparece.
2. O site do jogo abre e vai direto para a tela do QR, com o baú.
3. Se é a primeira vez no aparelho, o jogo guarda o QR e o abre quando o jogador chega ao Início, depois do tutorial.
4. Teste também um inválido (ex.: **Editado**). O site abre e o jogo mostra "assinatura não confere".

## C. Proteções (página 2)

| QR | Esperado |
|---|---|
| Editado | "QR Code inválido: a assinatura não confere." |
| Falsificado | Igual: foi assinado com outra chave |
| Sem assinatura | Igual |
| QR comum | "Esse QR Code não é de Kaerith." Só serve na câmera do jogo, porque a do celular abre outro site |
| 108 Nova Zelândia | "Só funciona das 10h às 23h…" entre 8h e 19h de Brasília (lá é madrugada) |
| 109 Inimigo novo | "Esse QR Code é de uma versão mais nova do jogo." |
| Sem vidas | Com 0 vidas, qualquer QR é recusado e abre a janela de vidas |

Nenhum inválido gasta vida nem dá prêmio.

## D. Mudar a hora do celular (teste do professor)

Os QR válidos valem das 10h às 23h.

| Teste | Esperado |
|---|---|
| Com internet, pôr o relógio em 3h da manhã e ler o QR 101 | Aceita: o jogo pergunta a hora ao servidor ("Conferindo a hora...") e ignora o relógio do celular |
| Com internet, ler um QR; depois tirar a internet e, com o jogo aberto, pôr 3h da manhã | Continua valendo a hora certa: o jogo conta o tempo pelo cronômetro interno |
| Offline, voltar o relógio para antes da última leitura | Recusado: "O relógio do celular foi mudado..." até acertar a hora ou conectar |
| Fora do horário de verdade (depois das 23h), offline, com o jogo fechado, adiantar o relógio para 15h e abrir o jogo | **Aceita.** É o único caso sem saída: offline e com o jogo recém-aberto, não existe hora confiável. Na Web quase sempre há internet, então o caso 1 cobre a apresentação |

## Fala curta para a apresentação (cerca de 2 min)

1. Ler o **Baú** com a câmera do celular, que abre o jogo e o baú.
2. Ler o **Inimigo 103** com a câmera do jogo e lutar.
3. Ler o **Editado** e explicar: "cada QR tem uma assinatura digital (ECDSA). O jogo só tem a chave pública e confere sem internet. Mudar uma letra quebra a assinatura, e só quem tem a chave secreta, que não está no jogo, cria QR novos."
