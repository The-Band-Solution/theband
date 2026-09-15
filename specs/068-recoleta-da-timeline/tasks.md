# Tasks: a recoleta da timeline — fatia 1 (US1 + US2)

- [ ] **T001** A query de timeline por número, em lotes
  - **Descrição**: `priv/connectors/github/queries/issue_timelines.graphql` — a timeline de N
    issues por `issue(number:)`, com os mesmos 12 tipos de evento da coleta. Montada com
    aliases; o lote é de 10, medido como íntegro
  - **Teste**: contra o dado gravado, a #1828 devolve 14 itens

- [ ] **T002** A recoleta de um repositório
  - **Descrição**: `TimelineRecollection.recolher/3` — percorre as issues **por número**,
    busca em lotes, resolve as pessoas antes de gravar, insere o que falta, conta. Para com
    segurança quando a cota acaba e devolve o ponto de retomada. FR-001 a FR-006
  - **Teste**: duas execuções seguidas; a segunda insere zero

- [ ] **T003** A conferência por amostra
  - **Descrição**: para uma amostra, ler pela **conexão** e comparar a contagem; divergência
    torna o veredito `:incompleta`, com as issues nomeadas. FR-007 a FR-009
  - **Teste**: com uma contagem forçada a divergir, o veredito é `:incompleta`

- [ ] **T004** O relatório
  - **Descrição**: issues percorridas, com eventos novos, eventos inseridos, custo, issues no
    teto, e os limites declarados. Repositório sem nada aparece **com zero**. FR-010 a FR-014
  - **Teste**: repositório sem nada a recuperar aparece no relatório

- [ ] **T005** A medida do estrago, antes de recoletar
  - **Descrição**: `suspeitas_por_repositorio/1` — quantas issues na faixa do teto, com a
    ressalva de que é indício. FR-015
  - **Teste**: devolve número por repositório, e a ressalva está no texto

- [ ] **T006** A Mix task
  - **Descrição**: `mix coleta.timeline <repositório>` — dispara, imprime o relatório, e devolve
    código de saída diferente de zero quando o veredito é incompleta
  - **Teste**: a task existe, tem `@shortdoc`, e recusa repositório inexistente

- [ ] **T007** Gates
  - **Teste**: `echo $?` imediatamente após `mix gates`

## Fora desta fatia

O efeito por mês (US3) e a tela de disparar. A recoleta grava o que eles leem.
