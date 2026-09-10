# Retomar — estado em 2026-09-10, a v0.7.0 no ar e a conta desativada conforme o protótipo

**Este é o único documento de estado.** `docs/sprints/RETOMAR.md` aponta para cá (AGENTS.md §5).

Escrito para a sessão seguinte começar trabalhando, não reconstruindo contexto.

---

## Onde parei, em uma frase

**A v0.7.0 está em produção**, a conta desativada foi reimplementada conforme o protótipo
aprovado (#853, mergeado), e a deriva de design do repositório foi de **262 achados a zero**
(#854, aberto). O que sobra é uma lista curta, e o item mais grave dela é um requisito
**MUST** de 2026-09-06 que nunca ganhou tela.

## O primeiro comando

```bash
git checkout development && git pull
mix gates          # o veredito é o CÓDIGO DE SAÍDA, e nada depois dele
```

Estava **0** em 2026-09-10, com **2 026 testes** passando.

---

## O que está no ar

A **v0.7.0**, mergeada em `main` por `dd4272f4` às 04:11Z de 2026-09-10. CD verde nos sete
passos, tag `v0.7.0` apontando para o merge, imagem em `ghcr.io/the-band-solution/theband`, e
o Dokploy respondeu `{"message":"Application deployed successfully"}`.
`app.theband.dev/sign-in` responde **HTTP 200**.

> **Ressalva que vale repetir:** webhook aceito **não prova** container rodando 0.7.0. Não há
> endpoint de versão — `/health`, `/version` e `/api/version` devolvem 404. É a lacuna que a
> regra *"a versão e as features na página"* (agentes de Design e PO) existe para fechar, e
> ela ainda não foi implementada.

### Depois da v0.7.0, na `development` e ainda não em produção

- **#853** — a conta desativada conforme o protótipo: razão de lista fechada mais nota,
  episódio com as duas pontas, a recusa que fica na tela, o vocabulário na base de
  conhecimento. FR-025 a FR-029 da spec 045.

---

## O que fazer, em ordem

### 1. O back-merge, e é o primeiro porque atrasa tudo o resto

`dd4272f` — o merge de release da v0.7.0 em `main` — **não está na `development`**. É a lição
L83/L92: back-merge depois de **cada** release, senão os conflitos crescem e a divergência não
se desfaz.

```bash
git checkout development && git pull
git merge --no-ff origin/main -m "chore: back-merge da v0.7.0"
```

### 2. O #854, e o que ele muda em produção

A ramp tipográfica declarada e a borda colorida de um lado removida. Toca `ui.ex`
(`notice/1`), `teams_live/show.ex`, `sync_live/mapping_rules.ex` e `accounts_live/index.ex`.
Gates verdes, detector em zero. **Não foi visto renderizado** — o `puppeteer` não está
instalado; a inspeção computada (contraste, sobreposição, estouro em 390px) depende de
`npm install puppeteer`.

### 3. FR-003 da spec 055 — vincular pessoa a equipe NÃO TEM TELA

**É o achado da revisão de 2026-09-10, e é o mais grave da lista.**

A spec 055 diz, em cláusula **MUST**:

> **FR-003**: Quem administra MUST poder vincular uma pessoa a uma equipe, com papel e data de
> início, e o vínculo MUST guardar quem o declarou.

E a emenda de 2026-09-06 é explícita: *"Vincular do zero continua existindo para quem a origem
não mostra."*

**Medido:** `EO.declare_team_membership/5` existe, tem `@spec`, tem `@doc`, tem **11 testes** —
e **zero chamadas em `lib/`**. Nenhuma tela do produto a alcança. Os únicos atos de vínculo que
a interface oferece são:

| ato na tela | o que faz | função |
|---|---|---|
| `promover` | transforma **evidência já coletada** em papel declarado | `EO.promote_evidence` |
| `registrar_equivoco` | marca que o vínculo nunca existiu | `EO.record_team_membership_mistake` |
| `registrar_saida` | encerra o vínculo com data | (via `show.ex`) |
| `registrar_papel` / `abrir_papel` | declara ou troca o papel de um vínculo existente | — |

Ou seja: **a saída é declarável e a entrada não.** Quem a origem não mostra não entra em equipe
nenhuma pela interface — e é exatamente o caso que a emenda nomeou.

É o mesmo padrão que o papel de Product Owner recusou duas vezes neste ciclo: função escrita,
documentada, testada, **sem consumidor visível**. A regra da casa é *vertical slice* — nunca
infraestrutura sem consumidor na tela.

**O que fazer**: protótipo primeiro (a tela muda), depois o código. O formulário precisa de
busca entre as pessoas coletadas — o mesmo padrão que `/accounts` já usa para o elo —, papel
opcional e data de início opcional (FR-016 da 060: em branco, a tela diz o que assume).

### 4. O ato de criar subequipe — dois defeitos, um deles real

Revisado em 2026-09-10. O ato **existe e funciona**: `criar_subequipe` em
[teams_live/show.ex:197](lib/the_band_web/live/teams_live/show.ex#L197) chama
`EO.declare_structural_team/4` e depois `EO.compose_teams/4`.

| # | achado | gravidade |
|---|---|---|
| a | **duas escritas sem transação** — se `compose_teams/4` falhar, a equipe **fica criada e solta** na organização, sem composição. O `Repo.insert` da composição pode falhar por constraint, e a mensagem de erro fala do segundo passo sem dizer que o primeiro ficou feito | **real** — uma linha de `Repo.transaction` resolve |
| b | o `else` do `with` trata só `{:error, motivo} when is_binary(motivo)` | **não é defeito**: as duas funções declaram `{:error, String.t()}` no `@spec`, e a cláusula é exaustiva por contrato. Fica registrado para não ser "consertado" de novo |

O ciclo **é** recusado, e a recusa **nomeia o caminho** (*"Equipe A faz parte de Equipe B, que
faz parte de Equipe C"*). A homônima entre declaradas é recusada por índice único, e a homônima
de uma observada é permitida — fato do mundo, não erro.

### 5. A reclassificação do D06 — é do papel de Product Owner

O entregável D06 da v0.7.0 está classificado **`sro.not_accepted_deliverable`** em
[docs/releases/v0.7.0.md](docs/releases/v0.7.0.md). Das três razões, duas foram consertadas
pelo #853 e a terceira deixou de valer. **Quem conserta não é quem aceita**: trocar o veredito
é reavaliar cada critério contra a evidência nova e reescrever o registro, e é ato do papel.

### 6. A lacuna de revisão: 21 PRs sem revisor

Vinte e um dos 21 PRs desta janela foram abertos sem revisor solicitado. A API do GitHub aceita
solicitação em PR já mergeado, então a lacuna é recuperável.

### 7. Segurança — o que sobra dos 16 achados

Fechados: **H1, H2, H3, H4, H6, H12** e o vazamento de escopo de projeto.

| achado | o que é | precisa de release? |
|---|---|---|
| **H7** | Dokploy implanta `latest` | **não** — ajuste no passo de delivery do `cd.yml` |
| **H8** | ações de CI em tag móvel | **não** — SHA nas ações, `permissions: contents: read` |
| **H9** | `ssl: true` comentado | **depende da topologia** — pergunta para quem opera |
| **H13** | `PHX_HOST` com fallback | **parcial** — a variável no Dokploy remove o caminho hoje |
| **H5, H10, H11, H14–H16** | média e baixa | — |

---

## Features especificadas e sem código

| spec | o que é |
|---|---|
| **061** | API pública com token e controle de acesso a dado por tenant. **Bloqueia o critério** *"conta desativada não autentica por token"*, que hoje não se pode avaliar |
| **062** | MCP |
| **063** | issue ausente da origem — o achado da pessoa mantenedora, já corrigido na coleta; a spec cobre o estado `deleted` na issue |

Issues abertas que pesam: **#397** (equipe composta por equipes — hierarquia com rollup de
competências, e é vizinha do item 3 acima), **#568** (gestão da marca de administrador, com o
guarda do último admin), **#801** (o Oban pode parar sem erro nenhum), **#802** (observabilidade
com OpenTelemetry).

---

## Decisões esperando a pessoa mantenedora

1. **Instalar o `puppeteer`?** Sem ele não há inspeção computada de tela — contraste,
   sobreposição, estouro em 390px. É `npm install puppeteer`.
2. **O *eyebrow* (rótulo mono em caixa alta acima do título).** O `craft-floor` do `impeccable`
   o proíbe sem exceção; o `DESIGN.md` declara a voz mono como uma das três da casa, e os quatro
   protótipos e várias telas o usam como estrutura. Remover é **redesenho**, não conserto — e
   por isso não foi feito. Precisa de decisão.
3. **H9** — a topologia do banco em produção decide se `ssl: true` entra.
4. **Sucessor de quem sai** — fica na nota (recomendação aceita), ou vira campo consultável?
5. **Desabilitar o `rebase merge`?** Está habilitado no repositório, e a tabela da seção 12
   do `AGENTS.md` **não o prevê em caso nenhum**. Método habilitado que a regra não cobre é
   caminho aberto sem regra.

---

## Três armadilhas que este ciclo ensinou

1. **`git add -A` num worktree compartilhado commita o trabalho de outro agente** (L102).
   Caminhos explícitos, sempre.
2. **`gh pr create --body` substitui o template inteiro** — e a declaração do tipo de merge
   desaparece sem aviso. O gate `pr-tipo-de-merge.yml` recusa o PR que não diga, e exige a linha
   `Motivo:`. Ele pegou o meu próprio PR #853.

   E o gate obriga o PR a **dizer** o método, mas nada obriga o **clique** a obedecer: o
   GitHub não tem configuração de método default, e a pré-seleção do botão é sempre *merge
   commit*. Por isso o merge passou a se fazer por comando — `gh pr merge <n> --squash` ou
   `--merge` —, onde o método está escrito (seção 12 do `AGENTS.md`).
3. **Sucesso silencioso continua sendo o defeito que mais reincide.** Neste ciclo:
   `.problema>h4::before` num cartão que não tem `h4` — o seletor não casava nada, e o canal da
   cor foi perdido **sem erro nenhum**. Pior que a barra que ele substituía.

---

## Comandos

```bash
set -a; . ./.env >/dev/null 2>&1; set +a   # segredos, sem imprimir
mix gates                                  # a definição única de verde
node .claude/skills/impeccable/scripts/detect.mjs specs assets lib docs site   # deriva de design
gh pr checks <n>                            # o veredito da CI
```

## Referências

- Protótipo da conta desativada: `specs/045-autenticacao-e-acesso/prototipo/` — o `PROMPT.md`
  seção 3 é a régua do QA
- `DESIGN.md` — a ramp de dez passos, os quatro raios, e a regra da borda de acento
- `docs/producao/desligar-alguem.md` — o procedimento, atualizado para o ato que existe
- `docs/backlog/conta-desativada.md` — o item, com as seis lacunas fechadas
