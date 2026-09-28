# As varreduras de segredo

Cada arquivo aqui é um relatório de `mix the_band.varre_segredos`, com a data no nome (FR-010 da
064). Sem o registro, ninguém sabe se a varredura anterior aconteceu.

## Como ler

| código | significa |
|---|---|
| `0` | limpo, **e o controle positivo achou o plantio de cada padrão** |
| `1` | achou pelo menos um segredo; o relatório diz **onde** (tabela, coluna, linha, deslocamento, tamanho), nunca **o quê** |
| `2` | o controle positivo falhou: a varredura não enxerga, e a contagem não vale |

Um relatório sem a linha `controle positivo ... ACHOU` não é válido, qualquer que seja a
contagem.

## Por que o banco sai com `1` hoje

`users.session_token` guarda o token de sessão em texto claro, **por desenho**, até a US2 da
064 estar pronta. Cada conta que já entrou tem um, e a varredura os acha. É o resultado certo: o
relatório não esconde o que ainda não foi consertado.

Os outros dois padrões (token do GitHub e chave de provedor de modelos) procuram em **qualquer**
coluna. O de sessão procura só na coluna dele, e a razão está no contrato
(`specs/064-segredo-em-repouso/contracts/varre-segredos.md`): medido em 2026-09-28, a forma de 43
caracteres casou 5 928 vezes num dump de desenvolvimento, e só 2 eram token de sessão.

## Antes de cada cópia do backup

    pg_dump ... > backup.sql
    mix the_band.varre_segredos --dump backup.sql --saida docs/seguranca/varreduras

Código diferente de `0` e de `1` com só `users.session_token`: **não copiar**, e investigar.
