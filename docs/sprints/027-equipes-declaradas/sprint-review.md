# Sprint 027 — Review

**Período**: 2026-09-01 a 2026-09-08 · encerrado antecipadamente em 2026-09-02
**Feature**: [055 — equipes declaradas](../../specs/055-equipes-declaradas/spec.md)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | 3 |
| Tarefas | 15 | 13 |
| Entregáveis aceitos | 15 | **13 com ressalva** |

As três user stories estão completas em código. **Nenhuma issue foi fechada** —
as 18 continuam abertas na origem, e é a primeira coisa que esta review corrige.

## O que foi feito

| Tarefa | Issue | Entregável | Aceito |
|---|---|---|---|
| T001 | [#687](https://github.com/The-Band-Solution/theband/issues/687) | baseline dos gates aberta | sim |
| T002 | [#688](https://github.com/The-Band-Solution/theband/issues/688) | `eo.team_part_of_team` na ontologia, acíclica por restrição | sim |
| T003 | [#689](https://github.com/The-Band-Solution/theband/issues/689) | `eo_team_compositions` + as três colunas de invalidação | sim |
| T004 | [#690](https://github.com/The-Band-Solution/theband/issues/690) | registrar saída não apaga: o teste da violação | sim |
| T005 | [#691](https://github.com/The-Band-Solution/theband/issues/691) | `declare_team_membership/5` | sim |
| T006 | [#692](https://github.com/The-Band-Solution/theband/issues/692) | `record_team_departure/5` | sim |
| T007 | [#693](https://github.com/The-Band-Solution/theband/issues/693) | `record_team_membership_mistake/5` | sim |
| T008 | [#694](https://github.com/The-Band-Solution/theband/issues/694) | "vigente" com duas condições, nas seis consultas | sim |
| T009 | [#695](https://github.com/The-Band-Solution/theband/issues/695) | `declare_structural_team/4` | sim |
| T010 | [#696](https://github.com/The-Band-Solution/theband/issues/696) | tela cria e diz de onde a equipe veio | sim |
| T011 | [#697](https://github.com/The-Band-Solution/theband/issues/697) | recusa do ciclo de comprimento 3 | sim |
| T012 | [#698](https://github.com/The-Band-Solution/theband/issues/698) | `compose_teams/4` e `decompose_teams/4` | sim |
| T013 | [#699](https://github.com/The-Band-Solution/theband/issues/699) | estrutura nas duas telas | sim |

**User stories**: [US1 #702](https://github.com/The-Band-Solution/theband/issues/702) ·
[US2 #703](https://github.com/The-Band-Solution/theband/issues/703) ·
[US3 #704](https://github.com/The-Band-Solution/theband/issues/704) — as três completas.

## O que não foi feito

| Tarefa | Issue | Motivo | Destino |
|---|---|---|---|
| T014 | [#700](https://github.com/The-Band-Solution/theband/issues/700) | as duas afirmações quando coleta e declaração discordam nunca foi implementada. A seção que existe hoje em `show.ex` é a de evidência pendente de confirmação, que responde outra pergunta | **sprint 028**, dentro da feature 057 — a tela da equipe é reescrita lá, e fazer as duas afirmações agora seria trabalho jogado fora |
| T015 | [#701](https://github.com/The-Band-Solution/theband/issues/701) | gates e PR no padrão aconteceram; **a revisão independente não** | **sprint 028**, como condição de entrada dos PRs — ver a ressalva abaixo |

## Entregáveis aceitos com ressalva

**Os treze entregáveis passaram nos critérios da tarefa e foram incorporados sem
revisão independente.** Os quatro PRs — #706, #710, #712, #713 — têm **2 revisores
pedidos e 0 revisões** cada um. O merge não esperou.

O princípio VII é explícito: *"Aprovar o próprio PR, ou fazer merge sem revisão
independente, MUST NOT acontecer. Quando a revisão independente não puder ser
obtida, a lacuna MUST ser declarada — nunca marcada como cumprida."*

**A lacuna está declarada aqui.** T015 não é marcada como feita, e a condição
passa para o sprint seguinte.

## Evidências

| O quê | Onde |
|---|---|
| código na linha de integração | `origin/development` — commits `c2a2df9`, `f61f5f2`, `7392deb`, `1ca621c`, `8459cfb` |
| funções da feature no código | `compose_teams`, `decompose_teams`, `record_team_departure`, `record_team_membership_mistake`, `declare_structural_team` — todas em `lib/the_band/ontology/seon/eo/commands.ex` |
| PRs incorporados | [#706](https://github.com/The-Band-Solution/theband/pull/706), [#710](https://github.com/The-Band-Solution/theband/pull/710), [#712](https://github.com/The-Band-Solution/theband/pull/712), [#713](https://github.com/The-Band-Solution/theband/pull/713) |
| revisões nesses PRs | **zero** — medido em 2026-09-02 com `gh pr view --json reviews` |

## Dívida gerada

**A medida ignora o vínculo que este sprint criou.** A feature 055 entregou
`started_at`, `ended_at` e a invalidação — e `Profiles.TeamSkills` continua lendo
a evidência que a origem lista hoje. Quem saiu segue contando, e o conjunto de
membros de hoje é aplicado aos meses passados.

É o **mesmo defeito que o SC-003 desta feature proíbe no vínculo**, acontecendo na
medida. Já está registrado em [`docs/backlog/tela-da-equipe-complexa.md`](../../docs/backlog/tela-da-equipe-complexa.md)
e é a US1 da feature 057 — o primeiro item do sprint 028.

**Um defeito mais antigo, achado ao planejar a 057**: a condição de vigência usa
`started_at <= data`, e `started_at` é anulável de propósito. Contra nulo a
comparação avalia para desconhecido, e a linha é descartada — quem tem data de
início desconhecida **não é membro em data alguma**, sem erro e sem aviso.
Presente em `count_team_members_at/3` desde este sprint. Corrigido pela T034 da
057.

## Lições deste sprint

Três, e a primeira é a que mais custou.

### L95 — Pedir revisor não é obter revisão, e o merge não espera

Os quatro PRs tiveram revisores pedidos e nenhum revisou. A L89 dizia que PR sem
revisor pedido não é PR revisado; esta é a variante seguinte — **pedir e seguir em
frente**. O botão de merge não sabe a diferença.

### L96 — Issue que ninguém fecha faz o sprint parecer não entregue

Treze tarefas concluídas e incorporadas, **zero issues fechadas**. Quem olhasse a
origem em 2026-09-02 veria um sprint sem nenhuma entrega. A medida de fluxo que a
plataforma existe para calcular sairia errada sobre o próprio repositório.

### L97 — Feature que corrige o vínculo não corrige quem lê o vínculo

A 055 entregou o período do vínculo e nenhuma das consultas de medida passou a
usá-lo. O defeito nasceu **no mesmo sprint** que criou o dado para evitá-lo, e só
apareceu quando alguém foi desenhar a tela que o consome.
