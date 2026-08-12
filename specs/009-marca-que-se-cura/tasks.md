# Tarefas — Feature 009: a marca de inacessível se cura

**Spec**: [spec.md](spec.md) · **Plano**: [plan.md](plan.md) · **Contrato**:
[contracts/unreachable-recovery.md](contracts/unreachable-recovery.md) · **Quickstart**:
[quickstart.md](quickstart.md)

**Oito tarefas, três fases.** Dois padrões introduzidos, sete recusados, **nenhum módulo novo** — o
conjunto segue o tamanho do plano.

Ordem: F1 → F2 → F3, e é dependência.

**MVP**: F1 e F2. Com as duas, os 39 repositórios voltam à coleta e as 899 issues voltam a ser
alcançadas — que é a issue #213 inteira. F3 torna a lacuna **visível**, e é o que impede a próxima
de passar em silêncio.

**F1 vem antes de F2, e não é preferência**: sem a classificação corrigida, a cura ficaria limpando
marcas que a própria coleta recria na mesma execução.

---

## Fase F1 — A natureza do erro

Resolve a [#214](https://github.com/The-Band-Solution/theband/issues/214).

- [ ] T001 Julgar a natureza do erro da origem
  - **Pronta quando**: o contrato em `contracts/unreachable-recovery.md` declara o comportamento de
    `transient?/1`; nada mais
  - **Descrição**: acrescentar **uma cláusula** a `Client.transient?/1` em
    `lib/the_band/integrations/github/client.ex`, para `{:graphql_errors, errors}`, delegando a um
    julgamento privado por erro. **Nenhum módulo novo**: a pergunta *"esta falha se repete?"* já tem
    lugar, e um `ErrorClassifier` acrescentaria um salto para ler a mesma decisão (R2, princípio X).

    A regra:

    | erro | natureza |
    |---|---|
    | `type: NOT_FOUND`, `type: FORBIDDEN` | **permanente** |
    | `type: RATE_LIMITED` | transitória |
    | mensagem `Something went wrong… Please include \`<id>\`` | **transitória** — falha interna, com identificador de incidente |
    | sem `type` e sem essa assinatura | **permanente** |
    | lista com naturezas mistas | **permanente** — vence o mais permanente (FR-008) |

    **O desconhecido é permanente de propósito, e a ordem das correções é a razão**: marcar de menos
    deixaria repositório apagado sendo consultado a cada coleta, para sempre. O custo de marcar de
    mais deixou de ser permanente porque F2 existe na mesma feature
  - **Feita quando**: o payload real da 39ª marca é classificado como transitório; `NOT_FOUND`
    continua permanente; uma lista mista devolve permanente
  - **Teste**: `test/the_band/integrations/github/transient_test.exs` — o caso que importa usa o
    **payload real** gravado no banco: `"Something went wrong while executing your query on
    2026-08-12T12:32:30Z. Please include 6D2F:110188:1CD8DB0:1D79ED0:6A7C67D3 when reporting this
    issue"`. Inventar a mensagem faria o teste passar sobre um erro que a origem não produz

- [ ] T002 Não marcar por falha do momento
  - **Pronta quando**: T001 concluída
  - **Descrição**: conferir o caminho em `lib/the_band/ingestion/github_work_items.ex` — o ramo de
    erro de `coletar_issues/2` já consulta `Client.transient?/1` antes de marcar, então **nada muda
    ali**. A tarefa é o **teste de ponta a ponta**: a resposta de falha interna, entregando pela
    borda HTTP simulada, não deixa marca.

    É a tarefa que prova que a correção de T001 chega ao efeito, e não só à função — "a função
    classifica" e "o repositório não é marcado" são afirmações diferentes, e é a L28
  - **Feita quando**: uma coleta em que a origem responde falha interna termina com **zero**
    repositórios marcados; e uma em que responde `NOT_FOUND` deixa **um** marcado
  - **Teste**: `test/the_band/ingestion/unreachable_recovery_test.exs` — os dois casos, com o
    payload real no primeiro, e a asserção **no banco**, não no valor devolvido

---

## Fase F2 — A cura

Resolve a [#213](https://github.com/The-Band-Solution/theband/issues/213).

- [ ] T003 Voltar a tentar o repositório marcado
  - **Pronta quando**: T001 concluída — a classificação vem primeiro, senão a cura limpa o que a
    coleta recria
  - **Descrição**: em `lib/the_band/ontology/seon/cmpo/queries.ex`, `list_collectable/2` passa a
    rejeitar **só** `excluded_at`. O inacessível volta para a lista.

    **A exclusão vence**: repositório excluído **e** inacessível continua fora, porque exclusão é
    decisão de alguém e a plataforma não a desfaz (FR-004).

    **O nome da função não muda**, e é decisão registrada em R1: ele já dizia o certo — *o que a
    coleta deve consultar* —, e era a implementação que discordava. A função tem **um** consumidor
    de produção, conferido, então mudar a semântica muda o comportamento daquele ponto, que é
    exatamente o que a feature quer
  - **Feita quando**: `list_collectable/2` devolve o repositório inacessível e **não** devolve o
    excluído; um repositório com as duas marcas fica fora
  - **Teste**: `test/the_band/ontology/seon/cmpo/collectable_test.exs` — os quatro casos: sem marca,
    inacessível, excluído, e **os dois juntos**. O último é a asserção que importa

- [ ] T004 Preservar desde quando não se alcança
  - **Pronta quando**: T003 concluída
  - **Descrição**: em `lib/the_band/ontology/seon/cmpo/commands.ex`, `mark_inaccessible/3` grava
    `inaccessible_since` **só quando não há marca**. Havendo, preserva a data e atualiza
    `inaccessible_reason` (FR-003, R3).

    Hoje ela sobrescreve sempre — e com isso um repositório inacessível há dez dias parece **novo**
    em cada coleta, o que apaga a diferença entre problema crônico e falha de agora. Nenhum teste
    depende do comportamento atual, conferido
  - **Feita quando**: duas falhas consecutivas deixam a data **inalterada** e o motivo com a
    **última** falha; a primeira falha grava a data
  - **Teste**: `test/the_band/ontology/seon/cmpo/inaccessible_test.exs` — marcar, esperar, marcar de
    novo com motivo diferente, e asserir que a data não se moveu **e** que o motivo mudou. As duas
    asserções juntas, porque preservar tudo seria o defeito oposto

- [ ] T005 Limpar a marca ao alcançar
  - **Pronta quando**: T003 e T004 concluídas
  - **Descrição**: nenhuma linha nova — `coletar_issues/2` já chama `clear_inaccessible/2` quando a
    paginação conclui. A tarefa é **provar que o caminho agora existe**, que era o defeito: o
    repositório marcado era filtrado antes de chegar lá.

    A coleta precisa limpar a marca **e** coletar as issues na mesma execução (FR-002)
  - **Feita quando**: um repositório marcado que a origem alcança fica sem marca **e** com as issues
    dele coletadas, numa execução só
  - **Teste**: o mesmo arquivo de T002 — a asserção dupla: `inaccessible_since` nulo **e** contagem
    de issues maior que zero. Só a primeira passaria com a marca limpa e nada coletado

- [ ] T006 Concluir mesmo com tudo falhando
  - **Pronta quando**: T003 concluída
  - **Descrição**: conferir que uma falha por repositório não interrompe os outros (FR-005). O
    caminho já é tolerante — o ramo de erro devolve `%{repositorio: _, coletadas: 0}` —, e com o
    inacessível de volta na lista o número de tentativas cresce, então o teste passa a valer mais.

    **Repositório excluído não recebe requisição nenhuma**: o teste conta as chamadas à borda HTTP
  - **Feita quando**: com a origem falhando para todos, a coleta **conclui**; o repositório excluído
    não gera requisição
  - **Teste**: o mesmo arquivo de T002 — a falha total conclui, e a contagem de chamadas pela borda
    simulada **não** inclui o excluído

---

## Fase F3 — O número, e a tela

- [ ] T007 Contar os repositórios não alcançados
  - **Pronta quando**: T006 concluída
  - **Descrição**: migração acrescentando `repositories_unreachable` (`integer`, **não nulo**, padrão
    **0**) a `syncs`, mais o campo no schema e no `cast`. `GithubWorkItems.collect/1` passa a
    devolver `unreachable:` no relatório e a gravar o número no registro.

    **O padrão zero é exceção declarada** à regra do projeto: zero repositórios não alcançados é um
    **fato** de uma coleta que funcionou, não ausência. O risco é o inverso — esquecer de
    incrementar faz o zero **afirmar** sucesso, que é a L32.

    **NÃO usar `skip_reasons`**: o mecanismo `{:skipped, reason}` incrementa `records_collected`
    junto, e 39 repositórios entrariam como 39 registros coletados (R4)
  - **Feita quando**: a migração sobe e desce sem erro; uma coleta em que tudo falha grava o número
    igual à contagem de repositórios observados; uma coleta que alcança tudo grava zero
  - **Teste**: round trip da migração; e no arquivo de T002, o caso de **falha total** exigindo
    `repositories_unreachable == 121` no cenário real reproduzido — é a asserção que impede o zero
    de mentir

- [ ] T008 Dizer desde quando, e por quê
  - **Pronta quando**: T007 concluída
  - **Descrição**: em `lib/the_band_web/live/work_item_live/index.ex`, `situacao/1` passa a produzir
    `unreachable since <data>`, com `inaccessible_reason` abaixo em fonte reduzida — o mesmo
    tratamento que a organização recebe na linha da issue. **Em texto, nunca só por cor** (FR-010).

    **Nenhuma coluna nova**: estaria vazia em 96 das 135 linhas (R5).

    A frase que diz que a plataforma tenta de novo a cada coleta entra **uma vez**, no cabeçalho da
    seção de repositórios (FR-011) — repetir 39 vezes gasta a atenção que o motivo precisa ter.

    E em `lib/the_band_web/live/sync_live/index.ex`, o cartão da execução mostra quantos
    repositórios não foram alcançados, quando o número é maior que zero
  - **Feita quando**: a linha do inacessível diz desde quando e o motivo; com a cor removida, o
    estado continua legível; o cartão da execução mostra o número quando há não alcançados, e
    **não** mostra quando é zero
  - **Teste**: `test/the_band_web/live/unreachable_screen_test.exs` — a linha contém a data e o
    motivo; `refute` a informação existir só na classe de cor; e a asserção de que a frase do
    cabeçalho aparece **uma** vez, não uma por linha

---

## Dependências

```text
T001 → T002
  └──→ T003 → T004 → T005
              T003 → T006 → T007 → T008
```

T001 antes de tudo: a classificação corrigida é o que impede a cura de limpar marcas que a coleta
recria.

## Paralelismo

| Podem ir juntas | Por quê |
|---|---|
| T002 e T003 | um é teste de ponta a ponta da classificação, o outro é a consulta |
| T004 e T006 | comando e tolerância a falha, arquivos diferentes |

## Cobertura

| Requisitos | Tarefas |
|---|---|
| FR-001 (tentar o marcado) | T003 |
| FR-002 (limpar ao alcançar, e coletar) | T005 |
| FR-003 (a data preserva o começo) | T004 |
| FR-004 (excluído nunca é tentado) | T003, T006 |
| FR-005 (uma falha não interrompe as outras) | T006 |
| FR-006, FR-007, FR-008 (a natureza do erro) | T001, T002 |
| FR-009 (um lugar só para a classificação) | T001 — e a **ausência** de módulo novo |
| FR-010, FR-011 (desde quando, e por quê) | T008 |
| FR-012 (nada é apagado) | T005 — `clear_inaccessible/2` só zera a marca |
| FR-013 (isolamento entre tenants) | T003 |
| FR-014 (quantos não foram alcançados) | T007 |

**14 de 14 requisitos com tarefa.** SC-001 a SC-010 verificados por V1 a V8 do
[quickstart](quickstart.md).

**Uma cobertura é por ausência, e é de propósito**: FR-009 é atendido por **não** existir módulo de
classificação. Requisito atendido por ausência precisa estar escrito, ou alguém acrescenta o que ele
proíbe.

## Estratégia de entrega

**F1+F2 é o MVP**, e resolve as duas issues: as marcas erradas param de nascer, e as 39 que existem
saem na primeira coleta que alcançar a origem — trazendo as **899 issues** de volta.

**F3 não é opcional para declarar a feature completa.** Sem o número de não alcançados, a próxima vez
que 39 repositórios caírem também vai passar em silêncio: a execução conclui com sucesso e 100%,
porque o denominador só conta o que a plataforma decidiu olhar. Foi assim que este defeito viveu dois
dias.

## Fora do escopo, e ficou de fora

| Item | Por quê |
|---|---|
| módulo de classificação de erro | a pergunta já tem lugar — R2, princípio X |
| segunda função para listar incluindo inacessíveis | dois nomes que não distinguem nada — R1 |
| `last_attempt_at` | o registro de sincronização já data a última tentativa — R3 |
| histórico de incidentes por repositório | exige evento append-only e necessidade de informação própria |
| desistir de repositório que falha há muito tempo | é o defeito que esta feature corrige |
| coluna "desde quando" para todos os repositórios | vazia em 96 das 135 linhas — R5 |
