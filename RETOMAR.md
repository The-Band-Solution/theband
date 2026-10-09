# Retomar — estado em 2026-10-09: a v0.12.0 em PR de release, a 076 inteira no `development`, e três frentes de segurança em paralelo

**Este é o único documento de estado.** `docs/sprints/RETOMAR.md` aponta para cá (AGENTS.md §5).

Escrito para a próxima sessão começar trabalhando, e não reconstruindo contexto. Tudo abaixo foi
**medido em 2026-10-09** com `gh` e `git`, e não copiado do documento anterior, que estava parado em
2026-10-02.

---

## Onde parei, em uma frase

**A produção ainda está na v0.11.0, e o PR de release da v0.12.0 (#1422) está aberto, mergeável e
com a nota atualizada.** O merge dele é o deploy, e quem clica é a pessoa mantenedora. A 076 (análise
de rede) está inteira no `development`. Em paralelo correm três frentes de segurança: a #1409, as
#1387/#1388/#1391 e este documento.

## O primeiro comando

```bash
git fetch origin --prune && git status --short     # 1. NADA fora de commit — antes de tudo
curl -s "$PRODUCAO_URL/version"                    # 2. o que está no ar
gh pr view 1422 --json state,mergeable             # 3. a release
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"    # o veredito é o CÓDIGO DE SAÍDA
```

A suíte inteira não roda com o servidor dev de pé (`pgrep -fl phx.server`). Os worktrees
compartilham a base de teste: **nunca duas suítes ao mesmo tempo**. `mix gates` leva mais de 30
minutos: rode desacoplado (`nohup … &`) e leia o log depois.

---

## O que está no ar

**v0.11.0**: `/version` respondeu `0.11.0` em 2026-10-09. A `main` está no merge do #1026, e não tem
commit fora de `development`.

## O que fazer, em ordem

### 1. A release v0.12.0 — #1422, decisão e clique da pessoa mantenedora

São 57 PRs, e a nota está em `docs/releases/v0.12.0.md` (atualizada no #1421, em 2026-10-08). A
versão é MINOR, decidida pelo Product Owner: nenhuma rota sai, nenhum campo público muda de sentido, e
as 15 migrações são aditivas. A pessoa mantenedora confirmou a exceção *"embarca sem aceitação"* em
2026-10-04 e a estendeu à 076 em 2026-10-08.

1. Seguir *Antes do merge* na nota: no Postgres de produção, conferir os dados que fariam alguma
   migração recusar.
2. `gh pr merge 1422 --merge` (**nunca squash**: L83).
3. `curl -s "$PRODUCAO_URL/version"` deve responder `0.12.0`.
4. **O back-merge `main` → `development` sai por uma branch intermediária.** Com o head `main`, o
   `delete_branch_on_merge` apaga a `main` (#996).

### 2. Depois do deploy — a aceitação da 076 em produção (👤)

- **T003 (#1327)**: medir a rede de designação na maior organização (só agregados) e os núcleos da
  máquina. Se passar de 300 pessoas ou 3 000 arestas, a R5 e a T050 reabrem.
- **T054 (#1379)**: contar à mão contra a origem e medir o tempo da pergunta *"quais grupos se formam
  e quem os liga?"*. A folha de conferência está na issue. As dez divergências da R21 já foram
  decididas: **ficam como estão** (2026-10-06).
- Com as duas registradas: fechar US1–US9 (#1316–#1324) e o épico #1309. O Design republica o
  protótipo com *Decided* (item 3.9.1 da conferência).
- **#1384 (T034)**: a decisão de guardar o layout da visão parcial por (leitura, alcance) continua
  aberta; a medida foi feita (`research.md` R9).

### 3. Segurança aberta — em curso ou na fila

| issue | o que é | estado em 2026-10-09 |
|---|---|---|
| **#1409** | a troca de senha confere a senha atual sem espera nem contador (Média) | avaliação do `security` em curso. A proposta aceita pela pessoa mantenedora usa o mesmo contador e a mesma espera da entrada, a mesma frase de erro, e encerra a sessão como no H1 |
| **#1387, #1388, #1391** | pendências do parecer da #1221 (a chave do modelo) | implementação em curso, num PR só |
| **#1390** | medir a retenção do log de acesso em produção | 👤 |
| **#1407 → #1229** | ligar o limite por origem (077) atrás do Traefik, depois de medir | 👤. A v0.12.0 embarca o limite **desligado** (`THE_BAND_ORIGEM` ausente). A #1229 e as US da 077 (#1393–#1396) seguem abertas até ele estar ligado |
| **#1418** | a exceção do `cloak` | **fechada** pelo #1420. Ela cai quando sair a versão consertada; a guarda reprova |

### 4. O resto do backlog

A 074 (observabilidade: #1230–#1234, #1255–#1263; parte é 👤 no VPS), a 075 (#1278, #1285, #1292,
#1293), a 073 (#1187, #1188, #1190), a #1220, e o que já estava listado: #1131 (separar o papel do
banco que migra do que serve), #568, #802, a 069.

---

## O que esta sessão aprendeu, e vale para a próxima

- **Gate de segurança reprovando esconde o que vem depois.** A auditoria do `cloak` (#1418) parava o
  CI do `development` no gate 4. A quebra do teste da `dev.senha`, que surgiu quando o #1411 e o
  #1412 entraram sem se ver, só apareceu quando o #1420 fez a auditoria passar. Um `development`
  vermelho por motivo conhecido ainda pode estar quebrado por outro.
- **Um laço com `set -e` não para no `checkout` que falha dentro de `for`.** O merge seguinte caiu
  na branch errada. Antes de fazer merge, confira o `HEAD` contra a branch esperada, em cada
  iteração.
- **Guarda que lê `@behaviour` precisa de `List.flatten`.** O valor de cada atributo é uma lista, e
  sem isso a guarda nasce morta. Ela só foi vista reprovando depois do conserto.
- **`fill-opacity-10` não é utilitário do Tailwind.** Classe que não gera regra não reprova
  nenhum teste de render. Só a medida no CSS compilado pega (`design_tokens_test.exs`).
- **O Dialyzer recusa `Ecto.Multi` nesta combinação de Ecto e Elixir.** A casa usa
  `Repo.transaction/1` com `rollback`.
- **`SET search_path = pg_catalog, public` não protege da tabela temporária.** A forma segura é
  `pg_catalog, public, pg_temp`.
- **`TRUNCATE … CASCADE` num teste assíncrono** trava os outros testes. Teste com `TRUNCATE` é
  síncrono.
