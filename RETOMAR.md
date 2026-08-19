# Retomar — 2026-08-19

## Estado dos PRs

Mergeados hoje: **#430, #431, #432, #433, #434**. Issues #428 e #429 fecharam sozinhas.

| PR | branch | estado |
|---|---|---|
| **#435** | `037-coleta-do-ci` | conflito com o main resolvido, aguardando CI |
| **#436→** | `038-menus-do-rastro` | menus e mini-painéis, ainda sem PR |

## O que a 037 entregou

A coleta do CI, duas telas (`/work/verifications` e o detalhe) e a seção de verificação
na página da mudança.

**O achado que reorientou a feature:** toda execução do Actions estava sendo mapeada para
`ciro.continuous_integration_process`. Das 1.051 coletadas, 399 não são integração
contínua nenhuma — `Sync to GitLab`, `Sprint Rollover`, `Card de promoção`. O tipo passou
a ser derivado dos jobs, e "a rede não tem conceito para isto" é resposta, não lacuna.

## O que a 038 entrega

Três menus na barra — `Changes`, `Files`, `Checks` — porque 5.035 solicitações, 87.719
versões de arquivo e 1.051 execuções só eram alcançáveis digitando a URL.

Mais mini-painéis em `/work/changes` e `/work/files`.

## ⚠ O defeito aberto — issue [#438](https://github.com/The-Band-Solution/theband/issues/438)

O painel de `/work/changes` mostrava **"no issue recognised: 4.177"** — 83% das
solicitações. A pessoa mantenedora desconfiou do volume, e estava certa.

Conferido contra a origem em 2026-08-19, três PRs sem vínculo no banco:

| PR | a origem diz | o banco diz |
|---|---|---|
| `The-Band-Solution/theband#427` | fecha #426 | nenhum vínculo |
| `leds-conectafapes/…-otto#127` | fecha #675 | nenhum vínculo |
| `…prestacao-de-contas#133` | fecha nada | nenhum vínculo |

**Dois de três são falha nossa, não fato sobre o processo.** A causa está em
`GithubChangeRequests.vincular_issues/3`: o vínculo só é gravado quando a issue
referenciada **já está em `collected_issues`**. Quando não está, o vínculo é descartado
**em silêncio** — `map_size(ids)` conta só o que casou, e nada registra que a origem dizia
mais.

É a família do sucesso silencioso, de novo.

### O conserto

1. Guardar `attended_issues_total` (o que a origem disse) na solicitação, como já se faz
   com `commits_total`. Sem isso a plataforma não consegue nem medir o buraco.
2. O painel deixa de dizer "no issue recognised" — que é afirmação sobre o processo — e
   passa a separar "a origem não reconheceu nenhuma" de "a origem reconheceu e a issue não
   foi coletada".
3. Investigar por que a issue #426 do próprio `theband` não está coletada, se ela deveria.

**Enquanto isso o quadro não pode ir para produção com esse rótulo** — é o primeiro
item de amanhã.

## Coletas paradas

| coleta | onde parou |
|---|---|
| arquivos dos commits | 8.194 de 16.416 |
| verificações do CI | 4 de 160 repositórios |

Competem pela mesma janela de 5.000 req/h — rodar **uma de cada vez**. Scripts em
`coleta_ci.exs` e `coleta_arquivos.exs`.

## Backlog registrado hoje

- **#436** — os três menus (em implementação)
- **#437** — páginas de erro 404, 403 e 500
- **#438** — o vínculo PR→issue que descarta em silêncio (lição L63)
- **#439** — rastrear código com defeito por pessoa, pelo rastro PR → commit → CI

## Pedidos em aberto da pessoa mantenedora

1. Propor **outras métricas** a partir das necessidades de informação das ontologias.
2. **#439** — rastrear quem sobe código com defeito. O rastro já fecha: a 037 ligou o CI ao
   commit pelo `head_sha`, e a máxima `ci.ap03.integrated_with_red_verification` já
   descreve o fato.

   **A armadilha, escrita antes de implementar:** CI vermelho num ramo de proposta é o
   processo **funcionando** — a verificação pegou o problema antes de integrar. Contar isso
   como defeito premiaria quem desenvolve local e empurra uma vez, e puniria quem usa o CI
   como rede. A medida que se sustenta é **o que integrou vermelho**, não o que ficou
   vermelho.

   E **1.203 dos 16.416 commits têm mais de um autor**: atribuir a "o" autor é impossível
   em 7% deles. Denominador é obrigatório — "3 integrações vermelhas" sem "em 200
   solicitações" é o jeito mais rápido de produzir injustiça com dado correto.
