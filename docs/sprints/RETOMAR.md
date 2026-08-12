# Retomar — estado em 2026-08-12, fim do sprint 010

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

## Onde o trabalho parou

**Seis sprints fechados em sequência**, todos com o ciclo Spec Kit completo antes do código:

| Sprint | Feature | Estado |
|---|---|---|
| 005 | 005 regras de mapeamento · 006 detalhe da issue | fechado |
| 006 | 007 marca de trabalho no repositório | fechado, 10 de 11 critérios |
| 007 | 008 destravar a sincronização presa | fechado, 14 de 14 |
| 008 | 009 a marca de inacessível se cura | fechado, 12 de 12 |
| 009 | 010 detalhe da pessoa | fechado **com atraso** — review e lições escritas no sprint 010 |
| 010 | 011 de quem cada issue é parte | fechado, 12 de 13 |

`main` em `20a1468`, e o **PR [#264](https://github.com/The-Band-Solution/theband/pull/264) está
aberto** — `MERGEABLE · CLEAN`, CI verde, revisão pedida ao time `the-band`.

## O que a plataforma sabe hoje

```
135 repositórios observados · 4529 issues vigentes · 3 organizações · 75 pessoas
1630 issues com pai · 2899 sem · 1666 vínculos de decomposição
atendimento 1143 · violação da sro.rule07 293 · composição 197 · não nomeada 33
```

**A soma das quatro relações fecha em 1 666 exatamente** — e foi ela que pegou o erro da primeira
medida, que confundiu vínculo com issue.

## O que precisa de você, e eu não consigo fazer

**Três coisas, e as três precisam da plataforma no ar ou de olho humano.**

### 1. A tela em 360 px — quinto sprint com este item

| Tela | Feature |
|---|---|
| a marca de trabalho na lista de repositórios | 007, SC-009 |
| a célula de estado que cresceu | 009, T009 |
| a página da pessoa | 010, SC-011 |
| **a coluna `part of`** | **011, SC-010** |

As quatro estão asseridas em HTML e **nenhuma foi olhada**. Asserção em markup não substitui olhar.

### 2. A prova da feature 009 no dado real

Uma coleta com a origem respondendo precisa limpar as **39** marcas de inacessível e trazer
`leds-conectafapes-prestacao-de-contas` de 9 para as **11** issues que a origem tem.

```bash
export THE_BAND_MASTER_KEY=...   # no seu terminal, nunca no chat
mix phx.server                   # e disparar a sincronização em /syncs
```

### 3. Duas conferências de tela no dado real

- `/people/<id>` de `vinicius-je`: **350 e 609, nunca 959** — a soma é proibida;
- `/work/repositories/<id>` de um repositório com issues decompostas: a coluna `part of`, com as 293
  avisando sobre a `sro.rule07`.

**Exigem a chave mestra, que eu não peço nem recebo** — e é por isso que estes itens estão declarados
como pendentes em vez de contados como cumpridos.

## Os três defeitos achados no sprint 010, todos fora da feature

| # | O que é | Por que importa |
|---|---|---|
| [#261](https://github.com/The-Band-Solution/theband/issues/261) | `fetch_parent/2` com `limit: 1` **sem `order_by`** | pai arbitrário nas 36 issues com mais de um, e **esconde** que há outro |
| [#262](https://github.com/The-Band-Solution/theband/issues/262) | filha promovida a **defeito** fora das três listas do detalhe do pai | **33 vínculos** invisíveis, sem erro nenhum |
| [#263](https://github.com/The-Band-Solution/theband/issues/263) | vínculo de decomposição **nunca** marcado como ausente | a tela sabe exibir; o dado nunca chega nesse estado |

**Os três nasceram de medir para escrever a spec**, não de rodar teste. Nenhum produz erro: os três
produzem tela que parece completa.

## O que mudou no processo, e vale ler antes de abrir o próximo sprint

**O sprint 009 fechou sem review, sem aceitação e sem lições** — e a falta só apareceu quando o sprint
010 citou as lições **L38** e **L39** como restrição, de um arquivo onde elas não existiam.

É a **L44**, e a conferência é mecânica:

```bash
ls docs/sprints/<n>-*/          # sprint-backlog.md e sprint-review.md
ls specs/<feature>/aceitacao.md # a aceitação, do sprint 006 em diante
```

**Abrir um sprint novo confere o anterior.** E citar uma lição obriga a achá-la no arquivo, não na
memória.

## Product backlog — o que está por cima

| # | O que é | Prioridade |
|---|---|---|
| [#261](https://github.com/The-Band-Solution/theband/issues/261), [#262](https://github.com/The-Band-Solution/theband/issues/262), [#263](https://github.com/The-Band-Solution/theband/issues/263) | os três defeitos do sprint 010 — o **#263** é o mais grave: a plataforma afirma decomposição que a origem não declara mais | P1 |
| [#99](https://github.com/The-Band-Solution/theband/issues/99), [#100](https://github.com/The-Band-Solution/theband/issues/100) | cadastrar papel e alocar pessoa a papel — **transformaria as 88 evidências em vínculos** | P1 |
| [#232](https://github.com/The-Band-Solution/theband/issues/232) | falha de rede no gate de assets, no CI | P2 |
| [#176](https://github.com/The-Band-Solution/theband/issues/176) | criar as iterações que faltam no ProjectV2 | decisão pendente desde o sprint 004 |
| [#177](https://github.com/The-Band-Solution/theband/issues/177) a [#181](https://github.com/The-Band-Solution/theband/issues/181) | validador Elixir à paridade, status derivado, comentários e timeline, quadros do Projects v2 | |
| #81, #82, #98, #104, #107, #108 | papéis Scrum, quadros, escopo de observação | |

**A #263 é a próxima candidata natural**: é defeito de fidelidade do dado, o desenho já existe no
nível da issue — `mark_issues_no_longer_observed/3` —, e a tela que exibe o resultado acabou de ser
entregue.

## Dívida conhecida, e não esquecida

| Dívida | Onde |
|---|---|
| `TeamsLive.Show` continua em português | a migração para inglês passou por ela |
| `list_parents/2` e `fetch_parent/2` coexistem | duas funções para a mesma relação vista de baixo; a antiga é a #261 |
| o componente `origem/1` da página da pessoa tem **dois** usos, não três | está no limiar do critério, e foi declarado em vez de escondido |

## O que continua valendo, e não muda

- **`mix gates` é a definição única dos dez gates**, e o veredito é o código de saída;
- **nunca se apaga dado** — ausência é marcada, nunca removida;
- **a chave mestra e o token nunca entram no chat**, nem no repositório;
- **o ciclo Spec Kit vem antes do código**, e a fase de análise achou defeito de desenho em **cinco**
  features seguidas: a ordem de decisão da 007, o resgate por tempo da 008, a coluna estreita da 009,
  a terceira fronteira da 010, e — na 011 — **dois requisitos sem tarefa nenhuma**.
