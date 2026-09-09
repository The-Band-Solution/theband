# Retomar — estado em 2026-09-09, a v0.6.0 no ar e cinco achados de segurança fechados

**Este é o único documento de estado.** Havia dois — este e
`docs/sprints/RETOMAR.md` —, e eles divergiram: em 2026-09-09 um estava em 26/08 e o
outro em 03/09, cada um descrevendo um produto diferente. O de `docs/` passou a apontar
para cá.

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

---

## Onde parei, em uma frase

**A v0.6.0 está em produção** com a tela da equipe inteira, o site ganhou três endereços,
e uma avaliação de segurança de 16 achados foi feita — **cinco fechados, quatro PRs
esperando merge, e o H2 explicitamente incompleto.**

## O primeiro comando

```bash
git checkout development && git pull
mix gates          # o veredito é o CÓDIGO DE SAÍDA, e nada depois dele
```

Estava **0** em 2026-09-09, com **1 981 testes** passando.

> **`mix deps.get` já não é necessário depois de trocar de branch.** O `deps` estava
> commitado como link simbólico absoluto apontando para si mesmo, e apagava as
> dependências a cada `git checkout` — seis vezes num dia. Corrigido no #836, com gate que
> impede a volta.

---

## O que está no ar

A **v0.6.0**, publicada em 2026-09-09 às 13:39Z. PR **#828** (`development → main`), CD
verde nos sete passos, tag `v0.6.0` em `43cb7c0`, imagem em
`ghcr.io/the-band-solution/theband`, e o Dokploy respondeu
`{"message":"Application deployed successfully"}`.

**124 commits, 24 PRs (#796 a #827).** O grosso é a feature 060 — a tela da equipe: quem
está nela e de onde veio cada afirmação, declarar/trocar/encerrar papel, o equívoco que
nunca foi vínculo, *Problems now* com oito cartões, e o fluxo em três granulações com
previsão por Monte Carlo.

> ⚠️ **Webhook aceito não prova que o contêiner roda a 0.6.0.** Não há endpoint de versão
> nem versão na página — `/health`, `/version` e `/api/version` devolvem 404. Confirmar
> exige olhar o Dokploy. É a lacuna que a regra nova do PO e do Design fecha, e ela nasceu
> **junto** com esta release, não antes dela.

### O site tem três endereços, e cada um serve a alguém

| endereço | o que é | mantido por |
|---|---|---|
| `theband.dev` | a landing — o argumento | à mão, na raiz da `gh-pages` |
| `theband.dev/docs/` | a página do produto: para quem é, o que faz, os conceitos, as versões | à mão, na raiz da `gh-pages` |
| `theband.dev/developers/` | a referência técnica | gerado pelo MkDocs, workflow `docs.yml` |

A landing liga para os dois em **três lugares**: barra do topo, fecho da página e pé. E o
guarda do `docs.yml` confere `CNAME`, o `index.html` da raiz **e** `/docs/index.html` — o
último porque `/docs/` deixou de ser gerado, e um deploy que o apagasse publicaria com
sucesso derrubando um endereço anunciado.

---

## Os quatro PRs abertos, e a ordem de merge

| PR | o que | tipo de merge |
|---|---|---|
| **#837** | **H3-A** — `tenants.status` passa a ser lido, em três portas | squash |
| **#838** | **H2** — o veredito nas duas rotas sobre pessoa nomeada, e o procedimento de desligamento escrito | **merge commit** — o H6 é empilhado |
| **#839** | a investigação do estado divergente da issue, e o RETOMAR do site | squash |
| — | **H6** — `fix/admin-alcanca-pessoa`, commitada e empurrada, **sem PR aberto** | merge commit |

### E duas branches sem PR que precisam entrar

```
docs/po-release-v0.6.0-e-fila-de-seguranca
security/o-que-consertar-agora-2026-09-09
```

**Cinco PRs meus citam o documento do Security como "lacuna declarada".** Enquanto ele não
entrar no `development`, a referência não resolve.

---

## A avaliação de segurança: 16 achados, dez de severidade alta

`docs/seguranca/2026-09-09-o-que-consertar-agora.md`, na branch do Security. Cada achado
tem cenário de ataque no formato que o QA transforma em teste, e quatro foram **medidos com
teste**, não deduzidos.

### Fechados

| # | o que era | onde |
|---|---|---|
| **H1** | `POST /set-password` trocava a senha **sem exigir a atual** — acesso temporário virava posse da conta | #835 |
| **H12** | `deps` commitado como link simbólico absoluto para si mesmo | #836 |
| **H3-A** | `tenants.status` existia e **ninguém o lia** — tenant suspenso autenticava | #837 |
| **H2** *(parcial)* | duas rotas sobre pessoa nomeada sem veredito nenhum | #838 |
| **H6** | `pode_ver_equipe/3` concedia ao admin e `pode_ver/3` não — a tela afirmava um regime que não aplicava | sem PR |

**A FR-022 da spec 045 foi emendada** pelo H6 — *"ser administrador MUST NOT abrir painel
nenhum por si"* deixou de valer, com o texto original preservado riscado e a razão ao lado.

### Abertos, na ordem que o Product Owner decidiu

1. **H3-B — `users.disabled_at`.** Não existe estado de conta desativada. **Tem migração**,
   e o ensaio de restauração do §6 do runbook está adiado porque a conta S3 não existe —
   **bloqueio de recurso, não de agenda**, e confundir os dois é o que fez esse item ser
   replanejado por cinco releases;
2. **H4 — nenhum evento de autenticação ou autorização é registrado.** É o que responde
   *"isto já aconteceu?"*, e hoje a resposta para H1, H2 e H3 é **não se sabe**. O Security
   registrou isso como **resultado**, não como lacuna dele;
3. **H7 e H8 — sem release nenhum.** O Dokploy implanta `latest`, e as ações do CI usam tag
   mutável. Os únicos que se consertam sem código nem deploy;
4. **H9 — `ssl: true` comentado.** A severidade depende da **topologia de produção**, e é
   pergunta para quem opera. Verificado na fonte: o `Ecto` aceita `?ssl=true` na URL, mas o
   `postgrex` usa `verify_peer` com CAs do sistema — **certificado autoassinado quebraria o
   boot**;
5. **H5, H10, H11, H13 a H16** — média e baixa.

### ⚠️ O H2 **não** está resolvido, e não deve parecer

O inventário do Security é **piso, não total**: **8 dos 26** LiveViews autenticados foram
examinados quanto ao que exibem. As duas rotas medidas foram consertadas; as outras 18
ninguém olhou.

E dentro da própria página da pessoa a assimetria é fina — o perfil escrito por modelo e a
proveniência (com os PRs e commits) **não** são gateados.

---

## O achado da pessoa mantenedora que virou investigação

**O estado da issue no The Band divergindo do GitHub** —
`docs/backlog/investigar-estado-divergente-da-issue.md`, PR #839. Dois casos reais, com URL
nos dois lados, e **são defeitos diferentes com o mesmo sintoma**:

- **apagada** na origem, aberta na tela. `collected_issues` **tem**
  `no_longer_observed_at`, e o `grep` por quem o marca encontra só designações e etiquetas
  — nada, aparentemente, marca a issue em si;
- **fechada** na origem, aberta na tela. **Mais grave**: a issue continua existindo com o
  estado novo, e a coleta tinha tudo o que precisava. Se mudança de estado não chega,
  nenhuma medida de fluxo é confiável.

**Comece pelo banco de produção**, e não pelo código: o `state` e o `collected_at` da linha
contra a data do fechamento no GitHub distinguem as quatro hipóteses.

---

## O que o Product Owner decidiu e ainda não foi mergeado

**US9 e US1 passam a aceitas**, com evidência **executada** — não com a existência da
asserção. **US3 continua recusada**: o SC-013 nunca foi cronometrado.

E ele assumiu uma decisão de papel: **a v0.7.0 não sai com H1, H2 e H3 abertos.**

O achado de decomposição continua de pé: a US9 só pôde ser aceita porque **o artefato da
US7 foi construído fora de ordem** — a US7 não tem tarefa alguma, e a US8 também tem código
em produção sem tarefa.

---

## As features especificadas e sem código

| spec | estado |
|---|---|
| **061 — API pública com token** | spec completa, as oito perguntas respondidas, **ADR 0009 proposta**. Falta `plan.md`, `tasks.md`, sprint backlog e a confirmação da ADR |
| **062 — servidor MCP** | spec escrita. **Desbloqueada** pela 061 — o item de backlog dizia *"depende de decidir autenticação e tenant"*, e está decidido |

**A decisão que carrega as duas**: o token guarda *quem* e *onde*, e **nenhum veredito**.
JWT com *claims* está proibido — cria a segunda verdade que `access.ex` foi escrito para
não ter, e ela envelhece no bolso de quem saiu.

E o segredo **não se guarda**: hash irreversível, mostrado uma vez, sem recuperação. A tela
avisa **antes** de gerar.

---

## Decisões da pessoa mantenedora que continuam esperando

Conferido em 2026-09-09 — as quatro que estavam nesta lista desde 26/08 (**#506**, **#367**,
**#442**, **#369**) **fecharam**. Estas cinco seguem abertas:

| issue | o que é |
|---|---|
| **#397** | equipe composta por equipes — hierarquia, com o rollup |
| **#363** | a competência como unidade do perfil, com a tarefa que a demonstra |
| **#356** | T024 — medir o custo real de uma rodada |
| **#504** | dashboards na tela da equipe — throughput e período |
| **#507** | o painel da equipe — depende do critério de início |

---

## Duas armadilhas que 2026-09-09 ensinou, e as duas são de processo

**`git add -A` numa árvore compartilhada com subagentes.** O commit `5d02075` varreu
**1.450 linhas** de dois outros papéis para dentro de um PR de documentação que dizia mudar
três arquivos. Refeito. **Usar caminhos explícitos** quando há agentes em paralelo.

**Anunciar número de PR sem ter aberto o PR.** Aconteceu duas vezes: a branch foi empurrada
e o PR não. Conferir com `gh pr list --head <branch>` antes de citar número.

E uma que virou gate: **dos oito PRs abertos naquele dia, zero declararam o tipo de merge**
— `gh pr create --body` substitui o template inteiro, e a exigência desaparece em silêncio.
O #834 fechou isso: PR sem declaração agora reprova no CI.

---

## Comandos

```bash
mix gates > /tmp/gates.log 2>&1; echo "CODIGO_DE_SAIDA_DO_GATE=$?" >> /tmp/gates.log
grep CODIGO_DE_SAIDA_DO_GATE /tmp/gates.log     # o veredito é o número, lido num comando separado

set -a; . ./.env >/dev/null 2>&1; set +a        # a chave mestra vem do .env, sem imprimir
MIX_ENV=dev mix run script.exs                  # medir contra o banco de desenvolvimento
```

⚠️ **A chave mestra.** `THE_BAND_MASTER_KEY` cifra as credenciais de todas as ferramentas.
Ver `docs/producao/runbook.md` e a memória sobre o caminho de volta se ela se perder.

---

## Referências

- `docs/releases/v0.6.0.md` — a nota da release, com o veredito por user story;
- `docs/seguranca/2026-09-09-o-que-consertar-agora.md` — os 16 achados (branch do Security);
- `docs/seguranca/2026-09-09-api-com-token.md` — a superfície da API, 18 achados;
- `docs/producao/desligar-alguem.md` — o procedimento que **de facto** desliga alguém hoje;
- `docs/producao/runbook.md` — o resto da operação;
- `docs/backlog/README.md` — a fila priorizada de 14 posições (branch do PO).
