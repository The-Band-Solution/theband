# Aceitação — Feature 009: a marca de inacessível se cura

**Sprint**: [008](../../docs/sprints/008-marca-que-se-cura/sprint-backlog.md) ·
**PR**: [#230](https://github.com/The-Band-Solution/theband/pull/230)
**Avaliado em**: 2026-08-12, na branch `012-marca-que-se-cura`

**Suíte verde não é evidência de critério atendido** — é a L18. Cada critério tem a medida que o
sustenta, e onde a evidência é o teste, o teste é nomeado.

## Os dez gates

```
$ mix gates > /tmp/g9b.txt 2>&1; echo "código de saída: $?"
código de saída: 0

10 gates verdes.
Result: 430 passed
```

**28 testes próprios**: natureza do erro (9), a marca em CMPO (7), ponta a ponta (7), a tela (5).

## O efeito da mudança, medido no banco

```sql
select count(*) as observados,
       count(*) filter (where excluded_at is null) as coletaveis_depois,
       count(*) filter (where excluded_at is null and inaccessible_since is null) as coletaveis_antes,
       count(*) filter (where inaccessible_since is not null) as voltam_a_ser_tentados
  from observed_repositories;

 135 | 135 | 96 | 39
```

E as issues que voltam ao alcance da coleta: **899**.

## Critérios de sucesso

| # | Critério | Evidência | Veredito |
|---|---|---|---|
| SC-001 | nenhum repositório que a origem alcança permanece marcado | `unreachable_recovery_test.exs`, "o repositório marcado é tentado, a marca sai e as issues entram" — a asserção é **no banco**, e é dupla | **atendido, e não exercitado em produção** |
| SC-002 | as 899 issues voltam a ser alcançadas | medido: 96 → **135** repositórios coletáveis; os 39 marcados contêm 899 issues | **atendido no mecanismo**; a coleta real depende de você |
| SC-003 | a resposta real de falha interna não marca | mesmo arquivo, "o payload real da origem deixa zero repositórios marcados" — com a mensagem **copiada do banco** | **atendido** |
| SC-004 | "não encontrado" continua marcando | mesmo arquivo, "não encontrado marca" | **atendido** |
| SC-005 | coleta com tudo falhando conclui, e diz quantos | "a coleta conclui e conta os não alcançados" — 3 de 3 | **atendido** |
| SC-006 | excluído pelo tenant não é tentado | "nenhuma requisição é feita por ele" — o teste **conta as chamadas** à borda | **atendido** |
| SC-007 | a data de início não muda entre duas falhas | `inaccessible_test.exs`, "a data é gravada na primeira falha e preservada na segunda" — com a asserção de que o **motivo mudou** | **atendido** |
| SC-008 | a lista diz desde quando e por quê, legível sem cor | `unreachable_screen_test.exs`, 5 casos — incluindo o que remove as classes e exige o texto | **atendido** |
| SC-009 | nada é apagado ao limpar a marca | `clear_inaccessible/2` só zera os dois campos da marca; conferido no teste "limpa os dois campos" | **atendido, por construção** |
| SC-009a | coleta interrompida registra o parcial | "o número é gravado a cada falha, não no fim" — a fase levanta na terceira consulta, e o número é **2** | **atendido** |
| SC-009b | motivo de 500 caracteres não derruba | `inaccessible_test.exs`, "motivo longo é gravado sem levantar" | **atendido** |
| SC-010 | um tenant não alcança repositório de outro | `list_collectable/2` e `fetch_observed/2` recebem `%Tenant{}`; comportamento inalterado | **atendido, por construção** |

**12 de 12 atendidos**, dois com a ressalva de não terem sido exercitados em produção.

## Os dois defeitos, conferidos por reprovação

Invertendo o código de propósito:

| defeito reintroduzido | testes que reprovaram |
|---|---|
| `list_collectable/2` voltando a filtrar o inacessível | **3** — a cura, a data preservada e a lista |
| erro de GraphQL sempre permanente | **3** — o payload real, a lista mista e a ponta a ponta |

Um teste que não reprova quando o defeito existe não é evidência de nada.

## O que fica pendente, e por quê

**A prova no dado real.** Uma coleta com a origem respondendo precisa limpar as 39 marcas e trazer
`leds-conectafapes-prestacao-de-contas` de 9 para as **11** issues que a origem tem.

Ela **exige a chave mestra e o token da ferramenta**, que são da pessoa mantenedora — eu não os peço
nem os recebo. Está declarada como pendente em vez de contada como cumprida: o mecanismo está
medido no banco (96 → 135 coletáveis), e o efeito sobre as issues só a coleta produz.

## O que esta feature entregou além do planejado

| Item | Motivo |
|---|---|
| `inaccessible_reason` de `varchar(255)` para `text` | a análise mediu **27 caracteres de folga** contra o motivo real, e sem validação o valor longo **derruba a fase** — L05 |
| `repositories_unreachable` incrementado a cada falha | gravar no fim faria coleta interrompida afirmar que tudo foi alcançado — L32 |
| o `@doc` órfão em `Ingestion` | defeito meu do commit da 008, que impedia a **compilação limpa** desta branch |

## Um achado que não é desta feature

O `@doc` órfão **passou pelos dez gates** e pelo CI. Numa compilação limpa, `main` reprova com
código de saída 1:

```
$ git stash && rm -rf _build/dev/lib/the_band && mix compile --warnings-as-errors
main limpo: código de saída 1
redefining @doc attribute previously set at line 395
```

**O mecanismo que eu registrei aqui primeiro estava errado**, e a correção está na L36: o aviso **é**
emitido, e o gate sai zero porque `execute({:mix, ...})` descartava o retorno de `Mix.Task.run/2` —
e `mix compile --warnings-as-errors` devolve `{:error, diagnostics}` em vez de levantar.

Registrado em [#229](https://github.com/The-Band-Solution/theband/issues/229), **Bug, P0**.

## Veredito

**Aceito**, com a prova no dado real declarada como pendente.

Nove tarefas, 28 testes próprios, 430 na suíte, 10 gates verdes por código de saída, e os dois
defeitos que importavam conferidos por reprovação.
