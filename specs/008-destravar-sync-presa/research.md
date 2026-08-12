# Pesquisa — Feature 008: destravar a sincronização presa

Seis questões. Duas delas foram respondidas **lendo a fonte da dependência**, e não supondo — e
uma dessas leituras mudou o desenho.

---

## R1 — O que o Lifeline faz de fato, e ele resolve o caso órfão sozinho?

**Lido em `deps/oban/lib/oban/plugins/lifeline.ex`**, e não deduzido da intenção do nome.

**O que ele faz**: passa job travado em `executing` de volta para `available` — **por tempo puro**,
e o moduledoc é explícito: *"Rescuing is purely based on time, rather than any heuristic about the
job's expected execution time or whether the node is still alive."*

**E há um aviso, na própria documentação**:

> This plugin may transition jobs that are genuinely `executing` and cause duplicate execution.

Ou seja: **o Lifeline não sabe se o nó morreu.** Se `rescue_after` for menor que a execução
legítima mais longa, ele resgata coleta viva e ela roda **duas vezes** — que é a L02 deste projeto,
onde a coleta duplicada trouxe 32 registros em vez de 16 e o número pareceu plausível.

**Ele resolve o órfão? Parcialmente, e a distinção importa:**

| situação do job | o que o Lifeline faz | o sync fica preso? |
|---|---|---|
| `executing` com tentativas restantes | volta a `available` e **executa de novo** | **não** — a coleta retoma e encerra o sync |
| `executing` com tentativas **esgotadas** | marca `discarded` | **sim** — ninguém encerra o sync |
| `discarded` por falha | nada, não é do escopo dele | **sim** |

**Decisão**: configurar o Lifeline **e** a reconciliação. O Lifeline cobre o caso em que retomar é
possível — FR-010 —, e a reconciliação cobre os dois casos em que o job termina sem que nada
encerre o registro.

**Isto responde a pergunta que o pedido fez**: não, o Lifeline **não** resolve sozinho. Ele resolve
o melhor caso, e cria um caso novo — o `discarded` por esgotamento, que antes dele não existia
porque o job ficava `executing` para sempre.

---

## R2 — Quanto tempo até considerar um job órfão (FR-011)

**Decisão**: **60 minutos**, que é o padrão do plugin. E o padrão fica **explícito na
configuração**, não implícito.

**Razão, medida no banco:**

```sql
select status, count(*), max(finished_at - started_at) as mais_longa
  from syncs where finished_at is not null group by status;

 failed      | 2  | 00:01:34
 completed   | 28 | 00:16:25
 interrupted | 2  | 01:28:56   ← as duas presas, com 0 registros coletados
```

A execução **legítima** mais longa levou **16 min 25 s** e coletou 3 641 registros. Sessenta
minutos são **3,7×** isso.

**Por que não 5 minutos**, que a documentação sugere como "mais agressivo": resgataria a coleta de
16 minutos no meio, e ela rodaria duas vezes. O custo do erro é assimétrico — esperar 60 minutos
atrasa o destravamento; resgatar cedo **duplica coleta**, e a L02 mostra que o número duplicado
passa por correto.

**Por que declarar o valor mesmo sendo o padrão**: um padrão que ninguém escreveu é um padrão que
ninguém revisa. Quando a coleta mais longa passar de 60 minutos — e ela cresce com o número de
repositórios —, o valor precisa estar visível para ser aumentado.

**Critério de revisão, escrito aqui de propósito**: se alguma execução `completed` passar de
**30 minutos**, `rescue_after` precisa subir. Metade da margem gasta é o gatilho.

---

## R3 — Como ligar um sync ao trabalho que o executa

Sem essa ligação não há como distinguir coleta viva de coleta morta, e FR-005 proíbe encerrar
coleta viva.

**Decisão**: **consultar `oban_jobs` pelos args** — `args->>'sync_id'`. Nenhuma coluna nova.

**As três perguntas do princípio VIII:**

**Qual problema concreto resolve?** Saber se existe trabalho ativo para aquele sync. Hoje a
plataforma não sabe, e é por isso que o destravamento foi feito por SQL duas vezes.

**O problema existe agora?** Sim: 1 job `executing` há três dias, 5 `discarded`, 2 syncs
destravados à mão.

**O que fica pior?** A consulta depende da **forma dos args** — `%{"tenant_id" => _, "sync_id" =>
_}`. Se alguém enfileirar um worker de coleta sem `sync_id`, a ligação se perde em silêncio, e o
sync passa a parecer sem trabalho — o que o encerraria indevidamente. Mitigação: os args são
escritos por `Ingestion.enqueue/3`, **no mesmo módulo** que fará a leitura, e o teste do contrato
exige que a chave exista.

**Recusado: coluna `oban_job_id` no sync.** Poria identificador da fila dentro do registro de
domínio, e contradiz a decisão já escrita em `enqueue/3` — *"o worker é escolha de quem chama e não
vive no registro do sync"*. O ganho seria índice direto; o custo é um dado de infraestrutura no
domínio, que envelhece quando a fila muda.

**Critério de reversão**: se um worker de coleta passar a ser enfileirado sem `sync_id` nos args, a
coluna vira o caminho certo — porque aí a ligação deixou de existir no dado.

**Recusado: decidir por idade do sync sozinha.** Um sync de 20 minutos pode ser coleta viva de
3 641 registros ou coleta morta. Idade não distingue, e FR-005 exige distinguir.

**Sobre o custo da consulta**: `oban_jobs` é podado em 7 dias pelo Pruner já configurado — hoje tem
**41 linhas**. Varredura pequena, e nenhum índice novo. Se a tabela crescer, o índice sobre
`(args->>'sync_id')` é a correção, e este parágrafo é o gatilho.

---

## R4 — O gatilho que não depende de ninguém abrir a tela (FR-006)

**Decisão**: **um trabalho periódico**, a cada 5 minutos, via `Oban.Plugins.Cron`. E a tela
**também** chama a mesma reconciliação ao carregar.

**Recusado: handler de telemetria em `[:oban, :job, :*]`.** Duas razões, e a segunda é decisiva:

1. handler não registrado é **sucesso silencioso** — a família L22/L23/L26 deste projeto. Provar
   registro exige um teste que inspeciona `:telemetry.list_handlers/1`, o que é possível e ainda
   assim frágil;
2. **ele não cobriria o caso do Lifeline.** O Lifeline transiciona jobs **em SQL**, e emite
   telemetria de *plugin* (`rescued_jobs`, `discarded_jobs`) — não eventos de job. Um handler de
   evento de job **nunca veria** o job que o Lifeline descartou, que é exatamente o caso novo
   criado por R1.

O trabalho periódico vê o **estado**, e não o evento. Estado é o que sobrevive a reinício da
aplicação, a plugin que muda linha por SQL, e a handler que ninguém registrou.

**Por que 5 minutos**: é o atraso máximo aceitável entre a coleta morrer e a ferramenta voltar a
aceitar coleta. Menor que isso gasta consulta sem ganho; a tela cobre a pressa de quem está olhando.

**Recusado: reconciliar dentro do próprio worker de coleta, no `rescue`.** Job descartado por
exceção não executa mais nada — não há onde pendurar o `rescue`. E job morto com o nó não executa
`rescue` nenhum, por definição.

---

## R5 — Onde a decisão vive, e se é comando ou consulta

**Decisão**: uma função em `TheBand.Ingestion`, a fronteira do módulo. **Comando**, porque escreve.

Ela lê o estado do trabalho e escreve o registro do sync. A leitura é interna à decisão, e não
função pública de consulta — expor "este sync está preso?" convidaria a segunda implementação, que
é o que FR-007 proíbe.

**Um caminho, três gatilhos:**

```text
trabalho periódico ─┐
tela ao carregar ───┼──→ Ingestion.<a decisão> ──→ finish(:interrupted, motivo, autor)
ação humana ────────┘
```

A ação humana passa o autor; os outros dois passam **nada**, e a ausência é o que registra "foi a
plataforma".

**Recusado: submódulo `Ingestion.Reconciliation`.** `Ingestion` é um módulo só neste projeto —
diferente de `WorkItems` e `CMPO`, que têm `commands/` e `queries/`. Criar a divisão aqui para uma
função é dividir por antecipação, e o princípio X decide contra.

---

## R6 — O autor do encerramento, e por que sem check constraint

**Decisão**: `syncs.interrupted_by_user_id`, **anulável**, e **sem** check constraint exigindo
autor.

**Razão**: aqui há **dois** encerradores legítimos — a pessoa e a plataforma. O nulo não é lacuna:
é a afirmação "não foi pessoa".

**A comparação que explica**: `observed_repositories.excluded_by_user_id` **tem** constraint —
`observed_repositories_exclusion_has_author` —, porque exclusão só acontece por decisão de alguém.
Não há exclusão automática. Aqui há encerramento automático, e exigir autor forçaria inventar um.

**O que a constraint faria de errado**: obrigaria um usuário-sistema falso, ou obrigaria o
encerramento automático a mentir sobre quem decidiu. As duas coisas apagam a distinção que a coluna
existe para carregar.

**O que a tela mostra**: quem encerrou, por extenso — o nome da pessoa, ou "the platform". Nunca
`—` para os dois casos, porque aí a distinção não chegaria a quem lê.
