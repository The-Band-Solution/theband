# Contrato — o que a suspensão pede a `TheBand.Tenants`

FR-004, FR-013, FR-015. Duas funções novas, cada uma no módulo dono da tabela, e o que muda em
`Tenant`.

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
`api_tokens.ex:408-430`, e o token já revogado mantém o autor e a razão da primeira revogação.

## `TheBand.Tenants.ApiTokens.clausulas_registradas/0 :: [String.t()]`

As oferecidas mais `clausulas_so_registradas`. `clausulas_de_revogacao/0` continua só com as
oferecidas, e a tela de tokens não ganha opção.

A tela de tokens passa a escrever, para a revogação por suspensão, o autor como
*"revoked when the organisation was suspended"* (inglês, porque é tela), e não o nome de uma conta
que não existe.

## `TheBand.Tenants.Tenant`

- `changeset/2` deixa de fazer `cast` de `:status`, e ganha `validate_inclusion/3` e
  `check_constraint(:status, name: :tenants_status_valido)`;
- **nenhuma** função pública nova escreve o estado. A escrita é o `update_all` condicional dentro de
  `Platform.Suspensions`.

## O que a API NÃO expõe, e por quê

| ausência | por quê |
|---|---|
| `encerrar_da_organizacao` por `tenant_id` cru | primitivo no lugar do conceito |
| `reativar` token | `api_tokens.ex:379-381`: revogação é definitiva |
| `Tenants.set_status/2` ou `Tenants.suspend/1` | seria escrever o estado sem episódio, que é a O10 |
| `organizacao_suspensa` no select da tela de tokens | cláusula **só registrada**: ninguém a escolhe à mão |
