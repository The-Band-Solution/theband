# Sprint 007 — destravar a sincronização presa

**Período**: 2026-08-12 a 2026-08-18 (cadência de uma semana)
**Feature**: [008 — destravar sync presa](../../specs/008-destravar-sync-presa/spec.md)
**Plano**: [plan.md](../../specs/008-destravar-sync-presa/plan.md) ·
**Origem**: [#175](https://github.com/The-Band-Solution/theband/issues/175), product backlog
**Análise**: rodada antes do código, e **mudou a decisão central**

## Objetivo do sprint

Ao fim deste sprint, uma coleta que morreu **deixa de bloquear a ferramenta** — sem SQL, e sem
ninguém precisar abrir a tela.

Hoje o índice único que impede duas coletas simultâneas vira bloqueio permanente quando o trabalho
morre. **Duas execuções já foram destravadas à mão**, e o procedimento está registrado em
[RETOMAR.md](../RETOMAR.md). Precisar de SQL duas vezes é o argumento do sprint.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), 33 lições. As que entram como **restrição**:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L02** | Sprint 001 | é a lição que **derrubou o resgate automático**: coleta duplicada produz número plausível e errado. Ver a seção abaixo |
| **L08** | Sprint 002 | contrato escrito antes da primeira função pública, e **corrigido** quando a implementação mostrou que faltava uma terceira função |
| **L11** | Sprint 002 | **não** vou tocar a configuração de iterations |
| **L18** | Sprint 003 | critério atendido não é suficiente: a aceitação avalia os 13 SC com evidência |
| **L21** | Sprint 004 | F1 sozinha não entrega nada visível — decisão sem gatilho não destrava nada, e é por isso que F2 está no mesmo sprint |
| **L22**, **L23** | Sprint 004 | gate por **código de saída**, `mix gates`, sem `\| tail` |
| **L26** | Sprint 004 | casar o envelope certo: aqui o análogo é conferir o **resultado** do `Oban.insert`, que hoje vai para o vazio |
| **L27** | Sprint 005 | ciclo completo antes do código — e é a terceira feature seguida na ordem |
| **L29** | Sprint 005 | o motivo distingue falha transitória de permanente; um motivo genérico é o defeito que custou 899 issues |
| **L30** | Sprint 005 | os números do sprint vêm do banco, não de estimativa: 32 execuções, 5 descartados, 1 órfão de três dias |
| **L33** | Sprint 006 | a pergunta "o que a tela diz no dia seguinte" foi feita, e virou a carência de 1 minuto |

**A L02 é a que decidiu o desenho, e vale dizer como.** O plano tinha aceito configurar o resgate
automático de trabalho órfão com um `rescue_after` de 60 minutos — 3,7× a coleta mais longa medida.
A análise perguntou se existia proteção **além** do tempo, e a leitura da fonte respondeu que não:

```elixir
# deps/oban/lib/oban/engines/basic.ex:189
where([j], j.state == "executing" and j.attempted_at < ^cut)
```

Nenhuma verificação de nó vivo. A coleta cresce com o número de repositórios, e no dia em que passar
de 60 minutos existem **duas execuções da mesma coleta**, cada uma funcionando. É exatamente a L02 —
32 registros no lugar de 16, e o número passou por correto.

**O resgate saiu do desenho.** Órfão é encerrado, e a coleta nova recoleta sem duplicar linha, porque
a gravação é por chave natural.

## O terceiro caminho de travamento, que ninguém tinha visto

A mesma análise leu a abertura da execução e achou isto: `Repo.insert()` e `Oban.insert()` são
operações separadas, e **o resultado da segunda é descartado**. Se a criação do trabalho falhar, o
registro fica `running` sem nada para executá-lo.

**Não está nos 5 descartados nem no órfão medido** — porque ninguém saberia se já aconteceu. É a
T006, e é o tipo de defeito que só aparece lendo o código com a pergunta certa.

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteração**: **não existe para este sprint**, e é limitação declarada — não esquecimento.
Configurar iterations do ProjectV2 recria as existentes (L11), e já custou reatribuir 96 itens. Os
sprints 003 a 007 rodam sem iteração própria pelo mesmo motivo.

**Tipos**: a organização tem `Task`, `Bug` e `Feature`, e **não** tem `Epic` nem `User Story`. Épico
e user stories são tipados `Feature`, como nos sprints anteriores. A hierarquia carrega o que o tipo
não carrega.

## User stories selecionadas

| # | User story | Épico | Issue | Priority | Estimate | Estado |
|---|---|---|---|---|---|---|
| US1 | Coletar de novo depois de uma falha | [#198](https://github.com/The-Band-Solution/theband/issues/198) | [#199](https://github.com/The-Band-Solution/theband/issues/199) | **P0** | 13 | a fazer |
| US2 | Entender por que a execução morreu | [#198](https://github.com/The-Band-Solution/theband/issues/198) | [#200](https://github.com/The-Band-Solution/theband/issues/200) | **P0** | 3 | a fazer |
| US3 | Encerrar à mão o que a plataforma não prova | [#198](https://github.com/The-Band-Solution/theband/issues/198) | [#201](https://github.com/The-Band-Solution/theband/issues/201) | P1 | 5 | a fazer |

**US1 e US2 são P0, e é a primeira vez neste projeto.** A *importance* aqui não é preferência: sem
elas a ferramenta fica inutilizável e a única saída é SQL no banco de produção. US3 é P1 porque
cobre o caso que a plataforma não consegue provar — real, e menos frequente.

`Priority` é a *importance* da SRO; `Estimate` é a *complexity*. Campo em branco significa
**desconhecido**, nunca zero.

## Tarefas

Detalhadas em [008/tasks.md](../../specs/008-destravar-sync-presa/tasks.md). Cada tarefa é filha da
**user story que ela atende** — nunca do épico: tarefa sob épico viola `sro.rule07`.

| # | Tarefa | Atende | Issue | Estimate | Fase | Estado |
|---|---|---|---|---|---|---|
| T001 | Registrar quem encerrou a execução | US1 | [#202](https://github.com/The-Band-Solution/theband/issues/202) | 2 | F1 | a fazer |
| T002 | Achar o trabalho de uma execução | US1 | [#203](https://github.com/The-Band-Solution/theband/issues/203) | 3 | F1 | a fazer |
| T003 | Decidir se a execução está presa | US1 | [#204](https://github.com/The-Band-Solution/theband/issues/204) | 5 | F1 | a fazer |
| T004 | Dizer por que a execução morreu | US2 | [#205](https://github.com/The-Band-Solution/theband/issues/205) | 3 | F1 | a fazer |
| T005 | Não mudar o encerramento já feito | US1 | [#206](https://github.com/The-Band-Solution/theband/issues/206) | 2 | F1 | a fazer |
| T006 | Encerrar quando o trabalho não nasce | US1 | [#207](https://github.com/The-Band-Solution/theband/issues/207) | 3 | F2 | a fazer |
| T007 | Reconciliar a cada cinco minutos | US1 | [#208](https://github.com/The-Band-Solution/theband/issues/208) | 3 | F2 | a fazer |
| T008 | Encerrar a execução presa pela tela | US3 | [#209](https://github.com/The-Band-Solution/theband/issues/209) | 5 | F3 | a fazer |
| T009 | Dizer quem encerrou a execução | US3 | [#210](https://github.com/The-Band-Solution/theband/issues/210) | 2 | F3 | a fazer |

Tarefa não recebe `Priority`: herda a da user story que atende.

**Total: 28 de complexity, nove tarefas.**

## Escopo confirmado

**Feature 008 completa — F1 a F3, T001 a T009.**

**O MVP é F1+F2**, e resolve a issue #175 inteira: o bloqueio sai sozinho, sem SQL e sem ninguém
abrir a tela. F3 acrescenta o caso que a plataforma não consegue provar — o trabalho consta como
executando e quem administra sabe que o processo morreu.

**F1 sozinha não entrega nada visível**, e está declarado: decisão sem gatilho não destrava nada. É
a L21, e é por isso que F2 não é opcional.

## Fora do escopo deste sprint

| Fora | Por quê |
|---|---|
| **resgate automático de trabalho órfão** | decide por tempo sem saber se o processo vive; a constante envelhece com a coleta — R1, e é a L02 |
| cancelar coleta **em andamento** | é outra pergunta: parar o que está vivo, e ninguém pediu |
| painel de trabalhos da fila | a tela mostra coleta, não infraestrutura |
| repetir a coleta automaticamente | quem decide tentar de novo é quem administra; automatizar esconderia falha permanente |
| fila própria para a reconciliação | ela compete por slot em `ingestion` e, com 5 coletas, espera — atrasa, não impede |
| estado `stuck` | `interrupted` serve; a distinção vive no motivo e no autor |
| **página de detalhe da pessoa** | pedida durante este sprint e registrada em [#211](https://github.com/The-Band-Solution/theband/issues/211) — entra no próximo, com ciclo próprio |

## Riscos e dependências

| Risco | Mitigação |
|---|---|
| **encerrar coleta viva** — o defeito oposto, e pior que o problema | a decisão exige ausência de trabalho ativo, nunca idade; o teste insere job `executing` **de verdade** |
| lista de estados ativos escrita de memória | são **cinco**, derivados de `Oban.Job.states/0`; o teste falha se o Oban acrescentar estado |
| encerrar execução que acabou de começar | carência de 1 minuto, três ordens de grandeza acima da corrida real |
| o motivo apagar a diferença entre falha do momento e permanente | motivo por causa, e o teste exige textos **diferentes** — L29 |
| gatilho automático apagar decisão humana | age só sobre `running`; o teste encerra por pessoa e reconcilia depois |
| a reconciliação esperar slot na fila | aceito e declarado: atrasa o destravamento, não o impede |

**Nenhuma dependência de outra branch.** A `009-destravar-sync-presa` sai de `main`, com os
artefatos já commitados. O [PR #197](https://github.com/The-Band-Solution/theband/pull/197) — a
tagline — está aberto e não bloqueia: nenhum arquivo em comum.

## Definition of Done do sprint

- [ ] `mix gates` verde pelo **código de saída** — dez gates
- [ ] V1 a V9 do [quickstart](../../specs/008-destravar-sync-presa/quickstart.md) verificados
- [ ] o job órfão de 2026-08-09 **encerrado pela plataforma**, não por SQL — é a prova no dado real
- [ ] as nove issues encerradas ou repriorizadas com justificativa
- [ ] PR com revisor pedido e **conferido** por `requested_reviewers` (L14), ligado ao projeto
- [ ] `sprint-review.md` escrito, separando feito de não feito
- [ ] `licoes-aprendidas.md` atualizado
- [ ] `aceitacao.md` com os 13 SC avaliados um a um
