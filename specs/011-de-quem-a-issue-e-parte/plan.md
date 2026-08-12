# Plano de implementação: de quem cada issue é parte

**Feature**: `specs/011-de-quem-a-issue-e-parte/` · **Branch**: `015-de-quem-a-issue-e-parte`
**Spec**: [spec.md](spec.md) · **Pesquisa**: [research.md](research.md)
**Constituição**: v1.4.0, dez princípios · **Origem**: issue [#246](https://github.com/The-Band-Solution/theband/issues/246)

---

## Summary

Uma coluna na lista de issues do repositório dizendo **de quem aquela issue é parte** — o pai com
número e título, o **conceito** do pai, e **qual** das relações é: atendimento, composição, violação
da `sro.rule07`, ou uma relação que a rede de ontologias não nomeia.

Medido em 2026-08-12: **1 630** issues com pai, **1 666** vínculos, **2 899** sem pai. Por relação:
**1 143** atendimento · **293** violação · **197** composição · **33** não nomeada.

## O que este plano decide antes de tudo

**A coluna não é "o pai". É a relação.** O pedido dizia "seu US ou EPIC"; a medida mostrou que essas
duas palavras não cobrem 12 dos casos, e que a mesma coluna precisa distinguir quatro coisas.

| se a coluna | resultado |
|---|---|
| dissesse só "US ou EPIC" | 12 issues com pai que é **defeito** ficariam sem nome |
| chamasse tudo de "pai" | juntaria atendimento com composição, o que a feature 006 separou |
| mostrasse o pai das 293 sem aviso | apagaria um sinal que a tela **já** dá no painel acima |
| chamasse o axioma com pai ausente | **2 091** células viriam com aviso de violação |
| escolhesse um pai entre os vários | esconderia que há outro, em **36** issues |
| resolvesse o nome do repositório por linha | 50 consultas por render, o defeito da feature 007 |

## Technical Context

| | |
|---|---|
| Linguagem | Elixir 1.20.2 / OTP 29 |
| Framework | Phoenix 1.8.9 + LiveView |
| Persistência | Ecto + PostgreSQL 17 — **nenhuma coluna nova**, nada é gravado |
| Escala | 4 529 issues vigentes, 1 666 vínculos, página de 50, um repositório com 2 514 |
| Fronteiras cruzadas | **WorkItems** (issue, vínculo, axioma) e **CMPO** (nome do repositório do pai) |
| Tela alterada | `lib/the_band_web/live/repository_live/show.ex`, que já compõe três fronteiras |

---

## Constitution Check

### I. Domínio organizado pelas ontologias — **conforme**

Nenhum conceito novo. O vínculo de decomposição já existe, e os nomes das relações são os da rede:
`sro.epic_composed_of_user_story` compõe, `sro.intended_task_planned_to_meet_user_story` atende.

**E o princípio decide o quarto caso.** Filha promovida a `osdef.defect` sob qualquer pai: a rede
**não nomeia** essa relação. A coluna diz isso em vez de encaixar em composição — inventar nome seria
inferência por semelhança, que este princípio proíbe.

### II. Fonte externa não é domínio — **conforme**

O vínculo vem de `subIssues` do GitHub e já está traduzido em `decomposition_links`. A coluna lê o
domínio. O `issue_type` da origem não entra na decisão da relação: quem decide é o **conceito
promovido**.

### III. Proveniência e idempotência (NÃO NEGOCIÁVEL) — **conforme**

A coluna **exibe** proveniência do vínculo: o período de observação, e `no_longer_observed_at` quando
o vínculo deixou de aparecer. Nada é gravado — a relação é derivada na leitura, como a classificação
épico/atômica. Sem escrita não há idempotência a garantir.

**Ausência é marcada, nunca deletada**: vínculo com `no_longer_observed_at` continua na consulta e
aparece tracejado, com a data. Hoje são **zero** — o teste monta o caso.

### IV. Semântica declarada em YAML versionado — **não se aplica, e a razão importa**

Nenhuma regra nova de mapeamento. A `sro.rule07` **já está** na base de conhecimento, e é de lá que
vem a formulação que `Axioms.explicacao/1` cita. A coluna não declara semântica: ela **exibe** a que
já está declarada.

### V. Monólito modular multitenant — **conforme**

Toda consulta é escopada por `tenant_id`, e a rota é a que já existe — `/work/repositories/:id`, com
`fetch_observed/2` devolvendo `{:error, :not_found}` para repositório de outro tenant. A coluna não
acrescenta ponto de entrada.

### VI. Spec Kit e sprint backlog antes do código — **conforme**

Spec, checklist e pesquisa commitados antes deste plano. **Nada implementado.** O sprint 010 abre com
`sprint-backlog` antes da primeira linha de código, e a fase de análise roda antes também — nas
**quatro** features anteriores ela achou defeito de desenho que nenhum teste de unidade pegaria.

### VII. Quality gates e revisão independente — **conforme**

`mix gates` é a definição única dos dez, e o veredito é o código de saída desde a #229. PR com
revisor pedido e conferido por `requested_reviewers`.

### VIII. Desenho que o problema justifica — **dois padrões introduzidos, seis recusados**

As três perguntas de cada um estão na seção seguinte.

### IX. Ontologias modulares e autônomas — **conforme, e é o ponto sensível**

Duas fronteiras, e o plano **não** as dissolve:

| fronteira | o que ela responde | quem chama |
|---|---|---|
| `WorkItems` | os pais de um conjunto de issues, com conceito e repositório | o LiveView |
| `CMPO` | o **nome** do repositório observado | o LiveView |

**`WorkItems` não junta a tabela de CMPO.** A consulta dos pais devolve `observed_repository_id`, e o
nome é resolvido por `CMPO.list_observed/2` virando mapa — o mesmo `nomes_de_repositorio/1` que a
feature 010 usa em `people_live/show.ex`, e o mesmo `onde/2` da 007. Quem compõe é o LiveView, que já
compõe três fronteiras nesta tela.

### X. Responsabilidade única, em módulo e em tela — **conforme**

A tela do repositório continua respondendo **uma** pergunta: o que a plataforma sabe deste
repositório. A coluna acrescenta um atributo às issues que ela já lista — não uma segunda pergunta.

**O que este princípio proíbe aqui**: a coluna mostrar a linhagem completa. Épico → user story →
tarefa é outra pergunta, e o detalhe da issue já a responde.

---

## Padrões introduzidos

### P1 — `WorkItems.list_parents/2`: os pais de um conjunto de issues, agrupados

**Qual problema concreto resolve.** A página lista 50 issues e precisa, para cada uma, dos pais dela.
`fetch_parent/2` responde por **uma** issue: usá-la na lista seriam 50 consultas por render.

**O problema existe agora ou é previsão.** **Existe agora, e já custou.** A feature 007 nasceu com
135 consultas por render, e a FR-013 existe por causa dela. E o repositório maior desta organização
tem **2 514** issues.

**O que fica pior.** Duas funções fazem quase a mesma coisa — `fetch_parent/2` para uma, esta para
muitas — e podem divergir. Mitigação: a nova devolve **todos** os pais, e a antiga fica registrada
como dívida com o defeito nomeado (abaixo).

**Assinatura**

```elixir
@spec list_parents(Tenant.t(), [Ecto.UUID.t()]) :: %{Ecto.UUID.t() => [map()]}
```

Uma consulta, agrupada em memória por `child_issue_id`. Cada pai traz `id`, `number`, `title`,
`observed_repository_id`, `derived_concept` e `no_longer_observed_at` **do vínculo**.

**Ordem determinística**: `asc: number, asc: id` — FR-009. Sem isso as 36 issues com mais de um pai
mostrariam ordem que muda entre execuções, que é a família da **L20**.

### P2 — `WorkItems.Axioms.relacao/2`: qual relação é, num lugar só

**Qual problema concreto resolve.** A coluna precisa dizer atendimento, composição, violação ou "não
nomeada". Sem uma função, essa decisão nasceria dentro do HEEx — e a tela do detalhe já decide o
mesmo por outro caminho.

**O problema existe agora ou é previsão.** **Existe agora**: `rule07_violations/2` decide a violação
na mesma tela, num painel acima da tabela. Duas decisões diferentes fariam a coluna avisar sobre uma
issue que o painel declara correta — e o inverso.

**O que fica pior.** Um lugar a mais para olhar quando a semântica muda. É o custo aceito: o
`Axioms` existe exatamente porque a tela do detalhe verifica uma issue e a do repositório verifica
quatro mil, e as duas precisam concordar.

```elixir
@spec relacao(String.t() | nil, String.t() | nil) ::
        :atendimento | :composicao | :nao_nomeada | :pai_sem_conceito
        | {:violacao, :task_parent_is_epic}
```

**Chamada só quando há pai.** A ausência de pai não é caso desta função — é o R6 da pesquisa, e
chamá-la com pai nulo encheria 2 091 células de aviso.

**Dois `nil` diferentes, e confundi-los é o erro fácil.** Em `rule07/2`, `nil` no conceito do pai
significa **não tem pai**. Aqui significa **o pai existe e não foi promovido**. `relacao/2` trata o
`nil` **antes** de chamar o axioma, devolvendo `:pai_sem_conceito` — FR-007. Passar esse `nil`
adiante faria a tela dizer "task without parent" sobre uma issue que **tem** pai. É a **L34** —
a mesma palavra significando duas coisas — aplicada antes de doer.

**E `relacao/2` chama `rule07/2`, não o reimplementa** — FR-006.

## Padrões recusados

| Recusado | Por que não |
|---|---|
| **módulo novo para a coluna** | a decisão é um axioma e vive em `Axioms`; um `Relations` seria uma casa para uma função |
| **materializar a relação numa coluna** | derivada na leitura custa uma consulta; materializada precisaria de recálculo a cada promoção, e a promoção muda |
| **componente em `TheBandWeb.UI`** | um consumidor só; o critério de promoção é o **segundo** fora da tela |
| **reusar `fetch_parent/2`** | `limit: 1` sem ordem, e ela **esconde** que há outro pai em 36 issues |
| **mostrar a linhagem completa** | é outra pergunta, e o detalhe da issue já a responde — princípio X |
| **tabela de duplas de conceito na tela** | nove duplas hoje, e a décima nasce na primeira coleta com tipo novo; a decisão é por conceito, não por enumeração |

---

## Fases

### F1 — a consulta dos pais, e a decisão da relação

| # | O que |
|---|---|
| 1 | `Axioms.relacao/2` — quatro respostas, chamando `rule07/2` para a violação |
| 2 | `WorkItems.list_parents/2` — uma consulta, agrupada, ordem determinística |

**Contrato antes da primeira função pública** — o princípio VI, e está em
[contracts/issue-parent.md](contracts/issue-parent.md).

### F2 — a coluna na lista

| # | O que |
|---|---|
| 3 | a coluna: pai navegável, **conceito do pai**, e a ausência nomeada |
| 4 | as quatro relações, com texto próprio cada uma |
| 5 | o repositório do pai, quando difere — `CMPO.list_observed/2` virando mapa |
| 6 | mais de um pai dito, com ordem estável |

### F3 — o que o dado ainda não tem, e o custo

| # | O que |
|---|---|
| 7 | vínculo ausente tracejado, com a data — **zero** casos hoje, o teste monta |
| 8 | pai sem conceito — **zero** casos hoje, o teste monta |
| 9 | o custo do render medido: a diferença e a constância |

**Nove tarefas**, detalhadas em [tasks.md](tasks.md).

**F1 sem F2 não é entregável.** Consulta sem consumidor visível não é funcionalidade entregue — é a
**L21**, e por isso as três fases estão no mesmo sprint.

---

## Custo de consulta, e como ele é medido

A tela faz hoje, por render: `count_collected`, `count_by_promotion`, `count_gaps_by_reason`,
`rule07_violations` (que é uma), `list_issues`, `list_organizations`. **Esta feature acrescenta
duas** — `list_parents/2` e `CMPO.list_observed/2`.

**Duas, e não uma, porque são duas fronteiras.** A spec dizia uma antes de a fronteira do nome ser
notada; a correção está registrada na FR-013. É a mesma terceira fronteira que a análise da feature
010 achou.

**Como o teste mede** — o jeito que a feature 010 estabeleceu (**L38**):

1. a **diferença** entre a tela com a coluna e a tela sem ela: exatamente **duas**;
2. a **constância**: uma página com 3 issues e uma com 50 fazem o **mesmo** número de consultas.

"Um número que não cresce" não é asserção. O número medido é.

---

## Dívida declarada, com o defeito nomeado

| Dívida | O que é | Por que não aqui |
|---|---|---|
| `fetch_parent/2` com `limit: 1` **sem ordem** | no detalhe da issue, devolve pai arbitrário para as 36 com mais de um; pode mudar entre execuções | é outra tela, e o detalhe mostra a decomposição por outro caminho |
| filha promovida a **defeito** não aparece no detalhe do pai | **33** vínculos fora de `list_composition/2`, de `list_attendance/2` e de `list_unpromoted_parts/2` | corrigir a tela do pai é outra feature; aqui os 33 aparecem **do lado da filha** |

As duas são achado desta medida, e as duas vão para o backlog com número. **Registrar é o que
distingue dívida de omissão.**

---

## Complexity Tracking

| Item | Justificativa |
|---|---|
| duas fronteiras compostas no LiveView | `repository_live/show.ex` já compõe WorkItems, CMPO e EO; o princípio IX proíbe **junção de tabelas** entre fronteiras, não composição na tela |
| duas consultas novas em vez de uma | uma por fronteira, e a alternativa era resolver o nome por linha — o defeito que a FR-013 existe para impedir |

Nenhuma violação sem registro.

---

## Constitution Check — reavaliação pós-desenho

| Princípio | Antes | Depois |
|---|---|---|
| I | conforme | **conforme, e decidiu o quarto caso** — "não nomeada" em vez de nome inventado |
| II | conforme | conforme |
| III | conforme | conforme — ausência marcada, nada gravado |
| IV | não se aplica | não se aplica; a `sro.rule07` já está declarada |
| V | conforme | conforme |
| VI | conforme | conforme |
| VII | conforme | conforme |
| VIII | dois padrões | **dois introduzidos com as três perguntas, seis recusados** |
| IX | ponto sensível | **conforme** — nenhuma junção entre fronteiras; composição no LiveView |
| X | conforme | conforme — a coluna é atributo da issue, não segunda pergunta |
