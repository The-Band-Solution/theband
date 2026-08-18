# Retomar — 2026-08-18 (noite)

## Pendente de VOCÊ: mergear quatro PRs

Os três primeiros são **empilhados** — o GitHub reaponta a base sozinho conforme mergeia.
Todos com revisor conferido e gates 13/13 verdes.

| ordem | PR | o quê |
|---|---|---|
| 1 | **#430** | coleta das mudanças: 5.035 solicitações, 16.416 commits, 1.078 vínculos com issues |
| 2 | **#431** | lista `/work/changes`, busca que lê a forma, commits da pessoa, linha do tempo |
| 3 | **#433** | arquivos da mudança + página `/work/files` — quem mexeu e por qual issue |
| 4 | **#434** | as três fases do CI que faltavam na CIRO + os três antipadrões do workflow |
| — | **#432** | IA vira aba de Tools, Profiles vira aba de Sync (independente; fecha #428) |

**Conferir issues depois de cada merge**: `Closes` com várias issues numa keyword só fecha
apenas a primeira (aconteceu no #425, e as treze restantes foram fechadas à mão).

## Coleta rodando em background

Os arquivos de commit (`cmpo.artifact_copy`) estão sendo coletados de **todos** os 16.416
commits. Ela pausa nas janelas de rate limit e retoma sozinha; o checkpoint por commit
(`files_collected_at`) faz cada execução continuar de onde parou. **Se o processo morrer,
basta rodar de novo** — nada se perde.

## Protótipo esperando sua opinião

**Verificação Contínua (#401)** — https://claude.ai/code/artifact/98a56a7a-9fa9-4d92-8afa-0ae043acfb5a

Três telas para o CI, com dados reais deste repositório. As decisões que ele propõe:

- **cancelado não é malsucedido** — a CIRO define malsucedido como "não integrou por
  problema em componente", e cancelar não é falhar. `cancelled`, `skipped` e `timed_out`
  ficam sem fase;
- **"em andamento" não tem fase** — processo que não terminou não é nem bem nem
  malsucedido;
- **um job pode ser build, teste E inspeção** (o `quality-gates` deste repo é os três) — a
  classificação registra todos, nunca escolhe um;
- **integrado com verificação vermelha** é anti-padrão que só aparece porque CI e rastreio
  estão no mesmo rastro. O PR #427 tem um commit que nunca passou.

**As duas decisões que você tomou revendo o protótipo já estão na base (#434)**: as três
fases (cancelado/pulado/expirado deixaram de ser "sem fase" e ganharam nome) e os três
antipadrões do workflow.

O outro protótipo, já implementado: **Rastro da Mudança** —
https://claude.ai/code/artifact/d5f1ef0e-a9ed-4891-8631-b5384db28a97

## Próximo trabalho

1. **#401 — coletar o CI**. Agora o modelo está completo: mapeamentos de run e job, as três
   fases de `ciro.interrupted_verification`, os três antipadrões de `ci.antipatterns` e a
   regra `github.ci_job_routing` — tudo no #434. **Falta só a coleta e as telas**, e o
   protótipo acima já as desenha.
2. **Review dos sprints 018, 019 e 020** + consolidar lições. Cinco desta sessão:
   - crash da mediana `0.0` deixou a rodada muda por 7h (oitava do sucesso silencioso);
   - `Closes #A #B #C` fecha só a primeira (segunda da L48);
   - marcar por timestamp falha no mesmo segundo (L46 reincidindo → marcar por conjunto);
   - **contador armazenado mente quando nasce depois do dado** (a coluna de commits
     mostrava zero; virou derivada das entradas);
   - **"não coletado" era limitação nossa, não da origem** — duas vezes: os 509 PRs
     truncados e o escopo dos arquivos. Nas duas, o certo foi remover a limitação.
     E ao removê-la apareceu um defeito que não existia ainda: o GitHub usa **403 tanto
     para credencial recusada quanto para rate limit**, e tratar igual marcaria a
     ferramenta como problemática por engano.
3. #397 (equipe de equipes), #81 (filtro por organização), #363/#364 (competência como
   unidade).

## Decisões suas em aberto

#356 (pisos N/M), #358 (quickstart — o botão da landing diz README até existir), #367,
#368, #369, #370, #176.

## A rodada de perfis

Encerrada como `ended_early` pelo crash (consertado e testado). **Clicar "run now —
everyone"** na aba Profile generation gera com as regras novas: esperado ~60 de 88, em
inglês. ~750k tokens.
