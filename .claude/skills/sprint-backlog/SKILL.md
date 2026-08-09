---
name: sprint-backlog
description: Monta e fecha o Sprint Backlog do The Band, reunindo especificação, tarefas, issues do GitHub, o registro do que foi e do que não foi entregue, e as lições aprendidas que alimentam o próximo sprint. Use SEMPRE antes de começar qualquer implementação, e de novo ao encerrar o sprint. Dispara com "sprint backlog", "iniciar sprint", "fechar sprint", "vamos implementar", "começar a implementação", "lições aprendidas".
---

# Sprint Backlog

Reúne num só lugar o que vai ser feito no sprint, de onde veio, o que de fato foi
entregue, e o que o sprint ensinou.

**Obrigatória antes de implementar.** Implementar sem sprint backlog produz
trabalho sem rastro: ninguém sabe qual user story a tarefa atende, o que ficou de
fora, nem por quê.

**O ciclo só fecha com as lições.** Um sprint que termina sem registrar o que
aprendeu condena o próximo a repetir os mesmos erros — e é justamente o erro
repetido que mais custa caro, porque já era conhecido.

## Por que os conceitos da SRO

O The Band modela a Scrum Reference Ontology. Usar aqui os mesmos conceitos que
o produto descreve não é preciosismo: é o que permite, mais adiante, ingerir o
próprio repositório do projeto e validar o modelo contra dados reais.

| Conceito SRO | Neste processo |
|---|---|
| `sro.sprint_backlog` | o documento que abre o sprint |
| `sro.user_story` | vem do `spec.md`, seção User Scenarios |
| `sro.intended_scrum_development_task` | linha do `tasks.md`, antes de executar |
| `sro.performed_scrum_development_task` | a mesma tarefa, depois de executada |
| `sro.deliverable` | o que a tarefa produziu |
| `sro.accepted_deliverable` | entregável que atende aos critérios de aceitação |
| `sro.non_successfully_performed_scrum_development_task` | tarefa cujo entregável não foi aceito |
| `sro.retrospective_meeting` | a cerimônia que produz as lições aprendidas |

A distinção entre tarefa **pretendida** e **executada** é a razão de existirem
documentos separados: o backlog registra a intenção, a review registra a
ocorrência. Colapsar os dois apagaria a análise de aderência entre plano e
execução — que é uma das perguntas que o próprio produto existe para responder.

## Quando rodar

| Momento | O que fazer |
|---|---|
| **Antes de implementar** | ler as lições acumuladas, criar `sprint-backlog.md` |
| Durante | atualizar estado das tarefas e links de issue |
| **Ao encerrar** | criar `sprint-review.md` e consolidar em `licoes-aprendidas.md` |

## Pré-requisitos

O sprint backlog **deriva** de artefatos que já existem. Se algum faltar, pare e
resolva antes:

- [ ] `specs/<feature>/spec.md` aprovado
- [ ] `specs/<feature>/plan.md` aprovado
- [ ] `specs/<feature>/tasks.md` gerado por `/speckit-tasks`
- [ ] issues criadas no GitHub por `/speckit-taskstoissues`

Sem `tasks.md` não há o que colocar no backlog. Sem issues não há como rastrear.
Nesses casos a resposta correta é apontar o que falta, não improvisar.

## Onde os arquivos vivem

```text
sprints/
├── licoes-aprendidas.md          acumulativo, atravessa os sprints
├── 001-<nome-curto>/
│   ├── sprint-backlog.md         o que será feito
│   └── sprint-review.md          o que foi feito, e o que não foi
└── 002-<nome-curto>/
    └── ...
```

Numeração sequencial, estável, nunca reciclada.

---

## Procedimento — abrir o sprint

1. **Ler `sprints/licoes-aprendidas.md` primeiro.** Antes de qualquer outra
   coisa. As lições em aberto que se apliquem a este sprint entram como
   restrição, não como sugestão — e o backlog registra quais foram consideradas.
   Se o arquivo não existir, este é o primeiro sprint.

2. **Descobrir o número.** Maior número em `sprints/`, mais um.

3. **Ler os artefatos de origem.** `spec.md` para user stories e critérios de
   aceitação; `plan.md` para decisões técnicas; `tasks.md` para tarefas.

4. **Materializar o sprint no GitHub.** Ver a seção seguinte. O sprint precisa
   existir como iteration, e as user stories, épicos e tarefas como issues
   tipadas e hierarquizadas.

5. **Selecionar o escopo.** Nem toda tarefa do `tasks.md` entra. A seleção é
   decisão humana: se não estiver clara, pergunte quais user stories entram, em
   vez de assumir que é tudo.

6. **Escrever `sprint-backlog.md`**, com os links do GitHub resolvidos.

7. **Confirmar antes de implementar.** Apresente o backlog e aguarde o aval.

---

## Materializar o sprint no GitHub

O sprint não vive só no documento: existe também no GitHub, como iteration e
issues tipadas. Isso não é burocracia — é o que torna o próprio projeto uma fonte
de dados que o The Band consegue ingerir e mapear para a SRO, validando o modelo
contra dados reais em vez de sintéticos.

### Correspondência

| Conceito SRO | GitHub | Documento |
|---|---|---|
| `sro.sprint` | iteration do Projects v2 | cabeçalho do backlog |
| `sro.sprint_backlog` | itens do projeto na iteration | tabela de tarefas |
| `sro.epic` | issue com tipo `Epic`, com sub-issues | agrupamento de US |
| `sro.atomic_user_story` | issue com tipo `User Story` | tabela de user stories |
| `sro.intended_scrum_development_task` | issue com tipo `Task`, filha da US | tabela de tarefas |
| `sro.performed_scrum_development_task` | a mesma issue, fechada | review |

A regra de roteamento por tipo está declarada em
`priv/knowledge_base/rules/github_issue_type_routing.yaml`. **Manter os tipos
coerentes com ela é o que permite o produto ingerir o próprio repositório.**

### Passo 1 — garantir os tipos de issue

Organizações do GitHub vêm com `Task`, `Bug` e `Feature`. `Epic` e `User Story`
precisam ser criados uma vez, e só então ficam disponíveis.

```bash
# verificar o que existe
gh api graphql -f query='{ organization(login:"<ORG>"){
  issueTypes(first:20){ nodes{ name isEnabled } } } }'
```

Faltando, criar com `createIssueType`, informando `ownerId` da organização,
`name` e `description`. Criar tipo é ação que altera a configuração da
organização — **confirme antes**, e nunca crie tipo com nome divergente do que a
regra de roteamento espera.

### Passo 2 — garantir o sprint como iteration

Sprint é um campo de iteração no Projects v2, não um milestone. Milestone não tem
duração nem ordem, e é usado tanto para release quanto para sprint — o produto
não conseguiria distinguir.

```bash
# o projeto já tem campo de iteração?
gh api graphql -f query='{ organization(login:"<ORG>"){
  projectV2(number:<N>){ id
    fields(first:50){ nodes{
      ... on ProjectV2IterationField { id name
        configuration{ duration startDay
          iterations{ id title startDate duration } } } } } } } }'
```

Não havendo campo, criar uma vez com `createProjectV2Field`, `dataType: ITERATION`
e `iterationConfiguration` contendo `duration` em dias e `startDay`. As iterations
seguintes são acrescentadas na configuração do campo.

Se o projeto não usa Projects v2 com iteração, **registre isso como limitação no
backlog** em vez de improvisar com label ou milestone. O produto trata a ausência
como lacuna, e o processo deve fazer o mesmo.

### Passo 3 — tipar e hierarquizar as issues

Para cada user story e tarefa do escopo:

1. criar a issue, se ainda não existir — `/speckit-taskstoissues` costuma ter
   feito isso;
2. atribuir o tipo com `updateIssueIssueType`;
3. ligar à hierarquia com `addSubIssue` — tarefa é filha da user story, user
   story é filha do épico quando houver;
4. adicionar ao projeto e atribuir à iteration do sprint.

**A hierarquia importa mais do que parece.** A regra de roteamento decide entre
épico e user story atômica pela presença de sub-issues, com precedência da
estrutura sobre o tipo declarado. Uma issue marcada como `Epic` sem sub-issues
será tratada como user story atômica, com divergência registrada — o que está
correto, e é sinal de épico que nunca foi decomposto.

Sub-issue do tipo `Task` **não** transforma a user story em épico: tarefa atende
a user story, não a compõe.

### Passo 4 — preencher os campos da issue

Issue sem os campos preenchidos não sustenta nem priorização nem métrica. O
projeto **The Band** já traz `Priority`, `Size` e `Estimate` configurados, e o
campo `Iteration` com duração de 14 dias.

| Campo no GitHub | Onde vive | Conceito SRO | Preencher em |
|---|---|---|---|
| `Priority` | campo do ProjectV2 | `sro.user_story.importance` | user story e épico |
| `Size` | campo do ProjectV2 | — (t-shirt size, apoio à estimativa) | user story e tarefa |
| `Estimate` | campo do ProjectV2 | `sro.user_story.complexity` | user story e tarefa |
| `Iteration` | campo do ProjectV2 | `sro.sprint` | tudo que entra no sprint |
| `Parent issue` | nativo | composição de épico / atendimento de tarefa | user story e tarefa |

**Importance e complexity não são a mesma coisa, e trocá-las inverte a
priorização.** A SRO é explícita: *importance* diz quão valiosa a user story é
para a organização, e quem a define é o Product Owner. *Complexity* diz quão
difícil é para o time implementá-la. Uma story pode ser altamente valiosa e
trivial — é a primeira a fazer. Ou pouco valiosa e cara — provavelmente não
deveria estar no sprint.

`Priority` carrega a *importance*; `Estimate` carrega a *complexity*. `Size`
existe como apoio grosseiro e não tem correspondente ontológico — não use `Size`
onde `Estimate` é esperado, porque só `Estimate` é numérico e alimenta as
medidas de fluxo.

**Ausência é nula, nunca zero.** Story sem `Priority` preenchida não tem
importância zero: tem importância desconhecida. Preencher com zero produziria
ordenação errada e mediria como se a decisão tivesse sido tomada. O mapeamento
em `priv/knowledge_base/mappings/github/sro/issue_user_story.yaml` registra isso
como limitação; o processo deve respeitar.

**Tarefa não recebe `Priority`.** Prioridade é da user story — a tarefa herda a
da story que atende. Preencher prioridade na tarefa cria duas fontes que podem
divergir, e a divergência não teria como ser resolvida.

Os valores são gravados com `updateProjectV2ItemFieldValue`, informando
`projectId`, `itemId`, `fieldId` e o valor no formato do campo — `number` para
`Estimate`, `singleSelectOptionId` para `Priority` e `Size`, `iterationId` para
`Iteration`.

### Passo 5 — registrar no documento

Toda issue criada ou vinculada entra no `sprint-backlog.md` com número e URL.
Tarefa sem issue é registrada como pendência explícita — **nunca invente o
link**.

---

## Modelo — `sprint-backlog.md`

```markdown
# Sprint <N> — <nome>

**Período**: <início> a <fim>
**Feature**: [<id>](../../specs/<feature>/spec.md)
**Plano**: [plan.md](../../specs/<feature>/plan.md)

## Objetivo do sprint

<Uma frase. O que muda no produto quando este sprint terminar.>

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), consideradas neste sprint:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| L03 | Sprint 001 | <o que foi feito diferente por causa dela> |

<Se nenhuma se aplica, dizer isso explicitamente — e por quê.>

## Sprint no GitHub

**Iteration**: <título> · <início> a <fim> · <duração> dias
**Projeto**: [<nome>](url do ProjectV2)

<Se o projeto não usa iteration, dizer aqui e registrar como limitação.>

## User stories selecionadas

| # | User story | Tipo | Épico | Issue | Priority | Estimate | Critérios |
|---|---|---|---|---|---|---|---|
| US1 | <título, do spec.md> | User Story | [#3](url) | [#11](url) | P1 | 5 | <quantos> |

`Priority` é a *importance* da SRO — valor para a organização. `Estimate` é a
*complexity* — dificuldade para o time. Campo em branco significa desconhecido,
não zero.

## Tarefas

| # | Tarefa | Atende | Tipo | Issue | Estimate | Estado |
|---|---|---|---|---|---|---|
| T01 | <descrição> | US1 | Task | [#12](url) | 3 | a fazer |

Tarefa não recebe `Priority`: herda a da user story que atende.

Estados: `a fazer` · `em andamento` · `feito` · `bloqueado` · `não iniciado`

## Fora do escopo deste sprint

<O que está no tasks.md e ficou de fora, com o motivo. Silenciar isso faz o
sprint parecer completo quando não é.>

## Riscos e dependências

<O que pode impedir a conclusão, e o que depende de terceiros.>

## Definition of Done do sprint

Além da DoD por tarefa:

- [ ] quality gates verdes (`mix format --check-formatted`, `compile --warnings-as-errors`, `credo --strict`, `dialyzer`, `test`)
- [ ] base de conhecimento válida
- [ ] issues encerradas ou repriorizadas com justificativa
- [ ] `sprint-review.md` escrito
- [ ] `licoes-aprendidas.md` atualizado
```

---

## Procedimento — fechar o sprint

1. **Conferir o estado real**, não o presumido. Rodar os quality gates e
   `gh issue list --state all` para as issues do sprint.

2. **Classificar cada tarefa**:

   | Situação | Como registrar |
   |---|---|
   | executada, entregável atende aos critérios | feita, entregável aceito |
   | executada, entregável não atende | feita, entregável **não** aceito — user story volta ao backlog |
   | não executada | não feita, com o motivo |

   A segunda linha é a que costuma ser maquiada. Tarefa concluída com entregável
   recusado não é tarefa concluída — é retrabalho a caminho, e escondê-lo destrói
   a medida de qualidade que o produto existe para calcular.

3. **Escrever `sprint-review.md`.**

4. **Extrair as lições e consolidar em `licoes-aprendidas.md`.**

5. **Nunca declarar sucesso sem evidência.** Saída de teste, log ou captura.

---

## Modelo — `sprint-review.md`

```markdown
# Sprint <N> — Review

**Período**: <início> a <fim>
**Feature**: [<id>](../../specs/<feature>/spec.md)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | | |
| Tarefas | | |
| Entregáveis aceitos | | |

## O que foi feito

| Tarefa | Issue | Entregável | Aceito |
|---|---|---|---|
| T01 | [#12](url) | <o que ficou pronto> | sim |

## O que não foi feito

| Tarefa | Issue | Motivo | Destino |
|---|---|---|---|
| T05 | [#16](url) | <por que não> | próximo sprint / descartada / bloqueada |

## Entregáveis não aceitos

<Tarefas executadas cujo resultado não atendeu aos critérios. Para cada uma: o
que faltou, e para onde a user story volta.>

## Evidências

<Saída dos quality gates. Links de PR. Capturas quando houver interface.>

## Dívida gerada

<O que ficou consciente e precisará mudar. Diferente de "não feito": é o que foi
feito de um jeito que já se sabe provisório.>

## Lições deste sprint

<Rascunho do que vai para o registro acumulado. Ver o procedimento abaixo.>
```

---

## Procedimento — lições aprendidas

A retrospectiva não é seção decorativa da review: é o único mecanismo que faz o
processo melhorar entre sprints. Sem ela, cada sprint recomeça do zero.

### O que vira lição

Uma lição precisa ser **acionável no próximo sprint**. O teste é direto: *se eu
ler isto ao abrir o próximo sprint, faço algo diferente?* Se não, é desabafo, e
desabafo não entra no registro.

| Vira lição | Não vira |
|---|---|
| "Estimar tarefa de migração sem rodar o derivador subestimou em 3×" | "O sprint foi corrido" |
| "Classificar conceito antes de derivar evita refazer o esquema" | "Precisamos melhorar a comunicação" |
| "Credencial de teste expirou no meio do sprint; provisionar antes" | "Tivemos problemas com o GitHub" |

### De onde as lições saem

Olhe para estes lugares, nesta ordem — é onde o aprendizado costuma estar
escondido:

1. **Tarefas não feitas** — o motivo costuma ser a lição.
2. **Entregáveis não aceitos** — o que faltou era previsível?
3. **Dívida gerada** — por que foi aceita? A pressa era real?
4. **Estimativas erradas** — em que direção, e por quê.
5. **Retrabalho** — o que teria evitado.
6. **Bloqueios externos** — dava para antecipar.

### Classificação

| Tipo | Significa |
|---|---|
| `processo` | como trabalhamos |
| `técnica` | como construímos |
| `estimativa` | como dimensionamos |
| `dependência` | o que depende de terceiros |
| `conhecimento` | o que não sabíamos e precisávamos saber |

### Ciclo de vida

Uma lição nasce **aberta**, é aplicada em sprints seguintes, e só é **encerrada**
quando virou prática estabelecida ou deixou de valer. Encerrar cedo demais faz
ela voltar; nunca encerrar faz o registro inchar até ninguém ler.

```text
aberta → aplicada em <sprint> → aplicada em <sprint> → encerrada
```

Lição aplicada em três sprints seguidos sem reincidência já é prática — encerre
e, se couber, registre como regra no `AGENTS.md`, onde vira obrigação em vez de
lembrete.

---

## Modelo — `sprints/licoes-aprendidas.md`

```markdown
# Lições aprendidas

Registro acumulado, atravessa os sprints. **Lido ao abrir cada sprint**, antes de
selecionar escopo.

Uma lição só entra aqui se for acionável: se lê-la não faz ninguém agir
diferente, não é lição.

## Abertas

| # | Lição | Tipo | Origem | Aplicada em | O que fazer |
|---|---|---|---|---|---|
| L01 | <o que aprendemos> | técnica | Sprint 001 | 002, 003 | <ação concreta> |

## Encerradas

| # | Lição | Encerrada em | Como |
|---|---|---|---|
| L00 | <lição> | Sprint 004 | virou regra no AGENTS.md / deixou de valer |

---

## L01 — <título>

**Tipo**: técnica · **Origem**: Sprint 001 · **Estado**: aberta

**O que aconteceu.** <O fato, sem interpretação.>

**Por que aconteceu.** <A causa, não o sintoma.>

**O que fazer diferente.** <Ação concreta, verificável no próximo sprint.>

**Aplicada em**: Sprint 002 — <o que mudou por causa dela>
```

---

## Regras que não se negociam

- **Não implemente sem backlog aberto.** Se pedirem implementação sem ele, monte
  o backlog primeiro e apresente.
- **Não abra sprint sem ler as lições acumuladas.** É o passo que dá sentido ao
  registro; pular torna o documento decorativo.
- **Não invente link de issue.** Tarefa sem issue é registrada como pendência.
- **Não marque tarefa como feita sem evidência.**
- **Não omita o que ficou de fora.** Sprint que só lista sucesso é relatório, não
  review.
- **Não registre lição não acionável.** Encher o documento faz parar de ser lido.
- **Escopo é decisão humana.** Na dúvida sobre o que entra, pergunte.

## Relação com o Spec Kit

Esta skill não substitui nenhum comando do Spec Kit — consome o que eles
produzem, e devolve aprendizado ao início do ciclo.

```text
/speckit-specify        → spec.md
/speckit-plan           → plan.md, research.md, data-model.md, contracts/
/speckit-tasks          → tasks.md
/speckit-taskstoissues  → issues no GitHub
        ↓
   sprint-backlog  ←──────────────┐   ← esta skill, lendo as lições
        ↓                         │
   implementação                  │
        ↓                         │
   sprint-review                  │
        ↓                         │
   licoes-aprendidas ─────────────┘   ← alimenta o próximo sprint
```
