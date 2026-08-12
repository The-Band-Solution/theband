# Retomar — estado em 2026-08-12, fim do sprint 008

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

## Onde o trabalho parou

**Quatro sprints fechados em sequência**, todos com o ciclo Spec Kit completo antes do código:

| Sprint | Feature | Estado |
|---|---|---|
| 005 | 005 regras de mapeamento · 006 detalhe da issue | fechado |
| 006 | 007 marca de trabalho no repositório | fechado, 10 de 11 critérios |
| 007 | 008 destravar a sincronização presa | fechado, 14 de 14 |
| 008 | 009 a marca de inacessível se cura | fechado, 12 de 12 |

`main` em `26f8a45` — **10 gates verdes por código de saída, 430 testes**.

## O que a plataforma sabe hoje

```
135 repositórios observados · 4521 issues · 3 organizações
leds-conectafapes: 121 repos, 4280 issues no banco contra 4283 na origem
```

**A diferença de 3 issues está explicada**: nasceram depois da última coleta, e estão localizadas em
`conectafapes-project` (1) e `leds-conectafapes-prestacao-de-contas` (2).

## O único item aberto do sprint 008, e ele precisa de você

**A prova no dado real da feature 009.** Uma coleta com a origem respondendo precisa:

1. limpar as **39** marcas de inacessível — o mecanismo está medido no banco: `list_collectable`
   passou de **96** para **135** repositórios;
2. trazer `leds-conectafapes-prestacao-de-contas` de 9 para as **11** issues que a origem tem.

**Exige a chave mestra e o token da ferramenta.** Eu não os peço nem os recebo, e por isso o item
está declarado como pendente em vez de contado como cumprido.

```bash
export THE_BAND_MASTER_KEY=...   # no seu terminal, nunca no chat
mix phx.server                   # e disparar a sincronização em /syncs
```

Depois, a conferência:

```bash
docker exec -e PGPASSWORD=postgres the_band_postgres psql -U postgres -d the_band_dev -tAc "
select count(*) filter (where inaccessible_since is not null) as ainda_marcados
  from observed_repositories;"
```

## Pull requests abertos

| PR | O que é | Estado |
|---|---|---|
| [#231](https://github.com/The-Band-Solution/theband/pull/231) | o veredito do gate é o código de saída, mais a correção do registro da L36 | `MERGEABLE · CLEAN`, CI verde, aguardando revisão |

## O que mudou no processo, e vale ler antes de tocar em gate

**O gate de compilação nunca reprovou por aviso.** `execute({:mix, ...})` descartava o retorno de
`Mix.Task.run/2`, e `mix compile --warnings-as-errors` devolve `{:error, diagnostics}` em vez de
levantar. Valia para todo gate `{:mix, ...}` — `credo`, `dialyzer`, os dois validadores.

Corrigido no #231: **veredito é o código de saída**, cada gate em subprocesso. `mix gates` em
**78,6 s**.

**E eu publiquei um diagnóstico errado antes de isolar a causa.** A primeira versão da L36 dizia que
a compilação incremental não emitia o aviso — falso. A lição foi reescrita com o mecanismo real, e o
erro ficou registrado nela: *quando duas medidas verdadeiras parecem se contradizer, o elo entre elas
é hipótese, não conclusão.*

## Product backlog — o que está por cima

| # | O que é | Prioridade |
|---|---|---|
| [#211](https://github.com/The-Band-Solution/theband/issues/211) | página de detalhe da pessoa: equipes, repositórios e issues | P1, **pedida pela pessoa mantenedora** |
| [#176](https://github.com/The-Band-Solution/theband/issues/176) | criar as iterações que faltam no ProjectV2 | decisão pendente desde o sprint 004 |
| [#177](https://github.com/The-Band-Solution/theband/issues/177) | validador Elixir à paridade com o Python | |
| [#178](https://github.com/The-Band-Solution/theband/issues/178) | derivar `connected_tools.status` em vez de materializar | |
| [#179](https://github.com/The-Band-Solution/theband/issues/179), [#180](https://github.com/The-Band-Solution/theband/issues/180), [#181](https://github.com/The-Band-Solution/theband/issues/181) | comentários e timeline; quadros do Projects v2 | |
| #81, #82, #98 a #100, #104, #107, #108 | papéis Scrum, quadros, escopo de observação | |

**A #211 é a próxima feature natural**: foi pedida durante o sprint 007, tem as sete armadilhas
levantadas no corpo da issue, e a primeira delas é a que decide o desenho — *"trabalhou no
repositório" é derivado, não observado*.

## Duas coisas que ficaram sem olho humano

| Item | Onde |
|---|---|
| a tela em 360 px, com a célula de estado que cresceu | feature 009, T009 |
| a marca de trabalho em 360 px | feature 007, SC-009 |

As duas estão asseridas em HTML e **nenhuma foi olhada**. Asserção em markup não substitui olhar.

## O que continua valendo, e não muda

- **`mix gates` é a definição única dos dez gates**, e agora o veredito é o código de saída;
- **nunca se apaga dado** — ausência é marcada, nunca removida;
- **a chave mestra e o token nunca entram no chat**, nem no repositório;
- **o ciclo Spec Kit vem antes do código**, e a fase de análise achou defeito de desenho em **três**
  features seguidas: a ordem de decisão da 007, o resgate por tempo da 008, e a coluna estreita da
  009.
