# Contrato — perfil derivado

Escrito **antes** da implementação, conforme a constituição. Se a implementação mostrar que
este contrato errou, o contrato é corrigido no mesmo commit.

## `TheBand.Ontology.SEON.EO`

```elixir
@spec current_profile(Tenant.t(), person_id :: binary()) ::
        {:ok, PersonProfile.t()} | {:error, :not_found}

@spec list_profiles(Tenant.t(), person_id :: binary()) :: [PersonProfile.t()]

@spec record_profile(Tenant.t(), attrs :: map()) ::
        {:ok, PersonProfile.t()} | {:error, Ecto.Changeset.t()}
```

`record_profile/2` **rejeita corpo vazio** no changeset. Não há caminho que grave perfil vazio.

## `TheBand.Profiles`

```elixir
# Monta o material. Não fala com a rede — é testável com o banco só.
@spec build_material(Tenant.t(), person_id :: binary()) ::
        {:ok, Material.t()}
        | {:error, {:below_floor, %{with_body: non_neg_integer(), needed: pos_integer()}}}
        | {:error, {:period_too_thin, %{counts: [non_neg_integer()], needed: pos_integer()}}}
        | {:error, :no_assignment}

# Enfileira. Devolve o job, e não o perfil: quem chama não espera.
@spec request(Tenant.t(), person_id :: binary(), user_id :: binary()) ::
        {:ok, Oban.Job.t()} | {:error, term()}
```

**Três erros distintos, e nenhum é `:error` genérico.** `:no_assignment` é "não há de onde
olhar", `:below_floor` é "há material e é pouco", `:period_too_thin` é "há material e não dá
para falar de evolução". As três frases da tela são diferentes porque os três fatos são.

## `TheBand.Profiles.Sanitizer`

```elixir
@spec clean_summary(String.t()) :: {String.t(), removed :: non_neg_integer()}
```

Remove do trecho **anterior ao primeiro subtítulo** — e o título não conta como subtítulo:
grupos `(#1, #2)`, enumerações soltas, o conectivo órfão que sobra, e o parêntese vazio.
Devolve quantas saíram, para que a limpeza apareça no log em vez de acontecer calada.

## `TheBand.Integrations.LLM.HTTP`

```elixir
@callback complete(prompt :: String.t(), material :: String.t(), opts :: keyword()) ::
            {:ok, %{text: String.t(), model: String.t(), usage: map()}}
            | {:error, {:http, status :: integer(), message :: String.t()}}
            | {:error, {:empty_response, finish_reason :: String.t() | nil}}
            | {:error, term()}
```

`{:error, {:empty_response, _}}` é ramo próprio de propósito: 200 com texto vazio **não** é
sucesso, e casar `{:ok, _}` largo aqui reproduziria a L26 do projeto.

**A credencial nunca sai daqui.** Qualquer texto que este módulo devolva num erro passa por
filtro que substitui a chave — provedores devolvem a chave dentro da mensagem de alguns erros.
