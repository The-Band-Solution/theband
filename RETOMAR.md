# Retomar — 2026-08-17 (noite)

## Pendente de VOCÊ

**Mergear o PR #427** — https://github.com/The-Band-Solution/theband/pull/427 (verde,
revisor conferido). As cinco relações do rastreio declaradas na rede + os mapeamentos de
PR, commit e CI. Fecha a #426.

Já mergeados hoje: #396, #404, #405, #406, #407, #408, #409, #410 e **#425** (feature 030
— comentários das issues).

**Conferir issues depois de todo merge.** Aconteceu de novo hoje: o corpo do #425 dizia
`Closes #411 #412 …` com 14 issues numa palavra-chave só, e o GitHub fechou **apenas a
#411**. Cada issue precisa da própria keyword (`Closes #411, Closes #412, …`). Fechei as 13
à mão. Antes de mergear, conferir com:
`gh api graphql -f query='{repository(owner:"The-Band-Solution",name:"theband"){pullRequest(number:N){closingIssuesReferences(first:30){totalCount}}}}'`

## Onde a sessão parou

Branch `031-rastreio-issue-pr-commit`. Há **legendas de rótulo não commitadas** (ver
abaixo) — os gates estavam rodando quando você desligou; conferir antes de commitar.

### O que existe de MODELO, sem coleta nenhuma

Isto responde "em qual tela vejo commits e PR?": **em nenhuma, ainda.** Nenhuma tabela de
commit, PR, change_request ou workflow existe no banco — conferido. Hoje foi escrito só o
contrato:

- **`cmpo/modules/change_traceability.yaml`** (módulo novo na CMPO, que a tese já havia
  estendido): stakeholder→submissão→solicitação, stakeholder→checkin→solicitação,
  stakeholder→commit→solicitação. Seis relações, um conceito novo
  (`cmpo.change_request_submission` — participação exige evento, e solicitação é objeto
  social).
- **`sro/modules/scope_traceability.yaml`** (módulo novo na SRO, com `cmpo` nas deps):
  solicitação→user story / performed task / epic.
- Mapeamentos: `github.pull_request`, `github.commit`, `github.workflow_run`,
  `github.workflow_job`, e a regra `github.commit_issue_mention`.
- 4 testes que impedem a cadeia de ser desfeita em silêncio.

**Nenhuma ontologia nova foi criada** — só módulos dentro das que existem.

### Legendas de rótulo (não commitado)

Você pediu que os rótulos se expliquem na tela. Feito, e falta commitar:

- `silent` virou **`never discussed`** — você perguntou o que era, e rótulo que precisa da
  frase ao lado falhou. Os quatro agora falam da mesma coisa: never discussed / stale
  discussion / active discussion / discussion not collected.
- **Legenda dos quatro estados** na seção de paradas da página da pessoa, dizendo o que
  cada um significa e o que fazer.
- **Frase de significado por grupo** no report da rodada (`below_floor`, `no_assignment` são
  chaves de regra, opacas para quem abre a tela) — com o detalhe só onde acrescenta, porque
  um teste conta as repetições.

## Próximo trabalho

1. **Coletar PR + commits** (feature 031 propriamente): migração, ingestão, e a tela do
   rastreio — issue mostrando os PRs que a atendem, PR mostrando commits e quem fez. O
   modelo está pronto; falta tudo o resto.
2. **#401 — coletar o CI** (workflow runs/jobs). Mapeamento já escrito; a CIRO já tinha os
   três gatilhos e as fases por resultado.
3. **Review dos sprints 018 e 019** + lições. Duas desta sessão:
   - o crash da mediana 0.0 que deixou a rodada muda por 7h (oitava ocorrência do sucesso
     silencioso — já na memória);
   - `Closes` com várias issues numa keyword só (segunda ocorrência da mesma família da
     L48 — já na memória).
4. **Polish da discussão**: ela está na coluna estreita, e comentário longo estica o cartão
   a 12 mil pixels. Conversa é conteúdo, não metadado — merece a coluna larga.
5. #397 (equipe de equipes), #81 (filtro por organização).

## Decisões suas em aberto

#356 (pisos N/M), #358 (quickstart — o botão da landing diz README até existir), #367,
#368, #369, #370, #176, #363/#364.

## Rodada de perfis

A rodada de 00:09 travou por um crash (consertado no #406, mergeado). Encerrada como
`ended_early`. **Clicar "run now — everyone"** em /profiles gera com as regras novas:
esperado ~60 de 88, em inglês. ~750k tokens.
