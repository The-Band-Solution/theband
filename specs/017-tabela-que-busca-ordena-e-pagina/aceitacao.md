# Aceitação — feature 017, a tabela que busca, ordena e pagina

**Avaliada em**: 2026-08-13

## A medida, antes e depois

| Tela | Antes | Depois |
|---|---:|---:|
| `/work` | 120 ms | **61 ms** |
| `/work/repositories/:id` | — | **23 ms** |
| contar com busca | — | 4,9 ms |
| ordenar por conceito derivado | 14,2 ms | 14,2 ms |

**A tela ficou mais rápida ganhando função** — e não foi por acaso: a paginação numerada substituiu
uma contagem que já existia, e a busca entra na mesma consulta.

## Requisitos funcionais

| # | Requisito | Veredito | Evidência |
|---|---|---|---|
| FR-001 | busca alcança todas as linhas | **aceito** | o teste procura por algo **fora** da primeira página |
| FR-002 | a tela declara onde procura | **aceito** | *"buscar em título e número"*, e a mensagem de vazio repete |
| FR-003 | busca sem resultado é dita | **aceito** | com o texto procurado |
| FR-004 | ordena por coluna derivada | **aceito** | conceito, pela junção lateral da feature 013 |
| FR-005 | desempate determinístico | **aceito** | o teste percorre **todas** as páginas e compara o conjunto com o total |
| FR-006 | direção sem depender de cor | **aceito** | `↑`/`↓` como texto, mais `sr-only` |
| FR-007 | coluna não ordenável não parece clicável | **aceito** | só as declaradas viram botão |
| FR-008 | índices numerados e total | **aceito** | com reticências preservando primeira, última e vizinhas |
| FR-009 | uma página só não pagina | **aceito** | `/teams`, com 12 linhas |
| FR-010 | estado na URL | **não entregue** | ver abaixo |
| FR-011 | um componente | **aceito** | `th_ordenavel`, `busca` e `paginacao` em `core_components` |
| FR-012 | medida antes e depois | **aceito** | a tabela acima |
| FR-013 | ordenar em 360 px | **aceito em markup** | o cabeçalho vira botão, que existe no cartão — **olho humano pendente** |

## Critérios de sucesso

| # | Critério | Veredito |
|---|---|---|
| SC-001 | as sete tabelas | **parcial** — as duas maiores e `/people` (que já tinha busca); as menores não pedem |
| SC-002 | busca alcança as 4 529 | **aceito** |
| SC-003 | `/work` abaixo de 200 ms | **aceito** — 61 ms |
| SC-004 | conceito derivado abaixo de 50 ms | **aceito** — 14,2 ms |
| SC-005 | ordem estável | **aceito** |
| SC-006 | recarregar preserva | **não entregue** |
| SC-007 | `/teams` sem paginação | **aceito** |
| SC-008 | 360 px | **pendente de olho humano** |

## O que não foi entregue, e por quê

**FR-010 e SC-006 — o estado na URL.** A busca e a ordem vivem no socket, não no endereço:
recarregar volta ao começo, e o endereço não é compartilhável.

**Não foi esquecimento, foi corte declarado.** Levar o estado para a URL exige `handle_params` nas
duas telas e decidir o que fazer quando o parâmetro é inválido — e cada tela que já usava
`push_patch` para filtro de repositório teria de compor os dois. É trabalho próprio, e entra como
dívida com issue.

**SC-001 é parcial, e a razão está na spec**: uma tabela de 12 linhas e uma de 4 529 não pedem a
mesma solução. As menores ganham o componente quando alguém precisar procurar nelas.

## Veredito

**Aceita com dois cortes declarados**: o estado na URL, que vira issue, e o item de 360 px, que
precisa de olho humano.
