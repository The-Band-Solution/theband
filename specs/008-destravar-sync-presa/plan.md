# Plano de implementação: destravar a sincronização presa

**Feature**: `specs/008-destravar-sync-presa/` · **Branch**: `009-destravar-sync-presa`
**Spec**: [spec.md](spec.md) · **Pesquisa**: [research.md](research.md)
**Constituição**: v1.4.0, dez princípios · **Origem**: issue #175

**O número da branch difere do diretório de propósito.** O diretório é `008` porque era o próximo
livre em `specs/`; a branch é `009` porque `009-aceitacao-sprint-006` já existe como branch de
documento, e duas branches com o mesmo número não se distinguem no `git branch`. Mesma razão de R5
da feature anterior.

---

## Summary

Uma execução de coleta cujo trabalho morreu deixa de bloquear a ferramenta. Encerra sozinha, com o
motivo que a causa determina, e sem apagar nada.

Medido: **2 execuções já foram destravadas por SQL**, há **1 trabalho executando desde 2026-08-09**
num nó que não existe mais, e **5 descartados** — dois deles por um módulo que não existe no
repositório.

## O que este plano descobriu lendo a dependência

**O Lifeline não resolve sozinho, e cria um caso novo.** A leitura da fonte — não da intenção do
nome — mostrou que ele resgata por **tempo puro**, sem saber se o nó morreu, e que job com
tentativas esgotadas ele marca `discarded` em vez de resgatar.

| Antes de ler | Depois de ler |
|---|---|
| "o Lifeline resgata órfão, e o sync nunca fica preso" | resgata **só** quem tem tentativa restante; esgotado vira `discarded`, e aí ninguém encerra o sync |
| "handler de telemetria pega o descarte" | o Lifeline muda linha **em SQL** e emite telemetria de *plugin* — o handler de evento de job **nunca veria** esse descarte |

As duas descobertas mudaram o desenho: entram **três** peças em vez de uma, e a que parecia óbvia —
telemetria — está recusada.

## Technical Context

| | |
|---|---|
| Linguagem | Elixir 1.20.2 / OTP 29 |
| Framework | Phoenix 1.8.9 + LiveView |
| Fila | Oban 2.23.1, filas `ingestion` e `transformation` |
| Persistência | Ecto + PostgreSQL 17 |
| Escala | 32 execuções registradas, 41 trabalhos na fila (podados em 7 dias) |
| Execução legítima mais longa | **16 min 25 s**, 3 641 registros |

---

## Constitution Check

### I. Domínio organizado pelas ontologias — **conforme**

Nenhum conceito novo. "Execução de coleta" é camada de plataforma, e sempre foi: `syncs` não é
tabela de ontologia. O autor do encerramento é atributo de um registro de plataforma.

### II. Fonte externa não é domínio — **conforme, e reforçado**

O estado do trabalho na fila é **lido para decidir** e **não copiado** para o registro. É a mesma
regra aplicada à API do GitHub: consultar não é absorver. R3 recusou a coluna `oban_job_id`
justamente por isso.

### III. Proveniência e idempotência (NÃO NEGOCIÁVEL) — **conforme, e é o centro da feature**

O motivo e o autor **são** proveniência do encerramento: quem decidiu, e por quê. E FR-014 exige
idempotência explícita — encerrar duas vezes não altera o primeiro motivo nem o primeiro autor.

A retomada do trabalho resgatado depende da idempotência que já existe: cursor por entidade em
`sync_checkpoints`, chave natural na gravação. **Se essa idempotência não valesse, FR-010 seria
impossível** — e é por isso que resgatar é seguro aqui e não seria em qualquer sistema.

### IV. Semântica declarada em YAML versionado — **não se aplica**

Nenhum conceito, regra ou mapeamento novo. Nada a declarar na base de conhecimento.

### V. Monólito modular multitenant — **conforme**

A decisão vive em `TheBand.Ingestion`, atrás da fronteira, recebendo `%Tenant{}`. Execução de outro
tenant responde **não encontrado** — FR-013.

O trabalho periódico atravessa tenants por natureza: ele reconcilia o que estiver preso, em
qualquer tenant. Isso **não** é vazamento de escopo — é manutenção da plataforma, e nenhum dado de
um tenant chega a outro. A distinção está declarada aqui para não parecer descuido.

### VI. Spec Kit e sprint backlog antes do código — **conforme**

Spec, checklist, pesquisa, este plano, data-model, contrato e quickstart antes da primeira linha. É
a terceira feature seguida na ordem certa.

### VII. Quality gates e revisão independente — **conforme por construção**

Dez gates por `mix gates`. O contrato vem antes da primeira função pública, em
[contracts/](contracts/stuck-sync-reconciliation.md).

### VIII. Desenho que o problema justifica — **conforme, com quatro padrões e cinco recusas**

Ver a seção abaixo. **A recusa mais importante é a telemetria**, e a razão é técnica, não estética.

### IX. Ontologias modulares e autônomas — **não se aplica**

A feature não atravessa fronteira entre ontologias. `syncs` e `oban_jobs` são plataforma.

### X. Responsabilidade única, em módulo e em tela — **conforme, e decidiu contra criar submódulo**

A tela de sincronizações continua respondendo uma coisa: *o que aconteceu nas coletas*. Encerrar uma
execução presa é parte dessa pergunta — não é painel de fila, e FR-015 fecha o escopo.

E o princípio decidiu contra `Ingestion.Reconciliation`: um submódulo para uma função é divisão por
antecipação. `Ingestion` é um módulo só neste projeto, diferente de `WorkItems` e `CMPO`.

---

## Registro dos padrões introduzidos (princípio VIII)

### P1 — `Oban.Plugins.Lifeline`, com `rescue_after` explícito

**Qual problema concreto resolve?** Trabalho travado em `executing` num nó morto. Há **um** assim,
desde 2026-08-09, e nada o move.

**O problema existe agora?** Sim, e já custou dois destravamentos manuais.

**O que fica pior?** O plugin resgata **por tempo puro**, sem saber se o nó morreu — e a própria
documentação avisa que pode duplicar execução. Com `rescue_after` curto, uma coleta viva de 16
minutos rodaria duas vezes, que é a L02: números duplicados passam por corretos.

Mitigação: **60 minutos**, 3,7× a execução legítima mais longa medida, com o valor **escrito** na
configuração e um gatilho de revisão declarado em R2 — se alguma execução passar de 30 minutos, o
valor sobe.

### P2 — `Oban.Plugins.Cron` e um trabalho periódico de reconciliação

**Qual problema concreto resolve?** FR-006: o bloqueio precisa sair sem ninguém abrir a tela. E
cobre o caso que a telemetria não cobriria — o job que o **Lifeline** descartou por SQL.

**O problema existe agora?** Sim: os 5 descartados nunca encerraram os registros deles.

**O que fica pior?** Um trabalho a mais rodando a cada 5 minutos, para sempre, mesmo quando não há
nada preso — e uma configuração de agendamento que ninguém lê até quebrar. O custo é consulta
pequena numa tabela de 41 linhas.

Mitigação: o trabalho é **idempotente e silencioso quando não acha nada** — nenhum log de
"reconciliei 0", que é ruído que treina a pessoa a ignorar o log.

### P3 — A decisão de reconciliar, em `TheBand.Ingestion`

**Qual problema concreto resolve?** Decidir se uma execução `running` ainda tem trabalho vivo, e
encerrá-la quando não tem, com o motivo que a causa determina.

**O problema existe agora?** Sim, e é a feature.

**O que fica pior?** `Ingestion` cresce, e passa a conhecer a forma dos args da fila. É acoplamento
real, declarado em R3, com critério de reversão escrito.

### P4 — `syncs.interrupted_by_user_id`, anulável e sem constraint

**Qual problema concreto resolve?** Distinguir encerramento por decisão humana de encerramento pela
plataforma. FR-009 exige, e sem a coluna as duas coisas ficariam indistinguíveis no registro.

**O problema existe agora?** Sim: os dois encerramentos manuais que aconteceram não têm autor
registrado em lugar nenhum — só no `error_reason` que eu escrevi à mão no SQL.

**O que fica pior?** Uma coluna anulável a mais, e a tentação de ler nulo como "não se sabe". A
mitigação é a tela: ela diz **"the platform"** por extenso, nunca `—`.

### Padrões **recusados**, e por quê

| Recusado | Por quê |
|---|---|
| **handler de telemetria de job** | não veria o descarte feito pelo Lifeline, que muda linha em SQL e emite telemetria de *plugin*; e handler não registrado é sucesso silencioso — L22/L23/L26 |
| coluna `oban_job_id` no sync | identificador de fila dentro do domínio, e contradiz a decisão já escrita em `enqueue/3` — R3 |
| decidir por idade do sync | não distingue coleta viva de coleta morta, e FR-005 proíbe encerrar coleta viva |
| status novo — `stuck`, `abandoned` | `interrupted` já significa "não terminou e não vai terminar"; o que faltava era motivo e autor |
| `Ingestion.Reconciliation` como submódulo | divisão por antecipação para uma função — princípio X |
| `rescue_after` de 5 minutos | resgataria a coleta de 16 minutos no meio, e ela rodaria duas vezes — L02 |

---

## Project Structure

```text
specs/008-destravar-sync-presa/
├── spec.md          15 FR, 11 SC, 3 user stories, 5 casos de borda
├── research.md      R1 a R6 — R1 e R2 vêm da fonte da dependência
├── plan.md          este documento
├── data-model.md    uma coluna
├── contracts/
│   └── stuck-sync-reconciliation.md
├── quickstart.md    V1 a V8
└── checklists/requirements.md
```

```text
config/config.exs                          + Lifeline e Cron, com os valores explícitos
lib/the_band/ingestion.ex                  + a decisão, e o motivo por causa
lib/the_band/ingestion/sync.ex             + interrupted_by_user_id no cast
lib/the_band/jobs/reconcile_stuck_syncs.ex + o trabalho periódico
lib/the_band_web/live/sync_live/index.ex   + a ação e quem encerrou
priv/repo/migrations/*_add_interrupted_by_user_id.exs
```

---

## Fases, e por que esta ordem

### F1 — A decisão, e o motivo por causa

A função em `Ingestion`, a coluna de autor, e os motivos distintos. **Primeiro porque é o que os
três gatilhos chamam** — implementar gatilho antes da decisão produziria a decisão escrita três
vezes, que é o que FR-007 proíbe.

Entregável sozinha? **Não visível**, e é a exceção declarada: a função sem gatilho não destrava
nada. É a razão de F2 vir no mesmo sprint — a L21 proíbe entregar função pública sem consumidor.

### F2 — Os gatilhos automáticos

`Lifeline` e `Cron` na configuração, e o trabalho periódico chamando a decisão de F1.

**Aqui o bloqueio sai sozinho**, e é o valor central da feature — SC-001 e SC-002 passam a valer.

### F3 — A tela

Reconciliar ao carregar, a ação de encerrar com confirmação, e **quem encerrou** por extenso.

**Por último**, porque é a única parte que depende das duas anteriores para ter o que mostrar.

---

## Riscos

| Risco | Mitigação |
|---|---|
| **resgatar coleta viva e duplicar registros** | `rescue_after` de 60 min, 3,7× a mais longa medida; gatilho de revisão em 30 min declarado em R2 |
| encerrar sync de coleta viva | a decisão exige **ausência de trabalho ativo**, nunca idade; teste com job `executing` de verdade |
| a ligação por args se perder em silêncio | os args são escritos no mesmo módulo que os lê; o contrato exige a chave, e o teste falha sem ela |
| ler nulo de autor como "não se sabe" | a tela escreve **"the platform"** por extenso; SC-007 exige distinguir |
| o trabalho periódico virar ruído | silencioso quando não acha nada — log só quando encerra algo |
| dois gatilhos encerrando ao mesmo tempo | FR-014: encerrar o já encerrado não muda motivo nem autor; a decisão só age sobre `running` |

---

## Complexity Tracking

| Item | Custo | Aceito porque |
|---|---|---|
| dois plugins de fila | duas configurações que ninguém lê até quebrar | os dois casos medidos — órfão e descartado — não têm outra cura |
| trabalho periódico a cada 5 min | consulta pequena, para sempre | é o único gatilho que vê **estado** em vez de evento, e sobrevive a reinício |
| `Ingestion` conhece a forma dos args | acoplamento à fila | a alternativa punha identificador de fila no domínio; critério de reversão escrito em R3 |
| coluna anulável de autor | um nulo a mais para interpretar | sem ela, decisão humana e automática ficam indistinguíveis |

---

## Reavaliação da constituição, pós-desenho

Dez princípios: oito conformes, dois não aplicáveis (IV e IX). Quatro padrões introduzidos, seis
recusados.

O princípio III é o que sustenta a feature inteira: **retomar só é seguro porque a coleta é
idempotente**, e o motivo com o autor é proveniência do encerramento. O princípio VIII produziu a
recusa mais valiosa — a telemetria, que parecia o caminho óbvio e não veria o caso que o próprio
Lifeline cria.
