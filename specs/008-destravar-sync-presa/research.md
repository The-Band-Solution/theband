# Pesquisa — Feature 008: destravar a sincronização presa

Seis questões. Três foram respondidas **lendo a fonte da dependência**, e não supondo — e duas
dessas leituras **mudaram o desenho**, uma delas depois da análise.

| Questão | O que a leitura da fonte mudou |
|---|---|
| R1 | o resgate automático **saiu**: ele não verifica nada além do tempo, e resgataria coleta viva |
| R2 | virou a **carência** da execução recém-aberta, porque o resgate não existe mais |
| R3 | os estados ativos são **cinco**, não quatro: faltava `suspended` |

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

### A decisão mudou depois da análise: **o Lifeline não entra**

A primeira decisão era configurá-lo com `rescue_after` de 60 minutos e administrar o risco pelo
valor do tempo. A análise pediu para conferir se existe proteção **além** do tempo, e a resposta
está na implementação do resgate — `deps/oban/lib/oban/engines/basic.ex:189`:

```elixir
base = where([j], j.state == "executing" and j.attempted_at < ^cut)
rescue_query  = where(base, [j], j.attempt <  j.max_attempts)   # → "available"
discard_query = where(base, [j], j.attempt >= j.max_attempts)   # → "discarded"
```

**Não há verificação alguma de nó vivo, de heartbeat, de dono do trabalho.** Um `UPDATE` por
`attempted_at`, e nada mais. `attempted_at` marca o **início da tentativa** — então uma coleta que
leve mais que `rescue_after` numa tentativa única é resgatada **enquanto roda**.

Sessenta minutos são 3,7× a coleta mais longa de hoje. Mas a coleta cresce com o número de
repositórios — 135 agora —, e no dia em que passar de 60 minutos a plataforma passa a ter duas
execuções da mesma coleta ao mesmo tempo. **Sem aviso**, porque cada uma funciona.

É a L02, e ela já aconteceu: 32 registros coletados em vez de 16, e o número pareceu plausível.

**Decisão**: **não configurar o Lifeline.** A reconciliação encerra a execução órfã com o motivo, e
quem administra inicia uma coleta nova — que recoleta desde o começo **sem duplicar linha**, porque
a gravação é por chave natural.

| | com Lifeline | sem Lifeline |
|---|---|---|
| trabalho já feito | retomado pelos cursores | **recoletado** |
| custo | nenhum | consulta repetida à origem, ~16 min no pior caso medido |
| risco de execução dupla | **existe**, e cresce com a coleta | **não existe** |

**A troca é deliberada: menos capacidade, e nenhum caminho para número duplicado.** Administrar
risco por constante de tempo é exatamente o que a L02 diz para não fazer, e a constante aqui
envelhece com o crescimento do dado.

**Recusado: proteger o resgate com claim do sync pelo trabalho.** Resolveria — o trabalho reclamaria
a execução ao começar, e o resgatado veria a reclamação viva e desistiria. Mas é desenho novo,
maior que a feature, para recuperar 16 minutos de coleta. `DynamicLifeline`, que faz isso de fato,
é do Oban Pro.

---

## R2 — A carência da execução recém-aberta (FR-011)

**Decisão**: **um minuto**. Execução aberta há menos de um minuto **não** é candidata a
reconciliação, mesmo sem trabalho ativo.

**Por que existe**: abrir a execução e criar o trabalho são **duas operações separadas** —
`Repo.insert()` e depois `Oban.insert()`. No intervalo entre elas o registro está `running` e não há
trabalho, o que é exatamente a assinatura de "presa". Sem carência, a verificação automática
encerraria uma coleta que acabou de começar.

**Por que um minuto**: o intervalo real é de milissegundos. Um minuto é margem de três ordens de
grandeza, e o custo de errar para o lado da paciência é o destravamento sair um minuto depois — o
que ninguém percebe, dado que a verificação roda a cada cinco.

**A carência não é a defesa principal**, e isso importa: se a criação do trabalho **falhar**, a
execução é encerrada **na hora**, com o motivo (FR-011a). A carência cobre a corrida; o resultado
conferido cobre a falha. Confundir os dois deixaria a execução presa até a carência passar, e aí
encerrada com o motivo errado — "o processo não existe mais", quando ele nunca existiu.

**Recusado: transação envolvendo a inserção do registro e a do trabalho.** Poria a fila dentro da
transação do domínio, e um `Oban.insert` lento seguraria a transação do sync. O que resolve é
conferir o resultado — que hoje é **descartado**, e é o achado A4 da análise.

**Recusado: carência longa, de cinco ou dez minutos.** Atrasaria o destravamento pelo tempo todo
para cobrir uma corrida de milissegundos.

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

### Os estados que contam como vivo, e o que a análise corrigiu

`Oban.Job.states/0` — `deps/oban/lib/oban/job.ex:416` — tem **oito**:

```
suspended scheduled available executing retryable completed discarded cancelled
```

A primeira versão desta pesquisa listou **quatro** como ativos: `available`, `scheduled`,
`executing`, `retryable`. **Faltava `suspended`**, que significa trabalho pausado — vai executar. A
reconciliação teria encerrado execução viva por causa de uma lista escrita de memória.

**Ativo é**: `suspended`, `scheduled`, `available`, `executing`, `retryable` — os cinco.
**Não ativo**: `completed`, `discarded`, `cancelled`.

A lista vem de `Oban.Job.states/0` menos os três terminais, e o teste **compara com a função** em
vez de repetir a lista: assim uma versão nova do Oban que acrescente estado não passa em silêncio.

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
2. **ele não cobriria o caso órfão, que é o que aconteceu de verdade duas vezes.** Trabalho que
   morre com o nó **não emite evento nenhum**: não há `[:oban, :job, :exception]`, porque não houve
   exceção — houve ausência de processo. Telemetria vê o que acontece; ninguém emite evento sobre o
   que deixou de acontecer.

   O mesmo valeria para qualquer transição feita em SQL por plugin, que emite telemetria de
   *plugin* e não de job.

O trabalho periódico vê o **estado**, e não o evento. Estado é o que sobrevive a reinício da
aplicação, a nó que morre sem avisar, a plugin que muda linha por SQL, e a handler que ninguém
registrou.

**É a diferença entre perguntar "o que aconteceu?" e "como as coisas estão?"** — e o defeito desta
issue é justamente algo que **não** aconteceu: ninguém encerrou o registro.

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
