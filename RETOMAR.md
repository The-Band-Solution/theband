# Retomar — 2026-08-17 (tarde)

## A ação pendente de VOCÊ: mergear a onda de PRs

Ordem sugerida (o GitHub reaponta as bases sozinho):

| PR | O quê | Base |
|---|---|---|
| **#406** | fix: mediana 0.0 não derruba a rodada; exceção vira falha da pessoa | main — **primeiro** |
| **#407** | #399: primeira geração gera com designação, mesmo só de abertas (47→60 elegíveis) | empilhado no #406 |
| **#409** | #402: perfil em inglês, regra no schema (provado: FeLiXp90 em inglês) | empilhado no #406 |
| **#408** | #398: report agrupado por motivo, texto dito uma vez | main |
| **#410** | #403: evolução nas duas páginas; um mês só é ausência nomeada | main |
| **#405** | skill Impeccable vendorizada (301 arquivos) | main |

Já mergeados hoje: #396 (feature 029 + report + polish do piloto), #404 (PRODUCT.md + DESIGN.md). #395, #398, #399, #402, #403 fecham com os merges — **conferir depois** (regra da casa).

## Depois dos merges

- **Apagar a branch remota `029-competencias-da-equipe`** — recriada por engano por um push meu depois do merge do #396; o conteúdo está no #406.
- **Clicar "run now — everyone"** em /profiles: com as regras novas, esperado ~60 gerados de 88, todos em inglês. A rodada de 00:09 que travou está encerrada como ended_early (crash de mediana 0.0 — consertado e testado); os 34 perfis dela ficam.
- A landing polida e **mobile-first** já está publicada (gh-pages, sem PR).

## Próximo trabalho (nesta ordem)

1. **#400 — coletar comentários das issues**, usando os modelos da ontologia (classificar na base, mapeamento YAML, esquema derivado, vertical slice). Ciclo Spec Kit completo.
2. **#401 — coletar CI do GitHub** (workflow/check runs), mesma restrição. Depois do #400.
3. **Sprint 018: sprint-review.md** e consolidar lições (o crash da rodada é a oitava ocorrência do sucesso silencioso — já registrada na memória).
4. #397 — equipe formada por equipes (rollup em `TeamSkills.coverage`).
5. #81 — filtro por organização nas telas.

## Decisões suas em aberto (backlog)

#356 (pisos N/M), #358 (quickstart — o botão da landing diz README até existir),
#367 (Conecta Fapes), #368 (prazo), #369 (FR-012), #370 (FR-007), #176 (iterações),
#363/#364 (competência como unidade — adiado por você).

## Achado de gestão (não é código)

24 pessoas sem NENHUMA issue designada nos repositórios coletados. O report em
/profiles nomeia cada uma, agora agrupadas com contagem no cabeçalho.
