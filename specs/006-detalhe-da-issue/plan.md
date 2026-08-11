# Plano de implementação: detalhe da issue e decomposição navegável

**Feature**: `specs/006-detalhe-da-issue/` · **Branch**: `006-detalhe-da-issue`
**Spec**: [spec.md](spec.md) · **Pesquisa**: [research.md](research.md)
**Constituição**: v1.4.0, dez princípios

---

## Summary

Duas telas, e a segunda existe porque a primeira precisa de um lugar para voltar: o detalhe
de uma issue, com tudo o que foi coletado e a decisão da plataforma sobre ela; e as issues de
um repositório, com a contagem por conceito que soma o total.

O que a feature acrescenta ao dado: corpo, motivo do fechamento, autor, designados, rótulos,
marco, quadros, contagens de comentário e reação, datas de atualização e fechamento.

O que ela acrescenta ao entendimento — e é o eixo: **composição e atendimento aparecem como
relações separadas, nomeadas, e nunca somadas.** No épico do cenário real são 9 user stories
compondo e 30 tarefas atendendo. O número 39 não aparece em lugar nenhum, e o teste que
sustenta isso é um `refute`.

## Ordem, e a dívida de processo

**Este plano foi escrito depois da implementação.** O princípio VI pede o contrário: Spec
Kit e sprint backlog antes do código.

O que aconteceu: a spec e o contrato de API existiam; o pedido da pessoa mantenedora foi
direto — *"ao clicar no titulo do repositorio e da issue quero ver os detalhes"* — e a
implementação seguiu do contrato, não deste plano.

Isso é **dívida de processo declarada**, e está registrada aqui, em
[RETOMAR.md](../../docs/sprints/RETOMAR.md) e na review do sprint. O que a ausência do plano
custou, concretamente: as fases abaixo foram descobertas na ordem em que apareceram no
código, e duas decisões de desenho só foram examinadas quando um teste as reprovou — R4 e R5
da pesquisa registram quais.

O que **não** foi perdido: o contrato de API veio antes da primeira função pública, como o
princípio VII exige, e as decisões estão registradas com o que foi recusado.

## Technical Context

| | |
|---|---|
| Linguagem | Elixir 1.20.2 / OTP 29 |
| Framework | Phoenix 1.8.9 + LiveView 1.2 |
| Persistência | Ecto + PostgreSQL 17 |
| Testes | ExUnit, `Phoenix.LiveViewTest` |
| Escala | 4455 issues, 135 repositórios, duas organizações |
| Origem | GraphQL v4 do GitHub, consulta já existente |

**Consumo da origem**: os campos novos entram na **mesma consulta** de issues, sem
requisição adicional. `bodyText`, `stateReason`, `author`, `assignees(first: 10)`,
`labels(first: 20)`, `milestone`, `projectItems(first: 10)`, `comments { totalCount }` e
`reactions { totalCount }` são subcampos do nó que já era buscado.

**Abrir detalhe não consulta a origem** (FR-033). Tudo vem do banco.

---

## Constitution Check

### I. Domínio organizado pelas ontologias — **conforme**

Nenhum conceito novo é inventado. As duas relações que a tela mostra são as que a SRO
declara: `sro.epic_composed_of_user_story` e
`sro.intended_task_planned_to_meet_user_story`, exibidas com o identificador à vista.

O rótulo da origem **não** é promovido: `bug` não faz a issue um defeito. Promover por
semelhança de nome é o antipadrão que este princípio proíbe, e a tabela `issue_labels` existe
para registrar o rótulo **sem** agir sobre ele.

### II. Fonte externa não é domínio — **conforme**

Corpo, rótulo, marco e quadro são vocabulário do GitHub, e ficam em `collected_issues` e nas
duas tabelas satélites — camada de plataforma. Nada disso entra em tabela de ontologia.

### III. Proveniência e idempotência (NÃO NEGOCIÁVEL) — **conforme**

Os campos novos entram no mesmo `record_collected_issue/2`, que é idempotente pela
Application Reference. Duas coletas seguidas sem mudança produzem os mesmos valores —
SC-013.

`replace_assignees/3` e `replace_labels/3` são idempotentes por construção: chamar duas vezes
com o mesmo dado não duplica, e há teste para isso.

**A exceção, declarada**: as duas substituições **apagam** o que a origem não traz mais, o
que contraria "ausência marca, nunca apaga". A razão e o critério de reversão estão em R3.

### IV. Semântica declarada em YAML versionado — **conforme, sem acréscimo**

A feature não introduz conceito nem regra nova na base de conhecimento. O axioma que a tela
mostra — `sro.rule07` — já está declarado, e a tela **nomeia** o identificador para que quem
lê possa conferir a formulação na base em vez de acreditar na interface.

### V. Monólito modular multitenant — **conforme**

Toda leitura passa por `TheBand.WorkItems`, `CMPO` e `EO`. Nenhuma tela alcança schema de
outro contexto: o nome da pessoa vem por `EO.people_names/2`, e o repositório por
`CMPO.fetch_observed/2`.

Isolamento: issue e repositório de outro tenant devolvem **não encontrado**, nunca "sem
permissão" — dizer "sem permissão" confirmaria que o recurso existe. Dois testes cobrem.

### VI. Spec Kit e sprint backlog antes do código — **NÃO conforme, e declarado**

Ver "Ordem, e a dívida de processo", acima. Esta é a única não conformidade do plano, e não
está sendo reinterpretada como conformidade.

### VII. Quality gates e revisão independente — **conforme**

Nove gates verdes por `mix gates`, conferidos por código de saída. 29 testes novos, 247 no
total. O contrato de API veio antes da primeira função pública.

### VIII. Desenho que o problema justifica — **conforme**; ver a seção abaixo

### IX. Ontologias modulares e autônomas — **conforme, e a feature exercita a fronteira**

A issue guarda `author_person_id`: uma **referência** a `eo_people`, através da fronteira.
O nome não é copiado — vem por chamada à API pública de EO no momento da leitura. Copiar o
nome criaria duas verdades sobre a mesma pessoa, e a cópia envelheceria em silêncio.

### X. Responsabilidade única, em módulo e em tela — **conforme, e foi o que decidiu a
divisão**

Três telas, três perguntas:

| Tela | Responde |
|---|---|
| `/trabalho` | a coleta classificou o quê, no tenant |
| `/trabalho/repositorios/:id` | o que existe neste repositório |
| `/trabalho/issues/:id` | o que se sabe desta issue, e de onde veio |

Duas telas em vez de abas na mesma: o princípio X decide **como dividir**, e a divisão é por
pergunta. E `TheBandWeb.ConceptLabel` nasceu daqui: três telas mostravam os mesmos conceitos,
e com a lista copiada em cada uma `sro.epic` viraria "épico" numa e "epic" na outra.

---

## Registro dos padrões introduzidos (princípio VIII)

Três respostas para cada: que problema concreto resolve, se o problema **existe agora**, e o
que fica pior.

### P1 — Tabelas satélites para designados e rótulos

**Problema**: designado e rótulo são zero-ou-muitos. Uma coluna guardaria um e perderia o
resto; um array perderia a referência à pessoa coletada.

**Existe agora?** **Sim, medido.** A issue `#1` do repositório `theband` tem autor e zero
designados; issues das outras organizações têm até 3 designados e até 5 rótulos.

**O que fica pior**: duas tabelas a mais, duas consultas a mais por detalhe de issue, e a
semântica de substituição precisa ser decidida — o que R3 fez, contra a regra geral do
projeto.

### P2 — `TheBand.WorkItems.Axioms`, módulo de funções puras

**Problema**: o axioma `sro.rule07` é verificado em dois lugares com formas de dado
diferentes — uma issue e o grafo do repositório. Duas implementações discordariam, e uma tela
avisaria o que a outra nega.

**Existe agora?** **Sim, e já aconteceu na sua primeira forma.** `classification/2` existe
como caminho único exatamente porque a tela e a consulta de escopo divergiriam. Este é o
mesmo problema com outro axioma.

**O que fica pior**: um módulo a mais na fronteira, e a tentação de acrescentar ali qualquer
regra sobre issue — inclusive as que pertencem à base de conhecimento em YAML. O critério: só
entra aqui axioma **já declarado** na base, e a função **nomeia** o identificador dele.

### P3 — `TheBandWeb.ConceptLabel`, tradução centralizada

**Problema**: três telas exibem os mesmos conceitos e motivos de lacuna. Copiado, o mesmo
identificador ganha nomes diferentes em telas diferentes, e quem lê conclui serem coisas
diferentes.

**Existe agora?** **Sim**: a lista estava duplicada entre `/trabalho` e as duas telas novas
no primeiro rascunho.

**O que fica pior**: um módulo de apresentação com conhecimento de vocabulário do domínio.
O risco é ele crescer para decidir conceito em vez de exibi-lo — e o moduledoc declara que
identificador sem tradução é devolvido **como está**, nunca inferido.

### P4 — `list_unpromoted_parts/2`, a terceira lista

**Problema**: composição + atendimento é menor do que a origem declara quando há parte não
promovida. Sem a terceira lista, quem lê conclui que a plataforma perdeu vínculos.

**Existe agora?** **Sim, e em massa**: 3440 das 4455 issues não estão promovidas, e muitas
são partes de issues que estão.

**O que fica pior**: mais uma seção na tela, e mais uma consulta. E a tentação de somar as
três para "conferir" — que é justamente a soma que o SC-004 proíbe.

### Padrões que **não** serão introduzidos

| Recusado | Por quê |
|---|---|
| renderizador de markdown | superfície de injeção e dependência, para ganho de leitura — R1 |
| `count_children/2` | somaria as duas relações; a separação tem de estar na API |
| coluna com a violação de axioma | divergiria quando a classificação mudasse — ADR 0004 D7 |
| tabela de comentários | multiplicaria o consumo da origem; entidade própria |
| tabela `issue_projects` | meia entidade: id sem campos, sem mapeamento, sem quem atualize |

---

## Project Structure

### Documentação desta feature

```text
specs/006-detalhe-da-issue/
├── spec.md              34 FR, 13 SC, 4 user stories, 12 edge cases
├── research.md          R1 a R7
├── plan.md              este documento
├── data-model.md        as duas tabelas novas e as nove colunas
├── quickstart.md        V1 a V12, com os números do dado real
├── contracts/
│   └── issue-detail.md  escrito ANTES da primeira função pública
├── tasks.md             tarefas em quatro fases
└── checklists/
    └── requirements.md
```

### Código

```text
lib/the_band/work_items/
├── axioms.ex                    NOVO — sro.rule07 como função pura
├── commands.ex                  + replace_assignees/3, replace_labels/3
├── queries.ex                   + fetch_issue/2 e as sete leituras do detalhe
└── schemas/
    ├── collected_issue.ex       + nove campos
    ├── issue_assignee.ex        NOVO
    └── issue_label.ex           NOVO

lib/the_band/ingestion/
└── github_work_items.ex         coleta os campos novos, resolve pessoa em lote

lib/the_band/ontology/seon/eo/
└── queries.ex                   + person_ids_by_login/1, people_names/2

lib/the_band_web/
├── concept_label.ex             NOVO — tradução única
├── live/work_item_live/show.ex  NOVO — detalhe da issue
└── live/repository_live/show.ex NOVO — issues do repositório

priv/repo/migrations/
├── 20260811180000_add_issue_details.exs
└── 20260811180100_create_issue_assignees_and_labels.exs
```

---

## Fases, e por que esta ordem

### F1 — Os campos na origem e no banco

A consulta GraphQL pede os campos novos; as migrações criam as colunas e as duas tabelas; os
schemas passam a aceitá-los.

**Bloqueia todo o resto**: sem coluna não há o que a tela mostre, e sem a consulta a coluna
fica nula para sempre.

**A migração não remove coluna**, e o round trip é parte do gate.

### F2 — As leituras, e a separação na API

`fetch_issue/2`, `promotion_history/2`, `list_composition/2`, `list_attendance/2`,
`list_unpromoted_parts/2`, `fetch_parent/2`, `list_refused_for/2`.

**Aqui a separação é decidida**: duas funções, e nenhuma que devolva as duas juntas. Deixar
para a tela dividir permitiria a soma em qualquer consumidor futuro.

### F3 — O axioma como função pura

`TheBand.WorkItems.Axioms.rule07/2` e a consulta em lote que a alimenta com o grafo.

**Depende de F2** porque a decisão precisa do conceito do pai, e é F2 que sabe buscá-lo.

### F4 — As duas telas

Detalhe da issue e issues do repositório, e os links a partir de `/trabalho`.

**Por último**, e é a ordem certa: a tela é a única parte que não pode ser verificada sem o
resto pronto.

---

## Riscos

| Risco | Mitigação |
|---|---|
| corpo da origem renderizado como HTML | `bodyText` e escape do HEEx; teste que recusa |
| soma de composição e atendimento aparecer | `refute` no teste da tela, e ausência da função na API |
| axioma verificado de dois jeitos | função pura única, e teste que compara os dois caminhos |
| consumo da origem crescer | campos na mesma consulta; `first:` limitado em cada lista |
| 4455 issues sem corpo parecerem vazias | `nil` distinto de `""`, e a tela declara qual é |

---

## Complexity Tracking

| Item | Custo | Aceito porque |
|---|---|---|
| duas tabelas satélites | duas consultas por detalhe | multiplicidade real, medida |
| três listas de partes | três consultas por detalhe | a alternativa é a soma proibida |
| substituição que apaga | histórico só no payload | atributo do agora, não fato histórico |
| plano depois do código | decisões examinadas tarde | dívida declarada, não silenciada |

---

## Reavaliação da constituição, pós-desenho

Nove princípios conformes; um não. O VI foi violado e está declarado — nem reinterpretado,
nem diluído.

Duas decisões mudaram **por causa de teste**, e as duas estão na pesquisa: a contagem crua de
partes saiu da tela (R4), e o teste de concordância entre os dois caminhos do axioma foi
reescrito porque a primeira versão concordava por não olhar (R5). Isso é o princípio VII
funcionando — e é também a evidência de que o plano teria pegado as duas antes.
