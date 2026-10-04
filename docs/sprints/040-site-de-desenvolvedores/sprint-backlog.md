# Sprint 040 — o site de desenvolvedores

**Período**: 2026-10-03 a 2026-10-09, na iteration Sprint 035 do GitHub (`ee36a246`)
**Feature**: [075](../../../specs/075-site-de-desenvolvedores/spec.md) · **Plano**: [plan.md](../../../specs/075-site-de-desenvolvedores/plan.md) · **Tarefas**: [tasks.md](../../../specs/075-site-de-desenvolvedores/tasks.md)
**Issue de origem**: [#1267](https://github.com/The-Band-Solution/theband/issues/1267), retipada de `us` para `epic` em 2026-10-03: a spec a decompôs em quatro user stories (`sro.rule05`)

## Objetivo do sprint

A base do site: quem clica em *Documentação técnica* na landing continua em theband.dev, visualmente,
e volta por qualquer página; o site existe em PT e EN, com a ausência nomeada onde a tradução não chegou;
as funcionalidades novas têm página; e nenhum PR quebra o site em silêncio. **Nada é publicado neste
sprint**: o site muda só quando a `main` muda.

## Antes de escolher o trabalho (AGENTS §14.0)

`gh issue list --label security --state open` em 2026-10-03: nenhuma issue toca o site de documentação.
A avaliação desta feature ([seguranca.md](../../../specs/075-site-de-desenvolvedores/seguranca.md)) achou
a exposição que já estava no ar (`docs/seguranca/` publicado), e por isso T020 entra na base e bloqueia
a publicação.

## Lições aplicadas

| lição | como está sendo aplicada |
|---|---|
| L60 — o pipe devolve o código do `tail` | todo build e teste redireciona para arquivo e lê o `EXIT`; o CI não usa pipe no veredito |
| L102 — `git add -A` numa árvore compartilhada | cada commit adiciona os caminhos pelo nome |
| L106 — a verificação rodou e ninguém a leu | o build estrito já reprovava em `development` sem ninguém ver; T003 o põe em todo PR |
| L108 — feature sem sprint backlog | este documento existe antes do código do tema |
| a tela exatamente a aprovada | o protótipo de `docs/site-developers/prototipo/` é a régua; T026 confere item a item |

## User stories

| # | user story | issue | Priority |
|---|---|---|---|
| US1 | A mesma identidade de theband.dev, e o caminho de volta | [#1269](https://github.com/The-Band-Solution/theband/issues/1269) | P1 |
| US2 | O site em português e em inglês | [#1270](https://github.com/The-Band-Solution/theband/issues/1270) | P1 |
| US3 | O conteúdo novo, e as ausências nomeadas | [#1271](https://github.com/The-Band-Solution/theband/issues/1271) | P1 |
| US4 | O site não quebra em silêncio | [#1272](https://github.com/The-Band-Solution/theband/issues/1272) | P2 |

## Tarefas

| # | tarefa | atende | tipo | issue | escopo e estado (2026-10-03) |
|---|---|---|---|---|---|
| T001 | O build estrito volta a passar | US4 | Task | [#1273](https://github.com/The-Band-Solution/theband/issues/1273) | base · feita, evidência na issue |
| T002 | Página fora da navegação reprova | US4 | Task | [#1274](https://github.com/The-Band-Solution/theband/issues/1274) | base · feita, evidência na issue |
| T003 | O site é construído e varrido em todo PR | US4 | Task | [#1275](https://github.com/The-Band-Solution/theband/issues/1275) | base · feita local; o job roda no PR |
| T004 | Os dois idiomas, com o seletor | US2 | Task | [#1276](https://github.com/The-Band-Solution/theband/issues/1276) | base · feita, evidência na issue |
| T005 | A página sem tradução diz que não tem | US2 | Task | [#1277](https://github.com/The-Band-Solution/theband/issues/1277) | base · feita, evidência na issue |
| T006 | O Mermaid servido pelo site, com o hash conferido | US1 | Task | [#1278](https://github.com/The-Band-Solution/theband/issues/1278) | base · feita, evidência na issue |
| T007 | Os tokens de theband.dev, com a data da cópia | US1 | Task | [#1279](https://github.com/The-Band-Solution/theband/issues/1279) | base · feita, evidência na issue |
| T008 | O topo e a faixa do build | US1 | Task | [#1280](https://github.com/The-Band-Solution/theband/issues/1280) | base · feita, evidência na issue |
| T009 | O rodapé, editar no GitHub, anterior e próxima | US1 | Task | [#1281](https://github.com/The-Band-Solution/theband/issues/1281) | base · feita, evidência na issue |
| T010 | Larguras e tabelas | US1 | Task | [#1282](https://github.com/The-Band-Solution/theband/issues/1282) | base · feita; falta a captura a 360 px (QA) |
| T011 | A home | US1 | Task | [#1283](https://github.com/The-Band-Solution/theband/issues/1283) | base · feita, evidência na issue |
| T012 | Sem JavaScript e sem o script do Mermaid | US1 | Task | [#1284](https://github.com/The-Band-Solution/theband/issues/1284) | base · feita, evidência na issue |
| T013 | A 404, na raiz e em /developers/ | US3 | Task | [#1285](https://github.com/The-Band-Solution/theband/issues/1285) | base · feita, evidência na issue |
| T014 | A página da 064 | US3 | Task | [#1286](https://github.com/The-Band-Solution/theband/issues/1286) | base · escrita; falta a revisão do security (E5) |
| T015 | A página da 070 | US3 | Task | [#1287](https://github.com/The-Band-Solution/theband/issues/1287) | base · escrita; falta a revisão do security (E5) |
| T016 | A página da 071 | US3 | Task | [#1288](https://github.com/The-Band-Solution/theband/issues/1288) | base · escrita; falta a revisão do security (E5) |
| T017 | A página da 072 | US3 | Task | [#1289](https://github.com/The-Band-Solution/theband/issues/1289) | base · escrita; falta a revisão do security (E5) |
| T018 | A página da 073, depois do merge do PR #1228 | US3 | Task | [#1290](https://github.com/The-Band-Solution/theband/issues/1290) | fora: espera o merge (E5) |
| T019 | A página da 074, depois do merge do PR #1266 | US3 | Task | [#1291](https://github.com/The-Band-Solution/theband/issues/1291) | fora: espera o merge (E5) |
| T020 | A seção Segurança e as evidências fora do site | US4 | Task | [#1292](https://github.com/The-Band-Solution/theband/issues/1292) | base · feita, evidência na issue |
| T021 | O build da documentação endurecido | US4 | Task | [#1293](https://github.com/The-Band-Solution/theband/issues/1293) | base · feita, evidência na issue |
| T022 | O recibo das ADRs | US1 | Task | [#1294](https://github.com/The-Band-Solution/theband/issues/1294) | próximo sprint |
| T023 | O recibo dos modelos | US1 | Task | [#1295](https://github.com/The-Band-Solution/theband/issues/1295) | próximo sprint |
| T024 | Ver como tabela em toda figura | US1 | Task | [#1296](https://github.com/The-Band-Solution/theband/issues/1296) | próximo sprint |
| T025 | A busca diz o alcance | US1 | Task | [#1297](https://github.com/The-Band-Solution/theband/issues/1297) | próximo sprint |
| T026 | A conferência do QA, item a item | US1 | Task | [#1298](https://github.com/The-Band-Solution/theband/issues/1298) | próximo sprint |
| T027 | Tradução L01 | US2 | Task | [#1299](https://github.com/The-Band-Solution/theband/issues/1299) | lotes, outros agentes |
| T028 | Tradução L02 | US2 | Task | [#1300](https://github.com/The-Band-Solution/theband/issues/1300) | lotes, outros agentes |
| T029 | Tradução L03 | US2 | Task | [#1301](https://github.com/The-Band-Solution/theband/issues/1301) | lotes, outros agentes |
| T030 | Tradução L04 | US2 | Task | [#1302](https://github.com/The-Band-Solution/theband/issues/1302) | lotes, outros agentes |
| T031 | Tradução L05 | US2 | Task | [#1303](https://github.com/The-Band-Solution/theband/issues/1303) | lotes, outros agentes |
| T032 | Tradução L06 | US2 | Task | [#1304](https://github.com/The-Band-Solution/theband/issues/1304) | lotes, outros agentes |
| T033 | Tradução L07 | US2 | Task | [#1305](https://github.com/The-Band-Solution/theband/issues/1305) | lotes, outros agentes |
| T034 | Tradução L08 | US2 | Task | [#1306](https://github.com/The-Band-Solution/theband/issues/1306) | lotes, outros agentes |
| T035 | Tradução L09 | US2 | Task | [#1307](https://github.com/The-Band-Solution/theband/issues/1307) | lotes, outros agentes |

## Riscos

- **O plugin de idiomas declara compatibilidade só até o Material 9.7.1.** O build estrito em todo PR é a guarda.
- **A seção Segurança sai do site, e o repositório é público.** Excluir reduz o alcance, não desfaz a exposição; duas decisões são da pessoa mantenedora ([seguranca.md](../../../specs/075-site-de-desenvolvedores/seguranca.md)).
- **A 073 e a 074 ficam sem página**, contra o pedido inicial, porque a avaliação de segurança (E5) manda esperar o merge.
