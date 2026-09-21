# Phase 1 — modelo de dados: o token de API

Uma tabela nova. Nenhuma tabela existente muda.

---

## `api_access_tokens`

| Coluna | Tipo | Nulo? | Por quê |
|---|---|---|---|
| `id` | `uuid` | não | chave primária, padrão da casa |
| `tenant_id` | `uuid` | **não** | princípio V. Nenhuma consulta desta feature é emitida sem ele (FR-031) |
| `user_id` | `uuid` | **não** | de quem o token herda o alcance (FR-025, Q2). Sem conta dona não há alcance a recomputar |
| `label` | `varchar` | **não** | FR-009. Rótulo obrigatório — token sem rótulo é token que ninguém sabe revogar |
| `public_id` | `varchar` | **não** | a parte por onde a linha é buscada. **Único por tenant e indexado** — é o que tira a comparação do Postgres (Q1) |
| `token_hash` | `bytea` | **não** | SHA-256 do segredo. **Nunca** o valor em claro (FR-003), **nunca** reversível (FR-004) |
| `last_four` | `varchar(4)` | **não** | FR-007. Distinguir dois tokens da mesma conta na lista |
| `created_by_user_id` | `uuid` | **não** | quem gerou. Pode ser diferente de `user_id` se algum dia houver delegação; hoje são iguais |
| `expires_at` | `utc_datetime` | **sim** | FR-011. Nulo é *"sem expiração"*, e a tela escreve isso — nunca uma data vazia |
| `last_used_at` | `utc_datetime` | **sim** | FR-010. Nulo é *"nunca usado"*, e a tela escreve isso — nunca a data de criação (US1, cenário 3) |
| `revoked_at` | `utc_datetime` | **sim** | FR-012. Revogação **marca** |
| `revoked_by_user_id` | `uuid` | **sim** | quem revogou |
| `inserted_at` / `updated_at` | `utc_datetime` | não | padrão da casa |

### Índices

| Índice | Por quê |
|---|---|
| único em `(tenant_id, public_id)` | é o caminho de busca de toda requisição autenticada. Único para que não haja dois candidatos |
| em `(tenant_id, user_id)` | a revogação em massa por conta (Q4) e a lista da tela |

**Nenhum índice em `token_hash`.** Buscar por ele é justamente o que a decisão Q1
proíbe.

### O que a tabela NÃO tem, e é decisão

| Ausente | Por quê |
|---|---|
| o valor em claro | FR-003. SC-001 exige 0 ocorrências em log, resposta, página e banco |
| escopo, papel, lista de organizações, qualquer veredito | FR-027 e Q2. Veredito gravado é segunda verdade, e ela **envelhece no bolso de quem saiu** |
| coluna de "ativo" | estado é **derivado** de `revoked_at` e `expires_at` contra o instante da requisição. Coluna de estado exigiria job, e job cria a janela entre vencer e ser marcado — que é acesso concedido por atraso de fila (Q3) |
| série de eventos de uso | Q6: campo, e não série, no primeiro corte. **Lacuna declarada**: não haverá auditoria do *que* foi consultado |
| `deleted_at` ou qualquer apagar | SC-012 exige **0** linhas removidas fisicamente |

---

## O schema

```
TheBand.Tenants.Schemas.ApiAccessToken
```

**Deriva `Inspect` excluindo `token_hash` e qualquer campo virtual de valor**
(FR-008). Sem isso, um `IO.inspect` de depuração ou um relatório de erro do Oban
despejaria o verificador no log — e foi exatamente assim que um token do GitHub
ficou oito dias em claro em `oban_jobs.errors`, registrado no backlog.

O valor em claro existe **apenas** como campo virtual, preenchido **uma vez**, no
retorno da criação. Nunca é lido do banco porque não está lá.

---

## Estados, e como são lidos

O estado **não é coluna**. É leitura, feita contra o instante da requisição:

| Estado | Condição | Resposta da API |
|---|---|---|
| ativo | `revoked_at` nulo **e** (`expires_at` nulo **ou** `expires_at` > agora) | segue |
| revogado | `revoked_at` presente | `401` uniforme |
| expirado | `expires_at` <= agora | `401` uniforme |
| inexistente | `public_id` não casa | `401` uniforme |

As **quatro últimas linhas produzem a mesma resposta** — é FR-016, e SC-003 a
verifica byte a byte. O motivo real vai para o log interno, recuperável pelo
identificador da requisição (SC-004): calar para o cliente não é calar para quem
opera.

---

## Transições

```
        criar
          │
          ▼
       ┌──────┐   revogar    ┌──────────┐
       │ ativo│─────────────▶│ revogado │   (terminal — não há reativar)
       └──────┘              └──────────┘
          │
          │ o relógio passa de expires_at
          ▼
      ┌──────────┐
      │ expirado │   (terminal — o caminho é gerar outro)
      └──────────┘
```

**Não há reativar** (US3, cenário 3). Revogação é definitiva, e o caminho é gerar
outro. Um botão de reativar transformaria a revogação em pausa, e quem revoga por
suspeita de vazamento não quer uma pausa.

---

## A fronteira

`TheBand.Tenants` ganha, por `defdelegate` (ADR 0003):

| Função | O que faz |
|---|---|
| `create_api_token(tenant, user, attrs, actor)` | gera, devolve `{:ok, token, valor_em_claro}` — o valor **só aqui** |
| `list_api_tokens(tenant)` | a lista da tela, com o estado já lido |
| `revoke_api_token(tenant, token_id, actor)` | marca; nunca apaga |
| `authenticate_api_token(valor)` | o caminho da requisição: separa as partes, busca por `public_id`, confere em tempo constante, lê o estado, carimba o uso |

**Não existe** `update_api_token/2`: rótulo e expiração não mudam depois de criados
nesta fatia. Mudar a expiração de um token vivo é conceder prazo sem gerar
credencial nova, e isso merece decisão própria.

**Não existe** `delete_api_token/2`: ausência marca, nunca apaga.

---

## A regra na base de conhecimento

`priv/knowledge_base/rules/api_access_thresholds.yaml`, id `api.access.thresholds`.

| Limiar | Nome | Valor | Aplicado nesta fatia? |
|---|---|---|---|
| validade máxima | `api.access.token_lifetime` | 90 dias | **sim** |
| expiração por desuso | `api.access.token_idle_expiry` | 30 dias sem uso | **não** — declarado, e a regra diz que não é aplicado |

Nenhum destes valores vive em constante de módulo (FR-069). Limiar declarado e não
aplicado é pior que limiar ausente se ninguém disser qual é qual — por isso a coluna
de aplicação está **na regra**, e não só neste documento.
