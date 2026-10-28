# Retomar — estado em 2026-10-28: os avisos de segurança consertados no `development`, e a release para levá-los ao ar

**Este é o único documento de estado.** `docs/sprints/RETOMAR.md` aponta para cá (AGENTS.md §5).

Tudo abaixo foi **medido em 2026-10-28** com `gh`, `git` e `curl`, ao desligar a máquina.

---

## Onde parei, em uma frase

**A produção (v0.12.0) roda dependências com aviso de segurança alcançável sem conta, e o conserto já
está no `development` (#1441).** O que falta é a release, e antes dela uma contagem no log de
produção que decide se o `SECRET_KEY_BASE` tem de ser trocado.

## O primeiro comando

```bash
git fetch origin --prune && git status --short     # 1. NADA fora de commit, antes de tudo
curl -s https://app.theband.dev/version            # 2. o que está no ar (0.12.0 em 2026-10-28)
gh issue list --label security --state open        # 3. segurança primeiro (§14.0)
gh pr list --state open                            # 4. vazio em 2026-10-28, antes deste PR
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"    # o veredito é o CÓDIGO DE SAÍDA
```

- **O servidor dev não pode estar de pé** durante a suíte inteira (`pgrep -fl phx.server`).
- **O servidor dev só sobe com a chave mestra no ambiente.** Exporte SÓ ela, sem carregar o `.env`
  inteiro (ele tem `DATABASE_URL`, `PHX_HOST` e credenciais de produção):
  `export THE_BAND_MASTER_KEY="$(grep '^THE_BAND_MASTER_KEY=' .env | cut -d= -f2- | tr -d '"')"`.
- **O Docker precisa estar de pé** para o Postgres (`open -a Docker`, depois `docker compose up -d`).
- **Rode `mix gates` desacoplado** (`nohup … &`) e leia o log depois. Leva mais de 30 minutos.

---

## O que está no ar

**v0.12.0**, desde 2026-10-09 (#1422). O `/version` respondeu `0.12.0` em 2026-10-28.

**O `development` tem, fora da produção:**

| PR | o que é |
|---|---|
| #1431, #1432 | o procedimento para recriar o banco com os papéis separados (#1131) |
| #1434 | `decimal` 3.2.0, o HTTP/2 do Bandit desligado, e o host da conexão restrito a uma lista |
| #1435 | o roteiro do servidor |
| #1437 | a 074, US4 e US5: a senha na régua, o painel e o alerta da entrada |
| #1438 | o RETOMAR de 2026-10-22 |
| **#1441** | **a #1439: `bandit` 1.14.0, `plug_crypto` 2.2.1, `ex_mcp` `== 1.7.3`** (mergeado em 2026-10-28) |

### Por que a release é urgente

Em 2026-10-27 o `hex.audit` passou a reprovar todo PR com avisos novos, e a avaliação do agente
`security` (`docs/seguranca/2026-10-27-avisos-bandit-jose-plug-crypto-ex-mcp.md`) achou dois
caminhos **anônimos, pelo Traefik**, na v0.12.0:

- **A1, Alta — `plug_crypto` 2.2.0**: um `phx_join` no socket do LiveView com `"session"` de tipo
  errado derruba o canal com o **`secret_key_base` no log**. Provado pelo caminho do canal
  (`test/the_band_web/segredo_fora_do_log_do_join_test.exs`);
- **A2, Alta — `bandit` 1.12.5 (-114213)**: WebSocket com fragmentos de 1 byte esgota a memória do
  nó inteiro.

E a produção também **não tem o #1434**: HTTP/2 ligado e sem `HostAceito`.

## O que fazer, em ordem

### 1. 👤 Antes da release: contar no log de produção

No VPS, contar, **sem copiar linha nenhuma**, as ocorrências de
`no function clause matching in Plug.Crypto` no log do contêiner desde o deploy da v0.12.0. Mande
**só o número**.

- **0**: segue para a release;
- **> 0**: é **exposição ativa** (§14.0, item 1). Girar o `SECRET_KEY_BASE` **primeiro** (derruba
  todas as sessões abertas), e registrar a revogação na nota da release.

É o B2 da #1439. O B4 (a porta 4000 está publicada?) é o item 1 do roteiro (seção 4).

### 2. A release

Leva o #1434, a #1439 (#1441) e a 074 US4/US5 (#1437). Com funcionalidade nova, o semver dá
**MINOR: v0.13.0**, e não a v0.12.1 que o documento anterior previa. A decisão é do Product Owner.

1. `/release` (mede os três riscos e atualiza o `mix.exs`), e a nota em `docs/releases/`;
2. o PR `development` → `main`, mergeado com `gh pr merge --merge` (**nunca squash**: L83).
   **Meça de novo antes de mergear**: o PR leva o que o `development` tiver no instante do merge;
3. conferir o `/version`, e **a conferência em produção é obrigatória**: `bandit` 1.14.0,
   `jose` 1.11.13 e `ex_mcp` 1.7.3 saíram em 2026-10-26, e o risco de regressão é real. Cheque o
   login, o LiveView (WebSocket) e o `/mcp`;
4. o back-merge por uma branch intermediária (#996);
5. fechar a #1439 à mão, com a contagem do passo 1 e o `/version` como evidência.

### 3. O #1436 — o PR por abrir

A branch `fix/1436-fila-parada-sem-relogio` (`f3864ce`) está no remoto, **rebaseada sobre o
#1441**. O conserto: o teste mede o intervalo entre conferências por mensagem, e não conta numa
janela de relógio. Provado: 5/5 isolado, 5/5 com a CPU saturada, e reprova com o timer armado em
`load/1` (`"conferências a [1, 2, 1] ms"`).

**Falta o `mix gates` sobre a branch rebaseada**: foi interrompido ao desligar. Rode, e com `EXIT=0`
abra o PR. O corpo pronto, com dois marcadores (`__EXIT__`, `__RESUMO__`) a preencher, está em
`.git/pr-1436-corpo.md` (fora do repositório versionado).

### 4. O roteiro do servidor (👤), na ordem do documento

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

### 5. O que é meu, e espera o servidor

- **A T029 (#1263), atualizar o runbook:** espera a T026 (subir o SigNoz).
- **A US4 (#1233) e a US5 (#1234):** o código está mergeado. **Elas não estão aceitas.** O painel e
  o alerta só se aceitam em produção (T027). Fechar à mão só com a aceitação.

### 6. O que está aberto e não depende do servidor

| issue | o quê | estado |
|---|---|---|
| **#1436** | `FilaParadaTest` instável | conserto na branch; ver o item 3 |
| **#1440** | guardas de comportamento do `bandit` (G3 smuggling, G4 frame depois do Close) | a #1439 deixou só o piso de versão; Baixa |
| #1433 | a contagem da enumeração antes do descarte da fila (S12) | futura, e exige avaliação do `security` antes |
| #1384 | 076/T034: guardar ou não o layout da visão parcial | decisão sua |
| 075 (#1278, #1285, #1292, #1293) | o build da documentação endurecido | abertas, com label `security` |

**Implementado e esperando só a aceitação** (US não fecha sem ela): 062 US1–US3 (#948–#950), 065
US1–US3 (#904–#906), 072 US1–US3 (#1165–#1167), 076 US1–US9 (#1316–#1324, falta a #1379), 073
US2/US3 (#1187, #1188), 077 US1/US2 (#1394, #1395), 064 US1/US3 (#885, #887). Levantado em
2026-10-27 pelas sub-issues; o lado autenticado é "não medível" sem conta de aceitação.

**Não há sprint ativo no projeto**: o último (044) terminou em 2026-10-21. A #1439 foi feita sem
sprint backlog, pela §14.0, e o PR #1441 entrou no projeto sem iteração. A próxima feature abre
sprint pela skill `sprint-backlog`.

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

- **`stash@{0}`**: `.impeccable/config.json` com uma exceção `rgb(0, 0, 0)` **sem `files`**, que vale
  para o repositório inteiro (o `development` tem a mesma regra restrita ao `fila.ex`). Não foi
  reaplicada: se o falso positivo do `papel.ex` voltar, a saída é uma exceção restrita a ele. Decisão
  sua.
- **Worktrees que sobraram:** `.claude/worktrees/sprint-044`, `.claude/worktrees/retomar` e
  `.claude/worktrees/doc-servidor`. Remova com `git worktree remove` depois de conferir `git status`.
