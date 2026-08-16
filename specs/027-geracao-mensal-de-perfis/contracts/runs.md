# Contrato: `TheBand.Profiles.Runs`

**Feature**: 027 · **Data**: 2026-08-16

A rodada: abrir, registrar cada desfecho, encerrar, e devolver à tela o que aconteceu.

---

## `start/2`

```elixir
@spec start(Tenant.t(), keyword()) ::
        {:ok, Run.t()}
        | {:error, :already_running}
        | {:error, :no_credential}
        | {:error, :not_enabled}
```

Abre uma rodada e enfileira o job que a executa. `opts`: `:trigger` (`:cron` ou `:manual`) e `:requested_by` (obrigatório quando `manual`).

- `:already_running` — `FR-003`. Vale para a automática **e** para a disparada a mão, e cobre a rodada que passou do mês: a seguinte é recusada, não enfileirada em silêncio;
- `:no_credential` — `FR-011`. A rodada não abre; a tela diz por quê, e nenhum perfil é gerado com a conta de outra organização;
- `:not_enabled` — o disparo automático de um tenant desligado não abre rodada. O manual **não** passa por esta checagem: quem administra pode pedir uma rodada sem ligar a automação.

---

## `record/3`

```elixir
@spec record(Run.t(), Person.t(), map()) ::
        {:ok, RunEntry.t()} | {:error, :already_recorded} | {:error, Ecto.Changeset.t()}
```

Grava o desfecho de uma pessoa. É o checkpoint: `:already_recorded` vem da constraint única `[:profile_run_id, :person_id]`, e é o que faz a retentativa do Oban retomar em vez de regerar.

O mapa carrega `outcome` e, conforme ele, `reason`, `failure_reason`, `person_profile_id`, `input_tokens`. Combinação inválida — `skipped` sem motivo, `generated` com motivo — é erro de changeset, e também `check_constraint` no banco.

---

## `finish/2`

```elixir
@spec finish(Run.t(), :completed | {:ended_early, String.t()}) :: {:ok, Run.t()}
```

Fecha a rodada. `{:ended_early, motivo}` é o caminho da `FR-016`: falha de credencial encerra, porque a próxima pessoa falharia igual.

Não existe `finish(run, :cancelled)`: nenhuma linha do código o produziria.

---

## `latest/1` · `list/2`

```elixir
@spec latest(Tenant.t()) :: {:ok, Run.t()} | {:error, :never_ran}
@spec list(Tenant.t(), keyword()) :: [Run.t()]
```

Sempre restritas ao tenant — `FR-017`. `:never_ran` é resposta, e não lista vazia: *"nunca rodou"* e *"rodou e não gerou ninguém"* são fatos diferentes, e a tela diz os dois de formas diferentes.

---

## `summary/1`

```elixir
@spec summary(Run.t()) :: %{
        considered: non_neg_integer(),
        generated: non_neg_integer(),
        skipped: %{
          no_material: non_neg_integer(),
          no_new_work: non_neg_integer(),
          observation_ended: non_neg_integer()
        },
        failed: non_neg_integer(),
        input_tokens: non_neg_integer()
      }
```

Os nove números da `FR-014`, **derivados** das entradas por agregação — nunca lidos de coluna. Os motivos vêm nomeados um a um: um total de pulados agregaria o que a `FR-014` manda separar.

---

## O que este módulo **não** expõe, e por quê

- **`delete/1` ou expurgo por idade.** `FR-017a`: os registros são somente-acréscimo. Uma rodada apagada leva junto a única resposta para *"por que o perfil desta pessoa parou em março"*;
- **contadores incrementais** (`increment_generated/1` e afins). É a forma que diverge da realidade sob retentativa — ver `plan.md`, tabela do princípio VIII;
- **`summary/1` cross-tenant.** Não há visão de instalação: cada organização vê a sua, e a soma entre organizações não é pergunta que a plataforma responde.

---

## `plan/2` *(emenda de 2026-08-16 — a barra de progresso)*

```elixir
@spec plan(Run.t(), non_neg_integer()) :: {:ok, Run.t()}
```

Grava em `people_selected` quantas pessoas esta rodada vai percorrer. É o **denominador** da
barra de progresso; o numerador é a contagem de entradas, que já é derivada.

Escrita pelo worker no momento em que a seleção acontece — nunca pela tela. Na retentativa é
regravada como `entradas já feitas + restantes`, porque a elegibilidade pode ter mudado entre
as tentativas e um plano velho mentiria o total.

**Não é contador de desfecho.** Os nove números continuam saindo da agregação sobre as
entradas; isto é o tamanho do plano, conhecido antes de qualquer desfecho existir. `nil` em
rodadas antigas significa "não medido", e a tela mostra progresso indeterminado — nunca zero.

---

## `subscribe/1` *(emenda de 2026-08-16)*

```elixir
@spec subscribe(Tenant.t()) :: :ok | {:error, term()}
```

Assina o tópico de rodadas do tenant. A cada checkpoint gravado, plano definido, rodada
aberta ou encerrada, quem assinou recebe `{:rodada, run_id}` — sem payload além do id, porque
a tela recarrega do banco e duas fontes do mesmo fato divergiriam.

O tópico é por tenant, como em `Profiles.subscribe/2`: uma organização não recebe o progresso
da outra — `FR-017` vale também para o que trafega em PubSub.
