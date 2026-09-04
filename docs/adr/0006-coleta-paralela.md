# ADR 0006 — Coleta paralela: concorrência por repositório, e o contador que precisa ser atômico antes

## Status

Proposta — 2026-09-04

Depende de: [ADR 0001](0001-monolito-modular-elixir.md)
Relacionada: [ADR 0005](0005-telemetria-da-jornada.md) — a J2 observa o que esta acelera

## Contexto

A primeira coleta contra dado real, em 2026-09-04, foi medida:

| medida | valor |
|---|---|
| repositórios percorridos na etapa de mudanças | **86** |
| tempo | 09:32:04 → 10:06:39 = **34,5 min** |
| por repositório | **~24 s** |
| jobs simultâneos | **1** |
| capacidade da fila `ingestion` | **5** |

**Quatro slots ociosos o tempo todo.** O código percorre em série:

```elixir
resultados = Enum.map(repositorios, &coletar_repositorio(ctx, &1))
```

E não é rate limit: a cota GraphQL é 5 000 pontos/hora, e ~2,5 repositórios por minuto
não chega perto. Se fosse, haveria `snooze` — e não houve nenhum.

### O modo de falha que a serialização produz

No mesmo dia, um `KeyError` num único repositório derrubou o job inteiro: cinco
tentativas, `discarded`, e **as etapas seguintes nunca rodaram** — as verificações ficaram
em zero. Um erro em um repositório custou a coleta de todos.

Serializar não é só lento: **acopla o destino de 88 repositórios ao pior deles**.

## Decisão

### 1. O framework não muda: Oban continua

Persistência, retomada e visibilidade de estado são o que uma coleta de horas precisa, e é
o que Oban dá. **A mudança é de granularidade, não de ferramenta.**

Broadway, GenStage e Flow foram considerados e recusados: a fonte é uma API paginada, não
uma fila, e nenhum deles persiste. Trocariam o problema que temos pelo que não temos.

### 2. Antes de paralelizar: o contador precisa ser atômico

`Ingestion.tally/2` é **read-modify-write**:

```elixir
%{records_collected: sync.records_collected + 1, records_created: sync.records_created + 1}
```

Sob concorrência, duas escritas leem o mesmo valor e uma sobrescreve a outra. O resultado
não é erro: é **um número menor do que a realidade, sem nada acusando** — a família de
defeito que esta casa persegue, agora nos próprios números da coleta.

**Esta é a primeira mudança, e ela precede qualquer paralelismo.** `update_all` com
incremento no banco, onde a atomicidade é do Postgres e não da nossa sorte.

Paralelizar antes disso produziria uma coleta mais rápida com contadores errados — e
contador errado numa tela de progresso é pior do que coleta lenta.

### 3. Concorrência dentro da etapa, com teto declarado

`Task.async_stream` sobre a lista de repositórios, com `max_concurrency` declarado como
atributo de módulo — não literal espalhado.

O teto tem dois limites reais, e o menor manda:

| limite | valor | por quê |
|---|---|---|
| pool do Ecto | 10 | cada tarefa precisa de conexão; estourar o pool trava a aplicação inteira, não só a coleta |
| cota do GitHub | 5 000 pontos/h | com 88 repositórios não é o gargalo hoje; com 800 seria |

**Teto inicial: 5.** Deixa metade do pool para o resto da aplicação, e é o mesmo número da
fila `ingestion` — coincidência útil, porque torna o custo previsível.

`ordered: false` porque a ordem dos resultados não significa nada, e `on_timeout: :kill_task`
com timeout declarado, para um repositório lento não segurar o lote.

### 4. Fan-out por repositório fica para depois, e começa pelas verificações

Um job por `(repositório × etapa)` resolve o acoplamento de destino — um repositório que
falha não leva os outros. É a mudança certa, e é maior: exige resolver *quando a coleta
terminou* (hoje o sync fecha quando o job acaba), a dependência entre etapas, e rate limit
global.

Quando for feita, **começa pelas verificações**: é a etapa mais cara — uma requisição por
execução de workflow — e a única que não depende de nenhuma outra. Melhor retorno, menor
risco, sem precisar de DAG.

`Oban Pro` entra na conversa nesse momento, e não antes: `Batch`, `Workflow` e rate
limiting global são exatamente essa lista de problemas resolvida. Comprá-lo agora seria
adquirir solução para problema que ainda não se tem.

## Alternativas consideradas

**Subir o limite da fila `ingestion`.** Não resolve nada: há **um** job de sync, e ele
seria o mesmo job sequencial com mais vizinhos ociosos.

**Broadway.** Backpressure e concorrência prontos, e nenhuma persistência. A coleta precisa
sobreviver a reinício — sem isso, volta ao começo a cada deploy.

**`Task.async` sem stream.** Sem limite de concorrência: 88 requisições simultâneas
estouram o pool do Ecto e a cota do GitHub ao mesmo tempo.

**Fan-out completo agora.** Recusado por ordem, não por mérito: exige contador atômico
(item 2), *"quando terminou"*, DAG e rate limit global. Fazer tudo junto é uma mudança
grande sem medição intermediária — e a medição intermediária é o que diz se o fan-out
ainda vale.

## Consequências

**Ganha-se** tempo de parede — o teto teórico é 5× na etapa que hoje leva 34 minutos — e
um contador que passa a estar certo, o que hoje **não se sabe se está**.

**Paga-se**:

- **concorrência no acesso ao banco.** Cinco tarefas escrevendo ao mesmo tempo no mesmo
  sync; o item 2 é o que torna isso seguro, e é por isso que ele vem antes;
- **erro dentro de `async_stream` muda de forma.** Uma tarefa que levanta vira
  `{:exit, reason}` no fluxo, e não exceção no processo pai. Tratar como sucesso é o jeito
  clássico de perder falha em silêncio — precisa de ramo explícito e teste;
- **log intercalado.** Cinco repositórios registram ao mesmo tempo, e o log deixa de ser
  legível em ordem. É o que a J2 da [ADR 0005](0005-telemetria-da-jornada.md) resolve, com
  span por repositório em vez de linha de log;
- **o teste fica sensível ao sandbox do Ecto.** Tarefa nova não herda a conexão de teste
  automaticamente. Ou se usa `allow/3`, ou a concorrência é configurável e o teste roda com
  1 — e a segunda opção **não testa o que importa**, então é a primeira.

**Não se resolve**: um repositório que falha continua podendo derrubar a etapa, porque o
job ainda é um só. Isso é o item 4, e fica declarado como não feito.

## Verificação

1. **o ganho medido, não estimado** — a mesma etapa, no mesmo conjunto de repositórios,
   com e sem concorrência. Hoje: 86 repositórios em 34,5 min. Se o ganho real for muito
   menor que 5×, o gargalo é a rede e não o desenho — e a ADR precisa ser revista;
2. **o contador está certo** — teste que roda N incrementos concorrentes e afirma que a
   soma é N. Com o `tally` atual ele reprova, e é isso que o torna prova;
3. **falha de uma tarefa não vira sucesso** — teste que faz uma tarefa levantar e afirma
   que o resumo a conta como não alcançada;
4. **o pool não estoura** — a aplicação continua respondendo durante a coleta.

## Referências

- [#801](https://github.com/The-Band-Solution/theband/issues/801) — o Oban parado, e como o
  progresso da coleta ficou invisível
- [ADR 0005](0005-telemetria-da-jornada.md) — J2, que observa a jornada que esta acelera
- `lib/the_band/ingestion/github_change_requests.ex` — o `Enum.map` medido
- `lib/the_band/ingestion.ex` — `tally/2`, o contador que precisa mudar primeiro
