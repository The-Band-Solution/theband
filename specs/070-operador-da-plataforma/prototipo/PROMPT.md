# PROMPT — as telas do operador da plataforma (070, T012)

Protótipo: [`platform-operator.html`](platform-operator.html) · publicado em
<https://claude.ai/artifact/KWYR2rPJX1V4FukhszDVFA> · 2026-10-01 ·
versão 2 com as decisões de 2026-10-01 aplicadas · **data de aprovação em aberto** (a pessoa
mantenedora vai olhar a versão republicada; registrar aqui).

## 1. Os pedidos, textuais e em ordem

**Da pessoa mantenedora** (os que regem estas telas):

1. 2026-09-07: *"quero exatamente a tela aprovada"*.
2. 2026-09-29, issue #1009: quem suspende uma organização é um **operador da plataforma**, papel
   acima das organizações (registrado no topo da `spec.md`).
3. 2026-10-01: o papel é concedido **só por comando** de quem opera o servidor (FR-001); o
   operador é **entidade separada**, com telas por controller e cookie próprio (FR-011, T005);
   **TOTP nesta feature** (FR-016); a lista de razões de suspensão e reativação **aprovada**
   (data-model §5, T014).
4. 2026-10-01, sobre a versão 1 deste protótipo (via coordenador, textual): *"Q1 = (a) sem QR,
   base32 + URI em texto. Q2 = (a) digitar o slug para confirmar suspender e reativar. Q3 = (b)
   SIM: exigir a confirmação de que os códigos de recuperação foram guardados, com caixa + um POST
   a mais (contra a recomendação). Q4 = (b) não mostrar as contagens de sessões e tokens no
   histórico (ficam no log de acesso); D1–D5 aprovadas."*

**Do pedido que encomendou o protótipo** (2026-10-01, textual, trecho):

> Execute a T012 da spec 070 […]: o protótipo navegável das telas do operador da plataforma,
> ANTES de qualquer código. […] As cinco telas (interface em inglês): (1) entrada com e-mail,
> senha e código do segundo fator num formulário só, recusa única sem dizer qual campo falhou;
> (2) definição da senha com o código de uso único impresso pelo comando de release; (3) cadastro
> do segundo fator: o segredo em base32 e a URI otpauth em texto — SEM QR code (recomendação da
> pesquisa T009; mostre a alternativa só como nota para a pessoa mantenedora decidir),
> confirmação com um código, e os 10 códigos de recuperação mostrados UMA vez com aviso; (4)
> lista de organizações: nome, slug, estado, data do último episódio, "never suspended" com a
> marca de ausência, e NADA de dado de domínio (pessoas, equipes, issues, contagens — FR-007);
> (5) histórico de uma organização com o ato de suspender/reativar: razões da lista fechada,
> nota, confirmação explícita de que suspender encerra todas as sessões e revoga todos os tokens
> de API (FR-004, FR-013), e a recusa como estado (ex.: já suspensa). Inclua também o estado de
> quem não é operador (404 idêntico ao de rota inexistente) só como nota, não como tela.
> Use dado de exemplo (example-org etc.), nunca dado real.

## 2. O brief de design seguido

- **Herdar, não reinventar**: tokens de `specs/065-rotulos-no-item/prototipo/` (papel, tinta,
  verdete, `info`, âmbar, clay; serif no corpo, grotesca nos títulos, mono em identificadores,
  pilha do sistema, nenhuma webfont); a forma do ato com razão, nota e episódio de
  `specs/045-autenticacao-e-acesso/prototipo/accounts-disable.html`.
- **Marcas**: `active` verdete cheio; `suspended` cinza cheio (`left`: encerrado e mantido no
  registro, como a conta desativada da 045); `never suspended` e toda metade que falta
  tracejadas (`absent`); recusa hachurada em clay com ícone e palavra. Nenhuma distinção só por
  cor; botão *View in greyscale* para conferir.
- **Moldura de tela** com o método e o caminho reais de `contracts/rotas-da-plataforma.md`, para
  o QA saber qual controller renderiza cada estado.
- **Sem script nas telas reais**: controllers com CSP `script-src 'self'`; toda recusa é página
  re-renderizada; nota obrigatória e razão oferecida são decididas no servidor.
- **Recusa como estado de primeira classe**, sempre com "Nothing changed".
- **Dado só de exemplo**, marcado `example`.

## 3. A estrutura, seção por seção — a régua do QA

O QA confere na tela real, com captura ao lado, **inclusive em tons de cinza** e em 360 px.

### Tela 1 — `GET /platform/sign-in` e `POST /platform/session`

| # | item | o que tem de existir |
|---|---|---|
| 1.1 | cabeçalho | `The Band` + `platform operation`; sem menu, sem link para telas de organização |
| 1.2 | campos, nesta ordem | `Email` (`email`), `Password` (`password`), `Authenticator code` com dica `or a recovery code` (`second_factor_token`); um formulário só |
| 1.3 | botão | `Sign in` |
| 1.4 | texto sob o formulário | `Lost the password or the authenticator? Ask whoever runs the server for a new setup code. There is no reset by e-mail.` |
| 1.5 | recusa | notice de recusa (ícone + cor + palavra): **`Not signed in.`** `Check the email, password and code, then try again in a moment.` — idêntica para todos os motivos de `credenciais-do-operador.md` e para `{:throttled, _}`: mesma frase, status e destino; nenhum segundo exibido |
| 1.6 | estado após recusa | e-mail preenchido; senha e código vazios; **nenhum campo marcado** |
| 1.7 | sucesso | vai a `/platform/organizations` |

### Tela 2 — `GET /platform/setup` e `POST /platform/setup`

| # | item | o que tem de existir |
|---|---|---|
| 2.1 | passo | `Step 1 of 3. Set your password. Step 2 adds your authenticator, and step 3 asks you to store the recovery codes. You cannot sign in until all three are done.` |
| 2.2 | campos, nesta ordem | `Email`; `Setup code` com dica `from the release command, valid 30 minutes` (`setup_token`); `New password` com dica `12 to 128 characters` (`password`); `Repeat the new password` |
| 2.3 | botão | `Set password and continue` |
| 2.4 | aviso | `Setting the password signs out every open operator session and replaces any authenticator enrolled before.` |
| 2.5 | recusa única | **`Password not set.`** `The email or setup code was not accepted. A setup code works once and lasts 30 minutes; if it has expired, ask for a new one.` — para e-mail, código errado/vencido/usado, sem concessão e espera |
| 2.6 | recusa de política | **`Password not set.`** `The password needs 12 to 128 characters. Your setup code still works.` — só quando o código conferiu (o `ROLLBACK` devolve o código) |
| 2.7 | código nunca na URL | o código vai no corpo do `POST`; não há `GET` com código |

### Tela 3 — cadastro do segundo fator (`POST /platform/setup` sucesso; `POST /platform/setup/second-factor`; `POST /platform/setup/recovery-codes`)

| # | item | o que tem de existir |
|---|---|---|
| 3.1 | passo | `Step 2 of 3. Password set. Now add The Band to your authenticator app.` |
| 3.2 | aviso antes do segredo | notice de aviso com `1×`: **`This secret is shown once.`** … `even if the code below is refused` … `ask for a new setup code` … e a hora UTC em que o passo vence (10 minutos) |
| 3.3 | dados | `issuer` The Band Platform · `account` o e-mail · `type` `time-based, 6 digits, every 30 seconds` |
| 3.4 | chave | `Setup key` em mono, base32 maiúsculo em grupos de 4 |
| 3.5 | URI | `Or copy the address`: a `otpauth://totp/The%20Band%20Platform:<email>?secret=…&issuer=The%20Band%20Platform` em texto |
| 3.6 | **sem QR** | nenhuma imagem (*Q1 Decided (a) em 2026-10-01*) |
| 3.7 | formulário | campo oculto `enrollment_token` no corpo; `Code from the app` (`second_factor_token`); botão `Confirm authenticator` |
| 3.8 | recusa | **`Authenticator not confirmed.`** `The code was not accepted. Wait for the next code and try again; if the app's clock is off, codes will keep failing. The setup key is not shown again: if it never reached your app, ask for a new setup code.` — a chave **não** reaparece |
| 3.9 | código aceito | `Step 3 of 3. Code accepted. Store your recovery codes to finish.` — **sem** notice de sucesso: o segundo fator ainda não vale (*Q3 Decided (b) em 2026-10-01*) |
| 3.10 | aviso dos códigos | notice de aviso `1×`: **`Store these ten recovery codes now. They are shown once and never again.`** + uso único + só a impressão digital guardada + o caminho de volta |
| 3.11 | códigos | lista numerada de 1 a 10, mono, `xxxx-xxxx-xxxx-xxxx` minúsculo; duas colunas a partir de 30 rem |
| 3.12 | a guarda | campo oculto `acknowledgement_token` no corpo; caixa `codes_stored` com `required`: `I stored these ten recovery codes somewhere other than this page.` e a dica `Until you finish, neither your authenticator nor these codes can be used to sign in. This step expires at <hora> UTC, ten minutes after the code was accepted.`; botão `Finish setup` → `POST /platform/setup/recovery-codes` |
| 3.13 | recusa da caixa | **`Setup not finished.`** `Tick the box to confirm you stored the recovery codes. The codes are not shown again: if you did not store them, ask whoever runs the server for a new setup code. Nothing changed.` — os códigos **não** reaparecem; a caixa desmarcada não consome o passo |
| 3.14 | recusa do passo | passo vencido, usado ou ausente: **`Setup not finished.`** `The step was not accepted; ask for a new setup code.` |
| 3.15 | sucesso | notice `Setup finished. Your authenticator and your recovery codes are now valid. Every open operator session was signed out.`; botão-link `Go to sign in` → `/platform/sign-in`, com a nota de que não entra sozinho |

### Tela 4 — `GET /platform/organizations`

| # | item | o que tem de existir |
|---|---|---|
| 4.1 | cabeçalho | `The Band` + `platform operation`; nome e e-mail do operador; `Sign out` (`DELETE /platform/session`) |
| 4.2 | título | `Organisations` |
| 4.3 | linha de escopo | `You see each organisation's name, slug, state and suspension history. You do not see its people, teams, work or numbers. Operating the platform does not open any organisation.` |
| 4.4 | colunas, nesta ordem | `organisation` (nome, link para o histórico) · `slug` (mono) · `state` · `last suspended` |
| 4.5 | estado | `active` verdete cheio com ponto; `suspended` cinza cheio com ponto; texto sempre |
| 4.6 | nunca suspensa | `<.absent>` tracejado **`never suspended`** — nunca `—`, `0` ou vazio |
| 4.7 | episódio da migração | data + `· reason not recorded` |
| 4.8 | ordem | por nome |
| 4.9 | **nada de domínio** | nenhuma contagem de pessoas, contas, equipes, issues ou tokens, na linha ou na página; nenhum total |
| 4.10 | sem ato em lote | nenhuma caixa de seleção, nenhum "suspend all" |
| 4.11 | telefone | abaixo de 40 rem a tabela empilha (`stacked`, `data-label`); nada rola na horizontal |

### Tela 5 — `GET /platform/organizations/:slug`, `POST …/suspension`, `POST …/reactivation`

| # | item | o que tem de existir |
|---|---|---|
| 5.1 | cabeçalho | `← Organisations`, operador, `Sign out`; nome da organização; slug em mono; marca de estado; `since <data>` quando suspensa |
| 5.2 | histórico | `Suspension history`, do mais novo ao mais antigo; cada episódio um bloco de duas metades (`suspended` / `reactivated`), lado a lado a partir de 44 rem |
| 5.3 | metade | instante UTC · `by <nome do operador>` · rótulo da razão + código em mono · a nota entre aspas, ou `no note` tracejado; **nenhuma contagem** de sessões ou tokens (*Q4 Decided (b) em 2026-10-01*) |
| 5.4 | episódio aberto | metade da reativação: `not reactivated — still suspended` tracejado |
| 5.5 | `not_recorded` | `by: not recorded — suspended by hand before this record existed` tracejado; razão `The reason was not recorded` |
| 5.6 | só o ato que cabe | ativa: só `Suspend <nome>`; suspensa: só `Reactivate <nome>`; o outro não aparece |
| 5.7 | razões de suspender | `Suspected compromise` (*note required*) · `The contract ended` · `Requested by the organisation` · `Other` (*note required*); rótulo + código, da base |
| 5.8 | razões de reativar | `Investigation closed — no compromise found` **só** se a razão do episódio aberto for `suspected_compromise`, com a frase que diz por quê · `The contract resumed` · `Suspended by mistake` · `Other` (*note required*) |
| 5.9 | nota | `Note` com a dica de quando é obrigatória; `Kept with the episode.` |
| 5.10 | consequências de suspender | lista sob `What suspending does, at once and in one step`: todos desconectados; todos os tokens revogados; ninguém entra, nenhuma coleta; dado não apagado; reativar **não** devolve sessão nem token |
| 5.11 | consequências de reativar | lista sob `What reactivating does, and what it does not`: entram de novo; nenhuma sessão volta, inclusive as gravadas durante a suspensão; nenhum token volta; coleta no intervalo normal; a suspensão fica no registro |
| 5.12 | confirmação | `Type <slug> to confirm` (`confirm_slug`), nos dois atos (*Q2 Decided (a) em 2026-10-01*) |
| 5.13 | botões | `Suspend, sign everyone out, revoke all tokens` (clay); `Reactivate <nome>` (verdete) |
| 5.14 | recusas | página re-renderizada, formulário como estava, notice acima, terminando em `Nothing changed.`: `already suspended` (com desde quando e por quem, e passa a mostrar reativar) · `is not suspended` · `A note is required for this reason (<rótulo>)` · `Choose a reason from the list.` · `Not suspended. The confirmation did not match. Type <slug> exactly.` e `Not reactivated. The confirmation did not match. Type <slug> exactly.` · `The list of reasons is not available` |
| 5.16 | sessão caída no meio | `nao_autorizado` → cookie solto e o `404` da nota |

### Nota — quem não é operador (não é tela)

| # | item | o que tem de existir |
|---|---|---|
| N.1 | anônimo ou admin de organização em `/platform/*` protegida | o `404` comum: mesmo status, cabeçalhos e corpo (menos `csrf-token`) de `/platform/<inexistente>`; sem redirecionamento, sem "permission denied" |
| N.2 | slug inexistente | o mesmo `404` |
| N.3 | cookie do operador fora de `/platform` | `/people` → `/sign-in`; API e MCP → `401` |

### Em toda tela

| # | item |
|---|---|
| G.1 | em tons de cinza, `active` × `suspended` × ausência × recusa × aviso se distinguem pela forma **e** pelo texto |
| G.2 | em 360 px, nada rola na horizontal; formulários em uma coluna; alvos de 44 px |
| G.3 | texto de tela em inglês, com o comentário no código dizendo que é tela |
| G.4 | nenhum dado de domínio de organização em nenhuma das cinco telas |

## 4. Como cada papel usa este arquivo

- **Product Owner**: registra o link e este `PROMPT.md` no item do backlog da 070 (#1009) e a
  data de aprovação quando a pessoa mantenedora a der; aceita a entrega só conferida contra a
  seção 3. Q1–Q4 e D1–D5: *Decided 2026-10-01*.
- **Design**: marca *Decided <data>* nas respostas, ajusta (Q4 (b) tira a linha de contagens) e
  republica **no mesmo endereço**; registra a data de aprovação no topo deste arquivo.
- **Elixir/Phoenix Developer**: implementa exatamente a seção 3 (T039, T040, T056); o que não for
  possível ou honesto com o dado volta ao protótipo. Se Q2 ficar em (a) ou (b), emendar
  `contracts/rotas-da-plataforma.md` (emendado em 2026-10-01) e o fluxo de cadastro de
  `contracts/segundo-fator-do-operador.md` valem; `credenciais-do-operador.md` e `data-model.md`
  §1 ainda precisam da emenda do terceiro passo **antes** do código.
- **QA**: confere item a item 1.1–G.4 na tela renderizada, com captura colorida, em cinza e em
  360 px, por quem não implementou.

## Decisões

*Decided 2026-10-01*, pela pessoa mantenedora: D1–D5 aprovadas; Q1 (a) sem QR; Q2 (a) digitar o
slug; Q3 (b) confirmar a guarda dos códigos, contra a recomendação do Design; Q4 (b) sem contagens
no histórico. A **aprovação do protótipo** (com data) fica em aberto até a revisão da versão 2.
