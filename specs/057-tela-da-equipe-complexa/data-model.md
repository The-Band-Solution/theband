# Data Model — Feature 057

**Nenhuma migração.** A feature não cria tabela nem coluna: tudo que ela precisa
já existe. O que muda é **como o conjunto de membros é obtido**, e isso é consulta,
não esquema.

Este documento descreve as estruturas **calculadas** que atravessam a fronteira
entre domínio e tela, e as tabelas existentes de onde elas saem.

---

## Tabelas lidas (nenhuma alterada)

| Tabela | O que fornece | Por que importa aqui |
|---|---|---|
| `eo_team_memberships` | vínculo com `started_at`, `ended_at`, `invalidated_at` | **a fonte do conjunto de membros em qualquer data** |
| `eo_team_compositions` | parte-todo entre equipes, com período | decide se a equipe é composta |
| `eo_teams` | a equipe, e se é declarada ou observada | cabeçalho e navegação |
| `eo_people` | nome e login | identificação nas linhas |
| `eo_team_membership_evidence` | o que a origem lista | evidência não promovida (FR-005) |
| `collected_issues` | `external_created_at`, `external_closed_at` | as duas séries e o trabalho aberto |
| `issue_assignees` | issue ↔ pessoa | liga o trabalho a quem o faz |
| `eo_person_profiles` | perfil vigente, com `content` e `generated_at` | habilidades demonstradas |

**A que não existe**: não há data de atribuição em `issue_assignees` — R1. Toda
medida de tempo por pessoa sai da issue, nunca do vínculo com ela.

---

## Estruturas calculadas

### `membro_no_periodo`

Quem pertencia à equipe **numa data**. É a estrutura que corrige o defeito.

```text
%{person_id, name, login, started_at, ended_at}
```

**Regra de vigência — três condições, e a terceira é a da 055:**

```text
started_at <= <data>  e  (ended_at é nulo ou ended_at > <data>)  e  invalidated_at é nulo
```

Borda `[started_at, ended_at)` — fechada no início, aberta no fim. Mesma convenção
de `count_team_members_at/3`; divergir dela faria quem troca de equipe num mesmo
dia contar nas duas.

### `linha_de_subequipe`

Uma por subequipe, mais uma para os membros diretos. **Nunca somadas** — FR-008.

```text
%{
  team_id, name, direta?: boolean,
  membros: non_neg_integer(),
  abertas: non_neg_integer(),
  fechadas_na_janela: non_neg_integer(),
  paradas: non_neg_integer(),
  sem_trabalho?: boolean
}
```

`sem_trabalho?` existe para separar **zero observado** de **ausência** — FR-012. A
tela usa o booleano; não infere ausência de um zero.

### `serie_semanal`

```text
[%{periodo: "2026-W31", criadas: 6, fechadas: 4}, ...]
```

Um item por semana **dentro do período coletado**. Semana sem movimento vem com
zero nas duas; semana fora do período coletado **não aparece** — FR-016.

`periodo` usa ano ISO (`IYYY-"W"IW`) e não o civil: a semana de 29/12 pertence ao
ano ISO seguinte, e `YYYY` produziria dois rótulos iguais no fim de dezembro.

### `burn`

```text
[%{periodo, escopo, feito, aberto}, ...]
```

- `escopo` — **linha de base + acumulado de criadas**. É o burn-up.
- `feito` — acumulado de fechadas. É o burn-down.
- `aberto` — `escopo - feito`. É a **distância entre as curvas**.

**A linha de base é obrigatória** — FR-026a, R2. Sem ela `aberto` conta apenas os
itens nascidos dentro da janela.

`aberto` é campo calculado, não série a desenhar: FR-027 proíbe apresentá-lo como
terceira linha. É o mesmo número que a altura da faixa representa.

### `previsao`

```text
{:ok, %{
   congelado: %{p50, p85, p95, nao_concluiram: 0},
   vivo:      %{p50 | nil, p85 | nil, p95 | nil, nao_concluiram: 0..10_000},
   rodadas: 10_000, horizonte_semanas: 12,
   ritmo: %{abre_por_semana: float, fecha_por_semana: float}
 }}
| {:sem_historico, %{semanas: n, semanas_exigidas: 6, fechadas: n, fechadas_exigidas: 10}}
```

`nao_concluiram` é **exigido** — FR-035. Quando a maioria das rodadas não termina
dentro do horizonte, os percentis são de uma minoria, e omitir a proporção
transformaria "quase nunca termina" em "termina em 6 semanas".

Percentil de hipótese cujas rodadas não concluíram vem **nulo, nunca um número
grande** — nulo diz desconhecido, e um número grande diz uma data.

### `tarefa_aberta_da_pessoa`

```text
%{issue_id, external_id, titulo, aberta_ha_dias, parada?: boolean}
```

`aberta_ha_dias` conta da **abertura do item** — R1, FR-019.
`parada?` é `aberta_ha_dias > 90`.

Uma pessoa tem **lista**, não um item — FR-018 proíbe eleger "a atual".

### `habilidades_da_pessoa`

```text
{:ok, [String.t()]} | {:abaixo_do_piso, %{fechadas: n, exigidas: n}}
```

O relator, e não a lista vazia. Lista vazia responde "nenhuma habilidade", que é
afirmação diferente de "não havia material para ler" — e é a segunda que a tela
precisa dizer, FR-023.

---

## O que **não** existe como estrutura, de propósito

| Não existe | Por quê |
|---|---|
| `total_da_equipe_composta` | FR-008. Não há campo a preencher, então não há como alguém preenchê-lo depois "só para completar" |
| `tarefa_atual` | FR-018. Eleger uma entre várias é julgamento que o dado não faz |
| `tempo_desde_atribuicao` | R1. A data não existe na origem |
| `data_prevista` | FR-033. Só faixa com confiança |

A ausência destes campos é **decisão de desenho**, e é o que impede que a recusa
a somar seja desfeita por engano numa mudança futura: não há onde colocar o total.

---

## Relação com a ontologia

| Conceito SEON | O que esta feature usa |
|---|---|
| `eo.team` | a equipe, simples ou composta |
| `eo.team_part_of_team` | a composição, com seu próprio período |
| `eo.team_membership` | **o relator**: pessoa, papel, equipe e período |
| `eo.team_member` | o papel, nunca a identidade |
| `eo.person` | a identidade, que sobrevive à saída |

O período vive no **relator**, não na pessoa nem na equipe — é por isso que sair da
equipe não apaga o que foi feito, e é o que torna a correção desta feature
possível sem tabela nova.
