<!-- DERIVADO da varredura automática de lib/the_band/**/*.ex e lib/the_band.ex (184 arquivos):
     todo `defmodule` mapeado para arquivo, toda referência `TheBand.*` resolvida para o módulo
     conhecido mais longo e atribuída ao contexto do arquivo que a define.
     `@moduledoc`, `@doc` e comentários FORAM EXCLUÍDOS da contagem — 7 arestas existiam só em
     texto de documentação e não são dependência (lista no fim).
     Ciclos por Tarjan; sequenciamento por Eades-Lin-Smyth (conjunto de arestas de
     realimentação, heurístico) — em 2026-09-18.
     Conferido contra o código nesta data. Regenerar ao mudar a fonte.
     O método está descrito passo a passo na última seção, para quem precisar refazer. -->

# DSM — os módulos de `lib/the_band/`

**O que precisa vir antes do quê, dentro do código.** As DSMs de `dsm/` costumam ser entre
user stories; esta é entre **contextos de código**, e responde a outra pergunta: *se eu mexer
aqui, o que mais vou ter de entender?*

## Como ler

Linhas e colunas são os mesmos 37 contextos, **na mesma ordem**. A célula `(i, j)` marcada
significa **i depende de j** — a linha `i` *usa* a coluna `j`.

A marca diz a **natureza** da dependência, porque elas se desfazem de formas diferentes:

| Marca | Natureza | Como se desfaz |
|---|---|---|
| `F` | **chamada de fronteira** — `i` chama uma função pública de `j` | extraindo a função, ou invertendo quem chama |
| `S` | **alias de schema** — `i` monta consulta sobre um schema que pertence a `j` | expondo a consulta em `j`, em vez do schema |
| `FS` | as duas coisas na mesma aresta | — |
| `B` | **leitura da base de conhecimento** — `i` lê uma regra do YAML | não se desfaz, e nem deve: é o princípio I |

A ordem das linhas foi **reordenada** para empurrar as marcas para **baixo da diagonal**. O que
sobrou **acima** é realimentação — e é o achado.

## A medida

| | Quanto |
|---|---:|
| contextos | **37** |
| arquivos `.ex` cobertos | **184** |
| arestas entre contextos | **136** |
| referências que as sustentam | **303** |
| marcas `F` (chamada de fronteira) | 113 |
| marcas `B` (base de conhecimento) | 12 |
| marcas `S` (alias de schema) | 6 |
| marcas `FS` (as duas) | 5 |
| arestas **acima** da diagonal depois de reordenar | **16** de 136 (12%) |
| ciclos (componentes fortemente conexos com mais de 1 nó) | **2** |

**Cobertura declarada: 184 de 184 arquivos.** Nenhum ficou de fora. O que ficou de fora foram
dois conjuntos, por serem outra coisa:

- **`lib/the_band_web/`** — a camada de tela. A DSM entre LiveViews e contextos é outro
  documento, e não existe ainda;
- **`lib/mix/`** — as tarefas Mix, que são ferramenta e não domínio.

## O índice dos contextos

`usa` é o número de contextos distintos que o contexto chama; `é usado por`, o inverso.

| # | contexto | arquivos | usa | é usado por |
|---|---|--:|--:|--:|
| M01 | `forecast` | 1 | 0 | 1 |
| M02 | `ontology/schema_check` | 1 | 0 | 1 |
| M03 | `periodos` | 1 | 0 | 2 |
| M04 | `provenance` | 1 | 0 | 1 |
| M05 | `repo` | 1 | 0 | 21 |
| M06 | `segredo` | 1 | 0 | 2 |
| M07 | `the_band.ex (raiz)` | 1 | 0 | 5 |
| M08 | `vault` | 1 | 0 | 3 |
| M09 | `encrypted` | 1 | 1 | 2 |
| M10 | `integrations` | 5 | 2 | 5 |
| M11 | `ontology/yaml_loader` | 1 | 1 | 2 |
| M12 | `ontology/yaml_validator` | 1 | 2 | 1 |
| M13 | `ontology/knowledge_base` | 1 | 2 | 12 |
| M14 | `tenants` | 10 | 4 | 22 |
| M15 | `work_items` | 14 | 7 | 5 |
| M16 | `projects` | 8 | 5 | 2 |
| M17 | `ontology/sro` | 5 | 4 | 2 |
| M18 | `ontology/cmpo` | 6 | 3 | 3 |
| M19 | `sources` | 4 | 9 | 3 |
| M20 | `raw_data` | 1 | 4 | 4 |
| M21 | `ontology/eo` | 20 | 5 | 10 |
| M22 | `ontology/spo` | 21 | 6 | 6 |
| M23 | `semantic_integration` | 2 | 5 | 2 |
| M24 | `jobs` | 5 | 8 | 2 |
| M25 | `mapping` | 10 | 9 | 3 |
| M26 | `ai` | 2 | 4 | 1 |
| M27 | `profiles` | 15 | 7 | 2 |
| M28 | `verification` | 5 | 4 | 1 |
| M29 | `quality` | 4 | 3 | 1 |
| M30 | `configuration` | 3 | 2 | 1 |
| M31 | `communication` | 3 | 2 | 1 |
| M32 | `changes` | 7 | 2 | 1 |
| M33 | `ingestion` | 15 | 20 | 6 |
| M34 | `teams` | 2 | 7 | 0 |
| M35 | `release` | 1 | 1 | 0 |
| M36 | `ontology/smpo` | 3 | 2 | 0 |
| M37 | `application` | 1 | 5 | 0 |

## A matriz

A tabela é larga de propósito: é a DSM inteira, e reduzi-la esconderia justamente o que ela
existe para mostrar. Leia por linha: *o que **esta** linha precisa entender*.


| | M01 | M02 | M03 | M04 | M05 | M06 | M07 | M08 | M09 | M10 | M11 | M12 | M13 | M14 | M15 | M16 | M17 | M18 | M19 | M20 | M21 | M22 | M23 | M24 | M25 | M26 | M27 | M28 | M29 | M30 | M31 | M32 | M33 | M34 | M35 | M36 | M37 |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **M01** | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M02** |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M03** |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M04** |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M05** |  |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M06** |  |  |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M07** |  |  |  |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M08** |  |  |  |  |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M09** |  |  |  |  |  |  |  | F | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M10** |  |  |  |  |  | F |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | F |  |  |  |  |
| **M11** |  |  |  |  |  |  |  |  |  |  | · |  | B |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M12** |  | F |  |  |  |  |  |  |  |  | F | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M13** |  |  |  |  |  |  |  |  |  |  | F | F | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M14** |  |  |  |  | F |  |  |  |  |  |  |  | B | · |  |  |  |  |  |  | FS | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M15** |  |  |  |  | F |  |  |  |  |  |  |  | B | F | · |  |  |  |  |  | FS | S |  |  | FS |  | F |  |  |  |  |  |  |  |  |  |  |
| **M16** |  |  |  |  | F |  |  |  |  |  |  |  | B | F |  | · | F |  |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M17** |  |  |  |  | F |  |  |  |  |  |  |  |  | F | S | F | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M18** |  |  |  |  | F |  |  |  |  |  |  |  |  | F |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  | F |  |  |  |  |
| **M19** |  |  |  |  | F | F |  | F | F | F |  |  |  | F |  |  |  | S | · |  | F |  |  |  |  |  |  |  |  |  |  |  | F |  |  |  |  |
| **M20** |  |  |  |  | F |  |  |  |  |  |  |  |  | F |  |  |  |  | F | · |  |  |  |  |  |  |  |  |  |  |  |  | F |  |  |  |  |
| **M21** |  |  |  | F | F |  |  |  |  |  |  |  | B | F |  |  |  |  |  | F | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M22** |  |  | F |  | F |  |  |  |  |  |  |  | B | F | S |  |  |  |  |  | F | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M23** |  |  |  |  |  |  | F |  |  |  |  |  | B | F |  |  |  |  |  | F | F |  | · |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
| **M24** |  |  |  |  |  |  |  |  |  | F |  |  |  | F |  |  |  |  | F | F | F |  | F | · | F |  |  |  |  |  |  |  | F |  |  |  |  |
| **M25** |  |  |  |  | F |  | F |  |  |  |  |  | B | F | FS |  |  | F |  |  | F | F |  | F | · |  |  |  |  |  |  |  |  |  |  |  |  |
| **M26** |  |  |  |  | F |  |  |  | F | F |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  | · |  |  |  |  |  |  |  |  |  |  |  |
| **M27** |  |  |  |  | F |  | F |  |  | F |  |  | B | F |  |  |  |  |  |  | FS |  |  |  |  | F | · |  |  |  |  |  |  |  |  |  |  |
| **M28** |  |  | F |  | F |  |  |  |  |  |  |  |  | F |  |  |  |  |  |  |  | F |  |  |  |  |  | · |  |  |  |  |  |  |  |  |  |
| **M29** |  |  |  |  | F |  |  |  |  |  |  |  | B | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  | · |  |  |  |  |  |  |  |  |
| **M30** |  |  |  |  | F |  |  |  |  |  |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | · |  |  |  |  |  |  |  |
| **M31** |  |  |  |  | F |  |  |  |  |  |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | · |  |  |  |  |  |  |
| **M32** |  |  |  |  | F |  |  |  |  |  |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | · |  |  |  |  |  |
| **M33** |  |  |  |  | F |  | F |  |  | F |  |  |  | F | F | F | F | F | F | F | F | F | F | F | F |  |  | F | F | F | F | F | · |  |  |  |  |
| **M34** | F |  |  |  | F |  |  |  |  |  |  |  | B | F | S |  |  |  |  |  | S |  |  |  |  |  | F |  |  |  |  |  |  | · |  |  |  |
| **M35** |  |  |  |  |  |  |  |  |  |  |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | · |  |  |
| **M36** |  |  |  |  | F |  |  |  |  |  |  |  |  | F |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | · |  |

`F` = chamada de fronteira · `S` = alias de schema · `FS` = as duas · `B` = base de conhecimento
· `·` = a diagonal.

## Os quatro blocos

A ordenação separa o código em quatro faixas, e a leitura delas é o mapa mental do projeto:

| Bloco | Contextos | O que é |
|---|---|---|
| **A — fundação** (M01–M08) | `forecast`, `ontology/schema_check`, `periodos`, `provenance`, `repo`, `segredo`, `the_band.ex`, `vault` | **não dependem de nada**. São cálculo puro, cofre, tipo opaco e o acesso ao banco. |
| **B — vocabulário** (M09–M13) | `encrypted`, `integrations`, `ontology/yaml_loader`, `ontology/yaml_validator`, `ontology/knowledge_base` | a cifragem, o cliente HTTP da origem e a leitura da rede de ontologias. |
| **C — o núcleo** (M14–M33) | `tenants`, `work_items`, `projects`, as quatro ontologias, `sources`, `raw_data`, `jobs`, `mapping`, `ai`, `profiles`, `verification`, `quality`, `configuration`, `communication`, `changes`, `ingestion` | **20 contextos que se usam mutuamente.** É onde mora o ciclo grande — que inclui também `integrations`, do bloco B. |
| **D — o topo** (M34–M37) | `teams`, `release`, `ontology/smpo`, `application` | **ninguém os usa.** São pontos de entrada: a medida da equipe, a release, a leitura de iteração e a árvore de supervisão. |

**Os oito da fundação têm `usa = 0`** — nenhum deles chama contexto nenhum. **Os quatro do topo
têm `é usado por = 0`.** Entre eles, tudo.

Os três contextos mais usados, por número de contextos que os chamam:

| Contexto | É usado por | Por quê |
|---|---:|---|
| `tenants` | **22** | toda função de domínio recebe `%Tenant{}` — é o princípio V com forma no código |
| `repo` | **21** | é o `Ecto.Repo`; quem escreve, escreve por ele |
| `ontology/knowledge_base` | **12** | as regras do YAML, lidas em vez de escritas em constante |

Que `tenants` supere `repo` é o fato mais revelador da matriz: **há contexto que fala de tenant
sem tocar no banco**, e não o contrário. O escopo por organização não é uma cláusula `where`
acrescentada no fim; é o argumento que atravessa as assinaturas.

## Os ciclos — e há dois

**A resposta direta: sim, há ciclo.** Dois componentes fortemente conexos com mais de um nó,
achados por Tarjan sobre o grafo de 37 nós e 136 arestas.

### Ciclo 1 — a leitura da ontologia (3 contextos)

```text
ontology/knowledge_base  →  ontology/yaml_loader  →  ontology/knowledge_base
ontology/knowledge_base  →  ontology/yaml_validator  →  ontology/yaml_loader  →  ...
```

| Aresta | Natureza | Evidência |
|---|---|---|
| `knowledge_base → yaml_loader` | `F` | `lib/the_band/ontology/knowledge_base.ex:18` |
| `knowledge_base → yaml_validator` | `F` | `lib/the_band/ontology/knowledge_base.ex:19` |
| `yaml_validator → yaml_loader` | `F` | `lib/the_band/ontology/yaml_validator.ex:16` |
| **`yaml_loader → knowledge_base`** | **`B`** | `lib/the_band/ontology/yaml_loader.ex:52` |

**A aresta que fecha o ciclo é a última**, e é uma só. É pequeno, contido em três arquivos de
um mesmo assunto, e o corte é óbvio se um dia incomodar: o que `yaml_loader` precisa de
`knowledge_base` sai para um terceiro módulo, ou passa como argumento.

**Recomendação: não mexer.** Três módulos que leem o mesmo YAML e se conhecem não é acoplamento
que custe; quebrar isso adicionaria um módulo para resolver um problema que ninguém tem.

### Ciclo 2 — o núcleo de 21 contextos

Este é o grande, e é o achado do documento.

```text
ai, changes, communication, configuration, ingestion, integrations, jobs, mapping,
ontology/cmpo, ontology/eo, ontology/spo, ontology/sro, profiles, projects, quality,
raw_data, semantic_integration, sources, tenants, verification, work_items
```

**21 contextos num único componente fortemente conexo** — de qualquer um deles se chega a
qualquer outro seguindo as setas. Na prática: *qualquer um deles pode, em princípio, ser
afetado por qualquer outro.*

São os 20 do bloco C **mais `integrations`** (M10), que a ordenação empurrou para o bloco B
por ter pouca entrada, mas que pertence ao ciclo pela aresta
`integrations → ingestion` (`client.ex:11`).

Mas **21 contextos não formam um novelo de 21 pontas**. O sequenciamento mostra que bastam
**16 arestas** para fechá-lo, e dessas, poucas carregam quase todo o peso.

## As 16 arestas de realimentação

São as marcas **acima** da diagonal. Removê-las (ou invertê-las) deixaria o grafo acíclico.

| # | Aresta | Refs | Natureza | Evidência |
|---|---|---:|---|---|
| 1 | `jobs → ingestion` | **12** | `F` | `lib/the_band/jobs/sync_github_eo.ex:31-33` |
| 2 | `tenants → ontology/eo` | 3 | `FS` | `lib/the_band/tenants/access.ex:51-52`, `auth.ex:29` |
| 3 | `work_items → mapping` | 2 | `FS` | `lib/the_band/work_items/rotulos.ex:39`, `routing.ex:56` |
| 4 | `work_items → ontology/eo` | 2 | `FS` | `lib/the_band/work_items/team_work.ex:28-29` |
| 5 | `integrations → ingestion` | 1 | `F` | `lib/the_band/integrations/github/client.ex:11` |
| 6 | `jobs → mapping` | 1 | `F` | `lib/the_band/jobs/recompute_promotions.ex:40` |
| 7 | `ontology/cmpo → ingestion` | 1 | `F` | `lib/the_band/ontology/seon/cmpo/commands.ex:8` |
| 8 | `ontology/yaml_loader → knowledge_base` | 1 | `B` | `lib/the_band/ontology/yaml_loader.ex:52` |
| 9 | `projects → ontology/spo` | 1 | `F` | `lib/the_band/projects/commands.ex:14` |
| 10 | `projects → ontology/sro` | 1 | `F` | `lib/the_band/projects/commands.ex:13` |
| 11 | `raw_data → ingestion` | 1 | `F` | `lib/the_band/raw_data.ex:16` |
| 12 | `sources → ingestion` | 1 | `F` | `lib/the_band/sources.ex:13` |
| 13 | `sources → ontology/eo` | 1 | `F` | `lib/the_band/sources.ex:16` |
| 14 | `tenants → ontology/spo` | 1 | `F` | `lib/the_band/tenants/access.ex:53` |
| 15 | `work_items → ontology/spo` | 1 | `S` | `lib/the_band/work_items/person_work.ex:25` |
| 16 | `work_items → profiles` | 1 | `F` | `lib/the_band/work_items/team_work.ex:30` |

### Os doze pares que se olham

Doze arestas formam **ciclo de comprimento 2** — dois contextos que se usam mutuamente. São o
acoplamento mais fácil de ver e o mais caro de ignorar:

| Par | Refs (ida / volta) | Natureza |
|---|---|---|
| `ingestion` ↔ `integrations` | 8 / 1 | `F` / `F` |
| `ingestion` ↔ `jobs` | 1 / 12 | `F` / `F` |
| `ingestion` ↔ `sources` | 3 / 1 | `F` / `F` |
| `ingestion` ↔ `ontology/cmpo` | 1 / 1 | `F` / `F` |
| `ingestion` ↔ `raw_data` | 1 / 1 | `F` / `F` |
| `mapping` ↔ `work_items` | 6 / 2 | `FS` / `FS` |
| `ontology/eo` ↔ `tenants` | 10 / 3 | `F` / `FS` |
| `ontology/spo` ↔ `tenants` | 8 / 1 | `F` / `F` |
| `ontology/spo` ↔ `work_items` | 1 / 1 | `S` / `S` |
| `ontology/sro` ↔ `projects` | 2 / 1 | `F` / `F` |
| `jobs` ↔ `mapping` | 1 / 1 | `F` / `F` |
| `knowledge_base` ↔ `yaml_loader` | 1 / 1 | `F` / `B` |

## O que corta o ciclo grande — proposta, e só

**A decisão de arquitetura não é minha.** O que segue é leitura da matriz, para quem decide.

### Corte 1 — `jobs` ↔ `ingestion` e `integrations` ↔ `ingestion`

É a aresta mais carregada da matriz (12 referências) e a que mais gente encontra.

- `jobs → ingestion` **12x**: o job chama a coleta. Natural, e provavelmente certo.
- `ingestion → jobs` **1x**: `lib/the_band/ingestion.ex:17` cita `TheBand.Jobs.SyncGitHubEO` —
  a coleta **enfileira o próprio job**.
- `integrations → ingestion` **1x**: `client.ex:11` usa `TheBand.Ingestion.Cota` — o cliente
  HTTP consulta a cota, que mora na coleta.

**Proposta:** as duas arestas de volta são de **uma referência cada**, e as duas apontam para
coisas que não são "coleta": enfileirar e contar cota. Mover `Ingestion.Cota` para um contexto
próprio (ou para `integrations`, que é quem a consome) e tirar o enfileiramento de
`ingestion.ex` desfaz duas realimentações com pouca cirurgia.

### Corte 2 — `tenants` ↔ `ontology/eo` e `tenants` ↔ `ontology/spo`

`ontology/eo → tenants` **10x** é esperado: toda função de EO recebe `%Tenant{}`.

A volta, `tenants → ontology/eo` **3x**, é o acoplamento real, e está em dois lugares:
`access.ex:51-52` (a regra de visibilidade precisa da estrutura organizacional) e
`auth.ex:29` (alias do schema `Person`, para o elo).

**Proposta:** `auth.ex:29` é `S` — alias de schema atravessando fronteira. Trocá-lo por uma
consulta exposta em `EO` desfaz **um terço** desta aresta sem discutir arquitetura. As outras
duas são `F` e legítimas: decidir visibilidade **exige** conhecer a estrutura, e essa é a
dependência que o produto tem.

### Corte 3 — os seis aliases de schema atravessando contexto

São o acoplamento mais barato de desfazer, porque não pedem decisão de desenho: pedem uma
função de consulta no dono do schema.

| Quem monta a consulta | Sobre schema de | Onde |
|---|---|---|
| `ontology/spo` | `work_items` | `projects.ex:34` — `WorkItems.Schemas.CollectedIssue` |
| `ontology/sro` | `work_items` | `queries.ex:12` — `WorkItems.Schemas.CollectedIssue` |
| `sources` | `ontology/cmpo` | `sources.ex:15` — `CMPO.Schemas.ObservedRepository` |
| `teams` | `ontology/eo` | `problems_now.ex:54` — `EO.Schemas.TeamMembership` |
| `teams` | `work_items` | `problems_now.ex:58-59`, `flow_per_person.ex:56` |
| `work_items` | `ontology/spo` | `person_work.ex:25` — `SPO.Schemas.PerformedProjectActivity` |

**Proposta:** os dois de `teams` **não fecham ciclo** (ninguém usa `teams`), e são os mais
seguros de deixar como estão. Os quatro restantes participam de realimentação, e cada um vira
uma função na fronteira do dono.

> **Cuidado, e é o mais importante desta seção.** Trocar `S` por `F` **não é automaticamente
> melhor**: uma consulta exposta na fronteira que devolve uma lista grande pode ser mais cara
> que o `join` que existe hoje. A matriz diz *onde* está o acoplamento, e não que ele seja
> defeito. Quem decide é quem conhece a consulta.

## O que a matriz NÃO diz

- **Nada sobre qualidade.** Uma aresta `F` com 12 referências pode ser a coisa mais certa do
  projeto. A DSM mede **acoplamento**, não acerto.
- **Nada sobre a tela.** `lib/the_band_web/` ficou fora, e é de lá que vem boa parte das
  chamadas de fronteira. Uma DSM tela × contexto é trabalho que **não existe ainda**.
- **Nada sobre chamadas dinâmicas.** A varredura é textual: `apply/3`, nomes de módulo montados
  em tempo de execução e módulos passados como configuração **não aparecem**. Se existirem,
  há arestas a mais que esta matriz não tem.
- **Nada sobre frequência de execução.** Uma referência escrita uma vez e executada a cada
  coleta pesa o mesmo que uma escrita doze vezes e nunca executada.

## As 7 arestas que existiam só na documentação

Registro do método, porque o resultado depende dele. A primeira varredura devolveu **143**
arestas; excluindo `@moduledoc`, `@doc` e comentários, sobraram **136**. As sete diferenças
eram nomes de módulo citados em **texto explicativo**, e não dependências:

| Aresta aparente | Onde estava |
|---|---|
| `vault → application` | `lib/the_band/vault.ex:30` (moduledoc) |
| `vault → encrypted` | `lib/the_band/vault.ex:6` (moduledoc) |
| `segredo → sources` | `lib/the_band/segredo.ex:49` (moduledoc) |
| `segredo → vault` | `lib/the_band/segredo.ex:38` (moduledoc) |
| `tenants → release` | `lib/the_band/tenants/bootstrap.ex:20` (moduledoc) |
| `ontology/eo → periodos` | `lib/the_band/ontology/seon/eo/queries.ex:343` (comentário) |
| `ontology/sro → ontology/smpo` | `lib/the_band/ontology/continuum/sro.ex:23` (moduledoc) |

**Sem essa exclusão, `vault` e `segredo` apareceriam em ciclos que não existem.** É o mesmo
princípio das outras páginas desta pasta: o número tem de sair de uma contagem cujo método
está escrito.

## Como regenerar

O método, em quatro passos, para quem precisar refazer depois de uma mudança grande:

1. mapear todo `defmodule` de `lib/the_band/` para o arquivo que o define;
2. varrer cada arquivo por referências `TheBand.*`, **pulando** blocos `"""` e linhas `#`, e
   resolver cada uma para o módulo conhecido de nome mais longo;
3. atribuir origem e destino ao **contexto** (primeiro diretório sob `lib/the_band/`, com
   `ontology/` aberta por ontologia), descartando as arestas de um contexto para si mesmo;
4. rodar Tarjan para os ciclos e Eades-Lin-Smyth para a ordem que minimiza as marcas acima da
   diagonal.

A classificação da marca sai do **alvo**: `TheBand.Ontology.KnowledgeBase` → `B`; módulo em
`schemas/` ou com `.Schemas.` no nome → `S`; qualquer outro → `F`.
