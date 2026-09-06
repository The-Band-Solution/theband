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

E na etapa medida não era rate limit: a cota GraphQL é 5 000 pontos/hora, e ~2,5
repositórios por minuto não chega perto. Se fosse, haveria `snooze` — e não houve nenhum.

**Correção de 2026-09-05, apontada pela avaliação técnica independente**: essa frase vale
para as **mudanças**, que usam GraphQL. As **verificações** usam REST — uma requisição
por execução, no balde `core`, que tem cota e reset **próprios**. Foi esse balde que
estourou duas vezes no dia, e a ADR original tratava os dois como um só.

A aritmética que decide tudo: 5 000 req/h são **1,39 req/s sustentado**. A coleta com
concorrência 5 fez ~4 req/s — gasta a hora inteira de cota em **~21 minutos**. Os 3 316
runs de 10 repositórios extrapolam para ~28 000 requisições na carga inicial de 86: **no
mínimo 5,7 horas de cota a 100% de aproveitamento, com qualquer concorrência**. O desenho
não pode ir mais rápido; só pode não desperdiçar requisição e atravessar várias janelas
sem perder o lugar. **É coordenação de uma cota externa, e não processamento.**

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

### 5. O rate limit dentro da etapa: hibernar sem dormir, e retomar de onde parou

Pedido da pessoa mantenedora em 2026-09-05, depois de a coleta real mostrar o custo do que
existe hoje: **98 repositórios pulados e 586 execuções sem jobs**, todos por rate limit,
numa coleta que terminou em `completed` como se nada faltasse.

O que o código fazia ao bater na cota **no meio** de uma etapa:

1. marcava o repositório como não coletado e **seguia para o próximo** — que falhava
   igual, gastando mais uma requisição contra a cota secundária. Foram 98 seguidas;
2. gravava a execução sem os jobs e seguia para a próxima execução — 586 vezes;
3. terminava a etapa com resumo parcial, e o job com `:ok`. **A próxima coleta refazia
   tudo**, inclusive a requisição de jobs de execuções que **já os tinham** no banco —
   e batia na cota de novo, no mesmo lugar.

A implementação óbvia é `Process.sleep` até a janela reabrir. **É a errada**, e o código
já diz por quê: um job que dorme parece travado, o `ReconcileStuckSyncs` o encerraria, e o
slot da fila fica preso por até uma hora sem fazer nada.

#### O algoritmo

```
ao receber {:rate_limited, reset} dentro de uma etapa:

  1. PARAR a etapa — não tentar o próximo repositório nem a próxima execução.
     Todos falhariam igual, e cada tentativa é uma requisição que a cota
     secundária conta. Com Task.async_stream isso é reduce_while sobre o
     stream: as tarefas já iniciadas terminam, as não iniciadas não começam.

  2. NÃO gravar checkpoint do que ficou incompleto — já é assim (L29), e é
     o que faz a retomada saber onde continuar.

  3. A etapa devolve {:snooze, reset} em vez de {:ok, resumo_parcial}.
     O job propaga: Oban reagenda SEM consumir tentativa, o slot da fila é
     liberado, o sync fica `running`, e nenhum processo dorme.

  4. NA RETOMADA, repositório sem checkpoint é refeito — MAS execução que
     JÁ TEM jobs no banco NÃO gera nova requisição de jobs. É a diferença
     entre "retomar de onde parou" e "recomeçar": hoje a retomada refaz as
     mesmas 3 316 requisições e cai no mesmo buraco.

  5. Repetir até a etapa completar sem snooze.
```

**O passo 4 é o que torna os outros úteis.** Sem ele, hibernar e voltar só adia a mesma
falha: a cota reabre, a coleta refaz o que já tinha, gasta a cota de novo no mesmo ponto,
e hiberna outra vez — para sempre, no mesmo repositório.

#### O que isto NÃO muda

O `pause_needed?` preventivo (`remaining < cost * 2`) continua sendo a primeira defesa: é
melhor pausar antes de bater do que tratar a batida. Este algoritmo é o segundo nível — o
que acontece quando a pausa preventiva não alcançou, porque outra coisa gastou a cota (um
segundo coletor, ou a pessoa usando o mesmo token no `gh`).

## Alternativas consideradas

**Subir o limite da fila `ingestion`.** Não resolve nada: há **um** job de sync, e ele
seria o mesmo job sequencial com mais vizinhos ociosos.

**Broadway.** Backpressure e concorrência prontos, e nenhuma persistência própria.

*Emendado em 2026-09-05, depois de avaliação técnica independente pedida pela pessoa
mantenedora.* O argumento original — "a fonte é uma API paginada, não uma fila" — é
**fraco**: a fonte de um pipeline aqui seria a lista de `(repositório, etapa)` pendentes
no Postgres, e um `ack` que grava checkpoint é persistência suficiente. O argumento
correto é outro: **esse produtor é o Oban** — fila em Postgres com `SKIP LOCKED`,
`snooze` sem consumir tentativa, `unique`, telemetria, e o `ReconcileStuckSyncs` decide
"presa" consultando `oban_jobs`. Um pipeline fora do Oban seria encerrado como órfão em
60 segundos. Broadway sobre Postgres é reimplementar a metade do Oban que já se paga, para
ganhar a metade que não se precisa.

E o `rate_limiting` nativo do Broadway mede a coisa errada: **mensagens por pipeline**, com
taxa fixa. A cota é **requisições por token**, compartilhada entre etapas, coletores e o
`gh` de quem mantém — e toda resposta REST já traz `x-ratelimit-remaining`, que é a
verdade do token naquele instante. Ler o cabeçalho torna o limitador fixo desnecessário.

**OTP + Broadway, GenStage puro, e o híbrido** foram avaliados e recusados pelo mesmo
motivo: para uma lista finita de ~100 itens com concorrência 5, `async_stream` **já é** um
consumidor por demanda. Backpressure resolve fonte mais rápida que consumidor; aqui o
destino aceita menos do que se produz. O que rende é um GenServer por token só se for
**orçamento lido do cabeçalho**, não taxa fixa — e o primeiro passo disso nem precisa de
processo: é devolver `remaining`/`reset` das respostas 200, que hoje são descartados.

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
