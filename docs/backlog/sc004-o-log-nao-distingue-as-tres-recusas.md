# O log não distingue as três causas de recusa de token

**Achado em 2026-09-23**, ao percorrer os critérios da feature 061 para o registro de
aceitação. É o **SC-004**, e é o único critério da 061 que reprovou por defeito — o outro
reprovou por escopo.

## O que o critério pede

> **SC-004**: 100% das recusas têm o motivo real recuperável no log interno pelo
> identificador da requisição — verificável recusando as três e localizando **as três razões
> distintas**.

## O que foi medido

Três recusas — token inexistente, token revogado, requisição sem cabeçalho — produziram
**duas** categorias no log:

| Causa | `motivo=` no log |
|---|---|
| sem cabeçalho `Authorization` | `sem_cabecalho` |
| token inexistente | `credencial_recusada` |
| token revogado | `credencial_recusada` |
| token expirado | `credencial_recusada` |

Três causas distintas colapsam numa.

## A causa, e ela é de uma linha

`TheBand.Tenants.ApiTokens.autenticar/1`:

```elixir
with {:ok, id_publico, segredo} <- partes(valor),
     %Token{} = token <- por_id_publico(id_publico),
     true <- confere?(token, segredo),
     :ativo <- Token.estado(token, agora()) do
  {:ok, carimbar(token)}
else
  _ -> {:error, :recusado}
end
```

**A informação existe e é jogada fora.** `Token.estado/2` já devolve `:ativo`, `:revogado` ou
`:expirado`. O `_` do `else` a descarta, e o plug registra a mesma palavra para todas.

## O que NÃO deve mudar

**A resposta ao cliente.** O SC-003 exige que inexistente, revogado e expirado produzam
respostas **byte a byte idênticas** — e exige com razão: distinguir as três ali confirmaria a
quem testa uma credencial roubada que ela um dia existiu.

O que falta é a distinção **no log interno**, que é onde ela serve a quem opera.

## O conserto

Devolver o motivo em vez de descartá-lo:

```elixir
else
  :erro -> {:error, :malformado}
  nil -> {:error, :inexistente}
  false -> {:error, :segredo_errado}
  estado when is_atom(estado) -> {:error, estado}
end
```

e passar esse átomo ao `Logger.warning` que o plug já escreve. A resposta HTTP continua a
mesma.

**O teste é a distinção**: três recusas, três palavras diferentes no log, e a **mesma**
resposta nas três — as duas asserções juntas, porque provar uma sem a outra deixaria passar
o conserto que quebra o SC-003.

## Por que importa

Sem isto, à pergunta *"esta credencial foi recusada por quê?"* a resposta operacional é
*"por alguma coisa"*. Quem investiga uso indevido precisa saber se alguém está tentando um
token que **nunca existiu** — varredura — ou um que **foi revogado** — integração que ninguém
avisou, ou credencial que vazou antes da revogação.

São duas investigações diferentes, e hoje começam iguais.

**Prioridade**: média. Não há defeito visível a quem usa, e o dado de operação está
incompleto desde que a API existe.
