# Processo de trabalho por feature

Toda mudança no The Band percorre o ciclo do **GitHub Spec Kit**. Não há caminho
alternativo: código sem especificação, plano, tarefas e issue não entra.

O Spec Kit já está instalado neste repositório (`.specify/`, `.claude/skills/`),
versão `0.15.1.dev0`, integração `claude`.

## Ciclo

```text
Necessidade
→ Discovery
→ Feature Request
→ /speckit-specify        cria specs/<n>-<feature>/spec.md
→ /speckit-clarify        de-risca ambiguidades (opcional, antes do plan)
→ /speckit-checklist      valida completude dos requisitos (opcional)
→ APROVAÇÃO HUMANA
→ /speckit-plan           plano técnico, data model, contratos
→ revisão arquitetural
→ revisão semântica       (pode bloquear a feature)
→ /speckit-tasks          tasks.md ordenado por dependência
→ /speckit-taskstoissues  cria as GitHub Issues
→ /speckit-analyze        consistência entre spec, plan e tasks
→ SPRINT BACKLOG          obrigatório — ver abaixo
→ branch
→ /speckit-implement      execução das tarefas
→ testes e quality gates
→ /speckit-converge       verifica o que ficou faltando e reabre como tarefa
→ Pull Request
→ revisão independente
→ merge
```

> **Atenção aos nomes.** Nesta versão os comandos usam hífen (`/speckit-specify`), não
> ponto. Verifique com `specify version` e a listagem de skills antes de assumir outro
> formato — e nunca invente um comando que não existe.

## Sprint Backlog — obrigatório antes de implementar

Entre `/speckit-analyze` e a primeira linha de código existe um passo que **não é
opcional**: a skill `sprint-backlog`.

```
/sprint-backlog
```

Ela faz três coisas que o Spec Kit não faz:

**Lê as lições dos sprints anteriores.** `docs/sprints/licoes-aprendidas.md` é
consultado antes de selecionar escopo, e o backlog registra quais lições foram
aplicadas. Sem esse passo o registro vira decorativo e o mesmo erro se repete —
que é o erro mais caro, porque já era conhecido.

**Materializa o sprint no GitHub.** O sprint vira iteration do Projects v2; user
stories, épicos e tarefas viram issues tipadas e hierarquizadas por sub-issues,
seguindo os mesmos tipos que `priv/knowledge_base/rules/github_issue_type_routing.yaml`
espera. Isso torna o próprio repositório uma fonte que o The Band consegue
ingerir — o modelo passa a ser validado contra dados reais em vez de sintéticos.

**Fecha o ciclo ao final.** `sprint-review.md` separa o que foi feito do que não
foi, e trata entregável recusado como categoria própria — tarefa concluída cujo
resultado não passou nos critérios não é tarefa concluída, e escondê-la destrói a
medida de retrabalho que o produto existe para calcular.

| Artefato | Quando | Conceito SRO |
|---|---|---|
| `docs/sprints/NNN/sprint-backlog.md` | ao abrir | `sro.sprint_backlog` |
| `docs/sprints/NNN/sprint-review.md` | ao fechar | tarefas executadas e entregáveis |
| `docs/sprints/licoes-aprendidas.md` | acumulativo | `sro.retrospective_meeting` |

> **Implementar sem sprint backlog aberto é violação de processo.** Se alguém —
> pessoa ou agente — pedir implementação direta, a resposta correta é montar o
> backlog primeiro e apresentar para aprovação.

## O que uma feature ontológica precisa identificar

Antes de qualquer código:

- ontologia principal e ontologias das quais depende;
- conceitos adicionados ou alterados;
- relações, cardinalidades e restrições;
- perguntas de competência afetadas;
- YAMLs da base de conhecimento criados ou alterados;
- mapeamentos externos envolvidos;
- migrações necessárias;
- testes conceituais previstos;
- **riscos semânticos** — onde o modelo pode estar sendo distorcido para caber no dado.

## Definition of Ready

A feature está pronta para implementação quando: Discovery realizada, Feature Request
existente, `spec.md` aprovado, clarify concluído, checklist aprovado, `plan.md`
aprovado, ontologias e dependências identificadas, YAMLs planejados, mapeamentos
revisados, `tasks.md` aprovado, Issues criadas, riscos identificados, estratégia de
testes definida e analyze sem inconsistências críticas.

## Definition of Done

A feature está concluída quando: critérios de aceitação atendidos, tarefas concluídas,
Issues atualizadas, código implementado, YAMLs criados ou atualizados **e validados**,
perguntas de competência testadas, testes passando, Credo e Dialyzer aprovados,
migrações testadas, mapeamento semântico revisado, documentação atualizada, convergência
verificada, PR aprovado **por outra pessoa ou agente**, pipeline verde, merge realizado
e Issues encerradas.

## Branches e commits

```text
feature/<issue>-<descricao>    fix/<issue>-<descricao>    refactor/<issue>-<descricao>
docs/<issue>-<descricao>       test/<issue>-<descricao>   chore/<issue>-<descricao>
```

Conventional Commits, com escopo = ontologia ou subsistema:

```text
feat(sro): add user story knowledge definition
feat(github): add pull request connector definition
test(knowledge): validate semantic mappings
fix(cmpo): prevent duplicate commit ingestion
docs(ontology): document review semantics
```

## Quality gates antes do PR

```bash
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict
mix dialyzer
mix test
mix knowledge.validate
mix knowledge.graph
mix knowledge.test
```

Enquanto o projeto Elixir não existir, a base de conhecimento é validada por
`python3 scripts/validate_knowledge_base.py`, com o mesmo papel de porta de qualidade.

## O que o Pull Request precisa informar

Feature, especificação, plano, issues, ontologias afetadas, conceitos e relações
alterados, YAMLs alterados, tabela de mapeamentos semânticos
(origem | ontologia | conceito | equivalência | limitação), migrações, testes,
resultado dos quality gates, perguntas de competência validadas, evidências e riscos
residuais.

## Regra que não se negocia

Quem implementa não aprova o próprio PR, e nenhum agente declara sucesso sem evidência
— saída de teste, log ou captura. Diante de incerteza semântica relevante, o trabalho
para e as alternativas são apresentadas: um mapeamento errado contamina todas as
métricas derivadas dele, e o erro só aparece depois que alguém já decidiu com base nele.
