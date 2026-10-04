# Avaliação de segurança da 075, antes do código

**Feature**: [spec.md](spec.md) (issue #1267) · **Data**: 2026-10-03 · **Papel**: Security, por quem não
escreveu o desenho (AGENTS §13, §14.0).

A avaliação foi feita em duas partes, pelo agente `security`, e cada uma está no próprio arquivo, sem
edição de quem desenhou:

| parte | arquivo | achados |
|---|---|---|
| a dependência de i18n e o Mermaid servido pelo site | [seguranca-dependencias.md](seguranca-dependencias.md) | D1 a D5 |
| a exposição pública, a 404 na raiz e o CI | [seguranca-exposicao.md](seguranca-exposicao.md) | E1 a E10 |

Uma primeira tentativa, num arquivo só, parou duas vezes por inatividade antes de escrever achado
nenhum; foi substituída pelas duas acima.

## Veredito

**Pode seguir para o código, com quatro condições bloqueantes antes de publicar.** Nenhum achado alto
nas dependências; um alto (E5) no conteúdo.

| id | severidade | o que exige | tarefa |
|---|---|---|---|
| **E1** | média | `exclude_docs` com `seguranca/` e `producao/prototipo-fila-parada/seguranca.md`, e teste pós-build, inclusive no índice de busca | T020 |
| **E2, E7** | média | guardas no `docs.yml`: `developers/seguranca` não existe; `404.html` existe e é igual ao construído; a cópia para a raiz é só desse arquivo | T013 |
| **E5** | **alta** | as páginas de funcionalidade não descrevem defeito aberto nem mecanismo; **073 e 074 só depois do merge** do PR | T014–T019 |
| **E6** | média | 404 por `textContent`, `decodeURIComponent` em `try`, limite de 200, links fixos, só `pathname`, meta CSP com o hash do script | T013 |

Endurecimentos não bloqueantes, que entram na base porque custam pouco:

| id | o que | tarefa |
|---|---|---|
| D1 | `--require-hashes` em `requirements-docs.txt`, gerado com Python 3.13 | T021 |
| E8 | `persist-credentials: false` e `timeout-minutes` nos dois workflows; teste do workflow | T003, T021 |
| D2 | o hook do hash do Mermaid **levanta erro**, e não só avisa | T006 |
| D3 | teste que reprova `securityLevel` `loose` | T006 |
| E3 | `exclude_docs` para `*.txt`, `*.log`, `*.sql`, `*.dump`, `*.env*` | T020 |

**A dependência nova não exige ADR** (D5), na leitura do agente `security` e na do plano.

## O que muda no desenho por causa da avaliação

- **As páginas da 073 e da 074 não entram na base.** O pedido era escrevê-las; a avaliação (E5) manda
  esperar o merge dos PRs #1228 e #1266, e segurança prevalece (CLAUDE.md). A home lista as duas com
  "entra quando o PR for mergeado", que é o que o protótipo já desenhava.
- **A seção Segurança sai do site.** O `nav` perde a seção; links de outras páginas para ela passam a
  ir ao GitHub pelo hook, como os de `specs/`. O repositório é público: isso reduz o alcance, não
  desfaz a exposição (E1).

## Decisões da pessoa mantenedora

1. Os inventários de `docs/seguranca/` continuam no repositório público?
2. O que fazer com o que já está publicado e indexado em `theband.dev/developers/seguranca/` (o
   próximo deploy apaga do site; o buscador é fora do repositório).
