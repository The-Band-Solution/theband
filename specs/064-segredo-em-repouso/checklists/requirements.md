# Specification Quality Checklist: Todo segredo protegido em repouso

**Purpose**: Validate specification completeness and quality before proceeding to planning

**Created**: 2026-09-12

**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

### O julgamento sobre "nenhum detalhe de implementação"

A spec **nomeia** `bcrypt`, `AES.GCM`, `users.session_token` e `oban_jobs.errors`. Isso passa
no critério, e a razão precisa ficar escrita porque a leitura rápida diria o contrário:

- Esses nomes aparecem **na seção de medição**, e não nos requisitos. São **a evidência** que
  corrige a premissa do pedido. Tirá-los deixaria a frase *"cifrar seria um retrocesso"* sem
  nada que a sustente — e é justamente a frase que contraria o que foi pedido.
- Nenhum FR nomeia algoritmo ou biblioteca. FR-001 diz *"resumo (hash) com sal"*, que é
  **propriedade**; FR-004 diz o que o token de sessão **não pode permitir**, e deixa o
  mecanismo para o plano. Nenhum SC nomeia tecnologia.

### Como esta validação foi feita

Uma passada só. A spec foi escrita já com as duas precisões que a checklist cobraria, e não
houve iteração de correção — registrar duas rodadas que não aconteceram seria inventar
processo:

1. **SC-002 nasceu com a frequência dita**: *"em cem por cento das execuções de verificação"*.
   Sem isso, *"a varredura encontra o segredo plantado"* não seria mensurável — uma varredura
   que acha às vezes não prova nada.
2. **FR-005 nasceu com o nível dito**: *"em nenhum nível, inclusive os que não se publicam em
   produção"*. O nível que não se publica em produção é o que se publica em desenvolvimento, e
   o dump vem do mesmo esquema.

O que a validação não substitui: ninguém além de quem escreveu leu esta spec ainda.

### O que esta spec deliberadamente não decide

O tratamento do token de sessão (FR-004) — resumo, cifra ou substituição por um valor que não
sirva sozinho — fica para o `/speckit-plan`. A spec declara **a propriedade**: quem lê o banco
não consegue se passar por ninguém. Há mais de um mecanismo que a satisfaz, e escolher aqui
seria decidir implementação com nome de requisito.

### O item que não é código

A FR-011 exige **rotação** da credencial encontrada. É ato de quem tem acesso ao GitHub, e
nenhum plano a executa. Ela está na spec porque, sem ela, alguém apagaria a linha e daria o
problema por resolvido — e o token continuaria válido.

### A ordem é o requisito

A FR-010 (varredura **antes** da primeira cópia) é a única que o tempo torna impossível de
cumprir depois. Se o plano a tratar como mais uma tarefa da lista, ela perde o sentido: o que
passa para uma cópia não se desfaz.
