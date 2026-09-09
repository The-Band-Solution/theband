# Modelos

<!-- DERIVADO da estrutura de agentes em 2026-09-07. Índice mantido à mão; cada
     documento abaixo é derivado do código e traz a própria proveniência. -->

Os modelos que a implementação não carrega sozinha: o que existe, por quais situações passa, o
que o banco guarda, e o que depende do quê no backlog.

**A regra**: modelo é **derivado**, nunca lembrado. Todo documento aqui sai de uma fonte do
repositório — schema, migração, YAML da base, spec, issue — e abre dizendo de onde saiu, com
`arquivo:linha` e a data da conferência. Quem escreve é o papel
[Documentation — Modelos](../../.claude/agents/documentacao-modelos.md).

| Pasta | O que responde | Forma |
|---|---|---|
| `classes/` | quais entidades existem, o que carregam, como se ligam | `classDiagram` (Mermaid), uma por subsistema |
| `estados/` | por quais situações um registro passa, e o que provoca cada transição | `stateDiagram-v2`, com gatilho, guarda e o teste que prova |
| `banco/` | quais tabelas, colunas, chaves e **índices parciais** (que carregam invariante) | `erDiagram`, derivado das migrações |
| `dsm/` | o que precisa vir antes do quê, entre épicos, user stories e features | matriz em Markdown, com blocos e ciclos nomeados |

## O que existe hoje

| Documento | Derivado de | Data |
|---|---|---|
| [`classes/eo-estrutura-organizacional.md`](classes/eo-estrutura-organizacional.md) | `lib/the_band/ontology/seon/eo/schemas/*.ex`, as treze migrações da EO, `organizational_structure.yaml`, `github_team_membership_evidence.yaml` | 2026-09-07 |
| [`estados/vinculo-de-equipe.md`](estados/vinculo-de-equipe.md) | `eo/commands.ex`, `eo/queries.ex`, `schemas/team_membership.ex`, migrações `20260814140000`, `20260901230000`, `20260906230000`, ADR 0008 e os testes de vínculo | 2026-09-07 |
| [`dsm/060-tela-da-equipe.md`](dsm/060-tela-da-equipe.md) | `specs/060-tela-da-equipe/{spec,plan,tasks,data-model}.md` e os módulos que cada história toca | 2026-09-07 |

`banco/` ainda está vazia. Os índices parciais e os `CHECK` da EO estão na tabela *Invariantes*
do diagrama de classes; o `erDiagram` do contexto EO é a próxima entrega.

## Como ler uma DSM

Linhas e colunas são os mesmos itens, na mesma ordem. A célula `(i, j)` marcada significa
**i depende de j**, e a marca diz a natureza: `D` dado · `T` tela · `R` regra · `E` esquema.
Depois de reordenar, o que fica **abaixo** da diagonal é ordem possível; o que sobra **acima**
é ciclo, e ciclo é achado — o documento o nomeia e propõe o corte. Blocos na diagonal são as
fatias que viajam juntas numa PR; a recomendação de fatiamento é oferecida ao Product Owner,
que decide.
