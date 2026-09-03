# Contrato — As medidas de equipe

Escrito **antes** da primeira função pública, como exige o princípio VI. Quando a
implementação mostrar que ele está errado, corrigir aqui **no mesmo commit**.

Três módulos ganham API pública. Nenhuma migração.

---

## 1. `TheBand.Ontology.SEON.EO` — quem pertencia, e quando

### `team_members_at/3`

```elixir
@spec team_members_at(Tenant.t(), Ecto.UUID.t(), DateTime.t()) :: [membro()]
@type membro :: %{
        person_id: Ecto.UUID.t(),
        name: String.t(),
        login: String.t() | nil,
        started_at: DateTime.t() | nil,
        ended_at: DateTime.t() | nil
      }
```

Quem pertencia à equipe **na data**, pela mesma regra de vigência de
`count_team_members_at/3`: começou até a data, não terminou antes dela, não foi
invalidado. Borda `[started_at, ended_at)`.

Ordenada por `name`. Equipe sem membros na data devolve `[]`.

**`started_at` nulo é membro, e a condição precisa dizer isso.** A ontologia
declara o atributo como `required: false`, e `Commands.allocate/2` grava nulo de
propósito — nulo significa *não se sabe desde quando*, nunca *começou hoje*. Uma
condição escrita como `started_at <= data` avalia para **desconhecido** contra
nulo, e o Postgres descarta a linha: a pessoa deixa de ser membro **em data
alguma**, sem erro e sem aviso.

A condição correta é `(started_at is null or started_at <= data)`, e ela vale
igualmente em `count_team_members_at/3`, que tem o mesmo defeito desde a feature
055 — FR-006a, SC-011a.

**Não** inclui evidência não promovida — quem a origem lista sem vínculo declarado
sai por `pending_evidence/2`, que já existe, e a tela apresenta em separado
(FR-005).

**Por que é `EO` e não `Profiles`**: vínculo é conceito de EO. Ler o período do
vínculo de dentro de outro módulo alcançaria o schema alheio, contra o princípio V.

### `team_member_ids_at/3`

```elixir
@spec team_member_ids_at(Tenant.t(), Ecto.UUID.t(), DateTime.t()) :: [Ecto.UUID.t()]
```

Só os ids. Existe porque quem monta consulta de trabalho não precisa dos nomes, e
carregá-los seria trabalho jogado fora em toda chamada da série.

---

## 2. `TheBand.WorkItems` — o trabalho da equipe

### `team_state_changes_by_period/4`

```elixir
@spec team_state_changes_by_period(Tenant.t(), Ecto.UUID.t(), atom(), Keyword.t()) ::
        [%{periodo: String.t(), criadas: non_neg_integer(), fechadas: non_neg_integer()}]
```

Issues criadas e concluídas por período, **das pessoas que pertenciam à equipe na
data de cada evento** — R5.

`escala` em `[:semana, :mes, :ano]`, como `escalas/0` já declara.

`opts`: `:desde`, `:ate` — as bordas da janela.

**Duas garantias que a assinatura não mostra e o teste precisa provar:**

1. **`DISTINCT` na issue.** Item atribuído a duas pessoas da mesma equipe conta
   **uma vez** para a equipe — R4. É o oposto da regra por pessoa, e é a razão de
   FR-008 proibir somar linhas de subequipe.
2. **A vigência é avaliada contra a data do evento**, não contra hoje:
   `external_created_at` na série de criadas, `external_closed_at` na de fechadas.
   É o que faz SC-002 passar.

Período sem movimento vem com zero nas duas; período fora do coletado não aparece.

### `team_open_at/3`

```elixir
@spec team_open_at(Tenant.t(), Ecto.UUID.t(), DateTime.t()) :: non_neg_integer()
```

Quantos itens da equipe estavam **em aberto** naquele instante — criados até a
data, não fechados até a data, de quem pertencia na data.

É a **linha de base** de FR-026a. Sem ela o burn mede só o que nasceu na janela.

### `burn/2`

```elixir
@spec burn([serie_item()], non_neg_integer()) :: [
        %{periodo: String.t(), escopo: integer(), feito: integer(), aberto: integer()}
      ]
def burn(serie, aberto_inicial \\ 0)
```

Estende `burn/1`, que passa a delegar com `0`. Função **pura**, sem consulta.

`escopo` parte de `aberto_inicial` em vez de zero. A identidade que o teste verifica:

```text
aberto(t) == aberto_inicial + criadas(t₀..t) - fechadas(t₀..t)
```

**Compatibilidade**: `burn/1` continua existindo com o mesmo comportamento — a
página da pessoa não muda nesta feature. A limitação dela é registrada como
backlog, não corrigida aqui (R2).

### `team_open_tasks_by_person/3`

```elixir
@spec team_open_tasks_by_person(Tenant.t(), Ecto.UUID.t(), DateTime.t()) ::
        %{Ecto.UUID.t() => [tarefa()]}
@type tarefa :: %{
        issue_id: Ecto.UUID.t(),
        external_id: String.t(),
        titulo: String.t(),
        aberta_ha_dias: non_neg_integer(),
        parada?: boolean()
      }
```

Todas as tarefas abertas de cada pessoa da equipe — FR-017.

**Pessoa sem tarefa aberta aparece no mapa com `[]`**, e não é omitida: a tela
precisa distinguir "sem tarefa" de "não é da equipe" (FR-021). Chave ausente
significa que a pessoa não pertence; lista vazia significa que pertence e não tem
tarefa.

`aberta_ha_dias` conta da **abertura do item** — R1, FR-019. Nunca da atribuição:
a origem não fornece essa data, e FR-019a proíbe apresentá-la.

`parada?` é `aberta_ha_dias > 90`.

**Uma consulta**, não uma por pessoa.

---

## 3. `TheBand.Forecast` — a previsão

Módulo novo. Justificativa de existência no `plan.md`, seção de decisões de
desenho.

### `monte_carlo/2`

```elixir
@spec monte_carlo([serie_item()], Keyword.t()) ::
        {:ok, previsao()} | {:sem_historico, faltando()}

@type previsao :: %{
        congelado: hipotese(),
        vivo: hipotese(),
        rodadas: pos_integer(),
        horizonte_semanas: pos_integer(),
        ritmo: %{abre_por_semana: float(), fecha_por_semana: float()}
      }
@type hipotese :: %{
        p50: pos_integer() | nil,
        p85: pos_integer() | nil,
        p95: pos_integer() | nil,
        nao_concluiram: non_neg_integer()
      }
@type faltando :: %{
        semanas: non_neg_integer(), semanas_exigidas: pos_integer(),
        fechadas: non_neg_integer(), fechadas_exigidas: pos_integer()
      }
```

**Função pura.** Recebe a série já consultada e o número de itens em aberto; não
toca no banco. É o que a torna testável com igualdade em vez de tolerância.

`opts`: `:aberto` (obrigatório), `:rodadas` (10 000), `:horizonte_semanas` (12),
`:semente`.

**As duas hipóteses:**

- `congelado` — a cada semana sorteia um valor de `fechadas` do histórico e
  subtrai. Nada novo entra;
- `vivo` — sorteia também de `criadas` e soma. É a hipótese que responde se o
  ritmo se sustenta.

**Determinismo (FR-036, SC-009).** Sem `:semente`, ela é derivada dos dados de
entrada — a série e o aberto. A mesma entrada produz a mesma saída, sempre.
`:rand.seed/2` é aplicado em processo isolado por chamada, para não alterar o
estado do processo chamador.

**O piso (FR-034, R7).** Menos de 6 períodos na série **ou** menos de 10 fechadas
somadas devolve `{:sem_historico, faltando}` — nunca uma faixa larga. `faltando`
traz o observado **e** o exigido, para a tela dizer o que falta em vez de só
recusar.

**`nao_concluiram` (FR-035).** Rodadas que não zeraram o aberto dentro do
horizonte. Quando **todas** as rodadas de uma hipótese não concluem, os três
percentis vêm `nil` — nulo diz desconhecido; um número grande diria uma data.

---

## 4. `TheBand.Profiles.TeamSkills` — a correção

### `coverage/3` e `evolution/2`

```elixir
@spec coverage(Tenant.t(), Ecto.UUID.t(), DateTime.t()) :: coverage()
def coverage(tenant, team_id, quando \\ DateTime.utc_now())
```

`coverage/2` passa a delegar para `coverage/3` com o instante atual. O tipo
`coverage()` **não muda** — a tela não é afetada pela correção, só os números.

`evolution/2` mantém a assinatura e muda por dentro: em vez de um conjunto de
membros para todos os meses, **um por mês**, com o corte daquele mês — R9.

### `membros/3` (privada, mas o contrato importa)

Passa de `list_team_members(..., include_no_longer_observed: false)` — a evidência
de hoje — para `EO.team_members_at(tenant, team_id, quando)` — o vínculo vigente
na data.

**É a linha que o defeito inteiro atravessa.** Está no contrato apesar de privada
porque a mudança de comportamento é pública: os números da tela mudam.

---

## O que este contrato **não** oferece

| Ausente | Motivo |
|---|---|
| soma de linhas de subequipe | FR-008, e não há campo onde caberia |
| `current_task/2` | FR-018 |
| tempo desde a atribuição | R1 — o dado não existe |
| data prevista de entrega | FR-033 — só faixa com confiança |
| piso próprio de habilidades | R8 — consome o piso já em vigor |

---

## Regras que valem em todas as funções acima

1. **Tenant explícito, sempre** (princípio V, FR-038). Nenhuma das funções aceita
   ser chamada sem `%Tenant{}`.
2. **Ausência é nula, nunca zero** (princípio VIII, FR-012). Percentil
   desconhecido é `nil`; equipe sem trabalho é `sem_trabalho?: true`, não `0`.
3. **Erro previsto é retorno**, não exceção: `{:sem_historico, _}` e
   `{:abaixo_do_piso, _}` são respostas, não falhas.
4. **Determinismo**: a mesma entrada produz a mesma saída, na simulação e nas
   séries (SC-009).
