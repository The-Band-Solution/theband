# Pesquisa — Feature 006: detalhe da issue e decomposição navegável

Sete questões que a spec deixou para o plano. Cada uma com decisão, razão e o que foi
recusado.

**Nota honesta sobre a ordem.** Este documento foi escrito **depois** da implementação, a
pedido direto da pessoa mantenedora, e o princípio VI pede o contrário. As decisões aqui
não são retroprojeção: sete delas foram tomadas durante o código e três foram **mudadas
pelo teste**, o que está registrado em cada seção. A dívida de processo está declarada no
plano e na review, não silenciada.

---

## R1 — Como o corpo é coletado e renderizado

**Decisão**: pedir `bodyText` à origem, guardar cru, renderizar como **texto** com
`whitespace-pre-wrap`.

**Razão**: `body` traz o markdown cru e obrigaria a tela a decidir o que fazer com ele. As
duas saídas seriam ruins: renderizar como HTML abre injeção de conteúdo da origem
(SC-011), e mostrar o markdown cru como texto exibiria `**` e `<img src=...>` para quem lê.

`bodyText` é o texto que o GitHub já extraiu do markdown. Preserva o conteúdo — que é o que
a promoção por padrão de título usa como evidência — e não carrega marcação.

**O que se perde, e é aceitável**: formatação e links clicáveis dentro do corpo. Quem
precisa do markdown formatado clica em "ver na origem", que a tela oferece.

**Recusado**: renderizar markdown com uma biblioteca. Acrescentaria dependência,
superfície de injeção e a decisão de qual subconjunto permitir — três custos para um ganho
de leitura. O princípio VIII pede o problema concreto, e "ficaria mais bonito" não é um.

**Recusado**: sanitizar HTML no servidor. Mesma superfície, com a ilusão de estar resolvida.

---

## R2 — Onde autor, designados e rótulos vivem

**Decisão**: autor em **coluna** de `collected_issues`; designados e rótulos em **tabelas
próprias**.

**Razão**: é multiplicidade. Autor é exatamente um — coluna cabe. Designado é zero ou
muitos, e rótulo é zero ou muitos: uma coluna guardaria o primeiro e perderia o resto, e um
array perderia a ligação com a pessoa coletada.

É o mesmo raciocínio da ADR 0004 D5, que mantém papel organizacional fora de `eo_people`.

**A pessoa entra como referência, nunca como cópia.** `author_person_id` e
`issue_assignees.person_id` apontam para `eo_people`; o nome vem por
`EO.people_names/2`. É a regra da fronteira do princípio IX aplicada em leitura: `WorkItems`
guarda o id e **não** alcança a tabela de EO.

**`person_id` nulo é declaração.** Quando a pessoa designada não foi coletada — bot, conta
fora da organização, coleta de pessoas mais antiga —, o login fica e o vínculo fica
visivelmente ausente. Criar a pessoa a partir da issue produziria registro sem a
proveniência que a coleta de EO dá.

**Recusado**: array de strings para designados. Perderia a referência, e a tela não teria
como distinguir "pessoa coletada" de "login solto".

**Recusado**: criar `eo.person` a partir do designado. Ver acima.

---

## R3 — Substituir apaga, ou marca ausência?

**Decisão**: `replace_assignees/3` e `replace_labels/3` **apagam** o que a origem não traz
mais.

**Razão, e ela contraria a regra geral do projeto** — "ausência marca, nunca apaga". A regra
existe para **entidades observadas**: uma issue que desaparece da origem continua sendo um
fato histórico. Designação retirada é outro caso: é atributo do agora, e a pergunta que a
tela responde é *"quem está nisto"*, não *"quem já esteve"*.

O histórico não se perde: o payload bruto de cada coleta está preservado em `raw_payloads`
desde a feature 004, e reconstruir "quem estava designado em tal data" é possível a partir
dele.

**O custo, declarado**: uma pergunta sobre histórico de designação exige ler payload, não
consultar tabela. Se essa pergunta aparecer, a resposta é acrescentar marca de ausência
aqui — e este parágrafo é o critério de reversão.

**Recusado**: `no_longer_observed_at` em designado e rótulo. Obrigaria a tela a mostrar
ex-designados e ex-rótulos, ou a filtrá-los sempre — informação que ninguém pediu, com
filtro em todo lugar.

---

## R4 — Como composição e atendimento não se somam

**Decisão**: **duas funções**, `list_composition/2` e `list_attendance/2`, filtrando por
conceito promovido; e **nenhuma função** que devolva as duas juntas.

**Razão**: a separação tem de estar na **API**, não só na tela. Uma função
`list_children/2` que a tela dividisse depois deixaria a soma a um passo de distância —
qualquer nova tela, relatório ou medida chamaria a que já existe.

O contrato declara explicitamente a ausência de `count_children/2`, e o motivo.

**Uma terceira lista, e ela nasceu do desenho**: `list_unpromoted_parts/2`, as partes que a
plataforma não promoveu a nada. Sem ela, composição + atendimento seria menor que o que a
origem declara, e quem lê concluiria que a plataforma perdeu vínculos. Ela não perdeu: falta
regra de mapeamento, que é a feature 005.

**O que o teste mudou.** A primeira implementação mostrava, no painel lateral, "partes
declaradas: 39" — o `sub_issue_count` da origem, ao lado de 9 na composição e 30 no
atendimento. O `refute html =~ ">39<"` do SC-004 reprovou, e **com razão**: 39 é exatamente
a soma, e um leitor concluiria que as duas seções contam a mesma coisa duas vezes.

No lugar entrou o que a soma escondia: quando a origem declara mais partes do que a
plataforma tem, a tela avisa **quantas faltam** — lacuna de coleta, não de composição. No
caso normal não imprime nada.

**Recusado**: uma função com opção `:relation`. A soma continuaria a um argumento de
distância, e o padrão do projeto é impedir no tipo o que não deve acontecer — como
`mark_issues_no_longer_observed/3` faz com o escopo.

---

## R5 — O axioma `sro.rule07`: onde é verificado

**Decisão**: **uma função pura** em `TheBand.WorkItems.Axioms`, chamada pelos dois caminhos
de dados — uma issue no detalhe, o grafo inteiro no repositório.

**Razão**: é a lição de `classification/2` na sua segunda forma. Lá, o risco era a tela
derivar de um jeito e a consulta de outro; a resposta foi um caminho só. Aqui o risco é o
mesmo com duas telas: a do repositório avisaria sobre uma issue que o detalhe dela declara
correta.

A função é pura — recebe o conceito da issue e o do pai, devolve `:ok` ou
`{:violation, forma}`. O que muda entre as telas é **como os dados chegam**: `fetch_parent/2`
para uma, uma consulta com `left_join` para o lote.

**O `left_join` é o que torna "sem pai" um valor** em vez de ausência de linha, e é o que
permite a mesma função decidir os dois casos.

**Um teste compara os dois caminhos** e falha se discordarem. Ele já pagou por si: a
primeira versão do teste usava `for issue <- ..., pai = fetch_parent(...), ...` — e em
comprehension uma expressão que não é gerador vale como **filtro pelo seu valor**, então
`pai = nil` descartava justamente a tarefa sem pai. O teste concordava por não olhar.

**As duas formas são separadas, e não uma caso da outra**: tarefa com pai épico pede
retipar ou re-vincular; tarefa sem pai pede criar o vínculo. Somá-las esconderia qual ação
tomar.

**Recusado**: gravar a violação em coluna. Divergiria no instante em que a classificação do
pai mudasse — é a ADR 0004 D7.

**Recusado**: despromover a issue que viola. O inválido é o **vínculo**. Despromover
esconderia a issue exatamente onde o problema está visível, e mudaria as contagens de
escopo por causa de um vínculo errado.

---

## R6 — Corpo ausente: como a tela distingue

**Decisão**: `nil` é "nunca pedido à origem"; `""` é "a origem não tem descrição". A tela
diz coisas diferentes para os dois.

**Razão**: as 4455 issues já coletadas têm `body` nulo, e vão continuar assim até serem
reobservadas. Mostrar "sem descrição" para elas seria afirmar algo falso sobre a origem.

A distinção é possível porque `bodyText` devolve `""` para issue sem corpo, nunca `nil` — o
`nil` só existe onde a plataforma não perguntou.

É a L13 aplicada à exibição: `nil` e `""` não são a mesma coisa, e confundi-los já custou um
CI vermelho.

**Recusado**: preencher `""` na migração para todas as issues. Apagaria a distinção e
afirmaria que a origem não tem corpo em 4455 issues que ninguém olhou.

---

## R7 — O quadro e o marco: entidade ou referência?

**Decisão**: **referência** — `milestone_title` e `project_titles`, texto, sem promoção.

**Razão**: a coleta de quadros como entidade ficou fora da feature 004 (fase F4, não
implementada). Criar `projects` aqui inventaria a entidade pela porta de trás, sem a
proveniência e sem os campos que o quadro tem.

Guardar o título responde "esta issue aparece em qual quadro" sem afirmar mais do que se
sabe. E **nenhum dos dois é promovido**: FR-006 é explícito, e o quadro não é o sprint —
sprint é a iteração, que continua fora do escopo.

**Recusado**: tabela `issue_projects` com id externo. Seria meia entidade: id sem os campos,
sem o mapeamento, e sem quem a atualize quando o quadro mudar.

**Recusado**: promover o marco a `spo.project_milestone`. O marco do GitHub é usado para
release e para sprint indistintamente, e promovê-lo escolheria por conta própria.
