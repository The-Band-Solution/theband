# Quickstart — provar a fatia 1 ponta a ponta

O que rodar para saber que a fatia está entregue, e o que esperar de cada passo.
Cada cenário abaixo mede um critério de sucesso da spec, e o critério está nomeado.

---

## Pré-requisitos

```bash
mix deps.get
mix ecto.migrate
iex -S mix phx.server
```

Uma conta administradora no tenant de desenvolvimento. A senha **não passa por
chat nem por commit** — se precisar redefini-la, escreva o valor num arquivo fora
do repositório, com permissão `600`.

---

## 1. A tela gera o token, e mostra o valor uma vez

1. abrir `/api-tokens` com uma conta **administradora**;
2. criar um token com o rótulo `painel do diretor`;
3. **esperado**: o valor em claro aparece **uma vez**, com aviso explícito de que
   não voltará e ação de copiar;
4. recarregar a página;
5. **esperado**: o valor **não** aparece; a linha mostra `••••••••••••••••` seguido
   dos quatro últimos caracteres, o rótulo, quem criou, quando, e **"nunca usado"**.

**Mede**: US1 cenários 1 a 4, FR-006, FR-007, FR-048. E **SC-013** — a página
renderizada tem 0 ocorrências de valor em claro ou de hash.

### A recusa de quem não administra

Abrir `/api-tokens` com conta não administradora. **Esperado**: recusa com motivo
nomeado — FR-045, US1 cenário 5.

---

## 2. O valor não está em lugar nenhum

Com o valor copiado na variável `TOKEN`:

```bash
# no banco
mix run -e 'TheBand.Repo.query!("select count(*) from api_access_tokens where token_hash::text like $1", ["%" <> System.get_env("TOKEN") <> "%"]) |> IO.inspect()'

# no log da aplicação
grep -c "$TOKEN" _build/dev/lib/the_band/*.log 2>/dev/null || echo 0
```

**Esperado**: zero nos dois. **Mede SC-001**, e é o critério que o resto da fatia
não substitui.

---

## 3. A chamada autenticada devolve as equipes do tenant

```bash
curl -s -H "Authorization: Bearer $TOKEN" http://localhost:4000/api/v1/teams | jq
```

**Esperado**: `200`, com `data` trazendo as equipes do tenant e, em cada uma,
`origin` dizendo `observed` ou `declared`. Em `page`, `has_next` e `total: null`
com a nota junto.

**Mede**: US2 cenários 1 e 5, FR-026, e o contrato em
[contracts/api-v1-teams.md](./contracts/api-v1-teams.md).

### O carimbo de uso

Recarregar `/api-tokens`. **Esperado**: a coluna de último uso deixou de dizer
"nunca usado" e traz a data e hora da chamada — FR-010, US1 cenário 4.

---

## 4. Os dois tenants não se veem

Com um token de cada tenant e os dois povoados:

```bash
curl -s -H "Authorization: Bearer $TOKEN_A" http://localhost:4000/api/v1/teams > a.json
curl -s -H "Authorization: Bearer $TOKEN_B" http://localhost:4000/api/v1/teams > b.json
comm -12 <(jq -r '.data[].id' a.json | sort) <(jq -r '.data[].id' b.json | sort)
```

**Esperado**: saída vazia — nenhum identificador em comum. **Mede SC-002**.

---

## 5. As três recusas são indistinguíveis

Preparar três tokens: um inexistente (inventado com o prefixo certo), um revogado
e um expirado.

```bash
for T in "$INEXISTENTE" "$REVOGADO" "$EXPIRADO"; do
  curl -s -H "Authorization: Bearer $T" http://localhost:4000/api/v1/teams \
    | jq 'del(.error.request_id)'
done
```

**Esperado**: as três saídas **idênticas**. **Mede SC-003** e US3 cenário 4.

Depois, achar as três razões distintas no log interno pelos três `request_id`.
**Mede SC-004** — e é o que separa "calar para o cliente" de "calar".

---

## 6. A revogação recusa, e a linha fica

1. chamar a API com sucesso;
2. revogar na tela — **esperado**: a confirmação nomeia o rótulo (FR-049);
3. chamar de novo;
4. **esperado**: `401`.

```bash
mix run -e 'IO.inspect TheBand.Repo.aggregate(TheBand.Tenants.Schemas.ApiAccessToken, :count)'
```

**Esperado**: o mesmo número de antes da revogação. **Mede SC-012** — 0 linhas
removidas. E a lista mostra a linha marcada revogada, com data e quem revogou.

**Esperado também**: não existe ação de reativar — US3 cenário 3.

---

## 7. Nenhuma escrita responde

```bash
for M in POST PUT PATCH DELETE; do
  echo -n "$M: "
  curl -s -o /dev/null -w "%{http_code}\n" -X $M \
    -H "Authorization: Bearer $TOKEN" http://localhost:4000/api/v1/teams
done
```

**Esperado**: `405` nos quatro. **Mede SC-006**.

---

## 8. A paginação não repete nem omite

Com `page_size=2` e mais de três páginas de equipes, percorrer seguindo
`next_cursor` e comparar o conjunto com a consulta direta.

**Esperado**: cada equipe exatamente uma vez. **Mede SC-009**.

---

## 9. Os gates

```bash
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"
```

**Esperado**: `EXIT=0`. O veredito é o **código de saída**, e qualquer comando
depois dele substitui o código que vale — por isso o `echo` vem colado.

---

## O que este quickstart NÃO prova

| Não provado | Onde entra |
|---|---|
| as outras 7 rotas de FR-021 | fatia seguinte |
| Swagger e a divergência detectável no CI | US4, P2 |
| limite de taxa por token | US5, P2 |
| as ressalvas obrigatórias de medida | com a primeira rota que devolve medida |
| expiração por desuso | o limiar existe na regra e **não** é aplicado nesta fatia |
| auditoria do *que* foi consultado | Q6 — lacuna declarada, o carimbo é campo e não série |
