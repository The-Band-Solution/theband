# Contrato — o que a suspensão pede a `TheBand.Tenants`

FR-004, FR-013, FR-015, FR-007. As funções novas que a suspensão pede, cada uma **no módulo dono da
tabela**, e o que muda em `Tenant`.

> **Emendado em 2026-10-01** pelo `/speckit-analyze` (achado D1): `TheBand.Platform.Suspensions`
> **não** lê nem escreve a tabela `tenants`. A constituição, princípio X, letra **D**, manda depender
> da fronteira pública de outro módulo, "nunca dos schemas nem das tabelas dele", e o `plan.md`
> (decisão 1) já dizia que a suspensão pediria funções públicas a `Tenants`. A versão anterior deste
> contrato punha o `update_all` em `tenants.status` dentro de `Platform.Suspensions` e o
> `LEFT JOIN LATERAL` sobre `tenants` em `listar_organizacoes/1`; as duas coisas saíram, e entraram
> `TheBand.Tenants.trocar_estado_no_multi/5` e as duas leituras de resumo, abaixo. Em Elixir, sem exceção (as duas exceções no banco estão no
> `plan.md`, Constitution Check).

## `TheBand.Tenants.Sessions.encerrar_da_organizacao(%Tenant{}) :: {:ok, [Ecto.UUID.t()]}`

Grava `ended_at` em toda sessão aberta do tenant e devolve **os ids** encerrados, com `select` no
`update_all`. Os ids servem ao aviso `avisar_encerramento({:sessao, id})` do #1044, que quem chama
publica **depois do `commit`** (research R9, A2); a contagem é o comprimento. Esta função **não**
avisa: roda dentro do `Multi` da suspensão, e avisar antes do `commit` seria avisar o que o banco
ainda não confirmou. É a mesma regra que o #1044 escreveu em `encerrar_da_conta/2`.

Recebe `%Tenant{}`, e não `tenant_id` cru (antipadrão "primitivo no lugar do conceito"):
`encerrar_da_conta/2` (`sessions.ex:188-198` de `development`) recebe cru, e é uma das nove funções que a
seguranca.md §1.1 lista. Esta nasce sem o defeito. Usa o índice `user_sessions(tenant_id)`.

**Não** encerra sessão de outro tenant: o teste de seguranca.md §4, cenário 5, prova com dois
tenants, e o defeito a injetar é trocar por `girar_todas/0`.

## `TheBand.Tenants.ApiTokens.revogar_por_suspensao(%Tenant{}, suspensao_id) :: {:ok, non_neg_integer()}`

`update_all` em todo token do tenant com `revoked_at IS NULL`: `revoked_at = agora`,
`revoked_by_user_id = NULL`, `revoked_by_suspension_id = suspensao_id`,
`revocation_clause = "organizacao_suspensa"`. A condição fica no `WHERE`, como
`api_tokens.ex:436-441` de `development` (`gravar_revogacao/3`), e o token já revogado mantém o autor e a razão da primeira revogação.

A coluna `revoked_by_suspension_id` é **de `Tenants`**, porque `api_access_tokens` é de `Tenants`, e
nasce na migração dela (`<ts>_revogacao_por_suspensao.exs`, T047), e não na do episódio (achado L1;
`data-model.md` §6). `Tenants` recebe o id do episódio por argumento e não lê `tenant_suspensions`.

## `TheBand.Tenants.ApiTokens.clausulas_registradas/0 :: [String.t()]`

As oferecidas mais `clausulas_so_registradas`. `clausulas_de_revogacao/0` continua só com as
oferecidas, e a tela de tokens não ganha opção.

A tela de tokens passa a escrever, para a revogação por suspensão, o autor como
*"revoked when the organisation was suspended"* (inglês, porque é tela), e não o nome de uma conta
que não existe.

## `TheBand.Tenants.trocar_estado(%Tenant{}, de :: String.t(), para :: String.t()) :: {:ok, %Tenant{}} | {:error, :estado_mudou | :not_found}`

> **Emendado em 2026-10-02, na implementação (T049).** Era
> `trocar_estado_no_multi(Ecto.Multi.t(), nome, %Tenant{}, de, para) :: Ecto.Multi.t()`. O `mix gates`
> reprovou no Dialyzer com `call_without_opaque` em todo `Multi.run` sobre `Multi.new()`: nesta
> combinação de Ecto e Elixir, o termo opaco do `Multi` é recusado. A casa já evita o `Multi` pelo
> mesmo motivo (`item_phase.ex:63`), e usa `Repo.transaction/1` com `rollback`.
>
> A garantia que o `Multi` dava (a troca nunca se confirma sem o resto da transação de quem chama)
> passa a ser uma **guarda**: fora de `Repo.transaction/1` (`Repo.in_transaction?/0` falso), a
> função **levanta** `ArgumentError`. É defeito de quem chama, e não caso de negócio. O D1-c, que era
> o `update_all` executado na construção do `Multi`, vira "chamar fora da transação", e a injeção
> desse defeito (a guarda retirada) reprova o teste. O resto desta seção continua valendo, com
> "o passo" lido como "a chamada": o `WHERE` condicional, os dois pares, o chamador único e a
> tradução de `:estado_mudou` pelo ato.

**O texto abaixo é o da versão com `Multi`**, mantido para o histórico da decisão.


A **única** escrita de `tenants.status` fora da criação, e ela só existe **dentro de um
`Ecto.Multi`** de quem a chama: acrescenta ao `multi` um passo de nome `nome` e devolve o `multi`.
Não abre transação própria, e não há variante que grave fora de um `Multi`, para que a troca de
estado nunca se confirme sem o resto da transação de quem a pediu (o episódio, as sessões e os
tokens da suspensão: O10).

O passo faz, na transação do `Multi`:

```sql
UPDATE tenants SET status = $para, updated_at = now() WHERE id = $id AND status = $de
```

com a condição de estado **no `WHERE`**, como `api_tokens.ex:436-441` de `development` faz com a
revogação, e não numa leitura anterior: duas suspensões paralelas passariam as duas por uma
leitura de antes.

| resultado do passo | quando |
|---|---|
| `{:ok, %Tenant{status: para}}` | uma linha afetada |
| `{:error, :estado_mudou}` | zero linhas afetadas, e a organização existe: o estado já não era `de` (outra suspensão ou reativação confirmou primeiro, ou o estado já era `para`) |
| `{:error, :not_found}` | zero linhas afetadas, e não há linha com esse `id` (conferido por `Repo.exists?/1` **na mesma transação**, só no ramo de zero linhas) |

- **os pares aceitos são dois**, `{"active", "suspended"}` e `{"suspended", "active"}`, por cabeça de
  função. Outro par (`de == para`, ou um valor fora do `CHECK`) é `FunctionClauseError`: é defeito
  de quem chama, e não caso de negócio (AGENTS.md §7.2);
- recebe `%Tenant{}`, e não `tenant_id` cru (antipadrão "primitivo no lugar do conceito");
- **não** abre nem fecha episódio, **não** encerra sessão e **não** emite evento: cada uma dessas é de
  outro módulo, e quem compõe o `Multi` é `Platform.Suspensions` (research R8). Quem chama traduz
  `:estado_mudou` para o motivo do ato: `:ja_suspensa` em `suspender/3`, `:nao_suspensa` em
  `reativar/3` (`suspensao.md`);
- **um chamador só**: `TheBand.Platform.Suspensions`. Afirmado em dois tempos, pela saída de
  `mix xref callers`, na forma do teste de T032 sobre `TheBand.Platform.Grants` (achado O5): a
  tarefa que a cria (T046a) afirma que **nenhum chamador fora de `Suspensions`** existe em `lib/` —
  quando ela fecha, `Suspensions` ainda não a chama —, e a que escreve `suspender/3` (T049) afirma
  que há **pelo menos um chamador, e só `Suspensions`**;
- **o `xref` guarda a função, e não o invariante** (achado D1-a): outra escrita de `status`
  (`change/2`, `force_change/3`, `update_all` em outro módulo, `eval` de release) não passa por
  ela. Quem guarda o invariante "estado só com episódio" é o trigger adiado de `data-model.md` §4a,
  que recusa o `COMMIT`.

## `TheBand.Tenants.resumos_para_a_plataforma() :: [resumo]` e `resumo_para_a_plataforma(slug :: String.t()) :: {:ok, resumo} | {:error, :not_found}`

`resumo :: %{id: Ecto.UUID.t(), name: String.t(), slug: String.t(), status: String.t()}`

As leituras de `tenants` que a área do operador faz, com **`select` explícito** das quatro colunas
permitidas pela FR-007 (o `id` é a chave para compor com o histórico da própria `Platform`, e não é
mostrado). A primeira devolve todas, ordenadas por `name`; a segunda, uma pelo `slug`.

- devolvem **mapa**, e nunca `%Tenant{}`: a struct traz `has_many :users`
  (`tenant.ex:24` de `development`), a um `preload` de distância de dado de domínio;
- **nenhuma junção** com tabela de domínio, e nenhuma contagem (de pessoas, contas, sessões ou
  tokens): é a FR-007, e a guarda de telemetria de research R10 reprova o contrário;
- não leem `tenant_suspensions`: o último episódio e o histórico são da `Platform`, que compõe os
  dois em memória pelo `id` (`suspensao.md`, `listar_organizacoes/1`), com duas consultas no total e
  sem N+1;
- **nenhum chamador fora de `TheBand.Platform`** em `lib/` (achado D1-b de
  `seguranca-autenticacao.md`): não recebem tenant, por desenho, porque são o escopo da plataforma;
  uma tela de domínio que as chamasse mostraria a uma pessoa da organização A o nome, o slug e o
  estado de B. Afirmado pela saída de `mix xref callers` sobre as duas, em T038a, com o defeito de
  uma tela de domínio de rascunho chamando a leitura;
- os dois `POST` de ato **não** as usam: o ato resolve o slug por `Tenants.get_by_slug/1`, numa
  leitura só, dentro de `Suspensions` (`suspensao.md`, emenda U1).

## `TheBand.Tenants.Tenant`

- `changeset/2` deixa de fazer `cast` de `:status`, e ganha `validate_inclusion/3` e
  `check_constraint(:status, name: :tenants_status_valido)`;
- a escrita do estado é **só** `trocar_estado_no_multi/5`, acima. `create_tenant/1`
  (`tenants.ex:96-97` de `development`) deixa de poder escrever o estado, porque o `cast` não o
  aceita mais.

## O que a API NÃO expõe, e por quê

| ausência | por quê |
|---|---|
| `encerrar_da_organizacao` por `tenant_id` cru | primitivo no lugar do conceito |
| `reativar` token | `api_tokens.ex:391-393` de `development` (o `@doc` de `revogar/4`): revogação é definitiva |
| `Tenants.set_status/2`, `Tenants.suspend/1`, ou `trocar_estado` fora de `Ecto.Multi` | seria escrever o estado sem episódio, que é a O10. A troca só existe como passo do `Multi` de quem abre o episódio |
| `%Tenant{}` para a área do operador, ou `Tenants.list_tenants/0` (`tenants.ex:69-70` de `development`) | a struct traz `has_many :users`; as leituras de resumo devolvem só as quatro colunas |
| a tabela `tenants` lida ou escrita por `Platform` | constituição, princípio X, letra D: a `Platform` depende da fronteira pública de `Tenants`, nunca da tabela (achado D1) |
| `organizacao_suspensa` no select da tela de tokens | cláusula **só registrada**: ninguém a escolhe à mão |
