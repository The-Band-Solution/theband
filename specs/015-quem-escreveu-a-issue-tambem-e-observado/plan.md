# Plano de implementação: quem escreveu a issue também é observado

**Feature**: `specs/015-quem-escreveu-a-issue-tambem-e-observado/` · **Branch**: `020-clicar-leva-a-pagina`
**Spec**: [spec.md](spec.md) · **Constituição**: v1.4.0 · **Origem**: [#283](https://github.com/The-Band-Solution/theband/issues/283)

## Summary

A coleta de issues passa a pedir o **identificador** do autor e dos designados, e registra a pessoa
pelo mapeamento que já existe. As **288** aparições sem pessoa — **15** logins — passam a ter destino.

## O que este plano decide antes de tudo

**Nada aqui é conceito novo.** O que muda é de onde o mesmo mapeamento é alimentado.

| Decisão | Escolha | O que a alternativa quebraria |
|---|---|---|
| identidade | o `id` da origem | login é string que o GitHub deixa renomear — L25 |
| onde a pessoa nasce | mesmo caminho de `sync_github_eo` — `Mapper.apply_mapping/2` + `EO.upsert_person_from_source/2` | um segundo caminho de escrita discordaria do primeiro no dia em que um mudasse |
| bot | `Mapper.account_type/1`, que **já** classifica `Bot`, `App` e sufixo `[bot]` | reimplementar produziria duas classificações |
| pertencimento | **nenhuma** evidência de equipe é criada | criar faria "quem é da organização" responder 90 |
| payload | guardado como `github.user`, igual à coleta de EO | sem ele, reprocessar não reproduz |

## Technical Context

| | |
|---|---|
| Arquivos | `priv/connectors/github/queries/issues.graphql`, `ingestion/github_work_items.ex` |
| Reuso | `Mapper.apply_mapping/2`, `Mapper.complete/3`, `EO.upsert_person_from_source/2`, `RawData.store/1` |
| Persistência | **nenhuma migração** — `eo_people` já tem tudo |
| Semântica | **nenhum YAML novo** — `github.user.to.eo.person` já cobre |
| Escala | 4 529 issues, 15 logins órfãos, 75 pessoas hoje |

## Constitution Check

**I. Ontologias** — conforme: o conceito é `eo.person`, o mapeamento é o que já existe.

**II. Fonte externa não é domínio** — conforme, **e é o eixo**: o `author_login` da issue é vocabulário
de ferramenta; a pessoa é domínio. Hoje a plataforma guarda o texto e não promove; a feature faz a
promoção acontecer **pedindo identidade**, nunca deduzindo.

**III. Proveniência e idempotência (NÃO NEGOCIÁVEL)** — conforme: payload guardado, `external_id` da
origem, e a segunda coleta não cria ninguém. Nenhuma pessoa é apagada — as 4 ausentes continuam.

**IV. Semântica em YAML** — conforme, **sem tocar no YAML**. A limitação declarada no mapeamento
("Bot e App não são pessoas") passa a ser **exercida** por este caminho também.

**V. Multitenant** — conforme: a escrita é escopada por tenant, como em `sync_github_eo`.

**VI. Spec Kit antes do código** — conforme.

**VII. Gates e revisão** — conforme, com a lacuna de sempre declarada.

**VIII. Desenho que o problema justifica** — registro abaixo.

**IX. Ontologias autônomas** — conforme: EO é alimentada pela ingestão, e WorkItems continua sem
conhecer schema de EO — a resolução acontece na fase de coleta, que já orquestra as duas.

**X. Responsabilidade única** — conforme: `coletar_issues/2` já observa trabalho; observar quem o fez
é a mesma razão de mudar.

## Registro das decisões de desenho (princípio VIII)

### P1 — pedir identidade à origem

| Pergunta | Resposta |
|---|---|
| **Que problema resolve** | 288 aparições sem destino, e o payload guardado só tem login |
| **Existe agora ou é previsão** | **existe agora**, medido |
| **O que fica pior** | a consulta de issues fica maior, e o custo por página de coleta sobe um pouco. E **as issues já coletadas não ganham autor sem nova coleta** — o payload antigo não tem o `id` |

### P2 — reusar o caminho de escrita de EO

| Pergunta | Resposta |
|---|---|
| **Que problema resolve** | duas escritas para a mesma pessoa discordariam — é a dívida que a feature 012 encontrou em `promocoes_vigentes` e que a 013 pagou |
| **Existe agora ou é previsão** | previsão **com precedente**: já aconteceu duas vezes nesta base |
| **O que fica pior** | `github_work_items.ex` passa a depender de `Mapper` e de `EO`, que ele hoje só usa para **ler** (`person_ids_by_login/1`). A fronteira não é nova; o sentido é |

### P3 — o que foi recusado

| Recusado | Razão |
|---|---|
| criar a pessoa a partir do login guardado | identidade por string mutável — L25 |
| criar evidência de participação em equipe | faria "quem é da organização" responder 90 |
| conceito separado para quem só trabalhou | `eo_people` não tem organização: a distinção já existe na **relação**, não no kind |
| reprocessar payloads antigos | eles não têm o `id`; reprocessar não inventa o que não foi pedido |

## Fases

| Fase | O que |
|---|---|
| **F1** | a consulta alargada, e o teste que prova que a identidade chega |
| **F2** | a pessoa nascendo da coleta, com bot recusado |
| **F3** | a separação: membro continua membro, trabalho é outra coisa |
| **F4** | a conferência no dado real — precisa da chave mestra |

## Riscos

| Risco | Mitigação |
|---|---|
| **duplicar pessoa** que já existe | identidade é `external_id`; o teste coleta duas vezes |
| **bot virar pessoa** | `Mapper.account_type/1`, e o teste manda um `[bot]` |
| **inflar "quem é da organização"** | FR-006: a contagem por evidência de equipe é aserida antes e depois |
| a origem não resolver o autor | continua sem pessoa, e a tela continua declarando — FR-010 |
| **`... on User` mudar o formato do nó** | o teste usa payload com `__typename`, como a coleta de EO já recebe |

## Complexity Tracking

Nenhuma violação. Sem migração, sem YAML novo, sem tabela, sem conceito.
