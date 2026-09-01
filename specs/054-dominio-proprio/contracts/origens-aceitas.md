# Contrato — as origens aceitas para a conexão viva

**Feature**: [054](../spec.md) · **Requisitos**: FR-004 a FR-008

Este contrato descreve o comportamento observável. O nome do parâmetro da
biblioteca é detalhe de implementação e pode mudar; o que está aqui, não.

## A função

```elixir
TheBandWeb.Origens.aceitas(host_principal, declaracao_bruta)
```

| Argumento | Tipo | Significado |
|---|---|---|
| `host_principal` | `String.t()` | o endereço que a plataforma usa para gerar links |
| `declaracao_bruta` | `String.t() \| nil` | o valor cru da variável de ambiente, ou `nil` |

**Devolve**: `[String.t()]` — a lista de origens aceitas, sempre com ao menos uma
entrada.

## Os invariantes

| # | Invariante | Por que existe |
|---|---|---|
| C1 | O host principal está **sempre** na lista, em primeiro lugar | sem ele, publicar uma declaração errada derrubaria o endereço que funciona |
| C2 | `nil` e `""` produzem **exatamente** `["https://<host principal>"]` | FR-005: sem declaração, o comportamento é o de hoje. Ausência **restringe** |
| C3 | Cada entrada declarada vira uma origem, na ordem em que foi escrita | previsibilidade; a lista é lida por gente |
| C4 | Espaços em volta são ignorados; entrada vazia entre vírgulas é descartada | `a, ,b` é erro de digitação, não intenção de aceitar origem vazia |
| C5 | Uma entrada sem esquema recebe `https://` | o único esquema que a produção serve. Aceitar `http://` por omissão seria enfraquecer sem pedido |
| C6 | Nenhuma entrada duplicada aparece duas vezes | declarar o host principal na variável não deve produzir lista com repetição |
| C7 | **Não existe valor que produza "aceita qualquer origem"** | FR-007. Nem `*`, nem `true`, nem lista vazia. O que não está declarado é recusado |

## O que o contrato NÃO promete

- **Requisição sem cabeçalho de origem não é checada.** É comportamento do
  transporte do Phoenix, verificado em `research.md` R3: sem o cabeçalho, a
  conexão passa. Contra cliente programático a defesa é a sessão, não a origem.
  Quem ler C7 sem ler isto entenderia mais do que o contrato entrega.
- **Não valida se o endereço declarado existe.** Declarar um nome que não resolve
  não derruba a plataforma e não é detectado aqui — é o caso de borda "endereço
  declarado que ainda não resolve", e o comportamento correto é ignorá-lo até que
  alguém chegue por ele.
- **Não emite nem renova certificado.** Aceitar a origem e servir cifrado são
  problemas diferentes, e o segundo continua com quem já o resolve.

## O que a plataforma faz com a lista

A lista é entregue ao transporte do socket. Quando a origem de uma tentativa não
casa com nenhuma entrada:

1. o transporte registra em nível de **erro**, nomeando a origem que tentou
   (verificado em `research.md` R2);
2. responde **403** e interrompe a conexão.

Nenhum registro próprio é escrito por cima disso — ver a decisão 3 do
[plan.md](../plan.md).

## Comparação: o que muda em relação a hoje

| Situação | Hoje | Com o contrato |
|---|---|---|
| origem igual ao `PHX_HOST` | aceita — compara **só o host** | aceita — compara esquema, host e porta |
| origem em `http://` no mesmo host | **aceita** (o esquema não é comparado) | **recusa** |
| origem do segundo endereço | **recusa**, com 403 e log | aceita, se declarada |
| nada declarado | aceita só o `PHX_HOST` | aceita só o `PHX_HOST` |

A segunda linha é um aperto, não uma folga: escrever a origem com esquema torna a
comparação mais estrita do que o padrão da biblioteca. Está registrado aqui para
que a diferença não seja "consertada" por quem a encontrar sem contexto.
