# Implementation Plan: as caixas de tempo, e as issues dentro delas

**Branch**: `053-plano-sprints` · **Data**: 2026-08-15
**Spec**: [spec.md](./spec.md) · **Pesquisa**: [research.md](./research.md)

## Summary

Os quadros do Projects v2 declaram caixas de tempo com nome, início e duração — 11 de 26 quadros,
15 campos, e o DevOps com 40 sprints. A plataforma não coleta nenhuma, e por isso não sabe
responder "o que aconteceu no sprint 38".

A feature coleta as caixas e associa as issues a elas. **É a primeira materialização de um
conceito da SRO** — nenhuma tabela `sro_*` existe hoje.

## Technical Context

**Linguagem**: Elixir 1.20 · OTP 27 · PostgreSQL 16
**Testes**: ExUnit, com a borda HTTP do GitHub simulada por Mox
**Escala medida em 2026-08-15**: 26 quadros · 11 com iteração · 15 campos · DevOps com 677 itens
**Meta**: nenhuma consulta de item para quadro sem campo de iteração

**Restrições**:
- todo campo de iteração vira sprint, e o nome do campo é preservado;
- a duração gravada é a **da iteração**, nunca a configurada no campo;
- a associação é muitos-para-muitos, porque as caixas se sobrepõem;
- ausência marca, nunca apaga.

**Nenhum NEEDS CLARIFICATION.** As três verificações contra a API foram **feitas em 2026-08-15**,
e a terceira mudou o desenho — ver [research.md](./research.md#o-que-foi-medido-e-o-que-mudou).

## Constitution Check

| Princípio | Como esta feature se comporta |
|---|---|
| **I — domínio pelas ontologias** | a tabela nasce de `sro.sprint`, e o critério de identidade dele é **declarado nesta feature** — ele não existia |
| **II — fonte externa não é domínio** | o nome do campo é gravado como a origem o nomeia; `Quarter` não vira `Sprint` no dado |
| **III — proveniência e idempotência** | `source_external_id` da iteração é o critério; duas coletas produzem uma caixa |
| **IV — semântica em YAML** | o critério de identidade entra na base antes da migração |
| **V — monólito modular** | SRO ganha fronteira própria; `Ingestion` grava, e quem lê passa por ela |
| **VI — Spec Kit antes do código** | e a fase 0 achou que o conceito não tinha critério de identidade |
| **VII — gates e revisão** | treze gates; a SC-003 é a asserção de que a sobreposição não foi achatada |
| **VIII — desenho que o problema justifica** | ver abaixo |
| **IX — ontologias modulares** | `sro` já depende de `spo`; nada novo atravessa fronteira |
| **X — responsabilidade única** | esta feature **coleta e associa**; velocity é outra, e depende de dado que não existe |

### Princípio VIII — as três perguntas, por decisão introduzida

| Decisão | Qual problema concreto? | Existe agora? | O que fica pior? |
|---|---|---|---|
| **tabela `sro_sprints`** | não há onde registrar caixa de tempo; nenhum conceito SRO é materializado | **sim** — 15 campos ativos, 40 sprints só no DevOps | a primeira tabela SRO fixa convenções que as irmãs vão herdar |
| **`field_name` em coluna** | `Quarter` de 90d e `Sprint` de 14d ficariam indistinguíveis | **sim** — medido em 4 quadros com os dois | uma coluna que a maioria das consultas ignora |
| **tabela de associação** | a mesma issue está em duas caixas | **sim** — 527+203 sobre 677 itens | uma junção a mais para achar as issues de um sprint |
| **fase de coleta por quadro** | caixa de tempo não pertence a repositório, e a janela da 020 não se aplica | **sim** — quadro não tem `pushedAt` | uma fase a mais na sincronização, com orçamento próprio |
| **critério de identidade na ontologia** | `sro.sprint` não tem, e nenhum ancestral tem | **sim** — verificado na base | a base ganha uma declaração que a tese não trazia |

**Nenhuma é baseada em previsão.** As cinco saem de medida feita antes do plano.

### O antipadrão que este plano evita

**Achatar a sobreposição.** Uma coluna `sprint_id` na issue seria mais simples de ler e escrever,
e obrigaria a escolher entre `Sprint` e `Quarter` — sem regra que justifique a escolha. O
Produtos Internos inverte a proporção, então nem "a mais usada" serviria.

É a mesma família do que a feature 023 enfrentou com designação compartilhada: dividir por dois
inventaria uma fração que ninguém combinou.

## Fases

### Fase 0 — verificar a origem *(FEITA em 2026-08-15)*

Três sondagens. A terceira mudou o desenho: `Quarter` carrega trabalho, e às vezes mais que
`Sprint`.

E ela achou o que o plano não previa: **`sro.sprint` não tem critério de identidade**, nem
herdado. A feature 022 encontrou o dela pronto na ontologia; aqui ele precisa ser escrito — e
por isso a fase 1 começa na base de conhecimento, e não na migração.

### Fase 1 — o critério e a caixa *(US1, P1)*

Declarar `identity_criterion` em `sro.sprint`, e só então a tabela. A ordem é a do princípio I:
a tabela nasce do critério, não o contrário.

### Fase 2 — as issues dentro da caixa *(US2, P1)*

A associação muitos-para-muitos, com marca de ausência. É onde a sobreposição vira dado.

### Fase 3 — coletar *(US1 e US2, P1)*

Fase nova na sincronização, por quadro. Quadro sem campo de iteração não tem itens consultados.

### Fase 4 — o que ficou fora da caixa *(US3, P2)*

150 dos 677 itens do DevOps não estão em sprint algum. A plataforma passa a saber dizer isso — e
a distinguir de "o quadro não usa caixas de tempo", que é outra coisa.

## Artefatos gerados

| Arquivo | O que traz |
|---|---|
| [research.md](./research.md) | as cinco decisões, e o critério de identidade que faltava |
| [data-model.md](./data-model.md) | as duas tabelas, e o que elas deliberadamente não têm |
| [contracts/caixas-de-tempo.md](./contracts/caixas-de-tempo.md) | as assinaturas, antes da implementação |
| [quickstart.md](./quickstart.md) | como provar, incluindo a prova da sobreposição |

## Constitution Check — reavaliação depois do desenho

**Nenhuma violação.** Duas observações:

**A primeira tabela SRO fixa convenção.** `sro_sprints` é a primeira materialização da Scrum
Reference Ontology neste repositório, e o prefixo, a forma do critério e o tratamento da ausência
serão copiados pelas irmãs — sprint backlog, cerimônia, entregável. Vale revisar com esse peso.

**O critério de identidade entra na base como `project_decision`.** Ele não vem da tese: a tese
descreve o conceito sem dizer como identificá-lo numa ferramenta. Declará-lo como se viesse dela
seria proveniência falsa — a mesma distinção que `process_antipatterns.yaml` já faz.
