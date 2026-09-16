# Tasks: a recoleta da timeline — fatia 1 (US1 + US2)

- [x] **T001** A query de timeline por número, em lotes
  - **Descrição**: a timeline de N issues por `issue(number:)`, com os mesmos 12 tipos de
    evento da coleta, montada com aliases; o lote é de 10, medido como íntegro. **Ficou no
    módulo, e não em arquivo `.graphql`** — os arquivos de `priv/connectors` são os da
    coleta versionada por impressão digital, e uma consulta montada por alias variável não
    tem impressão estável
  - **Teste**: contra o dado gravado, a #1828 devolve 14 itens

- [x] **T002** A recoleta de um repositório
  - **Descrição**: `TimelineRecollection.recolher/3` — percorre as issues **por número**,
    busca em lotes, resolve as pessoas antes de gravar, insere o que falta, conta. Para com
    segurança quando a cota acaba e devolve o ponto de retomada. FR-001 a FR-006
  - **Teste**: duas execuções seguidas; a segunda insere zero

- [x] **T003** A conferência por amostra
  - **Descrição**: para uma amostra, ler pela **conexão** e comparar a contagem; divergência
    torna o veredito `:incompleta`, com as issues nomeadas. FR-007 a FR-009
  - **Teste**: com uma contagem forçada a divergir, o veredito é `:incompleta`

- [x] **T004** O relatório
  - **Descrição**: issues percorridas, com eventos novos, eventos inseridos, custo, issues no
    teto, e os limites declarados. Repositório sem nada aparece **com zero**. FR-010 a FR-014
  - **Teste**: repositório sem nada a recuperar aparece no relatório

- [x] **T005** A medida do estrago, antes de recoletar
  - **Descrição**: `pendentes_de_recoleta/1` — quantas issues ainda não têm nenhuma
    atividade com identificador da origem, por repositório. FR-015

    **Mudou de forma durante a implementação.** A spec pedia a faixa de 10 a 13 eventos
    como indício de corte. A distribuição foi medida sobre as 4 923 issues com evento e
    **não quebra ali**: desce sem degrau do pico em 6 e 7 (625 e 605) por 486, 419, 329,
    253, 154, 144, 110, 107. Contar aquela faixa marcava 880 issues sem separar truncada
    de inteira. A contagem de issues não relidas é exata e diz a mesma coisa que a spec
    queria saber: quanto trabalho falta
  - **Teste**: devolve número por repositório, e a ressalva está no texto

- [x] **T006** A Mix task
  - **Descrição**: `mix the_band.recollect_timeline <repositório> --apply` — dispara, imprime
    o relatório, e devolve código de saída diferente de zero quando o veredito é incompleta.
    O nome segue `the_band.recollect_changes`, que já existe. Sem `--apply` não fala com a
    origem; sem argumento lista o que falta
  - **Teste**: a task existe, tem `@shortdoc`, e recusa repositório inexistente

- [x] **T007** Gates
  - **Teste**: `echo $?` imediatamente após `mix gates`

## Fora desta fatia

O efeito por mês (US3) e a tela de disparar. A recoleta grava o que eles leem.
