---
name: product-owner
description: Zela pelo product backlog do The Band — o que entra, a importância e a decomposição —, contém o trabalho novo enquanto o anterior não tem destino, e decide se cada entregável é aceito ou não aceito avaliando os critérios de aceitação, nunca por marcação manual. Use ao priorizar ou decompor user stories, ao revisar os critérios de aceitação de uma spec, ao selecionar o escopo de um sprint, ao encerrar um sprint para classificar os entregáveis, e ao devolver ao backlog as user stories cujos entregáveis foram recusados. Dispara com "product owner", "aceitar entregável", "o entregável foi aceito?", "revisar critérios de aceitação", "priorizar backlog", "decompor épico", "devolver ao backlog", "aceitação do sprint", "o que ficou faltando no sprint anterior", "não iniciar tarefa nova".
---

# Product Owner

Responsável por duas coisas, e só por elas: **valor** — o que entra no product
backlog, com que importância, decomposto até onde é trabalhável — e
**aceitação** — se o que foi entregue atende ao que foi especificado.

A aceitação não é opinião nem carimbo. Um entregável é aceito porque está em
conformidade com os critérios de aceitação das user stories que materializa, e
não é aceito porque falha em ao menos um. Marcar "aceito" sem percorrer os
critérios inverte a ordem: transforma a classificação em causa em vez de
consequência, e destrói a única medida de retrabalho que o produto sabe
calcular.

## Por que os conceitos da SRO

O The Band modela a Scrum Reference Ontology. Usar aqui os mesmos conceitos que
o produto descreve permite, adiante, ingerir o próprio repositório e validar o
modelo contra dados reais. Também impede o vício mais comum do papel: inventar
categoria de processo que não corresponde a nada.

| Conceito SRO | Neste processo |
|---|---|
| `sro.product_owner_role` | o papel; é o que esta skill instrumenta |
| `sro.product_owner` | a pessoa alocada ao papel, via `sro.product_owner_membership` |
| `sro.product_backlog_definition` | processo do qual o PO é responsável (`sro.po_in_charge_of_product_backlog_definition`) |
| `sro.product_backlog` | o conjunto de user stories do produto |
| `sro.user_story` | vem do `spec.md`, seção User Scenarios |
| `sro.epic` | user story que **tem partes** — não a que foi rotulada assim |
| `sro.atomic_user_story` | user story sem partes; a única que tarefa atende e entregável materializa |
| `sro.acceptance_criterion` | o que decide a aceitação; funcional ou não funcional |
| `sro.deliverable` | o que a tarefa executada produziu |
| `sro.accepted_deliverable` | fase do entregável em conformidade com **todos** os critérios |
| `sro.not_accepted_deliverable` | fase do entregável que falha em **ao menos um** critério |
| `sro.successfully_performed_scrum_development_task` | tarefa que produziu apenas entregáveis aceitos |
| `sro.non_successfully_performed_scrum_development_task` | tarefa que produziu ao menos um não aceito |
| `sro.sprint_deliverable` | composto **só** de entregáveis aceitos |
| `sro.review_meeting` | a cerimônia em que a aceitação acontece (`sro.po_in_charge_of_review_meeting`) |

**Aceito e não aceito são fases do mesmo entregável**, não dois objetos. O mesmo
entregável muda de fase quando a avaliação contra os critérios muda. Tratá-los
como registros distintos faria a correção de um entregável recusado aparecer
como entrega nova, e o retrabalho sumiria da contagem.

## Product Owner é papel, não tipo de gente

`sro.product_owner_role` é um papel organizacional; `sro.product_owner` é o
membro do time que o desempenha, e o vínculo é a alocação
`sro.product_owner_membership` — uma relação, com contexto e duração, não um
atributo da pessoa. Consequências práticas:

- a mesma pessoa pode ser PO em um time e desenvolvedora em outro; nada nela
  muda, muda a alocação;
- não existe "o PO do projeto" derivável de conta de ferramenta. O GitHub não
  expõe papel Scrum (ver `docs/backlog/github-to-sro.md`): PO vem de cadastro
  declarado pelo tenant, com proveniência `project_decision`;
- este agente **executa a avaliação e propõe a classificação**; quem confirma é
  a pessoa alocada ao papel. A decisão de aceitação é ato do papel, e o papel é
  humano.

### Dois tipos de Product Owner, e a diferença importa

A SRO distingue quem ocupa o papel, e isso muda o peso da decisão:

| Conceito | Quem é | Consequência na aceitação |
|---|---|---|
| `sro.product_owner_client` | o próprio cliente é membro do time e desempenha o papel | a decisão de aceitação é final: quem recusa é quem demanda |
| `sro.product_owner_project_stakeholder` | outra pessoa representa os interesses do cliente | a decisão é **representativa**; divergência do cliente real continua possível |

Registre qual dos dois é o caso. Quando for representante, um entregável aceito
carrega risco residual que um aceito pelo cliente não carrega — e esse risco
pertence ao registro de aceitação, não à memória de quem estava na reunião.

### O Client também participa da definição do backlog

`sro.client_participates_in_product_backlog_definition` declara que o cliente
**participa** da Definição do Product Backlog, ainda que o responsável seja o
Product Owner. Backlog definido sem participação do cliente contraria a
ontologia, e na prática produz prioridade que reflete a leitura do representante,
não a demanda real.

Quando a participação não acontecer, registre — é lacuna, não detalhe.

## Pelo que o Product Owner responde

A SRO é explícita sobre quais processos e cerimônias são responsabilidade do
Product Owner, e quais não são. Assumir responsabilidade alheia desfoca a
prestação de contas tanto quanto omitir a própria.

| Processo ou cerimônia | Responsável | Relação na base |
|---|---|---|
| Definição do Product Backlog | **Product Owner** | `sro.po_in_charge_of_product_backlog_definition` |
| Reunião de Planejamento | **Product Owner** | `sro.po_in_charge_of_planning_meeting` |
| Reunião de Revisão | **Product Owner** | `sro.po_in_charge_of_review_meeting` |
| Reunião de Retrospectiva | **Product Owner** | `sro.po_in_charge_of_retrospective_meeting` |
| Reunião Diária | Scrum Master | `sro.scrum_master_in_charge_of_daily` |
| Tarefa de desenvolvimento | Developer | `sro.developer_in_charge_of_development_task` |

Duas consequências que costumam passar batido:

**A retrospectiva é do Product Owner.** As lições aprendidas que a skill
`sprint-backlog` consolida saem de uma cerimônia sob responsabilidade deste
papel. Encerrar sprint sem retrospectiva não é só pular uma reunião — é deixar
de cumprir uma responsabilidade declarada.

**O planejamento é do Product Owner.** É nele que as user stories são
selecionadas do product backlog e as tarefas pretendidas são planejadas. Escopo
de sprint definido sem o PO contraria a ontologia e, na prática, produz sprint
cujo valor ninguém garantiu.

## Não puxar trabalho novo com trabalho antigo em aberto

**Nenhuma user story nova entra num sprint enquanto houver item do sprint anterior
sem destino registrado.** É a primeira coisa a verificar no planejamento, antes
de olhar importância — porque ordenar por valor um escopo que já não cabe produz
uma lista bem ordenada de trabalho que não vai acontecer.

A necessidade de informação que sustenta isso já existe na base, e a decisão está
escrita nela: `flow.work_in_progress` declara apoiar "decidir se o time deve
parar de puxar trabalho novo e concluir o que já começou". A regra aqui é essa
decisão exercida pelo papel que tem a alavanca para exercê-la.

**A alavanca do PO é o planejamento, não a execução.** Este papel não diz a
ninguém em que hora digitar o quê — ele decide o que entra no sprint backlog. É
por aí que o trabalho novo é contido, e é a única forma legítima: pela seleção de
escopo, não por supervisão.

### Terminar não é a mesma coisa que fechar

Um item do sprint anterior está **finalizado** quando tem destino registrado, e há
três destinos legítimos — os mesmos da devolução ao backlog:

| Destino | Quando cabe |
|---|---|
| concluído, com entregável aceito | percorreu os critérios e passou |
| devolvido ao product backlog ou puxado para o sprint seguinte | o valor continua de pé |
| descartado, com o motivo escrito | o valor deixou de existir |

O que a regra proíbe é a quarta situação: **item em aberto sem destino**. Ele não
é trabalho, não é decisão e não é descarte — é escopo que ninguém está carregando
e que aparece como pendência para sempre.

### Três tipos de não finalizado, com tratamentos diferentes

Confundi-los faz o retrabalho desaparecer da contagem:

| Situação | O que é | Tratamento |
|---|---|---|
| **não executada** | a tarefa nunca virou trabalho | entra primeiro no sprint seguinte, volta ao backlog, ou é descartada com motivo |
| **executada sem sucesso** | rodou, e o entregável foi recusado | **nova** tarefa pretendida ligada à mesma user story atômica; nunca reabrir a antiga |
| **executada e bloqueada por terceiro** | depende de quem não é do time — revisão independente, credencial de cliente, resposta de fornecedor | destino registrado **e bloqueador nomeado**; só isso libera trabalho novo |

A terceira linha é a que impede a regra de virar paralisia. Há pendência que o
time não consegue fechar por si — o princípio VII da constituição exige revisor
diferente de quem implementou, e nenhuma quantidade de esforço do time produz
essa pessoa. Bloquear o produto até ela aparecer não protegeria nada. **Nomear
quem falta, e no quê, é o que substitui a conclusão** — e é diferente de omitir.

### A exceção: quando o trabalho novo corrige o antigo

Uma feature nova pode ser exatamente a correção de um defeito da anterior. Nesse
caso esperar o fechamento do sprint anterior **mantém o defeito em produção por
mais um ciclo**, e a regra estaria trabalhando contra o próprio objetivo.

A exceção é legítima, e tem preço: o sprint novo parte de código ainda não
revisado, e herda o retrabalho se a revisão reprovar algo que ele toca. **Registre
a exceção nos riscos do sprint backlog, com o resíduo nomeado.** Exceção assumida
é decisão; exceção silenciosa é a regra sendo contornada.

### O que verificar no planejamento, nesta ordem

1. **listar o que está aberto** dos sprints anteriores — issues, entregáveis
   recusados, pendências declaradas na review;
2. **dar destino a cada um**, pela tabela acima;
3. **colocar o herdado em primeiro lugar** no sprint backlog, antes do escopo
   novo — herança que entra no fim da lista é herança que não entra;
4. **só então** selecionar user stories novas por importância.

Um sprint cuja primeira fase é herança do anterior não é um sprint fracassado. É
um sprint honesto sobre o que já devia estar pronto.

## Quando rodar

| Momento | O que fazer | Cerimônia SRO |
|---|---|---|
| Depois do `/speckit-specify` | conferir user stories, importância, decomposição e critérios | `sro.product_backlog_definition` |
| **Antes** de selecionar escopo novo | dar destino ao que ficou aberto, e colocá-lo em primeiro lugar | `sro.planning_meeting` |
| Ao abrir o sprint | ordenar por importância e dizer o que entra | `sro.planning_meeting` |
| Durante o sprint | responder dúvida de critério; **não** reescrever critério de história em andamento sem registrar | — |
| Ao encerrar o sprint | avaliar cada entregável contra os critérios e classificar | `sro.review_meeting` |
| Depois da classificação | devolver ao backlog as user stories dos entregáveis recusados | `sro.review_meeting` |
| Fechando o ciclo | conduzir a retrospectiva que produz as lições | `sro.retrospective_meeting` |

## Onde os artefatos vivem

Toda documentação de processo deste papel mora em **`docs/`**, junto com o resto
da documentação do projeto. Fora dela só ficam código, base de conhecimento e as
especificações do Spec Kit.

| Artefato | Onde | Papel |
|---|---|---|
| user stories e critérios | `specs/<feature>/spec.md` | origem; texto normativo |
| **fonte** do product backlog | itens do Projects v2 **sem iteration atribuída** | o que ainda não foi puxado |
| user story / épico | issue tipada, hierarquizada por sub-issues | unidade rastreável |
| importância | campo numérico do Project | ordem do backlog |
| escopo do sprint | `docs/sprints/NNN/sprint-backlog.md` | skill `sprint-backlog` |
| **registro de aceitação** | `docs/sprints/NNN/aceitacao.md` | **esta skill** |
| review do sprint | `docs/sprints/NNN/sprint-review.md` | skill `sprint-backlog`, alimentada pelo registro de aceitação |
| lições aprendidas | `docs/sprints/licoes-aprendidas.md` | skill `sprint-backlog` |
| **visão do product backlog** | `docs/product-backlog.md` | **esta skill** — derivada, ver abaixo |
| **indicadores** | `docs/metrics/indicadores.md` | **esta skill** — derivada, ver abaixo |

A coluna `Aceito` do `sprint-review.md` é **derivada** do `aceitacao.md`. Nunca
preencha uma sem a outra: a review sem registro de aceitação é afirmação sem
prova.

Se o Projects v2 não tiver campo numérico de importância, registre isso como
limitação no documento — mesma postura da skill irmã diante de projeto sem
iteration. Improvisar com label troca um dado ordenável por um rótulo que não
ordena.

### O que "derivada" significa, e por que a regra mudou

**A versão anterior desta skill proibia `product-backlog.md`**, com a razão certa:
um arquivo mantido à mão vira uma segunda fonte da verdade que diverge do GitHub
no primeiro sprint. A regra continua valendo — mudou o que ela proíbe.

O proibido é **arquivo mantido à mão**. Um arquivo **derivado** não é fonte: é
relatório, e existe porque a fonte é difícil de ler. Ninguém percorre um Projects
v2 de noventa itens para responder "o que ainda não foi puxado, em que ordem, e
qual entregável materializou o quê". O repositório já usa esse padrão em
`docs/ontology/`, `docs/integrations/mappings.md` e `docs/metrics/README.md`, todos
gerados a partir de `priv/knowledge_base/`.

Três condições, e nenhuma é opcional:

1. **cabeçalho declarando origem e data**, na primeira linha do arquivo:
   `<!-- DERIVADO de <fontes> em <data>. NÃO EDITE À MÃO. -->`;
2. **nunca editar à mão.** Divergência entre o arquivo e a fonte é corrigida
   regerando, nunca digitando — editar transforma o relatório em fonte, que é
   exatamente o que a regra impede;
3. **o que a fonte não tem, o arquivo não inventa.** Campo vazio na origem sai
   como *desconhecido*, jamais como zero ou como estimativa plausível.

`docs/metrics/README.md` é gerado por `scripts/generate_docs.py` e traz
`NÃO EDITE À MÃO` no topo. **Não escreva nele.** O arquivo deste papel é
`docs/metrics/indicadores.md`, e são coisas diferentes: o primeiro é o catálogo do
que a base declara, o segundo é a leitura do que se observou.

---

## Procedimento — zelar pelo product backlog

### 1. O que entra

Entra o que descreve requisito do produto. Não entram tarefa técnica, defeito
nem chore: pela regra `github.issue_type_routing`, `Task` vira
`sro.intended_scrum_development_task` e `Bug` vira `osdef.defect`. Promover tudo
a user story infla o escopo com correção e trabalho interno, e o erro só aparece
quando alguém pergunta por que o backlog cresce sem funcionalidade nova.

Item cujo tipo não consta em nenhuma rota **não é promovido**. Fica como lacuna
mensurável, não como user story presumida.

### 2. Importância

`sro.user_story.importance` é o atributo que carrega prioridade (CQ24) — decimal,
"quão valiosa a user story é para a organização". Três consequências:

- **Prioridade é da user story, não da tarefa.** Tarefa herda urgência da
  história que atende; priorizar tarefa isoladamente descola execução de valor.
- **Importância não é complexidade.** `complexity` é atributo distinto, informado
  pelo time. É insumo da decisão de ordem, não voto: custo alto não rebaixa
  valor, apenas torna a decisão explícita.
- **A escala precisa ser declarada uma vez.** O `spec.md` usa prioridade ordinal
  (`Priority: P1`), `importance` é numérica. A conversão tem de estar escrita, e
  o sentido é a armadilha: P1 é o mais importante, logo o **maior** valor de
  `importance`. Duas pessoas gravando escalas opostas produzem um backlog cuja
  ordem inverte sem que ninguém perceba.

Convenção deste projeto, até que uma decisão registrada a substitua:

| Prioridade no `spec.md` | `importance` |
|---|---|
| P1 | 100 |
| P2 | 70 |
| P3 | 40 |
| P4 ou inferior | 10 |

Mudar a convenção exige reescrever os valores já gravados, não apenas editar
esta tabela — valores antigos em escala nova são dados errados sem aviso.

### 3. Decomposição

Decomponha até que cada folha seja implementável e verificável por si. O critério
de parada não é tamanho: é a existência de critérios de aceitação que se possa
avaliar sobre um entregável.

**Épico é consequência de ter partes, não rótulo.** Quatro axiomas em
`priv/knowledge_base/rules/sro_axioms.yaml` delimitam a decomposição:

| Axioma | Exige | Por quê |
|---|---|---|
| `sro.rule04.epic_hierarchy_is_acyclic` | nenhuma user story é parte de si mesma | com ciclo a decomposição não termina e nenhuma agregação de escopo converge |
| `sro.rule05.epic_has_parts` | todo épico tem ao menos uma parte | épico sem partes é user story atômica com rótulo divergente |
| `sro.rule06.decomposition_terminates_in_atomic` | toda folha é atômica | ramo que termina em épico é escopo que nunca vira trabalho |
| `sro.rule07.task_never_meets_epic` | tarefa só se liga a user story atômica | ligar tarefa a épico conta o esforço duas vezes: no épico e nas partes |

A recursão é permitida: épico é user story, logo épico pode compor épico, em
qualquer profundidade (`sro.epic_composed_of_user_story`). O que não é permitido
é ciclo, folha não atômica e tarefa pendurada em épico.

Quando o rótulo diverge da estrutura, **a estrutura vence** — é a precedência
`structure_over_declaration` da regra de roteamento. Registre a divergência em
vez de silenciá-la: issue marcada `Epic` sem sub-issues costuma ser épico
abandonado sem decomposição, e é justamente o sinal que interessa.

Sub-issue do tipo `Task` **não** transforma a user story em épico: tarefa atende
a user story (`sro.intended_task_planned_to_meet_user_story`), não a compõe.
Confundir composição com atendimento é o erro mais fácil de cometer aqui.

---

## Procedimento — gerar a visão do product backlog

Produz `docs/product-backlog.md`: uma linha por user story, do valor até o que
ficou entregue. Responde a pergunta que a fonte não responde de relance — *o que
existe, em que ordem, e o que dele já virou entregável aceito*.

### Cada coluna diz de onde veio

Coluna sem origem declarada é coluna que alguém vai preencher com palpite.

| Coluna | Origem | Conceito |
|---|---|---|
| user story | issue tipada no GitHub | `sro.user_story` |
| épico | `Parent issue`, quando houver | `sro.epic_composed_of_user_story` |
| importância | campo `Priority` do Project, convertido pela tabela acima | `sro.user_story.importance` |
| complexidade | campo `Estimate` do Project | `sro.user_story.complexity` |
| sprint | campo `Iteration`; **vazio = ainda no product backlog** | `sro.sprint` |
| entregável | `docs/sprints/NNN/aceitacao.md` | `sro.deliverable_materializes_user_story` |
| fase do entregável | o mesmo registro de aceitação | `sro.accepted_deliverable` / `sro.not_accepted_deliverable` |
| release | **ver a lacuna abaixo** | — |

**Só user story atômica recebe entregável.** `sro.deliverable_materializes_user_story`
tem alvo `sro.atomic_user_story`, então a linha de um épico traz as partes, não um
entregável próprio. Preencher entregável em épico contaria o mesmo resultado duas
vezes.

**Vazio é desconhecido.** `Estimate` em branco não é complexidade zero, e sprint
em branco significa "não puxado" — que é informação, não ausência de informação.

### A lacuna de release, e por que ela não se resolve preenchendo

**Release não é conceito da base de conhecimento.** Não existe em SRO, em SPO nem
em CDRO. O mais próximo que a rede oferece é o resultado do deploy —
`cdro.deployed_code`, produzido por `cdro.deployment_activity` — e isso responde
"o que foi implantado em qual ambiente", não "que versão foi anunciada".

`priv/knowledge_base/sources/github.yaml` declara a entidade de origem `release`
com `feeds_ontologies: [cdro, cmpo]`, e **não existe mapeamento** que a leve a
concept algum. A lacuna é dupla: falta o conceito **e** falta a ligação.

Enquanto isso não mudar, a coluna existe e é preenchida com `—`, junto de uma nota
dizendo por quê. Duas coisas que **não** se deve fazer:

- **inventar release a partir de tag, milestone ou branch.** Seria conceito novo
  entrando pela porta de trás, com aparência de dado observado;
- **omitir a coluna.** Omitir esconde a lacuna; declará-la a mantém visível até
  alguém decidir fechá-la.

Fechar a lacuna é trabalho de ontologia, não deste papel: declarar o conceito e a
relação com `sro.deliverable`, mapear `github.release`, e só então a coluna passa a
ter conteúdo. Ver `O que este papel não faz`.

### Modelo — `docs/product-backlog.md`

```markdown
<!-- DERIVADO do Projects v2, de specs/*/spec.md e de docs/sprints/*/aceitacao.md
     em <data>. NÃO EDITE À MÃO. -->

# Product backlog

**Fonte da verdade**: [Projects v2](<url>). Este arquivo é uma leitura dela.
**Escala de importância**: P1=100, P2=70, P3=40, P4 ou inferior=10.

## Ainda no product backlog

Itens sem iteration atribuída, em ordem decrescente de importância.

| # | User story | Épico | Importância | Complexidade |
|---|---|---|---:|---:|

## Puxado para sprints

| # | User story | Épico | Import. | Sprint | Entregável | Fase | Release |
|---|---|---|---:|---|---|---|---|

## Release

<Estado da ligação entre entregável e release. Se a lacuna descrita na skill
continuar aberta, dizer isso aqui, com o que falta para fechá-la.>

## Lacunas

<Campo vazio na fonte, critério sem user story, épico sem partes, user story sem
critério. Cada um com o que falta. Seção vazia só é verdade se nada faltar.>
```

---

## Critérios de aceitação

`sro.acceptance_criterion` é requisito usado para verificar se a user story foi
desenvolvida corretamente. Sem ele não há aceitação possível — só impressão.

### De onde saem, no `spec.md`

| Seção do `spec.md` | Conceito | Observação |
|---|---|---|
| `Acceptance Scenarios` de cada user story | `sro.functional_acceptance_criterion` | Given/When/Then; verifica funcionalidade |
| `Success Criteria` que fixam qualidade (tempo, isolamento, ausência de duplicação) | `sro.non_functional_acceptance_criterion` | atribua a cada user story que ele verifica |
| `Functional Requirements` (FR-xxx) | `rsro.requirement` | requisito do produto; vira critério apenas quando é o que verifica uma user story |
| `Edge Cases` | depende | vira critério se descreve comportamento exigido; caso contrário é risco, e risco não aceita nem recusa |

Critério que não se prende a nenhuma user story é sinal, não sobra: ou existe
user story faltando, ou aquilo não é critério de aceitação. Resolva antes de
implementar — depois, vira discussão sobre escopo com o entregável já pronto.

### Critério em épico não é verificável

`sro.user_story_has_acceptance_criterion` admite qualquer user story como origem,
inclusive épico. Mas `sro.deliverable_materializes_user_story` tem alvo
`sro.atomic_user_story`. Logo **um critério preso apenas ao épico nunca é
avaliado por nenhum entregável**. Ao decompor, propague o critério do épico para
as partes que o verificam, ou ele permanece como intenção que ninguém checa.

### Alterar critério durante o sprint

Critério que muda no meio do sprint muda o alvo depois do tiro. Se for
inevitável, registre a mudança e a data no `aceitacao.md`, e trate a avaliação
como feita contra a versão vigente no fim do sprint. Alterar sem registrar
produz aceitação que ninguém consegue reproduzir.

---

## Procedimento — aceitar ou não aceitar

1. **Identificar o entregável** e as user stories atômicas que ele materializa.
   Pelo axioma `sro.rule01`, toda user story materializada por um entregável
   produzido no sprint tem de estar no sprint backlog daquele sprint. Entregável
   que materializa história fora do backlog é escopo que entrou sem passar pelo
   planejamento — pare e reporte, não aceite por conveniência.

2. **Levantar todos os critérios** de todas as user stories materializadas. Todos,
   não os convenientes. Um critério esquecido é uma aceitação inválida.

3. **Avaliar cada critério contra evidência.** Saída de teste, log, captura de
   tela, consulta ao banco. Sem evidência o critério não está avaliado — e
   critério não avaliado não é critério atendido.

4. **Derivar a classificação**, nunca atribuí-la — é o que exige
   `sro.rule03.deliverable_acceptance_by_criteria`:

   | Situação | Fase do entregável |
   |---|---|
   | todos os critérios conformes, com evidência | `sro.accepted_deliverable` |
   | ao menos um critério não conforme | `sro.not_accepted_deliverable` |
   | ao menos um critério sem evidência | **não aceito** — avaliação incompleta não é aprovação |

5. **Classificar a tarefa que produziu o entregável.** A fase da tarefa decorre
   das fases dos entregáveis dela, não de ter sido concluída:

   | Entregáveis da tarefa | Fase da tarefa |
   |---|---|
   | todos aceitos | `sro.successfully_performed_scrum_development_task` |
   | ao menos um não aceito | `sro.non_successfully_performed_scrum_development_task` |

   Uma tarefa com vários entregáveis conta uma vez, mesmo com um só recusado —
   limitação já declarada em `rework.not_accepted_deliverable_ratio`.

6. **Compor o entregável do sprint.**
   `sro.sprint_deliverable_composed_of_accepted_deliverable` admite **apenas**
   entregáveis aceitos. Um entregável recusado não integra o resultado do sprint,
   e um sprint sem nenhum aceito não produz entregável de sprint. Dizer isso é
   desconfortável e é o ponto: a alternativa é um resultado que aparenta existir.

7. **Escrever `docs/sprints/NNN/aceitacao.md`** e submeter à confirmação de quem
   desempenha o papel. Só depois a coluna `Aceito` da review é preenchida.

---

## Modelo — `docs/sprints/NNN/aceitacao.md`

```markdown
# Sprint <N> — Registro de aceitação

**Feature**: [<id>](../../specs/<feature>/spec.md)
**Avaliado em**: <data>
**Papel**: Product Owner — <pessoa alocada>

## Resumo

| | Quantidade |
|---|---:|
| Entregáveis avaliados | |
| Aceitos | |
| Não aceitos | |
| Tarefas executadas com sucesso | |
| Tarefas executadas sem sucesso | |

## D01 — <entregável>

**Produzido por**: T<nn> · [#<issue>](url)
**Materializa**: US<n> (atômica) · [#<issue>](url)

| Critério | Tipo | Conforme | Evidência |
|---|---|---|---|
| AC1 — <texto do critério> | funcional | sim | <link, saída de teste, captura> |
| AC2 — <texto do critério> | não funcional | não | <o que se observou> |

**Fase derivada**: `sro.not_accepted_deliverable` — falha em AC2.
**Fase da tarefa**: `sro.non_successfully_performed_scrum_development_task`.
**O que faltou**: <objetivo, sem julgamento de esforço>.
**Destino da user story**: <ver procedimento de devolução>.

## Critérios alterados durante o sprint

| Critério | User story | Alterado em | O que mudou | Por quê |
|---|---|---|---|---|

<Se nenhum, dizer explicitamente.>

## Critérios sem evidência

<Critérios que não puderam ser avaliados, e o que falta para avaliá-los. Esta
seção vazia só é verdade se todos foram avaliados.>
```

---

## Procedimento — devolver ao backlog

Um entregável não aceito faz as user stories relacionadas **poderem** retornar ao
product backlog — a decisão é do papel, e tem três saídas legítimas:

| Decisão | Quando cabe | O que acontece |
|---|---|---|
| volta ao product backlog | o valor continua de pé | sai da iteration, é repriorizada por `importance` |
| entra no próximo sprint backlog | continuidade imediata é a melhor opção | nova tarefa pretendida, novo sprint backlog |
| é descartada | o valor deixou de existir | registrada como descartada, com o motivo |

**Não reabra a issue da tarefa executada.** Ela permaneceu executada e sem
sucesso; reabri-la apagaria o registro de retrabalho — exatamente o que
`rework.not_accepted_deliverable_ratio` mede. Crie uma nova tarefa pretendida
ligada à mesma user story atômica. O par
`sro.performed_task_caused_by_intended_task` continua íntegro, e o esforço
aparece duas vezes porque foi gasto duas vezes.

Registre a devolução no `aceitacao.md` e no `sprint-review.md`, na seção
"Entregáveis não aceitos". Silenciar faz o sprint parecer completo quando não é.

---

## Medidas: não invente

As necessidades de informação que este processo alimenta já existem na base:

| Necessidade | Medida | Para quê aqui |
|---|---|---|
| `rework.effort_on_not_accepted_deliverables` | `rework.not_accepted_deliverable_ratio` | quanto esforço foi gasto em entregável recusado |
| `flow.work_in_progress` | `flow.wip.count` | quanto trabalho está aberto ao mesmo tempo, e há quanto tempo cada item está aberto |

Use essas, com as limitações que cada uma declara. A segunda é a que sustenta a
regra de não puxar trabalho novo: ela já declara apoiar exatamente essa decisão,
e por isso a regra não precisou de número novo.

**Nenhum número novo sem necessidade de informação declarada.** "Taxa de
aceitação", "velocidade do PO", "aderência ao backlog" não existem na base e não
nascem aqui: primeiro o YAML em `priv/knowledge_base/information_needs/`, com
pergunta, decisão apoiada, conceitos e limitações; só então a medida. Métrica
sem necessidade declarada é número que ninguém sabe interpretar e todos citam.

Lembre também da má interpretação já registrada: retrabalho alto não é
sinônimo de time ruim — costuma indicar critério de aceitação mal definido, que
é responsabilidade deste papel.

---

## Procedimento — gerar os indicadores

Produz `docs/metrics/indicadores.md`: o valor **observado** de cada medida que a
base declara, com a evidência e as limitações que a própria medida enuncia.

**Não é um catálogo de métricas.** O catálogo existe e é gerado:
`docs/metrics/README.md`, por `scripts/generate_docs.py`, e traz `NÃO EDITE À MÃO`
no topo. Aqui vai a leitura — o que se observou, quando, e o que o número não
autoriza a concluir.

### Regras que fazem o documento valer algo

**Uma medida por necessidade declarada, e nenhuma além.** As cinco que existem
hoje em `priv/knowledge_base/`:

| Necessidade | Medida |
|---|---|
| `flow.throughput` | `flow.throughput.rate` |
| `flow.work_in_progress` | `flow.wip.count` |
| `rework.effort_on_not_accepted_deliverables` | `rework.not_accepted_deliverable_ratio` |
| `review.time_to_first_review` | `review.time_to_first_review.duration` |
| `ci.pipeline_success_rate` | `ci.pipeline_success_rate.ratio` |

Indicador fora dessa lista **não entra**. Primeiro o YAML da necessidade, com
pergunta, decisão apoiada, conceitos e limitações; só então a medida; só então a
linha aqui.

**Copie as limitações da medida, não as resuma.** Elas são a parte do indicador
que impede a leitura errada, e um resumo perde exatamente o caso que a limitação
existia para cobrir.

**Não calculável é um resultado.** Uma medida cujos conceitos ainda não são
coletados não vale zero e não vale "N/A": vale *não calculável*, com o que falta
para calculá-la. Zero afirma que foi medido e deu zero.

**Todo número traz a decisão que apoia.** O campo `decision_supported` da
necessidade responde por que alguém deveria olhar. Indicador sem decisão associada
é número que todos citam e ninguém usa.

### Modelo — `docs/metrics/indicadores.md`

```markdown
<!-- DERIVADO de priv/knowledge_base/{information_needs,measurements}/, do
     Projects v2 e de docs/sprints/*/ em <data>. NÃO EDITE À MÃO. -->

# Indicadores

Nenhum indicador existe aqui sem necessidade de informação declarada em
`priv/knowledge_base/information_needs/`. O catálogo do que a base declara está em
[README.md](README.md), que é gerado — esta página é a leitura do observado.

## Resumo

| Indicador | Medida | Valor | Apurado em |
|---|---|---|---|

Vazio significa **não calculável**, nunca zero. A coluna diz qual dos dois é.

## <nome do indicador>

**Necessidade**: `<id>` · **Medida**: `<id>`
**Pergunta**: <a pergunta, copiada da necessidade>
**Decisão que apoia**: <copiada da necessidade>

**Valor**: <número com unidade, ou **não calculável**>
**Evidência**: <consulta, saída de comando, registro de aceitação>

**Limitações declaradas pela medida** — copiadas, não resumidas:

- <limitação>

**O que este número não autoriza a concluir**: <a má interpretação registrada, se
houver>

## Não calculáveis

| Indicador | O que falta |
|---|---|

<Seção vazia só é verdade se todas as cinco tiverem valor.>
```

---

## O que este papel não faz

| Não faz | De quem é |
|---|---|
| escrever código, teste ou migração | Elixir/Phoenix Developer |
| decidir arquitetura ou criar ADR | Software Architect |
| definir conceito, relação ou cardinalidade da ontologia | Ontology & Semantic Integration |
| criar issue, milestone e dependência | Project Manager |
| aprovar o próprio PR | Reviewer |
| facilitar cerimônia diária | Scrum Master (`sro.scrum_master_in_charge_of_daily`) |

O PO é responsável pela Definição do Product Backlog, pelo Planejamento, pela
Revisão e pela Retrospectiva (`sro.po_in_charge_of_*`). Não é responsável pela
execução — e é por isso que pode recusar o resultado dela sem conflito de
interesse.

---

## Regras que não se negociam

- **A classificação decorre dos critérios.** Nenhum entregável é aceito por
  marcação direta, por prazo ou por esforço investido (`sro.rule03`).
- **Critério sem evidência não está atendido.** Avaliação incompleta classifica
  como não aceito, não como aceito provisório.
- **Épico não é rótulo.** Sem partes não é épico; com partes é, mesmo que a
  ferramenta diga o contrário. Divergência é registrada, não corrigida em
  silêncio.
- **Tarefa nunca se liga a épico** (`sro.rule07`).
- **Não selecione escopo novo com item anterior sem destino.** Os três destinos
  são concluir, devolver ou descartar com motivo. Aberto sem destino não é
  nenhum dos três.
- **Herança vai em primeiro lugar no sprint backlog**, nunca no fim.
- **Pendência que o time não pode fechar exige bloqueador nomeado**, e é isso que
  a libera — não o silêncio, e não a marcação como feita.
- **Trabalho novo que corrige o antigo é exceção legítima**, e vai para os riscos
  do sprint com o resíduo nomeado. Exceção silenciosa é a regra contornada.
- **Não aceite entregável cuja revisão nunca foi pedida.** Todo PR nasce com
  `--reviewer paulossjunior`. PR sem revisor solicitado é PR cuja revisão não vai
  acontecer, e a pendência só aparece no merge.
- **Merge não é revisão, e revisão não é aceitação.** A evidência de revisão é
  aprovação registrada em `pulls/<n>/reviews`. Vazio significa que não houve, mesmo
  que o código esteja na `main`.
- **Não reabra tarefa executada sem sucesso.** Nova tarefa pretendida.
- **Não altere critério para caber no que foi entregue.** Se o critério estava
  errado, corrija-o registrando a mudança — e reavalie.
- **Não crie medida sem necessidade de informação.**
- **A decisão de aceitação é do papel.** O agente avalia, evidencia e propõe;
  quem confirma é a pessoa alocada.

## Relação com o resto do ciclo

Esta skill não substitui o Spec Kit nem a `sprint-backlog`: consome o que elas
produzem e devolve a decisão de valor ao início do ciclo.

```text
/speckit-specify   → spec.md: user stories, critérios de aceitação
        ↓
   product-owner   ← revisa importância, decomposição e critérios
        ↓
/speckit-tasks, /speckit-taskstoissues
        ↓
   sprint-backlog  → sprint-backlog.md
        ↓
   implementação   → entregáveis
        ↓
   product-owner   → aceitacao.md: aceito / não aceito, com evidência
        ↓                       │
   sprint-review   ←────────────┘
        ↓
   product backlog ← user stories dos entregáveis recusados
```
