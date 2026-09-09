# Sprint 027 — A organização declara suas equipes

**Período**: 2026-09-01 a 2026-09-08 (cadência de uma semana, decidida em 2026-08-10)
**Herança**: [#621](https://github.com/The-Band-Solution/theband/issues/621) e
[#620](https://github.com/The-Band-Solution/theband/issues/620) — as duas user
stories da 050 **não aceitas** no
[sprint 026](../026-heranca-e-a-producao/aceitacao.md)
**Feature**: [055-equipes-declaradas](../../../specs/055-equipes-declaradas/spec.md) ·
[plan](../../../specs/055-equipes-declaradas/plan.md) ·
[contrato](../../../specs/055-equipes-declaradas/contracts/equipes-declaradas.md)

## Objetivo do sprint

**A plataforma passa a saber de quem são as pessoas que ela mede.** Hoje equipe
só nasce da coleta: não há como criar uma que o GitHub não conhece, pôr uma
dentro de outra, nem dizer que alguém saiu sem apagar o que fez enquanto esteve.

Antes disso, a herança: **o ensaio de restauração executado** e **o próximo
release cronometrado** — as duas coisas que a produção deve desde a v0.1.0.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md):

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L91** | Sprint 026 | as 18 issues foram criadas **antes** da implementação, e conferidas por contagem. Foi a lição que nasceu de duas features seguidas pularem esse passo |
| **L89** | Sprint 026 | revisão pedida **e conferida** pelo JSON no T015 — o comando de pedir sai zero mesmo sem pedir ninguém |
| **L90** | Sprint 026 | o T005 assere os **dois lados** da corrida: o vínculo que nasce e o que a perdedora devolve |
| **L81** | Sprint 025 | o T008 é a caça aos irmãos: derivar o padrão de "vigente" e varrer o repositório **antes** de entregar |
| **L77** | — | T004 e T011 nascem reprovando por ausência da função, não por sintaxe |
| **L60/XI** | — | o código de saída dos gates é lido **dentro** do log, em T001 e T015 |
| **L93** | Sprint 026 | a medição do release (herança H2) espera o `SIGTERM` do contêiner antigo — durante o deploy, duas versões atendem |

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

⚠️ **Limitação declarada: a iteration 027 não foi criada.** O campo de iteração
do projeto existe, e as iterations 023 a 026 estão lá — mas **com datas que não
batem com quando o trabalho aconteceu**:

| iteration | data no projeto | quando rodou |
|---|---|---|
| Sprint 025 | 2026-09-12 | 2026-08-29 |
| Sprint 026 | 2026-09-19 | 2026-08-29 a 09-01 |

Três semanas de diferença. **A plataforma lê sprint dessas datas** — é de lá que
sai `flow.throughput.rate`. E reconfigurar iterations **recria as existentes e
reatribui os itens** (L11/L72: 53 valores capturados, recriados e conferidos na
última vez).

Corrigir isso é trabalho com risco próprio, e entra como **pendência nomeada**
em vez de ser feito no meio deste sprint. Enquanto não for, a vazão medida sobre
este repositório está deslocada — e isso está dito, não escondido.

## Herança — primeira da fila

| # | O que | Issue | Estado |
|---|---|---|---|
| H1 | O ensaio de restauração, executado em produção | [#621](https://github.com/The-Band-Solution/theband/issues/621) | **bloqueador nomeado**: acesso ao painel do Dokploy |
| H2 | As três medidas do release — sessão sobrevive, janela, primeiro acesso | [#620](https://github.com/The-Band-Solution/theband/issues/620) | espera o próximo merge na `main` |

**Nenhuma das duas é código.** A H1 é execução; a H2 é cronometragem. Ambas
caem se ninguém as fizer no momento certo — e é por isso que estão em primeiro
lugar, não no fim.

## User stories selecionadas

| # | User story | Issue | Priority | Critérios |
|---|---|---|---|---|
| US1 | A organização cria a equipe que o GitHub não conhece | [#702](https://github.com/The-Band-Solution/theband/issues/702) | P1 | 4 |
| US2 | A pessoa entra, sai, e o que ela fez continua lá | [#703](https://github.com/The-Band-Solution/theband/issues/703) | P1 | 5 |
| US3 | Equipe dentro de equipe | [#704](https://github.com/The-Band-Solution/theband/issues/704) | P2 | 4 |

## Tarefas

| # | Tarefa | Atende | Issue | Estado |
|---|---|---|---|---|
| T001 | Abrir baseline dos gates | — | [#687](https://github.com/The-Band-Solution/theband/issues/687) | a fazer |
| T002 | O conceito da composição entra na ontologia | — | [#688](https://github.com/The-Band-Solution/theband/issues/688) | a fazer |
| T003 | A migração: a composição e o equívoco | — | [#689](https://github.com/The-Band-Solution/theband/issues/689) | a fazer |
| T004 | A violação: registrar saída não pode apagar | US2 | [#690](https://github.com/The-Band-Solution/theband/issues/690) | a fazer |
| T005 | Vincular pessoa, com papel e início | US2 | [#691](https://github.com/The-Band-Solution/theband/issues/691) | a fazer |
| T006 | Registrar a saída | US2 | [#692](https://github.com/The-Band-Solution/theband/issues/692) | a fazer |
| T007 | Registrar o equívoco, sem apagar | US2 | [#693](https://github.com/The-Band-Solution/theband/issues/693) | a fazer |
| T008 | Vigente passa a ter duas condições, em todo lugar | US2 | [#694](https://github.com/The-Band-Solution/theband/issues/694) | a fazer |
| T009 | A equipe da estrutura, ao lado da equipe de projeto | US1 | [#695](https://github.com/The-Band-Solution/theband/issues/695) | a fazer |
| T010 | A tela cria, e diz de onde a equipe veio | US1 | [#696](https://github.com/The-Band-Solution/theband/issues/696) | a fazer |
| T011 | A violação: o ciclo de comprimento 3 | US3 | [#697](https://github.com/The-Band-Solution/theband/issues/697) | a fazer |
| T012 | Compor e descompor, com a recusa que diz o caminho | US3 | [#698](https://github.com/The-Band-Solution/theband/issues/698) | a fazer |
| T013 | A estrutura nas duas telas | US3 | [#699](https://github.com/The-Band-Solution/theband/issues/699) | a fazer |
| T014 | As duas afirmações, quando coleta e declaração discordam | US1/US2 | [#700](https://github.com/The-Band-Solution/theband/issues/700) | a fazer |
| T015 | Gates verdes, PR no padrão e revisão CONFERIDA | — | [#701](https://github.com/The-Band-Solution/theband/issues/701) | a fazer |

**MVP**: T001 a T008 — o domínio correto, com o histórico que sobrevive. Sem tela
ainda.

## Fora do escopo deste sprint

- **O rollup de competências** ([#397](https://github.com/The-Band-Solution/theband/issues/397)) — depende desta feature. Juntar as duas esconderia qual quebrou;
- **A 049 (entrar com o GitHub)** — spec pronta, adiada por decisão de 2026-09-01. Ela volta como **pré-requisito** do wizard de setup, não como item de fila;
- **O painel da equipe** ([#504](https://github.com/The-Band-Solution/theband/issues/504) e [#507](https://github.com/The-Band-Solution/theband/issues/507)) — escopo decidido, **sem spec**. Entram quando tiverem;
- **A correção das datas das iterations** — risco próprio, ver acima;
- **As quatro rotações de segredo** — pendentes desde a v0.1.0, e são da pessoa mantenedora.

## Riscos e dependências

- **A H1 depende de acesso ao painel** que o time não tem. É o bloqueador nomeado
  que a regra exige para liberar trabalho novo — sem ele, nada avança nela;
- **A H2 depende de haver um release** neste sprint. Se não houver, ela não cai
  por esforço, cai por falta de ocasião — e isso precisa ser dito na review, não
  virar "não feito";
- **A renovação do certificado do domínio virou manual** (`§9-B` do runbook). Não
  vence neste sprint, mas some da memória se não for anotado;
- **O T008 é o que mais pode escapar.** Ele varre consultas existentes; o que a
  varredura não achar continua contando vínculo invalidado, e ninguém saberá qual.

## Definition of Done do sprint

- [ ] quality gates verdes, com `EXIT` lido **dentro** do log (L60)
- [ ] base de conhecimento válida, com o conceito novo **declarado em `modules:`** (#527)
- [ ] issues #687–#704 encerradas APÓS a aceitação
- [ ] `sprint-review.md` escrito
- [ ] `licoes-aprendidas.md` atualizado
- [ ] PRs com revisão pedida **e conferida pelo JSON** (L89)
