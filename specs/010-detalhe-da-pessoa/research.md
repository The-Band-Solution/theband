# Pesquisa — Feature 010: o detalhe da pessoa

Seis questões. Duas foram respondidas por **precedente medido no repositório** — a tela já
existente que faz o mesmo cruzamento —, e uma pela **forma do dado**, que decidiu contra texto fixo.

| Questão | O que decidiu |
|---|---|
| R1 | precedente: `repository_live/show.ex` já compõe **três** fronteiras |
| R4 | o motivo da não promoção vem do **dado**, porque texto fixo passa a mentir |

---

## R1 — Quem monta uma página que cruza duas ontologias

A página precisa de pessoa e equipe (**EO**) e de issue e designação (**WorkItems**).

**Decisão**: **o LiveView compõe**, chamando as duas fronteiras. Nenhum módulo novo.

**Razão, e é precedente medido**: `lib/the_band_web/live/repository_live/show.ex` já faz exatamente
isto, com **três** fronteiras — `CMPO.fetch_observed/2`, `WorkItems.count_collected/2` e
`EO.list_organizations/1`. O padrão está em uso, e o princípio IX está satisfeito porque **nenhuma
ontologia lê a tabela da outra**: cada uma responde pela sua fronteira, e a composição acontece na
borda de apresentação.

**Recusado: um módulo `PersonProfile`** que devolvesse a página inteira montada. Ele teria de conhecer
as duas ontologias e viraria o lugar onde a fronteira se dissolve — exatamente o que a ADR 0003
impede. E teria **um** chamador.

**Recusado: `EO` consultando `issue_assignees`.** A designação é de WorkItems. EO passando a ler
tabela de trabalho é a fronteira quebrada por conveniência, e a ADR 0003 existe por causa disso.

---

## R2 — As consultas, e como não crescer com o dado

**Decisão**: **oito consultas**, todas agrupadas ou paginadas, e nenhuma por linha:

| # | pergunta | onde vive | forma |
|---:|---|---|---|
| 1 | quem é esta pessoa | `EO` | busca por identificador |
| 2 | em que organizações ela está | `EO` | uma consulta |
| 3 | em que equipes a origem a declara | `EO` | uma consulta, com a organização de cada equipe |
| 4 | quantos papéis o tenant cadastrou | `EO` | contagem |
| 5 | em quantas issues foi designada | `WorkItems` | contagem |
| 6 | quantas issues abriu | `WorkItems` | contagem |
| 7 | em quais repositórios aparece | `WorkItems` | agrupada por repositório |
| 8 | **o nome de cada repositório** | `CMPO` | uma consulta, virando mapa |

**O número é oito, e a primeira versão desta pesquisa dizia quatro.** A análise contou o que as
tarefas produzem: faltavam a busca da pessoa, as organizações dela, a contagem de papéis, e — a que
mais importa — **o nome do repositório**, que exige a terceira fronteira.

**O oito é aserido, não estimado**: o teste conta as consultas de uma renderização e exige o número.
"Um número que não cresce" não é asserção, e era o que o quickstart dizia.

**Razão**: FR-016 proíbe consultar por linha, e a feature 007 mostrou o custo de não decidir — 135
consultas por render, que nasceram sem ninguém escolher.

**O que fica pior**: quatro consultas em vez de uma. É o preço de manter designação e autoria
separadas — e juntá-las numa consulta só produziria o número que FR-009 proíbe.

**Recusado: uma consulta que devolva "as issues da pessoa".** "As issues da pessoa" são **três**
conjuntos diferentes — designadas, abertas, e a união —, e a união é justamente a que não corresponde
a nada.

---

## R3 — Como a lista de issues filtra por pessoa

**Medido**: `WorkItems.list_issues/2` pagina e filtra por `observed_repository_id` através de
`escopo/2`. Não há filtro por pessoa.

**Decisão**: `escopo/2` ganha **duas** opções distintas — designada e autora —, nunca uma opção
`person_id` que sirva às duas.

**Razão**: o nome da opção é onde a distinção sobrevive. `person_id: id` obrigaria quem lê o código a
descobrir em qual sentido; `assigned_to:` e `authored_by:` dizem. É a L34 aplicada antes de doer: a
mesma palavra para duas coisas esconde qual delas está sendo pedida.

**O que fica pior**: `escopo/2` cresce, e passa a ter três dimensões de filtro. Aceito: as três são
usadas, e a alternativa — uma função de listagem por pessoa em paralelo — duplicaria a paginação e a
ordem estável que já custaram para acertar.

**A ordem estável continua valendo**: `observed_repository_id`, `number`, `id`. Ordenar só por número
daria páginas que se sobrepõem, porque o número repete entre repositórios.

---

## R4 — De onde vem a explicação da não promoção

**A tela precisa dizer que a evidência não virou vínculo, e por quê.** Medido: **88 evidências, zero
vínculos, zero papéis**.

**Decisão**: o motivo vem do **dado**, não de texto fixo.

- a evidência diz se foi promovida — `promoted_membership_id` nulo ou não;
- a **contagem de papéis cadastrados** diz se a causa é a ausência de papel.

**Razão, e é o ponto**: um texto fixo dizendo *"nenhum papel foi cadastrado"* **passa a mentir** no dia
em que alguém cadastrar papel e as evidências forem promovidas. A tela ficaria afirmando uma causa que
deixou de existir, e ninguém notaria — porque a frase continuaria plausível.

**Medido, e afia o terceiro caso**: `eo_organizational_roles` tem **só** `code` e `name` — é catálogo
do tenant, sem pessoa nem equipe. E `eo_team_memberships.organizational_role_id` é **NOT NULL**.

Então contar papéis responde *"é possível promover alguém?"*, e **não** *"por que esta pessoa não foi
promovida?"*. As duas perguntas juntas dão os três casos, e todos são **verificáveis**:

| o que o dado diz | o que a tela diz |
|---|---|
| evidência promovida | o vínculo existe, com o papel |
| não promovida, **e zero papéis** no tenant | não promovida **porque nenhum papel foi cadastrado** — e promover é impossível para qualquer pessoa |
| não promovida, **com** papéis cadastrados | não promovida **porque ninguém alocou papel a esta pessoa nesta equipe** — que é a #100 |

A terceira linha é impossível hoje e vai existir. A primeira versão desta pesquisa dizia apenas *"a
causa não é a ausência de papel"* — frase plausível e sem conteúdo, e a análise a recusou. A causa
**é** verificável: ausência de linha em `eo_team_memberships` para aquela pessoa e equipe.

**Custo**: uma consulta a mais, de contagem. Barata, e é o que impede a frase de envelhecer.

---

## R5 — A gramática da evidência nesta tela

**Decisão**: as **três formas** do design system — sólida, hachurada, tracejada — com texto e rótulo
acessível, aplicadas assim:

| na tela | forma | por quê |
|---|---|---|
| equipe declarada pela origem | **sólida** | observado: a origem afirmou |
| repositório em que a pessoa aparece | **hachurada** | derivado de designação ou autoria |
| vínculo que deixou de ser observado | **tracejada** | ausente, com a data |

**Recusado: reusar `<.evidence>`.** Ela responde *"de onde veio este conceito"* — proveniência de uma
decisão semântica, com confiança. Aqui a pergunta é *"de onde veio esta relação"*. Emprestar o
componente faria a mesma forma responder duas perguntas, e a gramática perderia precisão no lugar em
que ela **é** o produto.

**Decisão sobre componente**: um componente **privado do LiveView**, porque há **dois** usos na mesma
tela — a lista de **equipes** e a de **repositórios**.

**A análise corrigiu a contagem**: eu havia escrito três, somando "vínculo ausente" como uso próprio.
Ele não é — equipe e vínculo ausente são a **mesma lista**, e a linha muda de forma conforme
`no_longer_observed_at`.

Dois é exactamente o limiar do projeto: a feature 007 recusou componente para **um** chamador. **Fica
no limiar de propósito**, e se uma das duas listas sair da tela, o componente sai com ela.

**Quando ele sobe para `TheBandWeb.UI`**: no segundo **consumidor fora desta tela**. Enquanto for uma
tela só, ele mora nela, e o critério de promoção é este parágrafo.

---

## R6 — A rota, e o isolamento entre tenants

**Decisão**: `/people/:id`, com `id` sendo o identificador interno da pessoa.

**Razão**: é o mesmo desenho de `/work/repositories/:id`, já em uso desde a feature 006 — e usar o
identificador da origem na URL vazaria a forma do sistema externo para dentro do endereço.

**Isolamento**: a busca é escopada por tenant, e pessoa de outro tenant responde **não encontrado**
(FR-015). Não "sem permissão": confirmar existência já é vazamento.

**Recusado: `/people/:login`.** O login é da origem, muda quando a pessoa o troca, e não é único entre
instâncias — o projeto já pagou por identificar pelo que a origem mostra, na L25.
