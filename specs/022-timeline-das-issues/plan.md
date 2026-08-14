# Implementation Plan: a timeline da issue

**Branch**: `048-plano-timeline` · **Data**: 2026-08-14
**Spec**: [spec.md](./spec.md) · **Pesquisa**: [research.md](./research.md)

## Summary

A plataforma tem dois instantes por issue — `created` e `closed` — e nada entre eles. Sem isso
não há cycle time, não há WIP verdadeiro, e as 1642 issues abertas com designado incluem quem foi
designado meses atrás e nunca começou.

A feature coleta a timeline e a registra como `spo.performed_project_activity` — **a primeira
materialização de um conceito que nada materializa hoje**, e cuja forma será herdada por commits,
execuções de teste, cerimônias e implantações.

## Technical Context

**Linguagem**: Elixir 1.20 · OTP 27 · PostgreSQL 16
**Testes**: ExUnit, com a borda HTTP do GitHub simulada por Mox
**Escala hoje**: 5032 issues · 3390 fechadas · 4286 designações vigentes
**Meta**: nenhuma consulta de timeline para repositório pulado ou issue não alterada

**Restrições**:
- a tabela é do **conceito**, e não do GitHub — commits e implantações vão para ela;
- nenhum evento recebido pode ser descartado;
- a plataforma não deriva cycle time sem regra declarada.

**Nenhum NEEDS CLARIFICATION.** As três verificações contra a API real foram **feitas em
2026-08-14**, e o que elas acharam mudou duas decisões — ver
[research.md](./research.md#o-que-foi-medido-e-o-que-mudou).

## Constitution Check

| Princípio | Como esta feature se comporta |
|---|---|
| **I — domínio pelas ontologias** | a tabela nasce do critério de identidade de `spo.performed_project_activity`, escrito na base |
| **II — fonte externa não é domínio** | o tipo do evento é gravado **como a origem o nomeia**; traduzir esconderia o que ela disse |
| **III — proveniência e idempotência** | `source_external_id` no critério de identidade é o que impede duas coletas gerarem duas ocorrências |
| **IV — semântica em YAML** | a regra de início e as máximas de antipadrão já estão em `process_antipatterns.yaml` |
| **V — monólito modular** | a atividade vive em SPO; `Ingestion` grava, e a detecção de antipadrão consome depois |
| **VI — Spec Kit antes do código** | e a análise achou dois defeitos, um deles antes da spec existir |
| **VII — gates e revisão** | treze gates; e a SC-003 é a asserção de que nada foi descartado |
| **VIII — desenho que o problema justifica** | ver abaixo |
| **IX — ontologias modulares** | o conceito é lido pela API da base de conhecimento |
| **X — responsabilidade única** | esta feature **coleta**; a detecção de antipadrão é outra, e a declaração da regra já é |

### Princípio VIII — as três perguntas, por decisão introduzida

| Decisão | Qual problema concreto? | Existe agora? | O que fica pior? |
|---|---|---|---|
| **tabela `spo_performed_project_activities`** | não há onde registrar ocorrência de atividade; o conceito não é materializado | **sim** — e é o que impede cycle time | uma tabela que quatro origens futuras vão dividir, e cujo esquema fica mais genérico do que a primeira precisa |
| **`activity_type` como texto** | tipo novo da origem não pode exigir migração | **sim** — o GitHub acrescenta tipos de timeline | perde a garantia do banco sobre o conjunto de valores |
| **ligação genérica à entidade de origem** | um commit não tem issue; coluna dedicada ficaria nula em metade das linhas | **previsão**, e ela está declarada na ontologia — não é minha | uma junção a mais para achar as atividades de uma issue |
| **`unknown_type` registrado com o nome da origem** | descartar faria a soma divergir sem erro | **sim** — quatro tipos do GitHub não têm conceito | linhas na tabela que nenhuma consulta usa ainda |

**A terceira é a única baseada em previsão**, e a justificativa não é minha: a ontologia declara
que commits, testes e implantações são especializações do mesmo *kind*, e que compartilham o
princípio de identidade. Ignorar isso agora seria desenhar contra o modelo que a plataforma
inteira segue.

### O antipadrão que este plano evita

**Fallback silencioso.** Um evento de tipo desconhecido não pode virar `nil` nem sumir. A FR-005
o registra nomeando o tipo, e a SC-003 afirma a soma — é a **L57**, que nasceu de uma verificação
percorrendo lista vazia e devolvendo verde.

## Fases

### Fase 0 — verificar a origem *(FEITA em 2026-08-14)*

As três perguntas foram respondidas contra a API real, e a terceira **mudou o escopo**:
`ProjectV2ItemStatusChangedEvent` está na timeline da issue, com estado anterior, novo e autor.

**A dependência da #181 caiu.** Os quatro antipadrões funcionam nesta feature.

E o quadro real trouxe duas coisas que o plano não previa: **não existe coluna "Em andamento"** —
o fluxo é `Backlog → Ready → In review → Done` —, e **160 das 357 movimentações são de robô**.

### Fase 1 — a atividade executada *(US1, P1)*

Tabela, schema e gravação. É a fase que define a forma herdada pelas irmãs, e por isso ela vem
antes de qualquer coleta.

### Fase 2 — coletar a timeline *(US1, P1)*

A consulta ganha `timelineItems`, dentro da janela da 020: repositório pulado não tem timeline
pedida.

### Fase 3 — a plataforma diz o que não sabe *(US2, P1)*

A tela mostra os tipos **e os estados** observados com a frequência, e diz que cycle time depende
de saber **qual movimentação marca o começo** — decisão que a medida tornou concreta: entre
`Ready` e `In review`, só quem conhece o quadro sabe qual significa "peguei".

**Esta fase é o teto da feature.** Sem ela, a plataforma teria dado novo e continuaria em
silêncio sobre o que não consegue medir.

## Artefatos gerados

| Arquivo | O que traz |
|---|---|
| [research.md](./research.md) | as cinco decisões, e a forma que dura mais que a feature |
| [data-model.md](./data-model.md) | a tabela do conceito, e o que ela deliberadamente não tem |
| [contracts/atividade-executada.md](./contracts/atividade-executada.md) | as assinaturas, antes da implementação |
| [quickstart.md](./quickstart.md) | como provar, incluindo a prova de que nada foi descartado |

## Constitution Check — reavaliação depois do desenho

**Nenhuma violação.** Duas observações:

**A tabela é mais genérica do que esta feature precisa, e isso é deliberado.** É o único ponto do
plano baseado em previsão, e a previsão está na ontologia — não em mim. O custo está nomeado: uma
junção a mais, e um esquema que a primeira origem não usa por inteiro.

**A dependência da #181 caiu, e a verificação valeu o que custou.** A suposição inicial estava
errada: a movimentação vem na timeline da issue. Uma consulta antes do código evitou uma feature
inteira desenhada em torno de uma dependência que não existia — é a **L23** dando lucro em vez de
cobrar.

**E ela trouxe o que ninguém tinha perguntado**: quase metade das movimentações é de automação.
Um cartão que o robô moveu para `Done` ao fechar a issue não diz que alguém trabalhou nela — e a
detecção precisa distinguir isso. Entrou no `research.md` R2.
