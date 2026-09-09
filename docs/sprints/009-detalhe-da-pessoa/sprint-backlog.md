# Sprint 009 — o detalhe da pessoa

**Período**: 2026-08-12 a 2026-08-18 (cadência de uma semana)
**Feature**: [010 — detalhe da pessoa](../../../specs/010-detalhe-da-pessoa/spec.md)
**Plano**: [plan.md](../../../specs/010-detalhe-da-pessoa/plan.md)
**Origem**: [#211](https://github.com/The-Band-Solution/theband/issues/211), pedida durante o sprint 007
**Análise**: rodada antes do código, **seis correções**, a crítica sendo de **fronteira**

## Objetivo do sprint

Ao fim deste sprint, clicar numa pessoa mostra o que a plataforma sabe dela — **e o que ela recusou
afirmar**.

São **88 evidências** de vínculo pessoa-equipe e **zero** vínculos materializados. A tela existe para
mostrar as três coisas: o que a origem declarou, que a plataforma não promoveu, e **por quê**.

## Lições aplicadas

Do [registro acumulado](../licoes-aprendidas.md), 37 lições. As que entram como **restrição**:

| Lição | Origem | Como está sendo aplicada |
|---|---|---|
| **L08** | Sprint 002 | contrato antes da primeira função pública — e ele **recusa** três funções de propósito |
| **L11** | Sprint 002 | sem tocar a configuração de iterations |
| **L18** | Sprint 003 | a aceitação avalia os 13 SC com evidência, nunca a suíte verde |
| **L21** | Sprint 004 | F1 e F2 são consultas sem consumidor; a página está no mesmo sprint |
| **L22**, **L23** | Sprint 004 | gate por código de saída — e desde a #229 ele **vale de verdade** |
| **L25** | Sprint 004 | a rota usa identificador **interno**; login é da origem, muda, e não é único |
| **L27** | Sprint 005 | ciclo completo antes do código — quinta feature seguida |
| **L28** | Sprint 005 | "a função devolve" e "a tela mostra" são afirmações diferentes: os testes da página vão ao HTML |
| **L30** | Sprint 005 | os números vêm do banco: 75 pessoas, 88 evidências, 4 232 designações, 4 241 autorias |
| **L32** | Sprint 006 | a tela **não afirma** o que não observou: a não promoção é explicada com base no dado |
| **L34** | Sprint 007 | **duas** opções com nomes distintos — `assigned_to` e `authored_by` —, nunca uma `person_id` |
| **L36** | Sprint 008 | quando duas medidas parecem se contradizer, o elo é hipótese — e a análise desta feature isolou seis antes de afirmar |

**A L34 entra antes de doer.** Ela nasceu de "vivo" significar duas coisas na feature 008; aqui a
palavra perigosa é *"as issues da pessoa"*, que são **três** conjuntos — designadas, abertas, e a
união. A união é a que não corresponde a nada, e FR-009 a proíbe.

## Sprint no GitHub

**Projeto**: [The Band](https://github.com/orgs/The-Band-Solution/projects/2)

**Iteração**: **não existe para este sprint** — limitação declarada. Configurar iterations do
ProjectV2 recria as existentes (L11), e já custou reatribuir 96 itens.

**Tipos**: a organização tem `Task`, `Bug` e `Feature`. Épico e user stories são tipados `Feature`.

## User stories selecionadas

| # | User story | Épico | Issue | Priority | Estimate | Estado |
|---|---|---|---|---|---|---|
| US1 | Ver o que a plataforma sabe de uma pessoa | [#233](https://github.com/The-Band-Solution/theband/issues/233) | [#234](https://github.com/The-Band-Solution/theband/issues/234) | P1 | 8 | a fazer |
| US2 | Ver as equipes, e o que a plataforma recusou promover | [#233](https://github.com/The-Band-Solution/theband/issues/233) | [#235](https://github.com/The-Band-Solution/theband/issues/235) | P1 | 8 | a fazer |
| US3 | Ver o trabalho: issues e repositórios | [#233](https://github.com/The-Band-Solution/theband/issues/233) | [#236](https://github.com/The-Band-Solution/theband/issues/236) | P1 | 8 | a fazer |

**As três são P1, e nenhuma é P0.** Diferente do sprint 008: ali a ferramenta ficava inutilizável e a
saída era SQL. Aqui a plataforma funciona — o que falta é **enxergar** o que ela já sabe.

## Tarefas

Detalhadas em [010/tasks.md](../../../specs/010-detalhe-da-pessoa/tasks.md). Cada tarefa é filha da
**user story que ela atende** — nunca do épico.

| # | Tarefa | Atende | Issue | Estimate | Fase | Estado |
|---|---|---|---|---|---|---|
| T001 | Listar as equipes que a origem declara | US2 | [#237](https://github.com/The-Band-Solution/theband/issues/237) | 3 | F1 | a fazer |
| T002 | Contar os papéis cadastrados | US2 | [#238](https://github.com/The-Band-Solution/theband/issues/238) | 2 | F1 | a fazer |
| T003 | Contar designações e autorias separadas | US3 | [#239](https://github.com/The-Band-Solution/theband/issues/239) | 3 | F2 | a fazer |
| T004 | Filtrar issues por pessoa, com dois nomes | US3 | [#240](https://github.com/The-Band-Solution/theband/issues/240) | 3 | F2 | a fazer |
| T005 | Agrupar os repositórios da pessoa | US3 | [#241](https://github.com/The-Band-Solution/theband/issues/241) | 3 | F2 | a fazer |
| T006 | Abrir a página da pessoa | US1 | [#242](https://github.com/The-Band-Solution/theband/issues/242) | 5 | F3 | a fazer |
| T007 | Ligar o nome à página | US1 | [#243](https://github.com/The-Band-Solution/theband/issues/243) | 2 | F3 | a fazer |
| T008 | Dizer o que a plataforma não promoveu | US2 | [#244](https://github.com/The-Band-Solution/theband/issues/244) | 5 | F3 | a fazer |
| T009 | Mostrar o trabalho sem somar | US3 | [#245](https://github.com/The-Band-Solution/theband/issues/245) | 5 | F3 | a fazer |

**Total: 31 de complexity, nove tarefas.** É o maior desde o sprint 005, e a razão é a tela: três
seções, cada uma com uma distinção que não pode ser achatada.

## O que a análise mudou, antes do código

| # | Achado | Correção |
|---|---|---|
| **A1** | `repositories_of_person/2` devolve identificador e contagens, e **nada** diz o nome do repositório. O nome é de **CMPO**, uma **terceira** fronteira que o plano não declarava. A implementação resolveria por linha, violando FR-016 | CMPO no plano e em T005/T009; o nome vem de **uma** consulta virando mapa |
| A2 | dois `no_longer_observed_at` — issue e designação — sem regra para o cruzamento | FR-008a: **a issue manda** |
| A3 | o plano dizia **quatro** consultas; são **oito**, e V8 media "um número que não cresce" | oito, **aserido**, com a tabela do que é cada uma |
| A4 | o terceiro caso da explicação era plausível e sem conteúdo | verificável: ninguém alocou papel a esta pessoa nesta equipe |
| A5 | as 288 issues sem autor eram afirmação sem verificação | SC-009a e V10: a soma das autorias fecha com 4 241 |
| A6 | o componente era justificado por três usos | são **dois**, e fica no limiar — declarado |

**O A1 não é sobre lógica, é sobre registro.** `repository_live/show.ex` já compõe três fronteiras,
então não havia violação — mas um plano que afirma duas autoriza a próxima pessoa a cruzar uma sem
pensar.

## Escopo confirmado

**Feature 010 completa — F1 a F3, T001 a T009.**

As três fases são o MVP: F1 e F2 são consultas sem consumidor, e a **L21** diz que isso não é
funcionalidade entregue.

**O corte possível é por user story**, na ordem da spec. US1 sozinha já entrega o clique que hoje não
existe.

## Fora do escopo deste sprint

| Fora | Por quê |
|---|---|
| cadastrar papel, ou alocar pessoa a papel | é a #99 e a #100; esta feature **exibe** a ausência |
| promover a evidência a vínculo | depende do papel existir |
| módulo que monte a página | dissolveria a fronteira entre EO, WorkItems e CMPO — princípio IX |
| um lugar para as 288 issues sem autor | não têm pessoa |
| contribuição por commit, ou revisão de PR | não é coletado hoje |
| editar dado da pessoa | criaria uma segunda verdade sobre o que a origem declara |

## Riscos e dependências

| Risco | Mitigação |
|---|---|
| **exibir a soma de designação com autoria** | FR-009; o teste procura o número proibido — `refute html =~ ">19<"` |
| ler nível de acesso como papel | FR-004; o teste faz `refute` sobre a palavra na seção de equipes |
| resolver o nome do repositório por linha | uma consulta virando mapa; o teste **conta** as consultas e exige oito |
| a explicação da não promoção envelhecer | o motivo vem do dado, com o terceiro caso previsto antes de existir |
| vínculo ausente desaparecer da tela | FR-006; o teste marca a evidência e exige que apareça com a data |
| issue ausente contar por causa da designação | FR-008a; o teste monta o cruzamento |

**Nenhuma dependência de outra branch.** A `014-detalhe-da-pessoa` sai de `main`, e não há migração.

## Definition of Done do sprint

- [ ] `mix gates` verde pelo **código de saída** — dez gates
- [ ] V1 a V10 do [quickstart](../../../specs/010-detalhe-da-pessoa/quickstart.md) verificados
- [ ] **no dado real**: a página de uma das 75 pessoas abre e mostra as três seções, com a explicação
      da não promoção
- [ ] a invariante das autorias conferida: a soma fecha com **4 241**
- [ ] as nove issues encerradas ou repriorizadas com justificativa
- [ ] PR com revisor pedido e **conferido** por `requested_reviewers` (L14), ligado ao projeto
- [ ] `sprint-review.md` escrito, separando feito de não feito
- [ ] `licoes-aprendidas.md` atualizado
- [ ] `aceitacao.md` com os 13 SC avaliados um a um
- [ ] **a tela olhada em 360 px** — e não só asserida em HTML, que é a dívida que atravessou três
      sprints
