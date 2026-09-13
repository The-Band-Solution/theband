# Data model — spec 064

**Data**: 2026-09-13 · Deriva de [research.md](research.md), R2 e R3.

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
| `id` | `uuid` | |
| `user_id` | `uuid`, FK, `on_delete: :delete_all` | apagar a conta encerra as sessões |
| `token_hash` | `bytea`, **não nulo**, **único** | SHA-256 do valor bruto. **O bruto nunca é persistido** |
| `inserted_at` | `utc_datetime` | quando a sessão abriu |
| `last_seen_at` | `utc_datetime` | para expirar por inatividade, se vier a existir |
| `ended_at` | `utc_datetime`, nulo | **carrega a data do encerramento** — FR-015 aplicada de saída, e não como remendo |

**Índices**: único em `token_hash`; `(user_id)` para o giro em massa; `(ended_at)` para a
limpeza.

**Por que `bytea` e não texto**: o resumo é binário. Guardá-lo em hexadecimal dobraria o
tamanho e convidaria alguém a compará-lo com `==` sobre string.

**`ended_at` desde o primeiro dia** é a FR-015 aplicada onde ela nasce, e não onde ela já
falhou: foi exatamente a ausência de `cancelled_at` que tornou quatro registros do Oban
permanentes.

## `users.password_epoch` (nova coluna)

| campo | tipo | nota |
|---|---|---|
| `password_epoch` | `integer`, não nulo, padrão `0` | incrementa a cada troca de senha |

**NÃO É SEGREDO, e isso precisa estar escrito no schema.** Ela não autentica: quem a lê não
ganha nada, porque sozinha não abre sessão nenhuma. Alguém que a tome por segredo vai tentar
protegê-la e concluir coisas erradas sobre o desenho.

A sessão guarda a época com que nasceu; época diferente da atual = senha trocada depois = a
sessão cai. É o comportamento de hoje, preservado.

## `users.session_token`

**Removida** ao fim da migração.

---

## A sessão do Phoenix (o cookie)

Passa a carregar três coisas: `user_id`, o **token bruto** e a **época**. O cookie continua
assinado com `SECRET_KEY_BASE`, como hoje.

**A propriedade que isso obtém (FR-004)**: o banco guarda só o resumo. Quem lê um dump —
**mesmo tendo o `SECRET_KEY_BASE`** — não consegue montar um cookie válido, porque o resumo não
devolve o bruto. É a diferença que hoje não existe: hoje as duas metades bastam, e uma delas
está legível em toda cópia.

---

## A migração, sem derrubar ninguém (FR-002)

O cookie de cada pessoa **já carrega o valor bruto de hoje**. Então:

1. cria `user_sessions` e `users.password_epoch`;
2. para cada usuário com `session_token` não nulo, insere **uma** linha com
   `token_hash = sha256(session_token)`;
3. deixa `password_epoch` em `0`, e o cookie sem época é lido como `0`;
4. em migração **posterior**, depois de a nova leitura estar no ar, remove
   `users.session_token`.

Na requisição seguinte, o valor do cookie é resumido e encontra a linha. **Ninguém cai** — o
primeiro ramo da FR-002, que é o preferível.

**A remoção da coluna é uma migração separada**, e de propósito: enquanto as duas leituras
coexistem, voltar atrás custa um deploy; depois de apagar a coluna, custa um backup.

### O que a migração deliberadamente não faz

Não gira as sessões existentes. Os valores de hoje foram medidos em claro num dump — **de
desenvolvimento**, e só exploráveis em combinação com o `SECRET_KEY_BASE` (R1). Derrubar toda
sessão de produção por uma medição feita fora dela seria agir por evidência que não existe lá.

O giro fica como **procedimento do runbook**, ato deliberado de quem opera, para quando houver
suspeita de exposição — inclusive depois da varredura da FR-010.

---

## Transições

**Sessão**: `aberta → encerrada`, e só. Não há reabertura: entrar de novo abre uma sessão
**nova**, com token novo. Uma sessão encerrada **não se apaga** — guarda `ended_at`, como o
episódio de desativação de conta guarda o dele.

As quatro formas de encerrar, e todas escrevem `ended_at`:

| como | efeito |
|---|---|
| a pessoa sai | encerra aquela sessão |
| troca de senha | incrementa a época → **todas** as outras caem na ação seguinte |
| giro operacional (runbook) | encerra **todas**, de todos |
| conta desativada ou organização suspensa | as sessões daquela pessoa caem, pelo caminho que já existe |
