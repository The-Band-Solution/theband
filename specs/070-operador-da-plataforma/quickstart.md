# Quickstart — validar a 070

Roteiro de validação, e não de implementação. Os contratos estão em [contracts/](contracts/); as
tabelas, em [data-model.md](data-model.md); os cenários de ataque, em
[seguranca.md](seguranca.md) §4.

**O veredito de cada passo é o código de saída** (AGENTS.md §4): redirecione e leia depois.

```bash
mix gates > /tmp/gates-070.log 2>&1; echo "EXIT=$?"
```

## 0. Pré-requisitos

- PRs #1038 (#1033), #1039 (#1034), #1040 (#1035) e #1044 (#1042) mergeados em `development`
  (conferido em 2026-10-01), e #1048 (#1046) e o da #1047 também;
- a revisão de segurança da segunda autenticação registrada na spec (`seguranca-autenticacao.md`) e
  a do TOTP (`seguranca-totp.md`);
- o protótipo da tela aprovado e guardado na spec (plan.md, "Tela");
- `docker compose up -d` e `mix ecto.migrate` sem erro.

## 1. Conceder o papel, sem senha em argumento (FR-001, O11)

```bash
mix run -e 'TheBand.Release.conceder_operador("op@exemplo.org", "Op", "teste local")'
```

Esperado: a saída diz o e-mail e imprime **um** código com a validade. Nenhuma senha foi digitada.
`SELECT setup_code_hash IS NOT NULL, password_hash IS NULL FROM platform_operators` → `t, t`.

Abrir `/platform/setup`, digitar e-mail, código e senha; cadastrar o segredo mostrado num
aplicativo autenticador e confirmar com um código dele; guardar os dez códigos de recuperação.
Repetir com o **mesmo** código de definição: recusa única. Entrar em `/platform/sign-in` sem o
segundo fator, ou com o mesmo código TOTP já usado: recusa única (FR-016).

## 2. A área responde "not found" a quem não é operador (FR-009)

| quem | `GET /platform/organizations` |
|---|---|
| anônimo | `404`, corpo idêntico ao de `GET /platform/nao-existe` |
| admin de uma organização, com sessão | o mesmo `404` |
| operador | `200`, com nome, slug, estado e última data de episódio |

## 3. A segunda autenticação (gate de segurança)

- senha errada quatro vezes: a quarta devolve `{:throttled, s}` internamente e a mesma frase na tela;
- operador sem concessão vigente e senha certa: a mesma frase, e o tempo da resposta na mesma
  ordem da senha errada;
- as constantes de espera de `Platform.Credentials` iguais às de `Tenants.Auth`: o teste de
  paridade afirma as duas.

## 4. Suspender e reativar (US1, SC-001, SC-002, FR-013, FR-015)

Com duas organizações povoadas, A e B, sessões abertas e um token de API em cada:

1. suspender A com `suspected_compromise` e nota, pela tela. Medir o tempo: **menos de um minuto**
   (SC-004);
2. o cookie de uma pessoa de A vai para `/sign-in`; o token de A recebe `401` e tem
   `revocation_clause = 'organizacao_suspensa'`;
3. as sessões e o token de B continuam valendo, e são mais de zero;
4. suspender A de novo: recusa `:ja_suspensa`, e nada muda;
5. reativar A com `investigation_closed_no_compromise`. O cookie **de antes** vai para `/sign-in`, e
   o token de antes continua `401`;
6. a consulta de `data-model.md` §7 devolve `0`.

Defeitos a injetar, um por vez, e cada um precisa reprovar o teste dele: retirar o encerramento na
suspensão; retirar o encerramento na reativação; trocar `encerrar_da_organizacao` por
`girar_todas/0`; retirar a revogação dos tokens.

## 5. Revogar com a tela aberta (FR-014, O6)

O operador abre o formulário de suspensão; em outro terminal, `revogar_operador`; o operador envia
o formulário. Esperado: A continua `active`, sem episódio novo, e a resposta é o `404`.

## 6. O operador não lê domínio (SC-003)

O teste de telemetria de research R10: nas rotas `/platform/*`, só fontes da lista permitida; nas
rotas de domínio com o cookie do operador, a recusa de anônimo e nenhuma consulta a `platform_*`;
e a guarda de que mediu algo com um membro de A.

## 7. O registro não se apaga (FR-002)

```sql
DELETE FROM platform_operator_grants;   -- MUST levantar
DELETE FROM tenant_suspensions;         -- MUST levantar
UPDATE tenant_suspensions SET suspend_reason = 'other';  -- MUST levantar
```

## 8. O estado só muda pelo episódio (O10)

- `Tenant.changeset(t, %{status: "suspended"})` não muda o estado;
- `UPDATE tenants SET status = 'Suspended'` reprova pelo `CHECK`.

## 9. O log diz quem (FR-010, O14)

Com o nível de teste, suspender e reativar geram `acesso: ato de plataforma` com `operator_id` no
metadado e o `tenant_id` da organização afetada.
