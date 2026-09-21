# Modelos

<!-- DERIVADO da estrutura de agentes em 2026-09-07; índice recontado em 2026-09-18
     (26 documentos, 42 blocos ```mermaid```, por varredura de docs/modelos/**/*.md).
     Índice mantido à mão; cada documento abaixo é derivado do código e traz a própria
     proveniência. -->

Os modelos que a implementação não carrega sozinha: o que existe, por quais situações passa, o
que o banco guarda, e o que depende do quê no backlog.

**A regra**: modelo é **derivado**, nunca lembrado. Todo documento aqui sai de uma fonte do
repositório — schema, migração, YAML da base, spec, issue — e abre dizendo de onde saiu, com
`arquivo:linha` e a data da conferência. Quem escreve é o papel
[Documentation — Modelos](../../.claude/agents/documentacao-modelos.md).

| Pasta | O que responde | Forma |
|---|---|---|
| `classes/` | quais entidades existem, o que carregam, como se ligam | `classDiagram` (Mermaid), uma por subsistema |
| `estados/` | por quais situações um registro passa, e o que provoca cada transição | `stateDiagram-v2`, com gatilho, guarda e o teste que prova |
| `banco/` | quais tabelas, colunas, chaves e **índices parciais** (que carregam invariante) | `erDiagram`, derivado das migrações |
| `dsm/` | o que precisa vir antes do quê, entre épicos, user stories e features | matriz em Markdown, com blocos e ciclos nomeados |

## O que existe hoje

**26 documentos, 42 diagramas Mermaid**, conferidos contra o código em **2026-09-18** — e
todos os 42 **renderizados** com `@mermaid-js/mermaid-cli@11.17.0` nessa data, para que nenhum
bloco publicado seja código que não vira desenho. A coluna
*diagramas* é a contagem de blocos ```` ```mermaid ```` no arquivo — zero significa que o
documento é censo, tabela ou matriz, e não que falta desenho.

### Por onde começar

Se você chegou agora ao projeto, leia nesta ordem. Cada um destes quatro é um **censo**, e
existe para dizer o tamanho do que você está olhando antes de mostrar qualquer desenho:

| Comece por | Responde |
|---|---|
| [`arquitetura/visao-geral.md`](arquitetura/visao-geral.md) | como o sistema se monta e por onde o dado entra — em C4 |
| [`banco/mapa-das-tabelas.md`](banco/mapa-das-tabelas.md) | quantas tabelas existem, e qual ERD cobre cada uma |
| [`classes/mapa-dos-schemas.md`](classes/mapa-dos-schemas.md) | quantos schemas existem — e por que `Repo.preload/2` quase não funciona aqui |
| [`estados/mapa-dos-ciclos-de-vida.md`](estados/mapa-dos-ciclos-de-vida.md) | onde mora o estado, já que só 3 das 66 tabelas têm coluna `status` |

### Arquitetura

| Documento | Diag. | Do que é derivado |
|---|--:|---|
| [`arquitetura/visao-geral.md`](arquitetura/visao-geral.md) | 9 | `application.ex`, `router.ex`, `compose.yaml`, `hooks.ex`, `access.ex`, `ingestion/*`, `config/config.exs` |

A estrutura é **C4** — contexto, contêineres e dois de componentes (coleta e acesso). O que é
**dinâmico** — a sequência da coleta, o boot da base, a cadeia do tenant, o pipeline de CD —
continua `flowchart`, e o documento diz por quê. **O suporte a C4 no Mermaid é experimental**:
visualizador antigo mostra o bloco como texto, e os diagramas foram escritos para continuarem
legíveis assim.

### Classes — o que existe, e o que cada coisa carrega

| Documento | Diag. | Cobre |
|---|--:|---|
| [`classes/mapa-dos-schemas.md`](classes/mapa-dos-schemas.md) | 0 | **censo**: 65 schemas, 3 associações Ecto, 214 campos `:binary_id` |
| [`classes/eo-estrutura-organizacional.md`](classes/eo-estrutura-organizacional.md) | 1 | organização, pessoa, equipe, papel, vínculo |
| [`classes/tenants-e-acesso.md`](classes/tenants-e-acesso.md) | 1 | tenant, conta, concessão, desativação |
| [`classes/ingestao-e-observacao.md`](classes/ingestao-e-observacao.md) | 1 | ferramenta, credencial, coleta, repositório |
| [`classes/trabalho-e-mudanca.md`](classes/trabalho-e-mudanca.md) | 2 | issue, promoção, PR, commit, verificação |
| [`classes/projetos-e-processo.md`](classes/projetos-e-processo.md) | 2 | projeto, quadro, item, sprint, atividade |
| [`classes/perfis-e-modelo.md`](classes/perfis-e-modelo.md) | 1 | credencial de modelo, execução, perfil |
| [`classes/declaracoes-da-organizacao.md`](classes/declaracoes-da-organizacao.md) | 1 | **novo** — os 9 schemas de declaração, incluindo os 3 da feature 066 |

### Banco — tabelas, chaves e índices parciais

| Documento | Diag. | Cobre |
|---|--:|---|
| [`banco/mapa-das-tabelas.md`](banco/mapa-das-tabelas.md) | 1 | **censo** das 66 tabelas de domínio + o mapa de alto nível dos grupos |
| [`banco/eo-e-acesso.md`](banco/eo-e-acesso.md) | 1 | 14 tabelas |
| [`banco/ingestao-e-observacao.md`](banco/ingestao-e-observacao.md) | 1 | 10 tabelas |
| [`banco/trabalho-e-mudanca.md`](banco/trabalho-e-mudanca.md) | 2 | 17 tabelas |
| [`banco/projetos-e-processo.md`](banco/projetos-e-processo.md) | 2 | 17 tabelas |
| [`banco/perfis-e-modelo.md`](banco/perfis-e-modelo.md) | 1 | 5 tabelas |
| [`banco/declaracoes-da-organizacao.md`](banco/declaracoes-da-organizacao.md) | 1 | **novo** — 9 tabelas de declaração, 12 índices parciais, FK declarada × coluna crua |

### Estados — por que situações um registro passa

| Documento | Diag. | Cobre |
|---|--:|---|
| [`estados/mapa-dos-ciclos-de-vida.md`](estados/mapa-dos-ciclos-de-vida.md) | 0 | **censo**: 51 tabelas com ciclo de vida, 3 com `status`, e a coluna `expires_at` que **não existe** |
| [`estados/declaracao-revogavel.md`](estados/declaracao-revogavel.md) | 2 | **novo** — a família de 9 tabelas: vigente, revogada, redeclarada |
| [`estados/observacao.md`](estados/observacao.md) | 2 | **novo** — `no_longer_observed_at` em 23 tabelas, e `excluded_at`, que é outra coisa |
| [`estados/atividade-executada.md`](estados/atividade-executada.md) | 1 | **novo** — por que a ocorrência nunca é atualizada; promoção e complementação |
| [`estados/conta.md`](estados/conta.md) | 2 | **novo** — desativar × revogar o elo, e por que confundi-los foi achado de segurança |
| [`estados/coleta.md`](estados/coleta.md) | 4 | **novo** — a execução, a ferramenta (estado por evento) e a credencial |
| [`estados/projeto-declarado.md`](estados/projeto-declarado.md) | 2 | **novo** — o projeto e seus quatro vínculos; o único estado final que não volta |
| [`estados/vinculo-de-equipe.md`](estados/vinculo-de-equipe.md) | 2 | quatro campos, cinco situações |

### DSM — o que precisa vir antes do quê

| Documento | Diag. | Cobre |
|---|--:|---|
| [`dsm/modulos-de-lib.md`](dsm/modulos-de-lib.md) | 0 | **novo** — 37 contextos de `lib/the_band/`, 136 arestas, **2 ciclos** nomeados |
| [`dsm/060-tela-da-equipe.md`](dsm/060-tela-da-equipe.md) | 0 | US1 a US9 da feature 060 |

> **O índice é mantido à mão, e por isso mente primeiro.** Em 2026-09-12 ele ainda dizia
> *"`banco/` ainda está vazia"* enquanto a pasta tinha seis documentos e sete ERDs. A regra
> que sobra disto: quem acrescenta documento **atualiza esta tabela no mesmo commit** — índice
> que contradiz o diretório é pior que índice nenhum, porque quem o lê não vai conferir.

## Três coisas que surpreendem quem chega

Estão medidas nos censos, e mudam como se lê todo o resto:

1. **O estado quase nunca é uma coluna.** Três das 66 tabelas têm `status`; o resto codifica
   situação em pares de datas que podem ser nulas, para preservar *desde quando*.
   → [`estados/mapa-dos-ciclos-de-vida.md`](estados/mapa-dos-ciclos-de-vida.md)
2. **Quase não há associação Ecto.** São 3 em 65 schemas, contra 214 campos `:binary_id`. A
   chave estrangeira existe no banco (201 delas) e **não** é modelada no Ecto: o `join` é
   sempre explícito. → [`classes/mapa-dos-schemas.md`](classes/mapa-dos-schemas.md)
3. **Nada é apagado.** Encerrar, revogar, excluir e marcar ausência são todos `UPDATE`, com
   autor e instante. A única linha que some é a que nunca foi escrita.
   → [`estados/observacao.md`](estados/observacao.md)

## Como ler uma DSM

Linhas e colunas são os mesmos itens, na mesma ordem. A célula `(i, j)` marcada significa
**i depende de j**, e a marca diz a natureza: `D` dado · `T` tela · `R` regra · `E` esquema.
Depois de reordenar, o que fica **abaixo** da diagonal é ordem possível; o que sobra **acima**
é ciclo, e ciclo é achado — o documento o nomeia e propõe o corte. Blocos na diagonal são as
fatias que viajam juntas numa PR; a recomendação de fatiamento é oferecida ao Product Owner,
que decide.
