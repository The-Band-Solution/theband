# Retomar — estado em 2026-08-13, depois de incorporar o #296, o #297 e o #298

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

## Onde o trabalho parou

**Nove sprints fechados em sequência**, todos com o ciclo Spec Kit completo antes do código:

| Sprint | Feature | Estado |
|---|---|---|
| 005 | 005 regras de mapeamento · 006 detalhe da issue | fechado |
| 006 | 007 marca de trabalho no repositório | fechado, 10 de 11 critérios |
| 007 | 008 destravar a sincronização presa | fechado, 14 de 14 |
| 008 | 009 a marca de inacessível se cura | fechado, 12 de 12 |
| 009 | 010 detalhe da pessoa | fechado **com atraso** — review escrita no sprint 010 |
| 010 | 011 de quem cada issue é parte | fechado, 12 de 13 |
| 011 | 012 o vínculo que sumiu na origem | fechado, 14 FR e 3 de 7 SC |
| 012 | 013 a página da pessoa que não varre tudo | fechado, **10 FR e 9 SC** — a pior página caiu de 6,12 s para 0,031 s |
| 013 | 014 clicar leva à página · 015 quem escreveu é observado | fechado, 23 FR e 9 de 14 SC — cinco pendem de coleta |
| 014 | 016 migalha de pão · 017 tabela que busca, ordena e pagina | fechado, **com dois cortes declarados** — um deles virou a 019 |
| — | **018 validador à paridade · 019 estado na URL** | incorporado em 2026-08-13, **sem pasta de sprint** |

**Nenhum PR aberto.** Os três últimos foram incorporados hoje, na ordem pedida:

| PR | O que é | Fechou |
|---|---|---|
| [#296](https://github.com/The-Band-Solution/theband/pull/296) | feature 018, o validador Elixir com as treze verificações | [#177](https://github.com/The-Band-Solution/theband/issues/177) |
| [#297](https://github.com/The-Band-Solution/theband/pull/297) | feature 019, busca, ordenação e página no endereço | [#292](https://github.com/The-Band-Solution/theband/issues/292) |
| [#298](https://github.com/The-Band-Solution/theband/pull/298) | lições L54 a L57 | — |

**As duas issues fecharam sozinhas**, pela palavra em inglês — é a L48 aplicada antes de doer. Confirmado
depois do merge, que é a própria L48.

### O que os dois últimos sprints deixaram no código

- **#291 e #293** — a migalha de pão no design system, e os dois jeitos antigos de voltar saíram; a tabela
  que busca, ordena e pagina;
- **#294 e #295** — o pai ganhou ordem antes do limite ([#261](https://github.com/The-Band-Solution/theband/issues/261),
  os **36** com mais de um pai), a filha que a ontologia não nomeia aparece
  ([#262](https://github.com/The-Band-Solution/theband/issues/262), **33** vínculos), e a situação da
  ferramenta virou derivada;
- **#296** — as **treze** verificações existem nos dois validadores, e o décimo terceiro gate
  (`validadores concordam`) roda os dois sobre a mesma base e compara **veredito**, não texto;
- **#297** — `?q=`, `?ordem=`, `?dir=` e `?pagina=` nas duas listas, com `EstadoDaTabela.ler/2` devolvendo
  `{estado, avisos}`: parâmetro inválido é dito, e a tela não cai;
- **#298** — L54 a L57, e três delas são a mesma família: ausência de erro lida como resultado.

## O que a plataforma sabe hoje

```
135 repositórios observados · 4529 issues vigentes · 3 organizações · 75 pessoas
1630 issues com pai · 1666 vínculos · 0 marcados como ausentes
52 vínculos que a última coleta não reviu — eo_lib 29, theband 15, ResearchDomain 8
atendimento 1143 · violação da sro.rule07 293 · composição 197 · não nomeada 33
```

**Estes números são do sprint 011 e não mudaram**: não houve coleta nova desde então, e nenhum dos
sprints seguintes tocou em coleta. Os **52** continuam sendo o alvo: o código que os marca está pronto e
testado, e o número só sai de zero quando houver coleta com a origem respondendo.

A base de conhecimento, medida no sprint do validador:

```
96 artefatos YAML · 12 ontologias · 220 conceitos · 144 relações · 5 medidas
```

## O que precisa de você, e eu não consigo fazer

**Três coisas, e todas precisam da chave mestra ou de olho humano.** Nenhuma mudou desde o último
`RETOMAR`, e é por isso que elas continuam aqui.

### 1. A prova no dado real das features 009, 012 e 015 — a mesma coleta serve para as três

```bash
export THE_BAND_MASTER_KEY=...   # no seu terminal, nunca no chat
mix phx.server                   # e disparar a sincronização em /syncs
```

| O que conferir | Esperado |
|---|---|
| feature 009 | as **39** marcas de inacessível saem, e `leds-conectafapes-prestacao-de-contas` vai de 9 para **11** issues |
| feature 012 | os vínculos que a origem largou saem da vigência, e a contagem de marcados deixa de ser **0** |
| feature 012 | no `theband`, os **157** revistos continuam vigentes |
| feature 012 | o painel da `sro.rule07` cai de **293** para **281** — a consequência declarada antes de acontecer |
| feature 015 | as **288** aparições sem pessoa caem; a contagem de pessoas sai de **75**; a de **membros** continua **75** |
| feature 015 | `sofialctv` passa a existir, com 64 issues em 5 repositórios, e a página dela mostra `worked at` |

As consultas estão em [`specs/012-vinculo-que-sumiu-na-origem/quickstart.md`](../../specs/012-vinculo-que-sumiu-na-origem/quickstart.md).
As issues que esperam por isso são a [#277](https://github.com/The-Band-Solution/theband/issues/277) e a
[#265](https://github.com/The-Band-Solution/theband/issues/265).

### 2. A tela em 360 px — **oitavo** sprint com este item

| Tela | Feature |
|---|---|
| a marca de trabalho na lista de repositórios | 007, SC-009 |
| a célula de estado que cresceu | 009, T009 |
| a página da pessoa | 010, SC-011 |
| a coluna `part of` | 011, SC-010 |
| a migalha de pão | 016 |
| a tabela com busca, ordenação e paginação | 017 |

Todas asseridas em HTML, **nenhuma olhada**. Asserção em markup não substitui olhar — e a lista só cresce.

### 3. Duas conferências de tela no dado real

- `/people/<id>` de `vinicius-je`: **350 e 609, nunca 959** — a soma é proibida;
- `/work/repositories/<id>` de `eo_lib`: as **29** issues dizendo, em texto, que a decomposição
  acabou — é o SC-004 da feature 012.

## O que ficou por escrever

| O que falta | Onde |
|---|---|
| `sprint-review.md` do sprint 014 | a Definition of Done em [`014-design-system/sprint-backlog.md`](014-design-system/sprint-backlog.md) tem o item **não** marcado |
| a pasta do sprint do validador | as features 018 e 019 foram entregues sem `sprint-backlog.md` nem review — só as lições existem |
| a numeração de sprint das L54 a L57 | elas dizem **Sprint 014**, e o 014 é o do design system; ou o sprint do validador é a continuação dele, ou a origem está errada — decidir e escrever |

## Product backlog — o que está por cima

As #285, #261, #262, #292, #177, #178 e #232 **fecharam**. O que sobra, por prioridade:

| # | O que é | Prioridade |
|---|---|---|
| [#99](https://github.com/The-Band-Solution/theband/issues/99), [#100](https://github.com/The-Band-Solution/theband/issues/100), [#98](https://github.com/The-Band-Solution/theband/issues/98) | cadastrar papel e alocar pessoa a papel — **transformaria as 88 evidências em vínculos** | P1 |
| [#277](https://github.com/The-Band-Solution/theband/issues/277), [#265](https://github.com/The-Band-Solution/theband/issues/265) | as conferências no dado real — dependem da coleta acima | P1, mas bloqueadas |
| [#179](https://github.com/The-Band-Solution/theband/issues/179) | coletar comentários e timeline das issues | P2 |
| [#180](https://github.com/The-Band-Solution/theband/issues/180), [#181](https://github.com/The-Band-Solution/theband/issues/181) | quadros, campos e iterações do Projects v2, e o mapeamento de campo para atributo | P2 |
| [#176](https://github.com/The-Band-Solution/theband/issues/176) | criar as iterações que faltam no ProjectV2 | decisão pendente desde o sprint 004 |
| [#81](https://github.com/The-Band-Solution/theband/issues/81), [#82](https://github.com/The-Band-Solution/theband/issues/82), [#104](https://github.com/The-Band-Solution/theband/issues/104), [#107](https://github.com/The-Band-Solution/theband/issues/107), [#108](https://github.com/The-Band-Solution/theband/issues/108) | consultar uma organização de cada vez, quem atravessa organizações, escopo de observação, quadros | |

**A dupla #99 e #100 é a próxima candidata natural**: é a única P1 que não depende da chave mestra, e ela
tem consequência visível — as 88 evidências de papel que hoje a plataforma observa e não consegue afirmar.

**E há uma candidata sem issue, saída da L47**: a primeira coleta de uma organização **subconta a
decomposição**, porque o vínculo entre repositórios vira recusa `out_of_scope` e só é registrado na
coleta seguinte. Ninguém percebe — a recusa é silenciosa.

## Dívida conhecida, e não esquecida

| Dívida | Onde |
|---|---|
| `list_parents/2` e `fetch_parent/2` coexistem | duas funções para a mesma relação vista de baixo; a #261 corrigiu a ordem da segunda, **não** a duplicação |
| **quatro** funções de marcação de ausência, sem abstração comum | os cortes não são iguais — um por data, dois por lista, e o do vínculo |
| `SchemaCheck` implementa um subconjunto do JSON Schema 2020-12 | oito construtos, escolhidos porque as bibliotecas param no draft 7; construto não implementado **reprova**, e é isso que contém o custo |
| dois validadores da mesma regra, em linguagens diferentes | o gate `validadores concordam` é o que impede a divergência — e ele compara veredito, não texto |
| o total de vínculos marcados por execução só existe no log | a pergunta ainda não foi feita por ninguém; inventar o campo seria padrão sem problema |
| as issues antigas só ganham autor na **próxima** coleta | o payload guardado não tem o `id` do autor, e reprocessar não inventa o que não foi pedido |
| `mapping/queries.ex` mantém a segunda definição de promoção vigente | reusar exigiria expor subconsulta pela fronteira — ADR 0003 |
| as tabelas menores não buscam nem ordenam | corte declarado da 017: 12 linhas e 4 529 não pedem a mesma solução |

## O que continua valendo, e não muda

- **`mix gates` é a definição única dos treze gates**, e o veredito é o código de saída;
- **nunca se apaga dado** — ausência é marcada, nunca removida. A feature 012 é essa frase virando
  código no nível do vínculo;
- **a chave mestra e o token nunca entram no chat**, nem no repositório;
- **o ciclo Spec Kit vem antes do código**, e a fase de análise achou defeito de desenho em **seis**
  features seguidas: a ordem de decisão da 007, o resgate por tempo da 008, a coluna estreita da
  009, a terceira fronteira da 010, os dois requisitos sem tarefa da 011, e — na 012 — **a
  consequência da marca em outra tela e a ordem contra a promoção**;
- **abrir um sprint novo confere o anterior**, e agora confere **onde** ele está — L45;
- **depois do merge, conferir o que o merge não fez** — L48, e a palavra de fechamento é em inglês;
- **uma feature por branch**, e a pergunta é no primeiro commit de código, não na abertura do sprint
  — é a **L52**, e ela nasceu de eu ter quebrado a regra que eu mesmo escrevera duas seções antes;
- **teto de teste de custo vem de medir os dois lados** — L53, e a L50 exige provar que a medida não
  é zero;
- **ausência de erro não é resultado** — L54 a L57, quatro num sprint só: átomo criado sob demanda,
  task que não compila, telemetria que não alcança o SQL cru, e verificação que filtra um tipo que
  ninguém produz.
