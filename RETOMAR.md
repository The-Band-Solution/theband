# Retomar — 2026-08-18

## Pendente de VOCÊ: mergear a cadeia, nesta ordem

Os PRs são **empilhados** — o GitHub reaponta a base sozinho conforme você mergeia.

| ordem | PR | o quê |
|---|---|---|
| 1 | **#430** | a coleta das mudanças: 5.035 solicitações, 16.416 commits, 1.078 vínculos, na mesma sincronização |
| 2 | **#431** | a lista `/work/changes`, a busca que lê a forma, os commits da pessoa, a linha do tempo |
| 3 | **#433** | os arquivos da mudança e a página `/work/files` — quem mexeu, e por qual issue |
| — | **#432** | IA em Tools, Profiles em Sync (independente dos três acima; fecha #428) |

Todos com revisor conferido e gates 13/13. **Conferir as issues depois de cada merge** —
`Closes` com várias issues numa keyword só fecha a primeira (aconteceu no #425).

## O que a sessão entregou

**Feature 030** (mergeada) — a conversa das issues: 2.013 comentários, o report da rodada
agrupado, os rótulos que se explicam na tela.

**Feature 031** (mergeada) — as relações do rastreio declaradas na CMPO e na SRO, com um
conceito novo (`change_request_submission`) porque participação exige evento.

**Features 032, 033, 035** (nos PRs acima) — a coleta das mudanças, as telas de navegação
e os arquivos. O rastreio completo: **arquivo → commit → pessoa → solicitação → issue**.

**Feature 034** (#432) — Sync concentra o que roda sozinho; IA é aba de Tools.

## Próximo trabalho

1. **#401 — coletar o CI do GitHub** (workflow runs e jobs). O mapeamento já está escrito
   e a CIRO já tinha os três gatilhos e as fases por resultado. É a última fonte grande.
2. **Review dos sprints 018, 019 e 020** + consolidar lições. Cinco desta sessão:
   - o crash da mediana `0.0` que deixou a rodada muda por 7h (oitava do sucesso silencioso);
   - `Closes` com várias issues numa keyword só (segunda da L48);
   - marcar por timestamp falha no mesmo segundo (L46 reincidindo — corrigido para
     marcar por conjunto observado);
   - **contador armazenado mente quando nasce depois do dado** (a coluna de commits
     mostrava zero; virou derivada das entradas);
   - **"não coletado" era limitação nossa, não da origem** (509 PRs truncados: a API
     paginava, e eu não).
3. #397 (equipe de equipes), #81 (filtro por organização), #363/#364 (competência como
   unidade).

## Decisões suas em aberto

#356 (pisos N/M), #358 (quickstart — o botão da landing diz README até existir), #367,
#368, #369, #370, #176.

## A rodada de perfis

Encerrada como `ended_early` pelo crash (consertado). **Clicar "run now — everyone"** na
aba Profile generation gera com as regras novas: esperado ~60 de 88, em inglês.
