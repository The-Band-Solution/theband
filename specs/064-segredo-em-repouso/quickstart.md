# Quickstart — provar que a 064 funciona

**Data**: 2026-09-13 · Detalhes em [data-model.md](data-model.md) e
[contracts/varre-segredos.md](contracts/varre-segredos.md).

Cada cenário abaixo diz **o que deve acontecer** e, onde importa, **o que deve falhar**. Um
cenário que só verifica o caminho feliz não distingue funcionando de não-olhando.

## Pré-requisitos

```bash
docker compose up -d postgres
mix deps.get && mix ecto.migrate
```

---

## 1. O segredo não está no banco, e a varredura prova que enxerga

```bash
docker exec the_band_postgres pg_dump -U postgres -d the_band_dev > /tmp/d.sql
mix the_band.varre_segredos --dump /tmp/d.sql ; echo "saída: $?"
```

**Esperado**: `saída: 0`, e o relatório traz `controle positivo ......... ACHOU`.

**E o que deve FALHAR** — sem isto o cenário não prova nada:

```bash
printf "INSERT INTO x VALUES ('ghp_%s');\n" "$(head -c 36 /dev/zero | tr '\0' 'A')omAX" >> /tmp/d.sql
mix the_band.varre_segredos --dump /tmp/d.sql ; echo "saída: $?"
```

**Esperado**: `saída: 1`, e o relatório nomeia o padrão — **sem imprimir o valor**.

## 2. Sessão viva não cai na migração (FR-002)

```bash
# ANTES de migrar: entre pela interface e guarde o cookie
mix ecto.migrate
# depois: recarregue a página
```

**Esperado**: a página carrega **normalmente**. Ninguém volta para `/sign-in`.

Conferindo que o banco não tem mais o bruto:

```sql
select count(*) from user_sessions where token_hash is not null;  -- 1 por sessão viva
select column_name from information_schema.columns
 where table_name='users' and column_name='session_token';         -- vazio ao fim das duas migrações
```

## 3. Quem lê o banco não se passa por ninguém (FR-004, SC-003)

```sql
select encode(token_hash,'hex') from user_sessions limit 1;
```

Ponha esse valor num cookie de sessão forjado **com o `SECRET_KEY_BASE` em mãos** e apresente.

**Esperado**: **recusado**, com a mensagem única — sem dizer qual das razões.

Este é o cenário que mede a diferença que o plano faz. Hoje, com o `SECRET_KEY_BASE`, o valor
lido do banco **serviria**. Depois, não serve: o banco tem o resumo, e o cookie precisa do
bruto.

## 4. Troca de senha derruba as outras sessões (comportamento preservado)

Entre em **dois** navegadores. Troque a senha no primeiro. Aja no segundo.

**Esperado**: o segundo cai na ação seguinte — não no próximo login —, e o primeiro continua.
É o comportamento de hoje, e a separação em época + token não pode tê-lo perdido.

## 5. Registro terminado carrega a data (FR-015, SC-008)

```bash
mix the_band.confere_encerramentos ; echo "saída: $?"
```

**Esperado**: `saída: 0`.

**E o que deve FALHAR**:

```sql
update oban_jobs set cancelled_at = null where id = (select min(id) from oban_jobs where state='cancelled');
```

```bash
mix the_band.confere_encerramentos ; echo "saída: $?"
```

**Esperado**: `saída: 1`, nomeando o registro. Desfaça depois.

## 6. O segredo do provedor de modelos não vira texto (FR-006)

```bash
mix test test/the_band/segredo_test.exs
```

**Esperado**: verde, **incluindo** o teste que reinjeta o defeito — com binário nu no mesmo
caminho, o segredo aparece. Se esse teste passar a não achar, a proteção deixou de ser
testada, e não é o defeito que sumiu.

## 7. O gate inteiro

```bash
mix gates ; echo "saída: $?"
```

**Esperado**: `saída: 0`. **Não leia o texto do fim** — `mix gates` é a definição única, e
qualquer comando depois dele substitui o código que vale. Foi assim que oito falhas passaram
por verdes em 2026-09-12.

---

## O que este guia NÃO prova

- **que a produção está limpa** — os cenários rodam contra o banco de desenvolvimento. A
  FR-010 exige a varredura lá, **antes** da primeira cópia para o destino novo;
- **que o backup remoto funciona** — `pg_dump → varredura → restauração` está coberto;
  `→ MinIO →` não;
- **o que acontece numa restauração real** — a FR-013 é documento, não teste; o cenário está
  descrito no runbook e ninguém o exercitou contra um desastre de verdade.
