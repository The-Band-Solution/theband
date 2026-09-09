# Sprint 028 — Review

**Período**: 2026-09-02 a 2026-09-09 · encerrado em 2026-09-02
**Feature**: [057 — a tela da equipe, e a equipe feita de equipes](../../../specs/057-tela-da-equipe-complexa/spec.md)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 6 | 6 |
| Tarefas | 37 | 36 |
| Entregáveis aceitos | 37 | **36 com ressalva** |

As seis user stories estão completas em `development`. A tarefa não entregue é
justamente a que exige revisão independente, e a ressalva é a mesma do sprint
anterior.

## O que foi feito

| # | User story | Issue | Entregue por |
|---|---|---|---|
| US1 | A medida conta só enquanto a pessoa pertenceu | [#715](https://github.com/The-Band-Solution/theband/issues/715) | [#758](https://github.com/The-Band-Solution/theband/pull/758) |
| US2 | A equipe complexa mostra suas equipes, uma a uma | [#716](https://github.com/The-Band-Solution/theband/issues/716) | [#759](https://github.com/The-Band-Solution/theband/pull/759) |
| US3 | O detalhe da subequipe | [#717](https://github.com/The-Band-Solution/theband/issues/717) | [#761](https://github.com/The-Band-Solution/theband/pull/761) |
| US4 | O que cada pessoa está fazendo, e o que demonstrou | [#718](https://github.com/The-Band-Solution/theband/issues/718) | [#761](https://github.com/The-Band-Solution/theband/pull/761) + [#762](https://github.com/The-Band-Solution/theband/pull/762) |
| US5 | Burn-up e burn-down, com o que resta entre as curvas | [#719](https://github.com/The-Band-Solution/theband/issues/719) | [#761](https://github.com/The-Band-Solution/theband/pull/761) |
| US6 | Uma previsão que diz sua confiança | [#720](https://github.com/The-Band-Solution/theband/issues/720) | [#761](https://github.com/The-Band-Solution/theband/pull/761) |

**42 das 43 issues fechadas.** Cada uma com o número do PR que a entregou no
comentário — a **L96** deste sprint existe porque isso não foi feito no 027.

### Os cinco PRs

| PR | O que entregou |
|---|---|
| [#760](https://github.com/The-Band-Solution/theband/pull/760) | o ciclo Spec Kit inteiro, o fechamento do 027 e a abertura do 028 |
| [#758](https://github.com/The-Band-Solution/theband/pull/758) | `team_members_at/3`, `vigente_em/2`, a correção de `TeamSkills`, as duas medidas em YAML |
| [#759](https://github.com/The-Band-Solution/theband/pull/759) | `TeamWork`, a tela composta sem soma, a ordem por trabalho parado |
| [#761](https://github.com/The-Band-Solution/theband/pull/761) | `burn/2` com linha de base, `Forecast`, as pessoas, o teto de consultas |
| [#762](https://github.com/The-Band-Solution/theband/pull/762) | as habilidades por pessoa — a metade que faltava da US4 |

## O que não foi feito

| Tarefa | Issue | Motivo | Destino |
|---|---|---|---|
| T033 | [#753](https://github.com/The-Band-Solution/theband/issues/753) | gates verdes ✅, PRs no padrão ✅, **revisão independente ✗** | **sprint 029**, como condição de entrada — pelo segundo sprint seguido |

## Entregáveis aceitos com ressalva

**Os cinco PRs foram incorporados com 0 revisões cada.** A decisão foi da pessoa
mantenedora em 2026-09-02, com o CI verde — e **CI verde não é revisão**: os
gates dizem que o código compila, passa e não regride, e não dizem que alguém leu
o desenho.

A lacuna está **declarada em cada PR**, como o princípio VII exige, e nunca
marcada como cumprida.

**É a segunda vez seguida.** A L95 nasceu disso no sprint 027, e reincidiu no
sprint que a registrou. Está anotado nas lições.

## Evidências

| O quê | Medida |
|---|---|
| `mix gates` no `development` depois de todos os merges | **código de saída 0** · 14 gates |
| código e teste acrescentados | 2 493 linhas em 15 arquivos |
| documentação | 3 473 linhas em 19 arquivos |
| arquivos de teste novos | 5 |
| módulos novos | `TheBand.Forecast`, `TheBand.WorkItems.TeamWork` |
| medidas declaradas em YAML | 5 → **7** |
| tipo de merge | **os cinco são merge commit** — conferido por `git rev-list --parents` |

## Dívida gerada

**O burn da página da pessoa parte de zero.** A correção equivalente foi feita
para a equipe neste sprint. Registrada em
[`docs/backlog/burn-da-pessoa-sem-linha-de-base.md`](../../backlog/burn-da-pessoa-sem-linha-de-base.md)
com os três motivos, e o terceiro é o que importa: na pessoa, talvez o recorte de
janela **seja** o desejado. Precisa ser decidido, não deduzido.

**O sprint rodou sem iteration no Projects v2** — o segundo seguido. Acrescentá-la
recria as existentes, e a L11 mediu o custo em 97 itens órfãos. A lacuna se
acumula, e resolvê-la é trabalho próprio.

**As user stories ficaram sem tipo.** `User Story` não existe na organização, e
tipá-las como `Feature` faria a regra de roteamento classificá-las erradamente.
Criar o tipo altera a configuração da organização e não foi autorizado.

## Lições deste sprint

### L98 — A lição que não vira regra reincide no sprint seguinte

A **L95** — pedir revisor não é obter revisão — nasceu no sprint 027 e
**reincidiu no 028**, com cinco PRs incorporados sem revisão. Escrever a lição
não mudou o comportamento; ela ficou no documento acumulado, e o documento é lido
ao **abrir** o sprint, não no momento de clicar o botão.

O mesmo aconteceu com o squash: **L75, L83 e L92**, e a terceira ocorreu depois de
as duas primeiras já estarem escritas.

**O que fazer diferente**: lição que descreve um ato repetível vira **regra no
`AGENTS.md` e campo obrigatório no artefato** onde o ato acontece. Foi o que se
fez com o tipo de merge no PR ([#763](https://github.com/The-Band-Solution/theband/pull/763)).
O registro acumulado guarda o **porquê**; o artefato carrega a **obrigação**.

### L99 — Conferir issue por issue achou o que planejar não achou

Ao fechar o sprint, a conferência de `gh issue list --state open` mostrou que
**T020 e T021 nunca foram implementadas**: a seção de pessoas tinha as tarefas e
não tinha as habilidades. A US4 estava pela metade, com o PR já incorporado e os
gates verdes.

Nenhum gate pega isso. Os testes provam o que existe, e não o que foi prometido —
uma seção ausente não tem teste que falhe.

**O que fazer diferente**: a conferência issue a issue **antes** de escrever a
review não é formalidade — é a única leitura que compara o prometido com o
entregue. Já está na DoD do sprint por causa da L96, e neste sprint ela funcionou
no sprint que a criou.

### L100 — Branch de documentação sem PR faz o código chegar sem a spec

Os PRs de código foram ramificados de `development`, e a branch com a spec, o
plano, as tarefas e o sprint **nunca teve PR**. Os três primeiros PRs saíram sem
os documentos que implementavam, e o defeito só apareceu quando um arquivo do
backlog sumiu da árvore de trabalho.

**O que fazer diferente**: ao ramificar para implementar, conferir que a branch de
origem **já está em `development`** — `git log development..<branch>` vazio — ou
abrir o PR dela antes. Um `git log` de uma linha responde.
