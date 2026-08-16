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

`record_profile/2` **rejeita conteúdo degenerado** no changeset e no banco: faltar qualquer
chave que a tela lê, ou vir sem habilidade alguma, é falha. Duas barreiras porque um perfil
com buraco no lugar de uma seção é pior que nenhum perfil — parece que a plataforma não teve
o que dizer sobre aquela parte.

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
@spec clean_summary(map()) :: {map(), removed :: non_neg_integer()}
```

**Corrigido em 2026-08-16, durante a implementação.** A versão anterior deste contrato dizia
`String.t()` e operava sobre prosa, adivinhando onde o resumo terminava pelo primeiro
subtítulo. Na primeira geração em que o modelo respondeu sem subtítulo algum, a limpeza
tratou os 6651 caracteres como resumo e apagou dezenove citações — a evidência inteira, em
silêncio.

Com saída estruturada, opera sobre os três campos de `resumo` e mais nada. `destaques` e
`lacunas` têm campo próprio para os números, e ficam intactos. Devolve quantas saíram, para
que a limpeza apareça no log em vez de acontecer calada.

## `TheBand.Integrations.LLM.HTTP`

```elixir
@callback complete(prompt :: String.t(), material :: String.t(), opts :: keyword()) ::
            # opts[:schema] liga a saída estruturada, com `strict: true`
            {:ok, %{text: String.t(), model: String.t(), usage: map()}}
            | {:error, {:http, status :: integer(), message :: String.t()}}
            | {:error, {:empty_response, finish_reason :: String.t() | nil}}
            | {:error, term()}
```

`{:error, {:empty_response, _}}` é ramo próprio de propósito: 200 com texto vazio **não** é
sucesso, e casar `{:ok, _}` largo aqui reproduziria a L26 do projeto.

**A credencial nunca sai daqui.** Qualquer texto que este módulo devolva num erro passa por
filtro que substitui a chave — provedores devolvem a chave dentro da mensagem de alguns erros.

## A saída é estruturada, e não prosa

`opts[:schema]` carrega o JSON Schema de `priv/profiles/perfil_schema.json`, e o provedor
recebe `strict: true`. **A estrutura passa a ser garantida, e não pedida.**

O que isso resolveu, medido:

| antes | depois |
|---|---|
| o modelo largou os subtítulos numa geração, e a limpeza apagou a evidência toda | "sem seções" deixou de ser um estado possível |
| quatro pedidos para não citar no resumo, ignorados nas quatro | zero citações no resumo, sem precisar limpar |
| a tela recebia markdown e despejava | cada parte tem componente próprio, e o critério de destaque fica visível |

`lacunas` pode vir **vazia**, e vem: na verificação de 2026-08-16 o modelo devolveu lista
vazia em vez de inventar um ponto fraco. Um relatório que sempre acha um não está lendo.
