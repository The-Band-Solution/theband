# Contracts: as leituras que esta feature acrescenta

**Feature**: 044 · **Date**: 2026-08-27

Três funções novas, cada uma na fronteira do domínio que é dono do dado. **Nenhuma
atravessa fronteira**: a tela compõe as três, e é ela quem tem o direito de saber das três.

---

## `TheBand.Changes.participacao_da_pessoa/2`

```elixir
@spec participacao_da_pessoa(Tenant.t(), Ecto.UUID.t()) :: %{
        abriu: non_neg_integer(),
        integrou: non_neg_integer(),
        revisou: non_neg_integer(),
        endossou: non_neg_integer(),
        objetou: non_neg_integer(),
        absteve: non_neg_integer()
      }
```

**Uma consulta.** Seis contagens por `filter (where ...)` sobre a mesma passagem.

Medido para `vinicius-je`: `%{abriu: 793, integrou: 844, revisou: 627, endossou: 634,
objetou: 57, absteve: 30}` em **25ms**.

**O que ela NÃO faz:**

- não soma os três papéis — quem quiser somar soma, e a tela não oferece o total;
- não conta `DISMISSED` nem `PENDING` como veredito;
- não conta revisão de `Bot`: o filtro é `author_person_id`, e bot tem nulo;
- não devolve lista. A lista é outra função, e é carregada só quando a seção abre.

**Unidades**, e elas diferem de propósito:

| campo | conta |
|---|---|
| `abriu`, `integrou`, `revisou` | **solicitações distintas** |
| `endossou`, `objetou`, `absteve` | **avaliações** |

`revisou 627` com `634 + 57 + 30 = 721` avaliações não é inconsistência: é quem revisou a
mesma solicitação mais de uma vez.

---

## `TheBand.Changes.solicitacoes_da_pessoa/3`

```elixir
@spec solicitacoes_da_pessoa(Tenant.t(), Ecto.UUID.t(), :abriu | :revisou | :integrou) ::
        [%{
          id: Ecto.UUID.t(),
          number: integer(),
          title: String.t(),
          repositorio: String.t(),
          desfecho: :integrada | :fechada_sem_integrar | :aberta,
          quando: DateTime.t()
        }]
```

A lista, **por papel**, das mais recentes. O corte é constante do módulo e é **dito na
tela** — 793 não cabem, e lista truncada em silêncio parece a lista inteira.

`desfecho` é derivado, e a derivação é a regra: `MERGED` → integrada; `CLOSED` com
`external_merged_at` nulo → fechada sem integrar; o resto → aberta.

---

## `TheBand.Quality.Verdict.traduzir/1`

```elixir
@spec traduzir(String.t()) ::
        {:veredito, String.t()} | {:ciclo_de_vida, atom()} | {:error, :nao_mapeado}
```

Traduz o estado cru para o conceito da rede, lendo o `value_map` do mapeamento
`github.pull_request_review.to.qapo.artifact_evaluation`.

```
"APPROVED"          → {:veredito, "qapo.endorsing_verdict"}
"CHANGES_REQUESTED" → {:veredito, "qapo.objecting_verdict"}
"COMMENTED"         → {:veredito, "qapo.abstaining_verdict"}
"DISMISSED"         → {:ciclo_de_vida, :retirada}
"PENDING"           → {:ciclo_de_vida, :nao_submetida}
qualquer outro      → {:error, :nao_mapeado}
```

**O erro é devolvido, e não engolido.** `unmapped: reject` está declarado no mapeamento, e
traduzir o desconhecido para o mais plausível é o erro que cai para o lado barato.

**Lugar único.** Traduzir na tela espalharia o mapa por cada uso, e o segundo uso
divergiria do primeiro.

---

## `TheBand.Verifications.por_pessoa/2`

```elixir
@spec por_pessoa(Tenant.t(), Ecto.UUID.t()) :: %{
        passou: non_neg_integer(),
        quebrou: non_neg_integer(),
        outras: non_neg_integer(),
        sem_autoria_no_tenant: non_neg_integer()
      }
```

**Uma consulta** para as três primeiras. Medido para `vinicius-je`: `%{passou: 985,
quebrou: 79, outras: 6}` em **42ms**.

`sem_autoria_no_tenant` é a parcela do tenant que não casa com pessoa alguma — **7.313 de
15.671**. Ela vai **ao lado** dos números da pessoa, e nunca descontada deles: é contexto
sobre o alcance da medida, e não parte da contagem dela.

**`outras`** reúne `skipped`, `cancelled` e nulo. Elas não são "passou" nem "quebrou", e
somá-las a qualquer um dos dois afirmaria resultado onde ninguém verificou nada.

---

## `TheBand.Verifications.execucoes_da_pessoa/2`

```elixir
@spec execucoes_da_pessoa(Tenant.t(), Ecto.UUID.t()) ::
        [%{
          workflow: String.t(),
          conclusion: String.t(),
          sha: String.t(),
          repositorio: String.t(),
          quando: DateTime.t()
        }]
```

A lista das mais recentes, com o corte dito.

**`conclusion` vem cru.** Diferente do veredito de revisão, o desfecho da verificação **já
é** vocabulário da rede — `ciro.verification` o declara —, e não há mapa a aplicar.

---

## O que nenhuma delas faz

- **Nenhuma escreve.** A feature é de leitura.
- **Nenhuma dispara coleta.** O dado já está no banco.
- **Nenhuma atravessa fronteira de domínio.** `Changes` não pergunta a `Quality` — a
  consulta de participação junta `collected_artifact_evaluations` porque a pergunta "quantas
  revisou" é sobre **solicitações**, e a solicitação é dela.
- **Nenhuma é chamada quando a aba está fechada** pela regra da #369.
