# Data model — spec 064

**Data**: 2026-09-13, **emendado em 2026-09-28** pela avaliação de segurança
[seguranca-us2.md](seguranca-us2.md) e pelas decisões P1–P6 da pessoa mantenedora · Deriva de
[research.md](research.md), R2 e R3.

---

## O campo que faz duas coisas

Hoje `users.session_token` (`character varying`, em claro) faz **dois** trabalhos:

1. prova que esta sessão é válida;
2. serve de época — girá-lo na troca de senha derruba todas as sessões.

É a razão de ele não poder ser resumido como está: o trabalho 2 exige que ele seja **estável
entre logins** (`auth.ex:191`), e o trabalho 1 exigiria que cada dispositivo recebesse o valor
bruto, que o banco não teria mais. Separar é a correção — princípio X.

---

## `user_sessions` (nova)

Uma linha por sessão aberta.

| campo | tipo | nota |
|---|---|---|
| `id` | `uuid` | vai no cookie — é por ele que a sessão é achada (S8) |
| `tenant_id` | `uuid`, **não nulo** | P4, S9: encerrar as sessões **de uma organização** exige a coluna, e a FK composta impede linha com `user_id` de outro tenant |
| `user_id` | `uuid`, **não nulo** | FK composta `(user_id, tenant_id) → users(id, tenant_id)`, `on_delete: :delete_all`: apagar a conta encerra as sessões |
| `token_hash` | `bytea`, **não nulo**, **único** | SHA-256 do valor bruto. **O bruto nunca é persistido** |
| `password_epoch` | `integer`, **não nulo** | a época da senha **com que a sessão nasceu**, lida na mesma leitura que conferiu a senha (S2) |
| `inserted_at` | `utc_datetime` | quando a sessão abriu, e o **início da validade absoluta de 7 dias** (P2, S6) |
| `ended_at` | `utc_datetime`, nulo | **carrega a data do encerramento** — FR-015 aplicada de saída, e não como remendo |

**Sem `last_seen_at`** (P2, S10). Sem expiração por inatividade ela não tem trabalho, e custaria
uma escrita por requisição mais uma trilha de atividade de pessoa em todo backup.

**Índices**: único em `token_hash`; `(user_id)` e `(tenant_id)` para encerrar em massa;
`(ended_at)` e `(inserted_at)` para a limpeza.

**Por que `bytea` e não texto**: o resumo é binário. Guardá-lo em hexadecimal dobraria o
tamanho e convidaria alguém a compará-lo com `==` sobre string.

**`ended_at` desde o primeiro dia** é a FR-015 aplicada onde ela nasce, e não onde ela já
falhou: foi exatamente a ausência de `cancelled_at` que tornou quatro registros do Oban
permanentes.

### Retenção: 90 dias (P3)

A linha é **apagada** 90 dias depois de deixar de valer — `ended_at`, ou o fim da validade
absoluta (`inserted_at + 7 dias`) para a sessão que venceu sem ninguém a encerrar. As duas
condições, e não só a primeira: sessão vencida não escreve `ended_at`, e sem a segunda seria o
mesmo registro permanente da FR-015. O evento de acesso continua no log (`AccessEvents`); a linha
guardada para sempre seria trilha de atividade de pessoa.

## `users.password_epoch` (nova coluna)

| campo | tipo | nota |
|---|---|---|
| `password_epoch` | `integer`, não nulo, padrão `0` | incrementa **atomicamente** (`inc:`, S13) a cada definição de senha — pelos cinco chamadores de `senha_changeset/3` |

**NÃO É SEGREDO, e isso precisa estar escrito no schema.** Ela não autentica: quem a lê não
ganha nada, porque sozinha não abre sessão nenhuma. Alguém que a tome por segredo vai tentar
protegê-la e concluir coisas erradas sobre o desenho.

A época **da sessão** mora na linha de `user_sessions`, e não no cookie (S2): no cookie, quem
tem o `SECRET_KEY_BASE` reassinaria com a época nova, que é um inteiro adivinhável. Época da
linha diferente da de `users` = senha definida depois = a sessão cai.

## `users.session_token`

Deixa de ser lida na T013 e é **girada para todos** no mesmo deploy (P1). **Removida** na T014,
em release seguinte.

---

## A sessão do Phoenix (o cookie)

Passa a carregar duas coisas: o **id da sessão** e o **token bruto**. O cookie continua assinado
com `SECRET_KEY_BASE`, como hoje. O `user_id` sai do cookie: ele vem da linha.

A conferência (S8, seguindo a ADR 0010 do token de API): acha a linha pela chave primária,
compara `sha256(bruto)` com `token_hash` por `Plug.Crypto.secure_compare/2` em memória, e exige
`ended_at` nulo, `inserted_at` a menos de 7 dias, e `password_epoch` igual à de `users`. Qualquer
ausência — sem id, sem bruto, linha inexistente — é recusa **por cabeça de função** (S4).

**A propriedade que isso obtém (FR-004)**: o banco guarda só o resumo. Quem lê um dump —
**mesmo tendo o `SECRET_KEY_BASE`** — não consegue montar um cookie válido, porque o resumo não
devolve o bruto. É a diferença que hoje não existe: hoje as duas metades bastam, e uma delas
está legível em toda cópia.

O bruto circula como `TheBand.Segredo.t()` de `abrir/1` até o `put_session` (S11, FR-006).

---

## A troca, e todos entram de novo (P1, decidida em 2026-09-28)

**As sessões vivas NÃO são migradas.** No deploy da T013:

1. `user_sessions` e `users.password_epoch` já existem (T009, T010);
2. a leitura passa a ser só por `user_sessions` — nenhum cookie antigo tem id de sessão, e todos
   são recusados: **cada pessoa entra de novo uma vez**, anunciado na nota da release;
3. `users.session_token` é **girada para um valor novo em toda conta**, em SQL puro. Não é
   para a leitura nova, que não a lê: é para um **rollback** do código não reabrir nada. O
   código antigo, de volta, recusaria todo cookie existente, e nenhum valor que já esteve num
   backup volta a casar;
4. em release **posterior**, a T014 remove a coluna.

**Por que não migrar**, que era o desenho de 2026-09-13: todo valor bruto de hoje está em cada
cópia tirada até aqui. Migrá-lo faria esses valores continuarem valendo, e abriria a janela da
S7, em que a coluna velha e a linha migrada coexistem e podem discordar. O custo medido é uma
entrada por pessoa (3 contas, 2 com sessão, segundo o plan.md).

---

## Transições

**Sessão**: `aberta → encerrada`, e só. Não há reabertura: entrar de novo abre uma sessão
**nova**, com token novo.

| como | efeito | escreve `ended_at`? |
|---|---|---|
| a pessoa sai | encerra aquela sessão, **no servidor** (S5) — hoje só o cookie local era apagado | sim |
| definição de senha (troca, reinício por quem administra, primeira definição) | incrementa a época **e** encerra as outras sessões da conta | sim |
| conta desativada | encerra **todas** as sessões da conta **na mesma transação** do episódio (S1). Reativar não devolve nenhuma | sim |
| giro operacional (runbook, T016) e depois de restaurar backup (P5, **obrigatório**) | encerra todas, de todos | sim |
| validade absoluta de 7 dias | recusada na conferência — plug **e** hook, pelo mesmo ponto (S6) | não — a retenção cobre |
| organização suspensa | **hoje** bloqueia enquanto dura e não encerra. Encerrar na suspensão (P6) é issue própria, fora da US2 | — |

`set_password` usa **a mesma** conferência, e não uma comparação de campo própria (S3).
