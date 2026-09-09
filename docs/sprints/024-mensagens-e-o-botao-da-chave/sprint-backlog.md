# Sprint 024 — Mensagens e o botão da chave

**Período**: 2026-08-28 a 2026-09-04
**Features**: [047-mensagens-internacionalizadas](../../../specs/047-mensagens-internacionalizadas/spec.md) e
[048-botao-sem-chave-desabilitado](../../../specs/048-botao-sem-chave-desabilitado/spec.md)
**Planos**: [047/plan.md](../../../specs/047-mensagens-internacionalizadas/plan.md) ·
[048/plan.md](../../../specs/048-botao-sem-chave-desabilitado/plan.md)

## Objetivo do sprint

Tudo o que a plataforma fala às pessoas sai do código e entra num catálogo com
verificação nos gates (047), e os botões de geração dizem ANTES do clique quando
falta a chave do provedor — com a guarda de domínio que a medição revelou faltar
(048). Duas features, duas branches, dois PRs — nunca misturadas (constituição).

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), consideradas neste sprint:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| L60 | Sprint 016/022 | forma completa em todo gate: `> log 2>&1; echo "EXIT=$?" >> log` |
| L71 | Sprint 022 | busca dirigida nos dois planos: 047 prova que NENHUM teste de texto quebra (msgid = frase atual); 048 mapeia os testes de gerar_perfil e run_now |
| L03 | Sprint 001 | verificador da 047 e guarda da 048 nascem pelo teste da violação |
| L38 | Sprint 009 | 048: 1 leitura de credencial por mount, nunca por linha; 047: zero consulta |
| L61 | Sprint 021 | 047: lacuna de tradução cai no msgid (nunca chave crua); 048: sem chave vira ramo com frase, não erro tardio |
| L72 | Sprint 023 | **aplicada preventivamente**: a iteration 024 foi criada reenviando as três vigentes, com as 34 atribuições capturadas ANTES e reatribuídas DEPOIS, conferidas por consulta (15+19 antes = 15+19 depois) |
| L75 | Sprint 023 | conferência por CONTEÚDO antes de qualquer squash-merge; foi ela que resgatou a emenda 1.6.0 (#571) horas antes deste sprint |

## Sprint no GitHub

**Iteration**: Sprint 024 — Mensagens e o botão da chave · 2026-09-05 · 7 dias (id `1dbd69cf`)
**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Nota de calendário**: as datas da iteration seguem a grade do campo (022 e 023
ocupam até 2026-09-04); o período REAL do sprint é o do cabeçalho deste documento.

**Reparo preventivo registrado (L72)**: acrescentar a 024 exige reenviar a lista
inteira — os ids `a00ce208`/`a61c4aa5` viraram `19bfe13e`/`d56dc05c` e os 34 itens
foram reatribuídos na hora, conferidos por consulta.

**Limitações herdadas**: tipos `Epic`/`User Story` seguem inexistentes na
organização (criar exige aval); hierarquia por sub-issues não usada — tarefa
referencia a US no corpo. `Priority` do projeto só tem P0/P1/P2 — a US3 da 047
(P3 na spec) recebe P2 no campo, com a prioridade real dita aqui.

## User stories selecionadas

| # | User story | Feature | Issue | Priority | Estimate | Critérios |
|---|---|---|---|---|---|---|
| US1 | Toda mensagem de erro sai de arquivo de tradução | 047 | [#573](https://github.com/The-Band-Solution/theband/issues/573) | P1 | 5 | 3 |
| US2 | Mensagens do sistema no mesmo regime | 047 | [#574](https://github.com/The-Band-Solution/theband/issues/574) | P2 | 3 | 2 |
| US3 | Um idioma escolhido, dois disponíveis | 047 | [#575](https://github.com/The-Band-Solution/theband/issues/575) | P2 (P3 na spec) | 3 | 2 |
| US1 | O botão desabilitado diz o que falta | 048 | [#587](https://github.com/The-Band-Solution/theband/issues/587) | P1 | 3 | 5 |

`Priority` é a *importance* da SRO; `Estimate` é a *complexity*. Em branco =
desconhecido, não zero.

## Tarefas

| # | Tarefa | Atende | Issue | Estimate | Estado |
|---|---|---|---|---|---|
| 047/T001 | Abrir baseline dos gates | US1 | [#576](https://github.com/The-Band-Solution/theband/issues/576) | 1 | feito |
| 047/T002 | Configurar locales e domínios do catálogo | US1 | [#577](https://github.com/The-Band-Solution/theband/issues/577) | 1 | feito |
| 047/T003 | Verificador de literais, pela violação | US1 | [#578](https://github.com/The-Band-Solution/theband/issues/578) | 3 | feito |
| 047/T004 | O gate mensagens no catálogo | US1 | [#579](https://github.com/The-Band-Solution/theband/issues/579) | 1 | feito |
| 047/T005 | As mensagens da 045 migram sem mudar um byte | US1 | [#580](https://github.com/The-Band-Solution/theband/issues/580) | 2 | feito |
| 047/T006 | Flashes de erro dos LiveViews para errors | US1 | [#581](https://github.com/The-Band-Solution/theband/issues/581) | 5 | feito |
| 047/T007 | Confirmações e avisos para sistema | US2 | [#582](https://github.com/The-Band-Solution/theband/issues/582) | 3 | feito |
| 047/T008 | Pendências de tela, medidas e nomeadas | US2 | [#583](https://github.com/The-Band-Solution/theband/issues/583) | 1 | feito |
| 047/T009 | O relatório de lacunas | US3 | [#584](https://github.com/The-Band-Solution/theband/issues/584) | 2 | feito |
| 047/T010 | A troca de idioma provada | US3 | [#585](https://github.com/The-Band-Solution/theband/issues/585) | 2 | feito |
| 047/T011 | Gates verdes e PR no padrão | US3 | [#586](https://github.com/The-Band-Solution/theband/issues/586) | 1 | feito |
| 048/T001 | Abrir baseline dos gates | US1 | [#588](https://github.com/The-Band-Solution/theband/issues/588) | 1 | feito |
| 048/T002 | A guarda do domínio, pela violação | US1 | [#589](https://github.com/The-Band-Solution/theband/issues/589) | 2 | feito |
| 048/T003 | A página da pessoa diz antes do clique | US1 | [#590](https://github.com/The-Band-Solution/theband/issues/590) | 3 | feito |
| 048/T004 | A geração mensal diz antes, tenant-only | US1 | [#591](https://github.com/The-Band-Solution/theband/issues/591) | 2 | feito |
| 048/T005 | Gates verdes e PR no padrão | US1 | [#592](https://github.com/The-Band-Solution/theband/issues/592) | 1 | feito |

Tarefa não recebe `Priority`: herda a da user story que atende.

Estados: `a fazer` · `em andamento` · `feito` · `bloqueado` · `não iniciado`

## Fora do escopo deste sprint

- **Texto HEEx das telas (notices, estados vazios, títulos)** — fica ENUMERADO em
  `specs/047-mensagens-internacionalizadas/pendencias.md` (T008), queimado em
  sprints futuros; o verificador v1 cobre os ralos de `put_flash` (fronteira do
  contrato).
- **Tradução pt completa** — nasce pelas recusas (T010); o resto fica visível no
  relatório de lacunas, nunca silencioso.
- **050 (produção)** — especificada e adiada por decisão da pessoa mantenedora
  ("faça o deploy depois").
- **049 (entrar com GitHub)** — depende da 050.
- **#568 (gestão da marca de administrador)** — backlog, precisa de spec.
- **PubSub de credencial (048)** — rejeitado no plano: problema não existe
  (princípio VIII).

## Riscos e dependências

- 047/T006 toca 12 arquivos com 55 chamadas — o risco é mudar UM byte de texto;
  a defesa é a suíte inteira como sentinela (L71) e o contrato que proíbe.
- O gate novo da 047 nasce vermelho de propósito até T007 — a run completa dos
  gates só é cobrada em T011; PRs intermediários não existem (um PR por feature,
  no fim dela).
- 048 muda o contrato de `Profiles.request/3` — quem mais o chama precisa tratar
  `:sem_chave` (busca dirigida no plano diz: só as duas telas).
- As duas features tocam `people_live/show.ex` — 048 entra DEPOIS do merge da 047
  ou faz rebase; nunca as duas abertas sobre o mesmo arquivo sem ordem declarada.

## Definition of Done do sprint

Além da DoD por tarefa:

- [x] quality gates verdes nas duas branches (forma L60, EXIT no log) — 14/14 nas duas, EXIT=0
- [x] base de conhecimento válida (parte dos gates)
- [x] issues #573–#592 encerradas à mão com evidência (PRs no padrão 1.6.0 não fecham sozinhos)
- [x] `sprint-review.md` escrito
- [x] `licoes-aprendidas.md` atualizado — L76–L79
