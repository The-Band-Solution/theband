# Aceitação — Feature 006: detalhe da issue e decomposição navegável

Avaliação de cada critério de sucesso da [spec](../../../specs/006-detalhe-da-issue/spec.md),
**um a um, com evidência**. É a L18 aplicada: critério atendido não é critério suficiente, e
suíte verde não é evidência de que *este* critério passou.

**Data**: 2026-08-11 · **PR**: [#149](https://github.com/The-Band-Solution/theband/pull/149) ·
**Estado**: aguardando revisão humana, **não incorporado**

Dado real no momento da avaliação: **4471 issues**, 135 repositórios, 22 877 promoções, 41
tarefas com pai épico e 3 sem pai.

---

| # | Critério | Veredito | Evidência |
|---|---|---|---|
| SC-001 | todo campo que a origem fornece está persistido ou declarado fora do escopo | **aceito** | 3991 issues com corpo, 4277 com autor, 2885 com motivo de fechamento, 3982 com quadro, 4185 designados e 1467 rótulos em 135 nomes distintos — medidos no banco depois da coleta real |
| SC-002 | nenhum campo ausente na origem aparece preenchido na tela | **aceito** | teste `ausência de designado e de marco aparece nomeada`: a tela mostra "ninguém designado", "fora de marco" e "fora de quadro" |
| SC-003 | composição e atendimento nunca aparecem somados | **aceito** | não existe função que devolva as duas juntas; o contrato declara a ausência de `count_children/2` com o motivo |
| SC-004 | num épico, mostrar as duas contagens e **nunca** a soma | **aceito, e o critério pegou um defeito** | `refute html =~ ">39<"` reprovou a primeira versão, que exibia "partes declaradas 39" ao lado de 9 e 30 |
| SC-005 | user story com nove tarefas aparece como atômica | **aceito** | teste `a user story #3 tem composição vazia e nove tarefas atendendo`, com `classification/2 == :atomic_user_story` |
| SC-006 | as 41 tarefas cujo pai é épico aparecem com o aviso, e continuam promovidas | **aceito** | SQL no dado real devolve 41; teste confere que a issue segue com `derived_concept` de tarefa |
| SC-007 | as 3 tarefas sem pai aparecem com o mesmo aviso | **aceito** | SQL devolve 3; a tela as separa em seção própria — não são caso da anterior |
| SC-008 | a contagem por conceito soma o total de issues do repositório | **aceito** | teste `contagem do cabeçalho soma`, e a tela mostra o desvio em vermelho quando não fecha |
| SC-009 | a ordem da lista paginada é a mesma em duas execuções | **aceito** | teste `a paginação é estável`, comparando os ids das duas leituras |
| SC-010 | abrir o detalhe não gera requisição à origem | **aceito por construção** | nenhuma função da tela chama `Client.graphql/4`; o contrato declara a ausência de `fetch_issue_from_source/2` |
| SC-011 | nenhum corpo renderizado permite injeção de conteúdo executável | **aceito** | a coleta pede `bodyText` (texto extraído, sem marcação) e o HEEx escapa toda interpolação |
| SC-012 | um tenant não alcança issue nem repositório de outro | **aceito** | dois testes, e ambos **recusam** a palavra "permissão" na mensagem |
| SC-013 | duas coletas seguidas sem mudança produzem os mesmos campos | **aceito parcialmente** | idempotência de designados e rótulos provada por teste; a igualdade campo a campo entre duas coletas reais **não** foi medida |

**12 aceitos, 1 aceito parcialmente. Nenhum sem evidência.**

---

## O defeito que a conferência com a origem encontrou

**A suíte estava verde e o dado estava errado.**

Ao medir para esta aceitação, 480 issues apareceram com `body` nulo depois de uma coleta que as
observou. Conferido contra a API: `bodyText` da issue `#1` de `Integrador SIGFAPES` devolve `""`
com comprimento zero — a origem **tem** a resposta, e o banco gravou `NULL`.

**Causa**: `Ecto.Changeset.cast/4` descarta string vazia por padrão — `empty_values` é `[""]`.
Para quase todo campo isso é correto. Para `body`, não: é justamente a distinção que a feature
declarou entre "nunca pedido à origem" (`nil`) e "a origem não tem descrição" (`""`).

**Efeito**: a tela diria "corpo não coletado" sobre 480 issues coletadas e genuinamente vazias.

**Correção**: `cast` separado para `:body` com `empty_values: []`, e um teste que **falha sem a
correção** — verificado removendo a linha e rodando a suíte: 14 de 15.

**As 480 linhas corrigem-se na próxima coleta.** Nenhum reparo retroativo: preencher `""` por
dedução afirmaria sobre a origem algo que só a coleta pode dizer.

É a L13 pela terceira vez, e a segunda vez nesta feature — `nil` e `""` não são a mesma coisa. E
é a lição de verificar o número contra a origem: a suíte não tinha como pegar, porque o cenário
de teste nunca gravava corpo vazio.

---

## Verificação dos gates

```text
mix gates → 9 gates verdes        (código de saída 0, não o texto — L22)
mix test  → 248 passed            (218 antes da feature)
CI do PR  → quality-gates SUCCESS
```

## O que **não** foi verificado, e é declarado

| Item | Por quê |
|---|---|
| SC-013 campo a campo entre duas coletas | exigiria duas coletas completas da mesma organização; a idempotência das partes está provada |
| revisão independente por outro agente | a constituição exige, e esta sessão não invoca agente sem pedido explícito — lacuna declarada, **nunca** marcada como cumprida |
| comportamento com corpo de milhares de linhas | edge case 2 da spec; a tela usa `whitespace-pre-wrap` sem truncar |
| autor que é bot | edge case 3; o caminho é o mesmo do autor não coletado, e está exercitado |
