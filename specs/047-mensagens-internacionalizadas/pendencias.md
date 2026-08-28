# Pendências — texto de tela fora do verificador v1

**O que este documento é**: o backlog nomeado do que a 047 NÃO cobriu — texto que
vive em HEEx (avisos `<.notice>`, ausências `<.absent>`, estados vazios, títulos e
legendas), fora dos ralos de `put_flash` que o verificador v1 vigia. É documento de
backlog, não allowlist: o gate não o lê (research R7), e cada linha é queimada
quando a tela migrar, em sprint futuro.

**O que já está coberto** (verificador `mix mensagens.verificar`, gate desde
2026-08-28): todo `put_flash` — 137 mensagens migradas, domínios `errors` (97) e
`sistema` (40).

## Por tela — medido, nunca estimado

Contagem de chamadas `<.notice>` e `<.absent>` (as componentes de mensagem nomeada),
por: `grep -rc '<\.notice\|<\.absent' lib/the_band_web --include='*.ex'` em
2026-08-28. O texto corrido de HEEx (parágrafos, títulos, legendas de gráfico) NÃO
está contado — a migração de cada tela o inventaria ao chegar nela.

| Tela | notices/absents | Queimada em |
|---|---:|---|
| `live/people_live/show.ex` (página da pessoa) | 15 | |
| `live/work_item_live/show.ex` | 8 | |
| `live/profile_run_live/index.ex` | 2 | |
| `live/process_live/index.ex` | 2 | |
| `live/ai_live/index.ex` | 2 | |
| `live/work_item_live/index.ex` | 1 | |
| `live/teams_live/show.ex` | 1 | |
| `live/roles_live/index.ex` | 1 | |
| `live/projects_live/index.ex` | 1 | |
| `live/people_live/index.ex` | 1 | |
| `live/change_live/show.ex` | 1 | |
| `live/board_live/index.ex` | 1 | |

## O que o verificador v1 declaradamente não vê

Do contrato (`contracts/catalogo-de-mensagens.md`): texto em `~H`, `@doc`, `Logger`,
`raise` e `IO.puts` de mix task. Ampliar a fronteira é decisão de sprint futuro —
por AST de template, nunca por regex larga ([[padrao-largo-inventa-mais]]).
