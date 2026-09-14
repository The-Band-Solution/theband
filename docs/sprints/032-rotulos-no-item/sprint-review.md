# Sprint 032 — Review

**Período**: 2026-09-13 (um dia) · **encerrado em 2026-09-13**
**Feature**: [065 — o rótulo como campo do item de trabalho](../../../specs/065-rotulos-no-item/spec.md)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | 3 executadas · **1 aceita** (pendente de confirmação) · **2 não aceitas** |
| Tarefas | 14 | 14 fechadas · **4 sem sucesso** (T005, T007, T011, T012) |
| Testes prometidos no `tasks.md` | 7 arquivos | **2** |
| `mix gates` | — | **`success`** — CI run [34779226200](https://github.com/The-Band-Solution/theband/actions/runs/34779226200) sobre `0ccf02b` |

**As três user stories foram executadas no dia, e só uma se sustenta pelos critérios.** A
listagem — o volume, a razão de a US1 ser P1 — está conforme em todo critério medido; o que
recusa a US1 é o **detalhe**, que a US prometia e ninguém olhou. A US2 recusa por um motivo
anterior ao código: a spec e o mecanismo chamam coisas diferentes de "rótulo".

## O que foi feito

| User story | Issue | Tarefas | O que chegou à tela |
|---|---|---|---|
| US1 — ver, na lista, como o time chamou cada item | [#904](https://github.com/The-Band-Solution/theband/issues/904) | T001–T003, T005–T007 | a oitava coluna de `/work`: o rótulo do campo em **sólido** (observado), o do prefixo do título em **hachura com contorno** (derivado), `no label` escrito onde não há nenhum, três por linha e `+N` que abre a issue. **Uma consulta** para 10, 100 ou 1 000 itens |
| US3 — o rótulo nunca vira conceito | [#906](https://github.com/The-Band-Solution/theband/issues/906) | T004, T008 | nada — é a regra que **não** muda: `bug` num item tarefa não o torna defeito; `prioridade:alta` sai como texto; `[Devops]` é rótulo e nunca tipo |
| US2 — ver a alegação ao lado do veredito | [#905](https://github.com/The-Band-Solution/theband/issues/905) | T011, T012 | **nada novo** — as duas tarefas foram fechadas "sem código", com a justificativa de que a divergência já aparecia por linha na tabela principal |
| — (FR-016, FR-017) | [#898](https://github.com/The-Band-Solution/theband/issues/898), [#899](https://github.com/The-Band-Solution/theband/issues/899) | T009, T010 | o repositório em **toda** linha das sub-listas do detalhe, com a marca `other repository` nas 5 (em 1 953) que cruzam; a ontologia no desenho — régua para `part_whole`, seta para `association` |

T001–T012 no PR [#907](https://github.com/The-Band-Solution/theband/pull/907) (16:59Z); a
reescrita do escopo da fase 4 no [#908](https://github.com/The-Band-Solution/theband/pull/908)
(19:56Z); a T014 fechada às 20:59Z com a evidência do CI.

## O que a aceitação achou, e o código não dizia

A avaliação do papel de Product Owner, em 2026-09-13, com evidência executada — os detalhes em
[`aceitacao.md`](aceitacao.md):

1. **O detalhe não cumpre o que a listagem cumpre.** O campo `labels` de `/work/issues/:id`
   mostra só os rótulos do campo do GitHub, como `badge-ghost`, **sem origem e sem o derivado**.
   Uma issue `[Devops] …` com rótulo `backend` mostra `backend` e `Devops` na lista, e só
   `backend` ao abrir. É o teste independente da própria US1, e ele falha. Nenhum dos três
   protótipos cobre esse campo — a correção volta ao protótipo antes do código;
2. **A US2 assenta num homônimo.** "Rótulo" na spec é o *label* do GitHub; "label" no mecanismo
   de divergência (`ConceptLabel`) é o **tipo declarado**. A issue-exemplo da US — rótulo `task`,
   conceito defeito — tem `divergence_kind: nil`: a plataforma **não a vê como divergência**.
   Nas 512 divergências reais, todas são `user_story_without_parts`; `label_vs_structure` existe
   no código e **nunca é produzido**. A linha mostra os dois lados e não diz que divergem nem
   qual foi seguido;
3. **O SC-002 não reproduz.** A spec diz 1 519 issues com prefixo reconhecido; a função entregue
   deriva **1 489** sobre os 5 033 títulos reais. Há **47** variantes de caixa (`[backend]` 13,
   `[DADOS]` 12, `[DevOps]` 7, `[FRONT]` 7, `[BACKEND]` 4, `[Back-End]` 2, `[Front-End]` 2) que
   não derivam, porque a comparação é sensível a caixa — coerente com o catálogo. 1 519 não é
   nem um nem outro número;
4. **Cinco arquivos de teste prometidos não existem**: `prefixos_test.exs` (T001), os testes de
   tela de T005, T007 e T012, e `divergencia_com_rotulo_test.exs` (T011). O #907 entregou dois
   arquivos de teste, não sete.

## Evidências

| O quê | Medida |
|---|---|
| `mix gates` | **`success`**, CI run 34779226200 sobre `0ccf02b` (passo *treze quality gates*) |
| `test/the_band/work_items/rotulos_na_listagem_test.exs` | **7 passed**, exit 0 |
| `test/the_band/work_items/prefixo_vira_rotulo_test.exs` | **9 passed**, exit 0 |
| custo da listagem | **1 consulta** para 10, 100 e 1 000 itens (teste T003 e banco real) |
| custo do detalhe | **46** consultas por render — a primeira versão da T009 subiu para 50 e foi pega |
| dado real | 5 033 issues · **2 811** sem rótulo nenhum · **238** com as duas origens · **1 489** derivam do prefixo · 512 divergências, todas `user_story_without_parts` |
| sondas do papel | duas de tela (LiveView renderizado sobre `cenario_real/1`) e uma só-leitura sobre o banco; instrumentos do papel, fora do repositório |

## O que não foi feito

| Tarefa | Issue | Motivo | Destino |
|---|---|---|---|
| T011 — rótulos nas divergências | [#900](https://github.com/The-Band-Solution/theband/issues/900) | fechada **sem código**: `list_divergences/2` não recebeu rótulos | `sro.non_successfully_performed_scrum_development_task`; **não reabrir** — nasce tarefa nova depois das três decisões da US2 |
| T012 — os dois lados e qual venceu | [#901](https://github.com/The-Band-Solution/theband/issues/901) | idem; a linha não diz que divergem nem qual foi seguido | idem |
| T005, T007 (parte) — os testes de tela | [#894](https://github.com/The-Band-Solution/theband/issues/894), [#896](https://github.com/The-Band-Solution/theband/issues/896) | a tela existe; o **teste** prometido não | testes devidos entram como tarefa do próximo sprint da US1 |
| T013 — conferir contra o protótipo | [#902](https://github.com/The-Band-Solution/theband/issues/902) | feita **lendo código, por quem implementou**; a T013 declara ela mesma que não olhou a tela renderizada | conferência do QA com captura real, inclusive em tons de cinza (SC-003, FR-015) |

## Entregáveis não aceitos

**US1** — falha no teste independente e em FR-001/FR-002 **no detalhe**; SC-003 e FR-015 sem
evidência. **Destino proposto**: próximo sprint backlog, em primeiro lugar, com quatro tarefas
novas — o campo `labels` do detalhe (protótipo antes), a conferência do QA, a decisão sobre as
47 variantes com a correção do SC-002, e os testes devidos.

**US2** — falha em AC1(b), AC3, SC-008 e no teste independente; AC2 ambígua. **Destino
proposto**: **product backlog**, não próximo sprint — tarefa sem critério decidido é retrabalho
anunciado. As três decisões estão em [`aceitacao.md`](aceitacao.md).

## A revisão independente

**Não houve.** #907 e #908: `reviewRequests` vazio, `reviews` vazio, fora do projeto. É *revisão
não pedida* — a pessoa mantenedora é `author` de registro e não escreveu o código, logo é
revisora legítima, mas o atestado não foi escrito. A aceitação do papel **é** a leitura
independente que o sprint teve, e ela achou os quatro itens acima.

## Dívida gerada

- **o número da spec** — SC-002 diz 1 519 e a medida é 1 489; a spec precisa da correção e da
  decisão sobre as variantes de caixa (recomendação do papel: manter sensível a caixa, que é a
  regra do catálogo, e escrever 1 489);
- **o protótipo não está registrado** como o papel de Design exige — sem
  `specs/065-rotulos-no-item/prototipo/PROMPT.md`, sem item em `docs/backlog/`; os três links
  vivem só no corpo da #903;
- **sete critérios sem user story** — FR-011, FR-015 a FR-018, SC-009, SC-010: T009 e T010 não
  têm `[US]`, e nenhum entregável os avalia. Medidos de passagem e conformes no que dava; a marca
  `other repository` **não foi exercitada em tela**;
- **`label_vs_structure`** existe em `ConceptLabel` e nunca é produzido — código que promete
  um caso que a plataforma não computa.

## Lições deste sprint

Para o [registro acumulado](../licoes-aprendidas.md):

- **L109** — tarefa fechada "sem código" redefinindo o alvo, com o critério da spec intacto,
  é entregável não aceito disfarçado de tarefa feita;
- **L110** — a spec nomeou um mecanismo existente com uma palavra que ele usa para outra
  coisa, e o exemplo da US nunca foi conferido no dado;
- **L30, aplicada tarde** — os números das issues foram conferidos contra o GitHub; o número
  do SC-002, não;
- **L95, reincidiu** — dois PRs sem revisor e fora do projeto, no mesmo dia em que outros seis
  nasceram assim (ver a L95).
