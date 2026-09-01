# Pendências — texto de tela fora do verificador v2

**Refeito em 2026-08-29 (047/T013, #610)** depois de a aceitação do sprint 024
derrubar a versão anterior: ela media com o grep do próprio instrumento e herdava a
cegueira dele (L80) — a classe "assign de mensagem renderizado" ficou invisível e
duas user stories voltaram. A classe agora está DENTRO do verificador (v2, T012);
este documento enumera o que segue FORA, e diz como foi validado.

## O que o verificador v2 cobre (gate `mensagens no catálogo`)

- `put_flash` — todas as formas (simples, pipe, qualificada), por AST;
- `assign` com chave de mensagem declarada (`:erro`, `:ok`, `:error`, `:aviso`) —
  a lista de chaves cresce com cada classe nova descoberta, no mesmo commit do caso
  de teste.

## O que segue fora, enumerado

Texto corrido em HEEx: avisos `<.notice>`, ausências `<.absent>`, títulos,
parágrafos e legendas de gráfico. Contagem de chamadas `<.notice>`/`<.absent>` por
`grep -rc '<\.notice\|<\.absent' lib/the_band_web --include='*.ex'` em 2026-08-29:

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

**A contagem acima NÃO é o inventário completo do HEEx**: parágrafos e títulos não
entram nela (um `<p>` explicativo não é notice). A migração de cada tela inventaria
o texto dela ao chegar — a tabela diz por onde começar, não quanto falta ao todo.

## Validação por amostragem independente (L80)

Duas telas abertas à mão em 2026-08-29, lendo o render e conferindo contra este
documento e contra o verificador:

- `teams_live/show.ex`: 1 `<.absent>` (linha 615, cobertura de perfis) — bate com a
  tabela; nenhum assign de mensagem restante (verificador v2 zero ali).
- `ai_live/index.ex`: 2 `<.absent>` (linhas 170 e 212) — bate; os flashes e o
  estado da chave já migrados (044/047/048).

Amostra limitada a duas telas nesta rodada; a regra fica: **toda queima de tela
valida a linha dela por leitura do render, não pelo grep** — e classe nova de ralo
achada na queima entra no verificador no mesmo commit.

## Classes nomeadas fora do verificador v2 (decisões da aceitação do 025)

- **Rótulos de situação em `.ex`** (`origem_rotulo/1` em access_scopes_live e
  parentes): classificados pela pessoa mantenedora (2026-08-29) como
  HEEx-pendência — migram quando a tela deles queimar.
- **Frases nascidas em função de origem**: deixaram de ser pendência E deixaram de
  depender de caça — o verificador v3 (2026-08-30) resolve UM salto no mesmo
  arquivo e as vê. Os 9 membros vivos foram migrados no mesmo commit
  (`ja_e_de_outra`, `frase_do_recalculo` ×3, `frase_da_mudanca` ×2,
  `primeira_mensagem` do sync, `frase_do_resultado` ×2).
  **A lição do caminho**: a caça manual pela forma `(erro|ok|error|aviso): funcao(`
  não via a forma posicional `put_flash(socket, :error, funcao(...))` — duas
  sintaxes, uma classe. Caça por forma erra; regra no verificador não.

**Correção de afirmação (aceitação do 025)**: este documento dizia que a razão do
FR-007 "vive nos comentários do próprio HEEx" — conferido nos três pontos de
"Checks", não vive. A razão vive nas SPECS das features que fixaram os termos
(044 para "Checks"), e quem queimar a tela a busca lá.

## Obrigações que viajam com as pendências

- **FR-007 (decisão de vocabulário migra com a razão)**: os textos com termo fixado
  — ex.: "Checks", nunca "CI" (decisão da 044) — estão no HEEx destas telas. Quem
  queimar a tela leva a decisão junto, como comentário `#.` na entrada do catálogo.
  Até lá, a razão vive nos comentários do próprio HEEx.
- Frase nova em tela NOVA nasce no catálogo desde já — o gate reprova os ralos, e a
  revisão de PR cobra o resto.
