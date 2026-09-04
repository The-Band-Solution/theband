# Sprint 029 — Review

**Período**: 2026-09-02 a 2026-09-09 · encerrado em 2026-09-03
**Feature**: [058 — as medidas que faltam na tela da equipe](../../../specs/058-medidas-da-equipe/spec.md)

## Resumo

| | Planejado | Entregue |
|---|---:|---:|
| User stories | 3 | 3 |
| Tarefas | 21 | 20 |
| Suíte | — | **1 704 testes, verde** |
| `mix gates` | — | **código de saída 0** · 14 gates |

As três user stories estão completas. A tarefa não entregue é a mesma de sempre,
e está dita abaixo sem rodeio.

## O que foi feito

| User story | Issue | Tarefas | O que chegou à tela |
|---|---|---|---|
| US2 — quem trabalhou neste projeto, e quando | [#766](https://github.com/The-Band-Solution/theband/issues/766) | T004–T007 | a seção por projeto, com as equipes por onde cada pessoa chegou e a marca do período parcialmente desconhecido |
| US1 — o tempo até a primeira revisão | [#765](https://github.com/The-Band-Solution/theband/issues/765) | T008–T011 | a mediana da equipe, a espera em curso contada ao lado, e a mesma medida por pessoa |
| US3 — a taxa do pipeline | [#767](https://github.com/The-Band-Solution/theband/issues/767) | T012–T016 | a taxa com o caminho e o tamanho da amostra, ou a recusa nomeando o elo que falta |

T001–T005 vieram do PR [#789](https://github.com/The-Band-Solution/theband/pull/789),
antes da v0.4.0. T006–T019 são deste trabalho.

## O Cenário 0 — a cobertura do dado, medida

A T020 existe porque a pesquisa **não conseguiu** medir: a aplicação não subia
com `:missing_master_key`, e uma taxa sobre amostra desconhecida não sustenta
decisão.

Agora subiu. A chave está no `.env` do ambiente de desenvolvimento, e os números,
medidos em 2026-09-03 contra `the_band_dev`:

```sql
select 'collected_verifications='||(select count(*) from collected_verifications)
    ||' spo_project_teams='||(select count(*) from spo_project_teams)
    ||' spo_project_repositories='||(select count(*) from spo_project_repositories);
```

| tabela | linhas |
|---|---:|
| `collected_verifications` | **0** |
| `spo_project_teams` | **0** |
| `spo_project_repositories` | **0** |
| `collected_change_requests` | **0** |
| `eo_team_memberships` | **0** |

**O que estes números querem dizer, e o que não querem.** O banco de
desenvolvimento desta máquina está **vazio** — 12 MB, só esquema. Ele não é a
origem que a pesquisa citou (19 200 atividades, 50 autores), e **a cobertura do
tenant real continua não medida**.

Isso é limitação declarada, e não estimada: medi, e o que encontrei foi ausência
de dado local. Medir a origem real exigiria o banco de produção, que não é acesso
deste trabalho.

**A conclusão sobre a US3 não muda por isso**, e é a que a T020 previu: com
vínculos em zero, a US3 entrega o ramo da recusa — `{:sem_projeto, _}`, com o elo
que falta nomeado na tela. **É resultado, não falha.** O ramo da taxa está
implementado e coberto por teste com dado montado; o que falta para vê-lo com
número real é dado coletado, e não código.

## Evidências

| O quê | Medida |
|---|---|
| `mix gates` | **código de saída 0** · 14 gates |
| suíte completa | **1 704 testes**, 187 s |
| código e teste acrescentados | **2 577 linhas** em 14 arquivos (937 em `lib/`) |
| testes novos | **37** — 13 da tela, 8 da espera, 8 da taxa, 7 do isolamento, 1 do teto |
| arquivos de teste novos | 2 |
| teto de consultas da tela | 17 → **19**, e as três seções somam **6** com projeto |

## O que os testes encontraram, e o código não dizia

Quatro defeitos nasceram e morreram dentro do sprint. Ficam registrados porque a
lição está no **como** foram achados, e não em que existiram:

1. **`list_team_projects/2` apagava o passado.** A seção da US2 usava a listagem
   da associação, que filtra `is_nil(unlinked_at)`. O projeto de que a equipe saiu
   sumia da tela **junto com todo mundo que trabalhou nele** — contra a FR-008.
   Achado pelo teste do intervalo encerrado, e corrigido com
   `team_projects_ever/2`;

2. **a consulta sobre tabela devolve `NaiveDateTime`.** Sem `type/2` no select, a
   conta de dias da espera em curso quebrava com `FunctionClauseError`. Errar
   assim é sorte: um número errado teria passado;

3. **o teto de consultas fez o trabalho dele três vezes.** Cada seção nova o
   reprovou, e cada subida está escrita com o motivo. A terceira levou a
   compartilhar a lista de vínculos entre duas seções, em vez de subir o número;

4. **o Credo estava certo sobre a complexidade.** A consulta do recorte, num
   `from` só, passou de 12. Quebrá-la em `abertas_por_quem_pertencia/2` e
   `com_primeira_revisao_humana/1` não foi obediência ao gate: o recorte pela data
   de abertura **é** a regra da medida, e lia-se melhor sozinho.

## O que não foi feito

| Tarefa | Issue | Motivo | Destino |
|---|---|---|---|
| T021 (parte) | [#788](https://github.com/The-Band-Solution/theband/issues/788) | gates verdes ✅, PR aberto ✅, **revisão independente ✗** | próximo sprint, como condição de entrada |

**É a terceira vez seguida.** A L95 nasceu no sprint 027, reincidiu no 028, e
reincide aqui. A lacuna está declarada no PR, como o princípio VII exige, e **não
está marcada como cumprida**.

O padrão é o que a lição 98 descreve: lição que não vira regra reincide. Uma
lição que reincide três vezes não precisa de outro registro — precisa de um
mecanismo, e propor qual é trabalho do próximo sprint backlog.

## O que continua aberto no épico [#504](https://github.com/The-Band-Solution/theband/issues/504)

Depois deste sprint, o épico **não fecha**, e por dois motivos que não são de
implementação:

1. **as perguntas do painel não vieram** — decisão de quem mantém, declarada como
   pendência no próprio épico desde 2026-08-25;
2. **`flow.throughput` e `flow.wip.count` dependem da feature 042** (critério de
   início), especificada, com 24 issues e sem código.

Escrever o painel antes das perguntas produziria a medida do que é fácil medir.

## Dívida gerada

**A marca de período parcial continua pessimista.** `Periodos.interseccao/1`
marca qualquer início nulo, mesmo quando a sobreposição é certa pelos outros
períodos — está documentado no próprio módulo desde a 057, e esta feature
**consome** o comportamento sem corrigi-lo. A consequência aparece agora que há
tela: uma equipe cujos vínculos não têm `started_at` verá a marca em toda linha,
e a marca deixa de distinguir.

Corrigir muda o que a função devolve para casos que já têm chamador, e é decisão
em aberto — não um esquecimento.
