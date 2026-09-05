# Architecture Decision Records

Registro das decisões arquiteturais do The Band: o contexto, a decisão, as
alternativas consideradas e as consequências. Uma ADR não descreve como o sistema
funciona — descreve **por que** ele funciona assim, para que a decisão possa ser
revisitada com a informação que existia quando foi tomada.

## Índice

| # | Decisão | Status |
|---|---|---|
| [0001](0001-monolito-modular-elixir.md) | Monólito modular em Elixir/Phoenix, não microserviços | Aceita |
| [0002](0002-yaml-como-base-de-conhecimento.md) | YAML versionado como base de conhecimento declarativa | Aceita |
| [0003](0003-organizacao-por-ontologias.md) | Domínio organizado pelas ontologias, não pelas ferramentas | Aceita |
| [0004](0004-modelo-de-informacao-one-table-per-kind.md) | Modelo de informação derivado da ontologia por `one table per kind` | Aceita |
| [0005](0005-telemetria-da-jornada.md) | Telemetria da jornada: `:telemetry` como barramento, coletor local, taxonomia declarada | **Proposta** |

## Quando escrever uma ADR

Toda decisão desta lista exige ADR antes de ser implementada:

- abandonar o monólito modular ou introduzir microserviços;
- introduzir Python, Go ou outro backend;
- introduzir frontend separado;
- substituir PostgreSQL ou Oban;
- introduzir broker externo, banco de grafos ou pgvector;
- alterar a estratégia multitenant;
- alterar a organização por ontologias;
- alterar o papel do YAML como base de conhecimento ou seu versionamento;
- alterar a separação entre fonte externa e domínio;
- alterar contratos públicos;
- abandonar o Spec Kit.

## Formato

Arquivo `NNNN-titulo-em-kebab-case.md` com as seções: Status, Contexto, Decisão,
Alternativas consideradas, Consequências. Uma ADR aceita não é editada para mudar de
ideia — cria-se uma nova que a supersede, e a antiga passa a *Substituída por NNNN*.
