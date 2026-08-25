# Specification Quality Checklist: Papéis por organização

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-24
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

**Nota.** A spec cita `eo_team_memberships.organizational_role_id`, `catalog_key` e os
identificadores `sro.*`. São **nomes do esquema e da rede**, e a decisão é sobre eles
especificamente — a `FR-001` fala de uma coluna que falta, e descrevê-la genericamente
tornaria o requisito não-verificável.

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## As três decisões, e de onde vieram

| ponto | decisão | frase de origem |
|---|---|---|
| escopo do cadastro | **por organização** | *"o cadastro de papéis é por organização"* |
| quem associa | **uma pessoa, via sistema** | *"quem associa os papéis é uma pessoa via sistema"* |
| os quatro do Scrum | **pré-cadastrados, em todas** | *"esses papéis pré-cadastrados estão em todas as organizações"* |
| papéis por pessoa | **mais de um na mesma equipe** | *"uma pessoa pode assumir mais de um papel na equipe do projeto"* |
| nível de acesso | **não entra na decisão, nem como contexto** | *"não use os níveis de acesso do GitHub"* |

Nenhuma virou `[NEEDS CLARIFICATION]` porque as três vieram ditas.

## A recusa que a spec protege, e a versão fraca que eu tinha escrito

A primeira versão desta spec dizia que a tela **poderia** mostrar o nível de acesso "como
contexto para a decisão", proibindo só a inferência.

A pessoa mantenedora corrigiu: *"não use os níveis de acesso do GitHub, isso não indica role
dos projetos"*. E a correção está certa por uma razão que a versão fraca não enxergava:

> **Exibir `ADMIN` ao lado de um seletor de papel faz dele uma dica**, por mais que o texto
> negue. A proibição da inferência viraria letra morta, e o viés entraria sem nenhum código
> o declarar — que é a pior forma, porque não há o que revisar.

`ADMIN` é atributo da **ferramenta**: diz quem administra membros e permissões no GitHub. Não
guarda relação com quem é Product Owner, Scrum Master, Developer ou Client.

Duas verificações, e a segunda é a que a versão fraca não permitia:

- **`SC-005`**: em toda evidência, o campo de papel começa **vazio**;
- **`SC-005a`**: procurar `ADMIN`, `WRITE` e `READ` no que a tela de promoção renderiza deve
  dar **zero**.

`platform_access_level` **continua sendo coletado** — é fato observado, e apagá-lo seria
perder dado verdadeiro. O que se proíbe é usá-lo para decidir papel, inclusive exibindo-o
onde a decisão acontece.

## O que a spec deliberadamente NÃO resolve

- **Sugerir papel a partir de comportamento** — quem revisa mais, quem fecha mais tarefa.
  Tem os mesmos riscos da `FR-012` e merece spec própria.
- **Hierarquia de equipes** (#397). Depende desta: hierarquia sem membro não soma nada.

## Notes

- Não depende de PR aberto. `eo_team_membership_evidence` já existe com as 101 linhas, e
  `eo_team_memberships` já tem `declared_by_user_id` esperando.
