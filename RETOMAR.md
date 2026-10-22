# Retomar — estado em 2026-10-22: a v0.12.0 no ar, a 074 com o código inteiro no `development`, e a fila agora é do servidor

**Este é o único documento de estado.** `docs/sprints/RETOMAR.md` aponta para cá (AGENTS.md §5).

Tudo abaixo foi **medido em 2026-10-22** com `gh`, `git` e `curl`. Nada foi copiado do documento
anterior, que estava parado em 2026-10-09.

---

## Onde parei, em uma frase

**O trabalho que dependia de código acabou, e o que falta agora é ato no servidor.** A produção roda
a v0.12.0. A 076 (análise de rede) está no ar e espera a aceitação. A 074 (jornada entrar e sair) já
tem as cinco user stories em código no `development` (sprint 044, PR #1437). O que segura as três
features é o servidor, e a lista está em
[docs/producao/o-que-fazer-no-servidor.md](docs/producao/o-que-fazer-no-servidor.md).

## O primeiro comando

```bash
git fetch origin --prune && git status --short     # 1. NADA fora de commit, antes de tudo
curl -s https://app.theband.dev/version            # 2. o que está no ar (0.12.0 em 2026-10-22)
gh issue list --label security --state open        # 3. segurança primeiro (§14.0)
gh pr list --state open                            # 4. vazio em 2026-10-22, antes deste PR
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"    # o veredito é o CÓDIGO DE SAÍDA
```

- **O servidor dev não pode estar de pé** durante a suíte inteira (`pgrep -fl phx.server`).
- **Nunca rode duas suítes ao mesmo tempo:** os worktrees compartilham a base de teste.
- **Rode `mix gates` desacoplado** (`nohup … &`) e leia o log depois. Leva mais de 30 minutos.

---

## O que está no ar

**v0.12.0**: o `/version` respondeu `0.12.0` em 2026-10-22, e está no ar desde 2026-10-09, quando o
#1422 foi mergeado.

**O `development` tem commits que ainda não estão na produção:**

| PR | o que é |
|---|---|
| #1431, #1432 | o procedimento para recriar o banco com os papéis separados (#1131) |
| #1434 | `decimal` 3.2.0, o HTTP/2 do Bandit desligado, e o host da conexão restrito a uma lista (avisos de 2026-10-15) |
| #1435 | o roteiro do servidor |
| #1437 | a 074, US4 e US5: a senha na régua, o painel e o alerta da entrada |

O #1434 é **conserto de segurança em produção**, e pela §14.0 vai na primeira release possível. A
v0.12.1 (PATCH) é a candidata. Ela sai por decisão do Product Owner e com o seu clique.

## O que fazer, em ordem

### 1. Decidir a v0.12.1, que leva o #1434 para o ar

Se a decisão for soltar, o caminho é o de sempre:

1. a nota em `docs/releases/v0.12.1.md`;
2. o PR `development` → `main`, mergeado com `gh pr merge --merge` (**nunca squash**: L83);
3. conferir o `/version`;
4. fazer o back-merge por uma branch intermediária (#996).

### 2. O roteiro do servidor (👤), na ordem do documento

Tudo está em [o-que-fazer-no-servidor.md](docs/producao/o-que-fazer-no-servidor.md). Cada item diz o
que me mandar de volta, e **nunca é valor de segredo**.

| # | item | fecha |
|---|---|---|
| 1 | a porta 4000 está publicada? | runbook §15.2, item 7 |
| 2 | recriar o banco com os papéis separados | #1131, #1140 |
| 3 | a distribuição Erlang só no loopback | #1162 (e a T025, #1259) |
| 4 | anotar quando vence a credencial do ghcr | — |
| 5 | medir o Traefik e ligar o limite por origem | #1063, depois #1407, #1229 |
| 6 | aceitar a 076 contra a origem | #1379, US1–US9, épico #1309 |
| 7 | subir o SigNoz em produção | T024–T028 (#1258–#1262) |
| 8 | `timedatectl` | antes do primeiro operador |

### 3. O que é meu, e espera o servidor

- **A T029 (#1263), atualizar o runbook:** espera a T026 (subir o SigNoz).
- **A US4 (#1233) e a US5 (#1234):** o código está mergeado. **Elas não estão aceitas.** O painel e
  o alerta só se aceitam em produção (T027). Fechar à mão só com a aceitação.

### 4. O que está aberto e não depende do servidor

| issue | o quê | estado |
|---|---|---|
| **#1436** | `FilaParadaTest` instável sob a suíte completa | **bug aberto. Corrigir antes de feature nova** (regra de 2026-09-29). O conserto é esperar a conferência por mensagem, e não pelo relógio. A guarda do HTTP/2, da mesma família, já foi consertada no #1437 |
| #1433 | a contagem da enumeração antes do descarte da fila (S12) | futura, e exige avaliação do `security` antes |
| #1384 | 076/T034: guardar ou não o layout da visão parcial | decisão sua |
| 075 (#1278, #1285, #1292, #1293) | o build da documentação endurecido | abertas, com label `security` |

---

## O que o sprint 044 ensinou

As lições completas estão em `docs/sprints/licoes-aprendidas.md`, e a review em
`docs/sprints/044-observabilidade-da-entrada/`.

- **L111.** No SigNoz, agrupar por uma chave opcional descarta, sem aviso, a linha que não a tem. Uma
  guarda em `signoz_artefatos_test.exs` impede isso.
- **L112.** Com o limite por origem (077) ligado, a campanha aparece como `limite_por_origem`. Por
  isso o alerta conta os dois motivos.
- **L11 (terceira vez).** `updateProjectV2Field` com `iterationConfiguration` substitui **todas** as
  iterations, inclusive as completas. O procedimento está na skill `sprint-backlog`.

## Higiene local

- **Worktrees que sobraram:** o `.claude/worktrees/sprint-044` (branch apagada no merge) e o
  `.claude/worktrees/retomar` (o deste documento). Remova com `git worktree remove` depois de
  conferir `git status`.
- **Arquivo modificado fora de commit:** o checkout principal tem `.impeccable/config.json`
  modificado, e não é deste trabalho. Olhe o arquivo antes de descartar.
