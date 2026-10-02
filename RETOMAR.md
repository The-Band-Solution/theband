# Retomar — estado em 2026-10-02: a v0.11.0 no ar, a v0.12.0 preparada com nove consertos de segurança, e a 070 inteira em PRs empilhados

**Este é o único documento de estado.** `docs/sprints/RETOMAR.md` aponta para cá (AGENTS.md §5).

Escrito para a sessão seguinte começar trabalhando, e não reconstruindo contexto. Tudo abaixo foi
**medido em 2026-10-02**, e não copiado do documento anterior, que estava parado em 2026-09-24.

---

## Onde parei, em uma frase

**A produção está na v0.11.0, e `development` carrega nove consertos de segurança que não estão no
ar.** A v0.12.0 está preparada (`docs/releases/v0.12.0.md`) e espera a decisão da pessoa
mantenedora. A **spec 070** (o operador da plataforma) está implementada, salvo a T043, em seis PRs
empilhados que esperam revisão e merge.

## O primeiro comando

```bash
git fetch origin --prune && git status --short     # 1. NADA fora de commit — antes de tudo
git checkout development && git pull
mix gates > /tmp/gates.log 2>&1; echo "EXIT=$?"    # o veredito é o CÓDIGO DE SAÍDA
```

A suíte inteira é inviável com o servidor dev de pé (`pgrep -fl phx.server`). Os worktrees
compartilham a base de teste: **nunca duas suítes ao mesmo tempo**. `mix gates` passa de 30
minutos: rode desacoplado, com `nohup … &`, e leia o log depois.

---

## O que está no ar

**v0.11.0**: `curl -s "$PRODUCAO_URL/version"` responde `0.11.0` em 2026-10-02. A `main` está no
merge do #1026.

## O que fazer, em ordem

### 1. A v0.12.0 — decisão da pessoa mantenedora (segurança primeiro)

`docs/releases/v0.12.0.md`. Os nove consertos de segurança que estão em `development` e não em
produção: #1039, #1040, #1038, #1048, #1049, #1044, #1051, #1053 e #1130. Não há migração nem
variável nova.

**A lacuna declarada**: nenhum desses PRs tem revisão registrada. Ou se aceita levá-los assim, ou
se pede a revisão antes. O PR de release se abre com `/release --executar`, depois da decisão.

### 2. A pilha da 070 — revisão e merge, nesta ordem, todos com `gh pr merge <n> --merge`

| PR | o que é |
|---|---|
| #1132 → `development` | a fundação: estado restrito, razões e cláusula na base, log do operador, CSP compartilhada (T013–T017) |
| #1133 | a base da US2: tabelas, schemas, segundo fator, eventos e a entrada do operador |
| #1134 | o domínio da US2: o cadastro em três passos, a sessão, a concessão e os comandos de release |
| #1136 | a camada web da US2: o cookie próprio, `/platform` com o 404 único e as telas de entrada, cadastro e lista |
| #1137 | **#1135 (security)**: a CSP e os cabeçalhos nas páginas de erro do domínio |
| #1138 | a US1, suspender e reativar, e a Fase 5 (T044–T063) |

Empilhado não fecha issue pela palavra: **depois de cada merge, fechar à mão** as issues listadas
no corpo de cada PR. A #1009 se resolve com a #1138.

### 3. O que só a pessoa mantenedora faz

- **T004**: medir se o Traefik do Dokploy sobrescreve `x-forwarded-for`. Sem isso, a T043 (#1106,
  o limite por IP) não entra, e o A4 fica como risco na release.
- **As decisões de tela** que a conferência da 070 deixou (`specs/070-operador-da-plataforma/prototipo/conferencia.md`):
  - D-7 e D-10 a D-13, as frases fora do protótipo;
  - o S-US1-2, a confirmação levar o verbo;
  - a frase do 403 de CSRF.
- **O `totp_secret` ilegível**: hoje `autenticar/3` dá 500 em vez de recusar.
- **Antes da primeira concessão de operador em produção**: o `timedatectl` (runbook §13.1), e as
  migrações medidas contra a produção (`nota-de-riscos-da-release.md` da 070).
- **A captura das telas do operador** (cor, cinza e 360 px), que a conferência pede.

### 4. Depois da 070

- **#1131 (security)**: separar o papel do banco que migra do que serve. Decidido em 2026-10-02:
  depois da 070. Exige spec própria, avaliação do `security` antes do código, e os dois papéis
  criados em produção pela pessoa mantenedora.
- **#568**: promover e rebaixar administrador. A spec ainda não foi escrita.
- O resto do backlog: #1023, #882–#884, #397, #802 (tracing com SigNoz, ADR 0005 proposta), #526,
  #363, #356, e a 069 (MCP, busca de pessoas; a spec ainda não foi escrita).

---

## O que esta sessão aprendeu, e vale para a próxima

- **O Dialyzer recusa `Ecto.Multi` nesta combinação de Ecto e Elixir** (`call_without_opaque` em
  todo `Multi.run` sobre `Multi.new()`). A casa usa `Repo.transaction/1` com `rollback`, e a 070
  passou a usar também.
- **`SET search_path = pg_catalog, public` não protege da tabela temporária**: o PostgreSQL procura
  `pg_temp` **primeiro** quando ele não está listado. A forma segura é
  `pg_catalog, public, pg_temp`, junto com os nomes qualificados.
- **A página de erro de exceção sai sem os cabeçalhos da pipeline.** A recusa de CSRF e o caminho
  inexistente levantam, e o endpoint desenha a página a partir da conexão de antes. Os cabeçalhos
  agora vêm de `TheBandWeb.Plugs.Borda`, no endpoint (#1135).
- **Corrida de duas abas num formulário de ato**: a página que relê o estado e troca de
  formulário não pode levar os valores digitados para o ato oposto (D-9 e S-US1-1).
- **`TRUNCATE … CASCADE` num teste assíncrono** trava os outros testes que gravam na tabela em
  cascata. Teste com `TRUNCATE` é síncrono.
