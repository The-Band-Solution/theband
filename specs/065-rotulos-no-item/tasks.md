# Tasks: o rótulo como campo do item de trabalho

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Decisões**: [research.md](research.md)

**Modelo**: [data-model.md](data-model.md) · **Validação**: [quickstart.md](quickstart.md)

**Protótipo aprovado**: <https://claude.ai/code/artifact/e52ca895-fa21-40b2-bbbc-bab0b4a711b0>

---

## Duas coisas que mudam como este arquivo se lê

**Nenhuma migração.** Nenhuma tarefa abaixo cria coluna, tabela ou índice. Tudo o que a
feature precisa já está guardado; o que falta é ler. Se alguma tarefa levar você a escrever
uma migração, a tarefa está sendo mal entendida.

**A US3 é P1, junto com a US1.** Ela é a regra que a US1 pode quebrar: um campo de rótulo ao
lado do conceito é exatamente a situação em que alguém, meses depois, "melhora" a
classificação lendo o rótulo. Por isso os testes dela entram **junto** com a primeira
entrega, e não numa fase posterior.

---

## Fase 1 — Fundação

- [x] **T001** Ler a lista de prefixos declarada — [#890](https://github.com/The-Band-Solution/theband/issues/890)
  - **Pronta quando**: nada além do repositório — `github_issue_pattern_catalog.yaml` já tem a seção `not_type_patterns`
  - **Descrição**: função que devolve os prefixos que a base **recusa como tipo** — `Devops`, `Back-end`, `Front-end`, `Dados`, `QA`, `Backend`, `Front`, `Infra`. Lê da base carregada; **não** copia a lista para dentro do código. A razão não é elegância: duas listas divergem, e a divergência aparece como **ausência silenciosa** na que ficou para trás — alguém acrescenta um prefixo na base, a tela não muda, e ninguém nota, porque ausência de rótulo é estado legítimo. FR-005
  - **Feita quando**: nenhum outro arquivo do repositório enumera esses prefixos; acrescentar um na base o torna reconhecido **sem recompilar consulta nenhuma**
  - **Teste**: `test/the_band/work_items/prefixos_test.exs` — a lista devolvida é exatamente a da base; e **o teste que importa**: acrescentar um prefixo ao carregamento da base o faz aparecer, sem tocar no código da consulta

---

## Fase 2 — US1 (P1) + US3 (P1): a lista mostra o que o time chamou, e o rótulo não vira conceito

**Objetivo**: quem abre a listagem lê os rótulos de vários itens numa tela só — e a
classificação continua vindo do fato estrutural.

**Teste independente**: abrir a lista, ler os rótulos sem abrir item nenhum, e conferir que
pôr um rótulo `bug` num item não muda o tipo dele.

- [x] **T002** [US1] Trazer os rótulos do campo para a listagem — [#891](https://github.com/The-Band-Solution/theband/issues/891)
  - **Pronta quando**: nada além do repositório
  - **Descrição**: em `lib/the_band/work_items/queries.ex`, `list_issues` ganha os nomes dos rótulos vigentes — `no_longer_observed_at` nulo — por **junção lateral agregada**, no mesmo padrão de `vigente_da_issue/1`, que o arquivo já usa. Nunca carregamento associado por linha: uma listagem de 100 itens faria 101 consultas, e é a L38. O agregado leva `ORDER BY` **dentro dele** — sem ordenação declarada a ordem vem do plano de execução e muda entre execuções. FR-001, FR-012, FR-013
  - **Feita quando**: a listagem devolve os rótulos de cada item; o número de consultas **não** muda com o número de linhas
  - **Teste**: `test/the_band/work_items/rotulos_na_listagem_test.exs` — duas leituras seguidas devolvem a **mesma ordem**; **e a reinjeção**: trocar a junção por carregamento associado faz o teste de custo acusar 101 consultas para 100 itens

- [x] **T003** [P] [US1] Provar que a listagem não cresce em consultas — [#892](https://github.com/The-Band-Solution/theband/issues/892)
  - **Pronta quando**: T002 concluída
  - **Descrição**: teste que conta as consultas de uma listagem de 10 itens e de uma de 100, e exige o **mesmo número**. Contar consultas, e não medir tempo: tempo varia com a máquina e esconde o 1+N atrás de um banco rápido. SC-005
  - **Feita quando**: a contagem de 10 e a de 100 são iguais; o teste nomeia o número esperado
  - **Teste**: o próprio arquivo, com a reinjeção — substituir a junção por `Repo.preload` faz a contagem de 100 subir para 101, e o teste falha

- [x] **T004** [US3] Impedir que o rótulo vire conceito — [#893](https://github.com/The-Band-Solution/theband/issues/893)
  - **Pronta quando**: T002 concluída — é preciso ter o campo para poder provar que ele não contamina
  - **Descrição**: teste, não código novo. Pôr rótulo `bug` num item classificado como tarefa, e o tipo derivado **não mudar**. É `commands.ex:134` virado asserção: *"o rótulo é preservado e não promovido"*. A classificação vem do fato estrutural; o rótulo é intenção. FR-007
  - **Feita quando**: pôr qualquer rótulo não altera a classificação; o teste afirma explicitamente que o conceito **não** passou a seguir o rótulo
  - **Teste**: `test/the_band/work_items/rotulo_nao_vira_conceito_test.exs` — `refute conceito == "osdef.defect"` com a mensagem dizendo que seguir o rótulo é o que a regra proíbe

- [x] **T005** [US1] Mostrar os rótulos na tela, com a origem — [#894](https://github.com/The-Band-Solution/theband/issues/894)
  - **Pronta quando**: T002 concluída; o protótipo aprovado é a referência
  - **Descrição**: a coluna na listagem de itens, com o preenchimento **sólido** para rótulo do campo, e **texto e `title` redundantes** — cor nunca é canal único (`DESIGN.md`). Ausência de rótulo é **escrita**, nunca célula vazia: vazio se confunde com "ainda não carregou". FR-001, FR-003, FR-010, FR-015
  - **Feita quando**: a coluna existe e bate com o protótipo item a item; item sem rótulo diz a ausência em palavras
  - **Teste**: teste de tela — com rótulos, os nomes aparecem no HTML; **sem rótulos, o HTML contém a frase de ausência**, e não uma célula vazia. O segundo é o que prova a FR-010

---

## Fase 3 — US1 continuada: a segunda origem

**Objetivo**: as 1 519 issues cujo título carrega um prefixo reconhecido passam a ter essa
caracterização consultável — hoje são zero.

- [x] **T006** [US1] Derivar o rótulo do prefixo do título — [#895](https://github.com/The-Band-Solution/theband/issues/895)
  - **Pronta quando**: T001 e T002 concluídas
  - **Descrição**: na leitura, extrair o prefixo entre colchetes do início do título e, **se ele estiver na lista da T001**, expô-lo como rótulo de origem `titulo`. Derivado na leitura, a partir do título já guardado — **sem coluna, sem migração, sem recarga de 5 033 linhas**. Consequência declarada: renomear uma issue muda seus rótulos, e isso precisa estar escrito ou parece defeito. FR-002, FR-004, FR-006
  - **Feita quando**: `[Devops]` vira rótulo; `[TASK]` **não** vira, porque é o tipo; a grafia sai como escrita — `Back-end`, não `backend`
  - **Teste**: `test/the_band/work_items/prefixo_vira_rotulo_test.exs` — **o caso que prova a regra é o negativo**: `[Portal ADM]` tem 68 issues reais, não está na lista, e **não** vira rótulo. Sem essa asserção, uma implementação que aceita qualquer colchete passaria

- [x] **T007** [US1] Mostrar as duas origens sem juntá-las — [#896](https://github.com/The-Band-Solution/theband/issues/896)
  - **Pronta quando**: T005 e T006 concluídas
  - **Descrição**: rótulo do título aparece **hachurado 135°**, ao lado do sólido do campo. **Não deduplicar e não normalizar grafia**: a issue cujo título começa com `[Back-end]` tem `backend` no campo e `Back-end` no título, e as **duas** aparecem. Juntá-las exigiria decidir que são a mesma coisa — interpretação, que é o que a FR-009 proíbe aplicada ao nome. FR-002, FR-003, FR-008
  - **Feita quando**: aquela issue mostra **dois** rótulos; a distinção entre sólido e hachurado é perceptível sem cor
  - **Teste**: teste de tela — a issue do `[Back-end]` mostra **dois** rótulos, não um. Se aparecer um, a implementação deduplicou e a FR-008 quebrou

- [x] **T008** [P] [US3] Recusar interpretar o conteúdo do rótulo — [#897](https://github.com/The-Band-Solution/theband/issues/897)
  - **Pronta quando**: T006 concluída
  - **Descrição**: teste. Um rótulo escrito `chave:valor` — `prioridade:alta`, `epic:base` — aparece **como escrito**, e nenhum campo do item é preenchido a partir dele. FR-009
  - **Feita quando**: o texto sai literal; nenhum campo do item deriva do rótulo
  - **Teste**: `test/the_band/work_items/rotulo_nao_e_interpretado_test.exs` — item com `prioridade:alta` mostra essa string, e o item **não** ganha campo de prioridade nenhum

---

## Fase 4 — A identidade visível (FR-016, FR-017)

**Objetivo**: duas issues de repositórios diferentes com o mesmo número deixam de ser
indistinguíveis.

**Independente das fases 2 e 3** — podia vir primeiro; vem aqui porque é ambiguidade de
leitura, não ausência de informação.

- [x] **T009** Trazer o repositório para as sub-listas do detalhe — [#898](https://github.com/The-Band-Solution/theband/issues/898)
  - **Pronta quando**: nada além do repositório
  - **Descrição**: as sub-listas do detalhe mostram `#N` e o título, sem repositório. Trazer o nome qualificado por **junção** em `Queries.partes/3`, na mesma leitura das partes — `qualified_name` já inclui a organização, então é um campo e não dois. FR-016
  - **Feita quando**: cada parte traz o nome do repositório dela; o número de consultas da tela **não** muda
  - **Teste**: o teste de custo do detalhe continua em **46** consultas por render — a primeira versão, com mapa em memória, subiu para 50 e foi pega por ele

- [x] **T010** Dizer quando a parte vem de outro repositório — [#899](https://github.com/The-Band-Solution/theband/issues/899)
  - **Pronta quando**: T009 concluída; o protótipo do detalhe é a referência
  - **Descrição**: o repositório aparece em **toda** linha, e não só quando difere — decisão da pessoa mantenedora. Mostrar só nos 5 casos ensinaria quem lê a pular o campo, e aí os 5 passariam despercebidos. O condicional fica na **marca**: o caminho diz *onde*, a marca diz que uma *fronteira foi atravessada*. FR-016, FR-017, SC-009
  - **Feita quando**: quem lê diz de qual repositório é cada parte sem abrir nenhuma, e reconhece as de fora sem comparar caminhos
  - **Teste**: a issue `#2393` mostra os dois repositórios das suas partes, com a marca nas duas


## Fase 5 — US2 (P2): a alegação ao lado do veredito

**Objetivo**: a tela que existe para mostrar desacordo passa a mostrar os dois lados.

- [x] **T011** [US2] Trazer os rótulos para as divergências — [#900](https://github.com/The-Band-Solution/theband/issues/900)
  - **Pronta quando**: T002 e T006 concluídas — reusa o mesmo mecanismo
  - **Descrição**: `list_divergences` ganha os rótulos das duas origens, pela mesma junção agregada. FR-014
  - **Feita quando**: cada divergência traz os rótulos; o custo por linha não muda
  - **Teste**: `test/the_band/work_items/divergencia_com_rotulo_test.exs` — o item real rotulado `task` cujo conceito derivado é **defeito** traz os dois no mesmo registro

- [x] **T012** [US2] Mostrar os dois lados e dizer qual venceu — [#901](https://github.com/The-Band-Solution/theband/issues/901)
  - **Pronta quando**: T011 concluída
  - **Descrição**: a tela mostra o rótulo (alegação) e o conceito (veredito) lado a lado, e diz **qual deles a plataforma seguiu** — o fato estrutural. Item sem rótulo diz **"não há o que comparar"**, e não deixa a célula vazia, que se leria como concordância. FR-014, FR-010
  - **Feita quando**: os dois aparecem na mesma linha; fica claro qual foi seguido; item sem rótulo diz a ausência
  - **Teste**: teste de tela — na linha do item rotulado `task` e derivado defeito, o HTML traz **os dois** e a palavra que diz qual venceu; na linha sem rótulo, a frase de ausência

---

## Fase 6 — Conferência

- [x] **T013** Conferir a tela contra o protótipo aprovado — [#902](https://github.com/The-Band-Solution/theband/issues/902)
  - **Pronta quando**: T005, T007, T010 e T012 concluídas
  - **Descrição**: comparar item a item com <https://claude.ai/code/artifact/e52ca895-fa21-40b2-bbbc-bab0b4a711b0>. Divergência do protótipo é **defeito**, não melhoria — e a correção volta ao protótipo **antes** do código. FR-015
  - **Feita quando**: cada elemento do protótipo tem correspondente na tela; as divergências encontradas estão listadas com o que se decidiu sobre cada uma
  - **Teste**: conferência item a item, escrita. Item que não puder ser conferido fica declarado como **não verificado** — nunca marcado como conforme

- [ ] **T014** Fechar os gates — [#903](https://github.com/The-Band-Solution/theband/issues/903)
  - **Pronta quando**: T013 concluída
  - **Descrição**: `mix gates` é a definição única, e o veredito é o **código de saída dela**. PR a partir do template, com o tipo de merge declarado, a lacuna de revisão dita se não puder ser obtida, e as **issues que o PR fecha** com a closing keyword em inglês — "Fecha #N" não fecha nada
  - **Feita quando**: `mix gates` sai com 0; o PR está aberto com todas as seções do template preenchidas
  - **Teste**: `echo $?` imediatamente após `mix gates`, sem nenhum comando entre os dois — qualquer comando depois substitui o código que vale

---

## O escopo da fase 4, reescrito em 2026-09-13

As T009 e T010 nasceram descrevendo a **listagem**, e ali não havia defeito: `/work` tem
colunas de organização e repositório desde antes desta spec. Eu li a consulta, vi um
identificador interno, e concluí que a tela mostrava só o número — sem abrir a tela.

O defeito está nas **sub-listas do detalhe**, e ali é real: 5 vínculos de 1 953 têm pai e
filha em repositórios diferentes. As duas tarefas foram reescritas para lá, e as issues
[#898](https://github.com/The-Band-Solution/theband/issues/898) e
[#899](https://github.com/The-Band-Solution/theband/issues/899) carregam o texto novo com a
correção declarada.

**O que não foi feito**: apagar o texto errado. Ele está nas issues, dito como erro meu, e
some da spec — porque a spec descreve o que vale, e a issue guarda como se chegou lá.

## As issues

Criadas em 2026-09-13, com os números conferidos contra o GitHub **depois** de criar — e não os que eu supus ter criado.

| nível | issue |
|---|---|
| US1 | [#904](https://github.com/The-Band-Solution/theband/issues/904) |
| US2 | [#905](https://github.com/The-Band-Solution/theband/issues/905) |
| US3 | [#906](https://github.com/The-Band-Solution/theband/issues/906) |
| T001 | [#890](https://github.com/The-Band-Solution/theband/issues/890) |
| T002 | [#891](https://github.com/The-Band-Solution/theband/issues/891) |
| T003 | [#892](https://github.com/The-Band-Solution/theband/issues/892) |
| T004 | [#893](https://github.com/The-Band-Solution/theband/issues/893) |
| T005 | [#894](https://github.com/The-Band-Solution/theband/issues/894) |
| T006 | [#895](https://github.com/The-Band-Solution/theband/issues/895) |
| T007 | [#896](https://github.com/The-Band-Solution/theband/issues/896) |
| T008 | [#897](https://github.com/The-Band-Solution/theband/issues/897) |
| T009 | [#898](https://github.com/The-Band-Solution/theband/issues/898) |
| T010 | [#899](https://github.com/The-Band-Solution/theband/issues/899) |
| T011 | [#900](https://github.com/The-Band-Solution/theband/issues/900) |
| T012 | [#901](https://github.com/The-Band-Solution/theband/issues/901) |
| T013 | [#902](https://github.com/The-Band-Solution/theband/issues/902) |
| T014 | [#903](https://github.com/The-Band-Solution/theband/issues/903) |

A deduplicação foi por `065/`, e não por `T001` — casar o ID nu encontraria as centenas de issues das specs anteriores, e nenhuma seria criada.

---

## Dependências

```
T001 ──┐
       ├──> T006 ──> T007 ──┐
T002 ──┴──> T005 ───────────┤
  │                          ├──> T013 ──> T014
  ├──> T003                  │
  ├──> T004                  │
  ├──> T008                  │
  └──> T011 ──> T012 ────────┤
T009 ──> T010 ───────────────┘
```

**Em paralelo**: T003, T004 e T008 entre si · T009 com toda a fase 2 · T011 depois de T006

## Escopo mínimo

**T001 a T005.** A listagem passa a mostrar os rótulos do campo, com a regra da US3 já
protegida por teste. Entrega valor sozinha, e é o mecanismo que as fases 3 e 5 reusam.

## O que estas tarefas não cobrem

- **As cinco consultas de hierarquia** — pai, partes, histórico de promoção. Fora do protótipo
- **Interpretar o conteúdo do rótulo** — recusa declarada, com teste próprio na T008
- **A busca por número** continua como está: é busca, não identidade
- **Editar rótulos pela plataforma** — o rótulo é observado
