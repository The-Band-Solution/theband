# Sprint 022 — Menu por entidades

**Período**: 2026-08-28 a 2026-09-03
**Feature**: [046-menu-por-entidades](../../specs/046-menu-por-entidades/spec.md)
**Plano**: [plan.md](../../specs/046-menu-por-entidades/plan.md)

## Objetivo do sprint

A navegação passa a dizer o que cada coisa é: barra principal com as entidades
(People, Teams, Projects, Organization), o resto em Settings com três seções — e a
tela Organization nasce, fechando o espelho entre menu e escopos de acesso.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), consideradas neste sprint:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| L60 | Sprint 016 | gates lidos por redirecionamento para arquivo, nunca `\| tail`; T001 e T011 trazem a forma no enunciado |
| L61 | Sprint 021 | a limitação "projeto não tem vínculo declarado com organização" virou ramo no código (grupo "sem organização identificada") e frase na tela — research R3, T008/T009 |
| L38 | Sprint 009 | a tela Organization lê por **uma** consulta agregada (`organization_overview/1`), não por consulta-por-linha; o teste de T008 cobre a forma |
| L03 | Sprint 001 | os testes de T008 exercitam a violação (vazamento entre tenants), não só o caminho feliz |
| L02/L20 (família) | — | verificação de T010 compara a tela com o banco de origem antes de declarar número certo |

## Sprint no GitHub

**Iteration**: Sprint 022 — Menu por entidades · 2026-08-28 · 7 dias — *ver limitação abaixo*
**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Limitações registradas (herdadas dos sprints anteriores, não improvisadas):**

- Os tipos de issue `Epic` e `User Story` **não existem** na organização (só Task,
  Bug, Feature). Criá-los altera configuração da organização e exige aval da pessoa
  mantenedora — as issues seguem sem tipo, como nos sprints 003–021, e a divergência
  fica registrada aqui.
- O campo `Iteration` existe no projeto com só os Sprints 001 e 002 (completados);
  os sprints 003–021 não criaram iterations. Tentativa de acrescentar a deste sprint
  registrada abaixo do resultado — se a mutação não for aceita, a limitação continua.
- Hierarquia por sub-issues não é usada no repositório; tarefa referencia a US no
  corpo, como nos sprints anteriores.

## User stories selecionadas

| # | User story | Tipo | Épico | Issue | Priority | Estimate | Critérios |
|---|---|---|---|---|---|---|---|
| US1 | A barra vira entidades + Settings | (sem tipo — limitação) | — | [#529](https://github.com/The-Band-Solution/theband/issues/529) | P1 | 5 | 6 |
| US2 | Work carrega as visões como sub-abas | (sem tipo) | — | [#530](https://github.com/The-Band-Solution/theband/issues/530) | P2 | 3 | 3 |
| US3 | Tela Organization no menu principal | (sem tipo) | — | [#531](https://github.com/The-Band-Solution/theband/issues/531) | P3 | 5 | 3 |

`Priority` é a *importance* da SRO — valor para a organização. `Estimate` é a
*complexity* — dificuldade para o time. Campo em branco significa desconhecido, não zero.

## Tarefas

| # | Tarefa | Atende | Tipo | Issue | Estimate | Estado |
|---|---|---|---|---|---|---|
| T001 | Abrir branch e registrar baseline dos gates | US1 | Task | [#532](https://github.com/The-Band-Solution/theband/issues/532) | 1 | feito |
| T002 | Helper de área ativa do menu | US1 | Task | [#533](https://github.com/The-Band-Solution/theband/issues/533) | 2 | feito |
| T003 | Reorganizar a barra principal | US1 | Task | [#534](https://github.com/The-Band-Solution/theband/issues/534) | 3 | feito |
| T004 | Menu Settings com três seções e gating | US1 | Task | [#535](https://github.com/The-Band-Solution/theband/issues/535) | 3 | feito |
| T005 | Rotas antigas respondem inalteradas | US1 | Task | [#536](https://github.com/The-Band-Solution/theband/issues/536) | 2 | feito |
| T006 | Componente de sub-abas | US2 | Task | [#537](https://github.com/The-Band-Solution/theband/issues/537) | 2 | feito |
| T007 | Sub-abas nas seis telas | US2 | Task | [#538](https://github.com/The-Band-Solution/theband/issues/538) | 2 | feito |
| T008 | Leitura agregada da organização | US3 | Task | [#539](https://github.com/The-Band-Solution/theband/issues/539) | 3 | feito |
| T009 | Tela Organization com estados vazios nomeados | US3 | Task | [#540](https://github.com/The-Band-Solution/theband/issues/540) | 3 | feito |
| T010 | Número conferido contra a origem | US3 | Task | [#541](https://github.com/The-Band-Solution/theband/issues/541) | 1 | feito |
| T011 | Gates verdes e evidência de viewport | US3 | Task | [#542](https://github.com/The-Band-Solution/theband/issues/542) | 1 | feito |

Tarefa não recebe `Priority`: herda a da user story que atende. T001/T002 atendem a
US1 por habilitarem o MVP; T011 fecha o sprint e está sob a última US por convenção.

Estados: `a fazer` · `em andamento` · `feito` · `bloqueado` · `não iniciado`

## Fora do escopo deste sprint

- **Spec 045 (autenticação e escopos de acesso)** inteira: especificada e prototipada,
  aguarda sprint próprio. O gating de Operação neste sprint usa o modelo vigente
  (`users.role == "admin"`) e a 045 o amplia depois num único ponto (research R5).
- **Tipos de issue e hierarquia no GitHub**: dependem de aval para alterar a
  configuração da organização (limitação acima).
- **FK projeto→organização**: research R3 rejeitou a migração; o vínculo é por
  `source_instance`, com a limitação declarada na tela.

## Riscos e dependências

- `source_instance` pode não casar com os logins das organizações no dado real — T010
  mede e o resultado entra como evidência; divergência é bloqueio da US3, não
  observação (research R3).
- Rate limit secundário do GitHub atrasou a criação das issues — links marcados
  `pendente` são atualizados assim que criados; nenhum link é inventado.

## Definition of Done do sprint

Além da DoD por tarefa:

- [ ] quality gates verdes (`mix gates` com saída lida do log, L60)
- [ ] base de conhecimento válida
- [ ] issues encerradas ou repriorizadas com justificativa
- [ ] `sprint-review.md` escrito
- [ ] `licoes-aprendidas.md` atualizado
