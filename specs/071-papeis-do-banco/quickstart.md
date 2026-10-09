# Quickstart — validar a 071

## 1. A suíte

```bash
mix test test/the_band/papeis_test.exs > /tmp/papeis.log 2>&1; echo "EXIT=$?"
```

A1 a A8 e A10 de `seguranca.md`, com o papel não-dono criado no sandbox. **Esperado**: `EXIT=0`. Com
cada defeito injetado da tabela de `seguranca.md`, ver o caso reprovar.

## 2. A suíte inteira como quem serve (SC-003)

Localmente:
1. Criar o papel e conceder:
   ```sql
   CREATE ROLE the_band_app_teste LOGIN PASSWORD '<hex local>';
   SELECT 1;  -- depois rodar o passo de conceder
   ```
2. Rodar `TheBand.Papeis.conceder/2` com a URL do `postgres` e o nome `the_band_app_teste`.
3. Rodar `mix test` com a URL do papel.

**Esperado**: `EXIT=0`. A fumaça do Oban (S9) roda com `Oban` ligado: enfileirar, executar e apagar
um job.

## 3. O contêiner (A9, e os três estados de FR-008)

`docker compose` com a imagem da release, e uma `DATABASE_MIGRATION_URL` de valor falso **óbvio**.
- Contar o **nome** da variável em `/proc/1/environ`. **Esperado**: 0.
- Contar o mesmo no processo do `HEALTHCHECK`. **Esperado**: 1. É o limite declarado de S5, e o
  número vai para a nota.
- Apagar a variável:
  - com quem serve dono, sobe com "separação NÃO em vigor";
  - sem ser dono e sem pendente, sobe;
  - com uma migração nova pendente, não sobe, e a linha nomeia `DATABASE_MIGRATION_URL`.

## 4. A conferência

```bash
/app/bin/the_band rpc 'IO.puts(TheBand.Release.conferir_papeis())'
```

**Esperado**:
- antes da troca em produção: "NÃO em vigor", com os motivos;
- depois: "em vigor".

## 5. O ensaio de restauração (SC-005)

O runbook §6, com os papéis criados no cluster de ensaio, servindo pelo papel que serve. **Esperado**:
a conferência diz "em vigor" no ambiente restaurado.
