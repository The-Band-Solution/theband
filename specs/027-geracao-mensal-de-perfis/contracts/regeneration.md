# Contrato: `TheBand.Profiles.Regeneration`

**Feature**: 027 · **Data**: 2026-08-16

Quem entra na rodada, e — para quem não entra — **qual dos motivos**. Este módulo não gera nada: decide.

---

## `select/1`

```elixir
@spec select(Tenant.t()) :: [
        {Person.t(), :generate}
        | {Person.t(), {:skip, :no_material | :no_new_work | :observation_ended}}
      ]
```

A lista completa de pessoas **consideradas**, cada uma com o veredito. Inclui quem será pulado: a `FR-014` conta por motivo, e um `select` que devolvesse só quem gera não teria como alimentar a contagem.

A ordem é estável e declarada — pessoas com mais tarefas novas primeiro. Se a rodada morrer no meio, terá gerado quem tinha mais o que dizer de novo.

---

## `due?/3`

```elixir
@spec due?(Tenant.t(), Person.t(), Thresholds.t()) ::
        :generate | {:skip, :no_material | :no_new_work | :observation_ended}
```

O veredito de **uma** pessoa, na ordem em que os motivos se excluem:

1. observação encerrada → `{:skip, :observation_ended}` (`FR-008`);
2. não passa nos pisos da 026 → `{:skip, :no_material}` (`FR-005`);
3. **sem perfil anterior** → `:generate` (`FR-007`) — não há recorte contra o qual comparar;
4. tarefas concluídas **depois do fim do recorte** do perfil vigente ≥ N → `:generate`;
5. perfil vigente **gerado** há mais de M → `:generate`;
6. caso contrário → `{:skip, :no_new_work}`.

Os dois extremos da `FR-006` estão nos passos 4 e 5, e são diferentes de propósito: a contagem parte do **fim do recorte**, que é a última data que o texto alcança; a idade parte da **data de geração**, que é a data que a tela exibe.

Devolver um átomo, e não um booleano, é o que permite a `FR-014` contar por motivo. `true`/`false` obrigaria quem chama a redescobrir o porquê — o antipadrão "booleano no lugar do relator" de `AGENTS.md` §7.7.

---

## `thresholds/0`

```elixir
@spec thresholds() :: {:ok, %{n: pos_integer(), m_months: pos_integer()}} | {:error, term()}
```

Lê `min_new_closed_tasks` e `max_profile_age_months` de `profile.thresholds`, na base de conhecimento.

**Não há valor padrão embutido** — `FR-009`. Ausente ou inválido devolve erro, e `mix knowledge.validate` reprova antes de chegar aqui. Um padrão silencioso faria a rodada usar um número que ninguém escolheu, que é a forma exata do defeito que mais reincidiu neste repositório.

---

## O que este módulo **não** expõe, e por quê

- **`eligible?/2` booleano.** Ver acima: o motivo é metade da resposta;
- **filtro por pessoa vinda de fora.** `select/1` recebe o tenant e decide; deixar quem chama passar uma lista permitiria uma rodada sobre um conjunto arbitrário, e a `FR-018` decidiu que a automação vale para a organização inteira;
- **o material.** Montar o material é `Profiles.Material`, da feature 026, e continua sendo. Este módulo decide **se** vale gerar, nunca **o que** entra no texto.
