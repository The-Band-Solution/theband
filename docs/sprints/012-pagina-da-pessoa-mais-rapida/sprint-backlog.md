# Sprint 012 — a página da pessoa que não varre tudo

**Período**: 2026-08-12 a 2026-08-18 (cadência de uma semana)
**Feature**: [013 — a página da pessoa que não varre tudo](../../../specs/013-pagina-da-pessoa-mais-rapida/spec.md)
**Plano**: [plan.md](../../../specs/013-pagina-da-pessoa-mais-rapida/plan.md)
**Origem**: pedido da pessoa mantenedora — *"estudo de como otimizar a tela de pessoas"*
**Análise**: rodada antes do código, **cinco correções** — duas de correção silenciosa, três de
testes que não podiam funcionar

## Objetivo do sprint

Ao fim deste sprint, a página de qualquer pessoa abre em **menos de 200 ms**. Hoje ela vai de
**0,09 s a 6,12 s** conforme quem é.

## A conferência da L44 e da L45, feita antes de tudo

```text
docs/sprints/011-vinculo-que-sumiu-na-origem/sprint-backlog.md   ✓
docs/sprints/011-vinculo-que-sumiu-na-origem/sprint-review.md    ✓
specs/012-vinculo-que-sumiu-na-origem/aceitacao.md               ✓
```

**E onde eles estão** — que é a L45: os três estão na `main`, incorporados pelos PRs #278, #279 e
#280. Esta branch saiu da `main` e enxerga tudo. Não precisou empilhar.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), 48 lições. As que entram como **restrição**:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L18** | Sprint 003 | a aceitação avalia os SC um a um, com evidência |
| **L21** | Sprint 004 | não há função sem consumidor: a mudança é numa consulta que 14 telas já usam |
| **L22** | Sprint 004 | **T010 mede linhas lidas, não milissegundos** — relógio dentro da suíte não sabe dizer o que funcionou |
| **L27** | Sprint 005 | ciclo completo antes do código — **oitava** feature seguida |
| **L28** | Sprint 005 | "a consulta ficou rápida" e "a tela mostra o mesmo" são afirmações diferentes: a F3 existe para a segunda |
| **L30** | Sprint 005 | **cobrou dentro deste estudo**: a primeira medida disse 85 ms, e era a exceção rápida |
| **L34** | Sprint 007 | duas coisas com o mesmo nome — `inner` e `left` lateral parecem a mesma troca e não são |
| **L36** | Sprint 008 | quando duas medidas parecem se contradizer, o elo é hipótese: a de que a largura das colunas custava era falsa |
| **L38** | Sprint 009 | o custo se mede por **diferença** e **constância**; `live/2` faz dois renders |
| **L39** | Sprint 009 | **é o risco central deste sprint**: junção nova no escopo compartilhado desloca bindings posicionais |
| **L44**, **L45** | Sprints 010 e 011 | a conferência acima, incluindo **onde** o fecho anterior está |

**A L30 cobrou dentro do próprio estudo, e vale registrar antes do sprint começar.** A primeira
versão da spec dizia que a tela custava 85 ms — medido numa pessoa. A pessoa mantenedora apontou uma
página de 2 s, e as oito maiores mostraram até 6,12 s. **Uma medida não descreve uma distribuição**,
e a que eu peguei era a exceção.

**A L36 cobrou em seguida**: a hipótese de que as 18 colunas multiplicavam o custo parecia explicar
tudo. Enxugar para nove dá **5 738 ms** contra 6 326 — quase nada. O elo entre duas medidas
verdadeiras era hipótese.

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteração**: **não atribuída** — mesma limitação desde o sprint 004: reconfigurar iterations do
ProjectV2 recria as existentes (L11), e já custou reatribuir 96 itens.

## User stories selecionadas

| # | User story | Priority | Estimate | Critérios |
|---|---|---|---|---|
| US1 | A página da pessoa abre sem varrer o tenant | P1 | 8 | 4 |
| US2 | Achar as issues de uma pessoa sem ler as designações de todas | P1 | 3 | 3 |
| US3 | A mesma correção vale para as outras telas | P2 | 5 | 3 |

**US3 é P2 e entra igual**: a causa é uma só, e a correção acontece na função que as 14 consultas
usam. Deixá-la fora significaria corrigir num lugar o que existe em catorze — e conferir catorze
mesmo assim.

## Tarefas

Detalhadas em [013/tasks.md](../../../specs/013-pagina-da-pessoa-mais-rapida/tasks.md).

| # | Tarefa | Atende | Estimate | Fase | Estado |
|---|---|---|---|---|---|
| T001 | Contar os empates que existem hoje | US1 | 1 | F1 | **feita** — zero, e `inserted_at` é de microssegundo |
| T002 | Fixar a vigência e o desempate em teste | US1 | 3 | F1 | a fazer |
| T003 | Registrar o retrato de cada tela afetada | US3 | 3 | F1 | a fazer |
| T004 | Resolver a promoção vigente por issue exibida | US1 | 8 | F2 | a fazer |
| T005 | Indexar a designação pela pessoa | US2 | 2 | F2 | a fazer |
| T006 | Unificar a segunda definição de promoção vigente | US3 | 3 | F2 | a fazer |
| T007 | Comparar cada tela com o retrato | US3 | 3 | F3 | a fazer |
| T008 | Fixar as contagens que o axioma produz | US3 | 2 | F3 | a fazer |
| T009 | Medir as três telas, antes e depois | US1 | 3 | F4 | a fazer |
| T010 | Provar que o custo parou de crescer com o histórico | US1 | 3 | F4 | a fazer |

**Total: 31 de complexity, dez tarefas.** Uma migração, de índice. Nenhuma tela alterada — e isso é
requisito, não efeito colateral.

## O que a análise mudou, antes do código

| # | Achado | Correção |
|---|---|---|
| **A1** | **oito das catorze chamadas são `inner`**, e `inner` exclui issue sem promoção. Trocar por `left lateral` faria a tela **ganhar linhas** que ela não tem, sem nada falhar | T004 separa `inner_lateral_join` de `left_lateral_join`, e o teste monta a issue sem promoção |
| **A2** | **`parent_as` exige binding nomeado**, e junção nova no escopo compartilhado desloca os posicionais — é a **L39**, que já trocou promoção por designação uma vez | T004 proíbe binding posicional nos `select` afetados |
| **A3** | o teste de `EXPLAIN` **reprovaria com o código certo**: no banco de teste as tabelas têm dezenas de linhas, e o Postgres varre de propósito | T005 assere o índice em `pg_indexes`; a prova do plano é no dado real |
| **A4** | T010 media **relógio dentro da suíte** — é a L22 | passou a medir **linhas lidas** |
| **A5** | o retrato em HTML cru **nunca** daria `diff` vazio: `csrf_token` e marcas do LiveView mudam a cada render | T003 grava o texto das células, e declara o que foi removido |

**E o estudo tinha achado dois antes disso, os dois por medir**: paginar não resolve (`LIMIT 5` custa
6 300 ms e `LIMIT 100` custa 6 648), e enxugar a projeção não resolve (5 738 ms).

## Fora do escopo deste sprint

| Fora | Por quê |
|---|---|
| reduzir, arquivar ou apagar o histórico de promoções | o histórico é proveniência — princípio III, FR-005 |
| cache de qualquer espécie | com a consulta corrigida são 3 ms; cache esconderia o custo e a primeira visita continuaria pagando |
| paginar de 100 em 100 | medido: a varredura acontece **antes** do limite |
| mudar qualquer coisa na aparência | FR-008 — se a tela mudar, é defeito |
| `/syncs` e o erro da chave efêmera | é ambiente, não código |

## Riscos e dependências

| Risco | Mitigação |
|---|---|
| **a tela ganhar linhas** ao trocar `inner` por `left` | T004 separa as variantes; o teste monta issue sem promoção e exige que ela **não** apareça |
| **binding posicional deslocado** — a L39 | nenhum `select` afetado fica posicional; T007 compara o conteúdo |
| a resposta mudar em alguma das 14 consultas | T003 grava o antes, T007 exige `diff` vazio, T008 fixa 520 e 293 |
| medir errado e declarar vitória | T009 usa o mesmo método dos dois lados, cinco medidas, e reporta constância junto |
| o índice pesar na escrita | a coleta roda `replace_assignees/3` 4 529 vezes; medir antes e depois |
| `LATERAL` perder em página muito grande | medido até `LIMIT 100`: 3,0 ms. Acima disso, o limiar está declarado no plano |

## Definition of Done do sprint

- [ ] `mix gates` verde por **código de saída**
- [ ] `diff` vazio em todos os retratos — a F3 inteira
- [ ] as dez tarefas encerradas ou repriorizadas com justificativa
- [ ] PR com revisão pedida à equipe `the-band` e item no projeto
- [ ] `aceitacao.md` avaliando os 10 FR e os 9 SC um a um
- [ ] `sprint-review.md` escrito **neste** sprint — L44
- [ ] `licoes-aprendidas.md` atualizado
- [ ] **e a palavra de fechamento da issue em inglês** — L48
