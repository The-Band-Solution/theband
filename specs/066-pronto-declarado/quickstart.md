# Quickstart — 066

## Provar que funciona, de ponta a ponta

```bash
mix test test/the_band/projects/declaracao_de_fase_test.exs
mix test test/the_band_web/live/declarar_fase_test.exs
echo $?          # o veredito
```

## Ver na tela

```bash
mix phx.server
# http://localhost:4000/boards → escolher um quadro com campo de seleção única
```

O que conferir contra o protótipo (seção 3 do `prototipo/PROMPT.md`, cartão B):

1. o cartão **What each column means** aparece **depois** de *Start criterion*, com cabeçalho
   próprio;
2. **toda** opção observada do campo aparece, na ordem observada, com a contagem de hoje
   (aberta · fechada);
3. opção sem declaração diz **sem decisão**; opção cujo nome casa o vocabulário aparece como
   **proposta**, e proposta **não vale** — nada muda enquanto ninguém ativa;
4. declarar grava autor e instante, e a tela os mostra;
5. revogar **marca**: a declaração anterior continua visível como revogada;
6. o desacordo aparece abaixo, com os dois números e a definição por extenso — ou *não
   declarado*;
7. no detalhe de um item, **as duas afirmações lado a lado**, distinguíveis sem cor, e nenhuma
   síntese entre elas.

## O que esta fatia NÃO entrega

Os períodos de estágio, a escolha da definição que alimenta as medidas, o desacordo por pessoa,
e o *em andamento* no painel. Estão na spec e ficam para a fatia seguinte.
