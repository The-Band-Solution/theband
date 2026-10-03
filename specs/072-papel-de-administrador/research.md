# Research — spec 072, a marca de administrador

As decisões partem da [avaliação de segurança](seguranca.md) (S1 a S9) e das decisões da pessoa
mantenedora de 2026-10-03 ([prototipo/README.md](prototipo/README.md), "Aprovação").

## R1 — Um guarda só, para promover, rebaixar e desativar (FR-002, FR-004; S2, S3)

**Decisão**: `TheBand.Tenants.PapelDeAdministrador.travar/3`, chamado **dentro** da transação de
cada ato, faz três coisas, nesta ordem:
1. trava com `FOR UPDATE`, em ordem de id, as contas `admin` ativas da organização;
2. confere que o **ator** está nesse conjunto, e senão devolve `:nao_autorizado`;
3. trava e **relê** o alvo, e devolve a struct relida.

Cada ato decide pelo alvo relido:
- **rebaixar ou desativar o último administrador ativo**: `:ultimo_admin_ativo`;
- **promover quem já é administrador**: `:estado_mudou`;
- **rebaixar quem já é membro**: `:estado_mudou`.

`disable_user/4` passa a usá-lo no lugar de `resta_um_admin_ativo/2`, que decidia pelo papel lido
antes da trava.

**Por quê**: com a promoção, há uma sequência de três atos concorrentes que deixa zero
administradores (S3). E um rebaixado com a aba aberta se promoveria de volta, se o ator fosse
conferido pela struct da tela (S2).

**O que fica pior**: a promoção também trava o conjunto, e serializa com as outras duas. É o que se
quer: os atos sobre a marca são raros.

## R2 — Os atos de administração que já existem conferem o ator relido (FR-002a; S1)

**Decisão**: uma função, `PapelDeAdministrador.exigir_ator/2`, que relê o ator no banco (`admin`,
ativo e da organização) e devolve `:ok` ou `{:error, :nao_autorizado}`. Ela é chamada no começo de:
- `Auth.reset_password/3` e `Auth.cadastrar_conta/3`;
- `Tenants.disable_user/4` (pelo guarda de R1) e `Tenants.enable_user/4`;
- `Tenants.declare_person/4` e `Tenants.revoke_person/3`;
- `Access.grant/5` e `Access.revoke/3`;
- `ApiTokens.criar/4`, quando o autor não é o dono, e `ApiTokens.revogar/4`.

**Por quê**: o papel fica congelado no `mount` do LiveView. Sem a conferência no domínio, um
rebaixado com a aba aberta continua administrando, por exemplo criando um token com dono admin
(S1).

**Alternativa recusada**: confiar só no aviso por PubSub (R4). Ele tem uma janela entre o `commit`
e a entrega, e o domínio é a camada que vale sem ela.

## R3 — O registro, garantido no banco (FR-005; S6)

**Decisão**: a tabela `account_role_changes`:
- as colunas: `tenant_id`, `user_id`, `changed_by_user_id`, `from_role`, `to_role`, `note`,
  `txid` (o default é `txid_current()`) e `inserted_at`;
- os `CHECK`s: `from_role <> to_role`, e os dois papéis dentro de `admin` e `member`;
- os triggers `nao_apaga`, `nao_altera` e `nao_trunca`, como os da 070;
- um trigger de constraint adiado em `users`, `AFTER UPDATE OF role`. Ele recusa o `COMMIT` se não
  houver episódio com `user_id = NEW.id`, `to_role = NEW.role` e `txid = txid_current()`.

O `INSERT` em `users` não entra: o bootstrap cria a primeira conta como admin. O cadastro cria
sempre `member` pelo código (R5).

**O que fica pior**: o trigger adiado não aparece no sandbox sem `SET CONSTRAINTS ALL IMMEDIATE`, e
os testes precisam forçá-lo, como na 070.

## R4 — A tela aberta cai (FR-008)

**Decisão**: depois do `commit` do rebaixamento, o ato publica
`Sessions.avisar_encerramento({:conta, user_id})`, o mesmo tópico do #1042. O
`reconferir/2` de `hooks.ex` passa a reler a conta, e, se a área exige admin (`on_mount
:require_admin` marca o socket), redireciona para `/people` com a frase de hoje, "Only organisation
administrators can do that." (Q3, decidida em 2026-10-03).

## R5 — Só o ato muda o papel (FR-006; S4, S7)

**Decisão**:
- `User.changeset/2` deixa de fazer `cast` de `:role`, e o papel entra só por `put_change` no
  bootstrap e no ato;
- `cadastrar_conta/3` cria sempre `member`;
- a migração cria o `CHECK users_role_valido` (`role IN ('admin','member')`), depois de contar as
  linhas fora da lista e levantar se houver alguma, como a T013 da 070.

## R6 — As frases e os rótulos na base de conhecimento

**Decisão**: a regra `access.account_role`, em
`priv/knowledge_base/rules/access_account_role.yaml`, na forma de `access_account_lifecycle.yaml`:
- os rótulos `admin` → "administrator" e `member` → "member";
- a frase de recusa "the organisation would have no active administrator";
- a ausência "no role change recorded".

"no note" reaproveita `access.account_lifecycle`. Sem razão de lista fechada, como a spec decide.

## R7 — A tela

Exatamente o protótipo aprovado (`prototipo/accounts-admin-role.html`, a régua em
`prototipo/PROMPT.md` §3), com Q1 a Q6 decididas. A tabela empilha no telefone (Q4).
