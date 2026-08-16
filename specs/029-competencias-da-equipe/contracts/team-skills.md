# Contrato — TheBand.Profiles.TeamSkills

**Feature**: 029 · **Data**: 2026-08-16 · Fronteira: `TheBand.Profiles`

## `coverage/2`

```elixir
@spec coverage(Tenant.t(), Ecto.UUID.t()) :: %{
        membros: non_neg_integer(),
        com_perfil: non_neg_integer(),
        sem_perfil: [%{person_id: Ecto.UUID.t(), name: String.t()}],
        competencias: [
          %{
            nome: String.t(),
            pessoas: [%{person_id: Ecto.UUID.t(), name: String.t(), tarefas: pos_integer()}],
            total_pessoas: pos_integer(),
            tarefas_somadas: pos_integer()
          }
        ]
      }
```

A fotografia de hoje: membros pela evidência declarada, perfil vigente de cada um,
competências dos `destaques` (domínio + tarefas). Competências ordenadas por
`total_pessoas` desc; **pessoas em ordem alfabética dentro de cada uma** (FR-006a).
`sem_perfil` vem nomeado — nunca dobrado em zero.

Número fixo de consultas (SC-001): membros, perfis vigentes, e nada por-membro.

## `evolution/2`

```elixir
@spec evolution(Tenant.t(), Ecto.UUID.t()) :: [
        %{mes: Date.t(), cobertura: %{String.t() => non_neg_integer()}}
      ]
```

Um ponto por **mês que teve geração** de algum membro: a cobertura recontada com os
perfis vigentes no fim daquele mês. Mês sem geração não existe na série — interpolar
afirmaria observação que não houve (FR-003).

## `summary/1`

```elixir
@spec summary(coverage_result) :: [%{tipo: :forte | :ponto_unico | :sem_perfil, frase: String.t()}]
```

As frases do resumo, montadas das contagens (FR-007). `:ponto_unico` para competência com
1 pessoa; `:forte` para o topo da cobertura. Determinístico: mesmo input, mesmas frases.

## O que este contrato não expõe

| Ausente | Por quê |
|---|---|
| `generate_team_profile/2` | texto de modelo sobre a equipe empilharia derivações — espera #363 |
| `compare_teams/2` | sem a distribuição, comparação vira ranking — mesma recusa do perfil individual |
| ordenação de pessoas por total | FR-006a: a matriz junta leituras individuais, nunca placar |
