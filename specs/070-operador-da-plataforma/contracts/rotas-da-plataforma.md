# Contrato — as rotas da área do operador

FR-009, FR-011, O13, O14. Decisões em [research.md](../research.md) R3.2, R4 e R12.

> O contrato abaixo é a opção **(a)** de research R3.2: cookie próprio e controllers. **Decidida
> pela pessoa mantenedora em 2026-10-01** (plan.md, pergunta 1; T005), com a FR-011 emendada de
> `live_session` para "pipeline, plug e cookie próprios" (commit `61d6098`). A avaliação da
> segunda autenticação já concordava com (a).
>
> **Emendado em 2026-10-01**: A8 (a mesma origem, com CSP; decisão da pessoa mantenedora), A12 (o
> curinga do `404`) e o segundo fator (FR-016).
>
> **Emendado em 2026-10-01 pelo protótipo T012** (decisões da pessoa mantenedora, Q2 (a) e Q3 (b),
> `prototipo/README.md`): o campo `confirm_slug` nos dois atos, e o terceiro passo do cadastro,
> `POST /platform/setup/recovery-codes`.
>
> **Emendado em 2026-10-01 por T011** (seguranca-totp.md, T5): a exibição única do segredo e dos
> códigos, e a re-renderização das recusas dos passos 2 e 3.

## A pipeline

```elixir
pipeline :plataforma do
  plug :accepts, ["html"]
  plug :fetch_session            # só pelo token de CSRF
  plug :put_root_layout, html: {TheBandWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers, @csp   # a mesma CSP de :browser, num atributo só
  plug :no_store                           # Cache-Control: no-store em toda resposta
  plug TheBandWeb.Plataforma.OperatorScope
end
```

**Emendado em 2026-10-02 por T038**: a CSP e o `no-store` são postos **também na borda do
endpoint**, antes do roteador, por `TheBandWeb.Plugs.Borda`, para todo caminho de `/platform` (e, desde a #1135, para todo caminho de tela do domínio, sem o `no-store`).
`protect_from_forgery` levanta `InvalidCSRFTokenError`, e o endpoint desenha o `403` a partir da
conexão de quando ela entrou no roteador. Medido: sem a borda, a página saía só com `content-type`,
`cache-control` padrão e `x-request-id`, sem CSP e sem `no-store`.

Responder a recusa com o `404` (um plug que resgatasse a exceção) foi tentado e recusado pelo
Sobelow (`Config.CSRF`: pipeline sem `protect_from_forgery`). Não se abre exceção em gate de
segurança para isso, e o `protect_from_forgery` literal fica.

O curinga tem uma ação para leitura (`get`) e outra para escrita (`post`, `put`, `patch` e
`delete`), e as duas respondem pela mesma função. A mesma ação nos dois é o achado
`Config.CSRFRoute`.

**A CSP é a defesa da mesma origem (A8).** O cookie `_the_band_operator` não chega ao domínio pela
rede (`Path=/platform`), mas um script da mesma origem o usa: `SameSite` não barra mesma origem, e
`http_only` impede a leitura, não o uso. Por isso toda resposta de `/platform/*` leva a CSP com
`script-src 'self'` **sem** `'unsafe-inline'` e `frame-ancestors 'none'`, e afrouxar `script-src` em
qualquer pipeline passa a ser achado alto também para o operador. O host próprio vem quando
`theband.dev` entrar em produção.

**Sem** `TheBandWeb.Plugs.CurrentScope`, sem `require_user`, sem `fetch_live_flash` de domínio.
`OperatorScope` atribui `:current_operator` e `:current_operator_session`, ou nada, e grava
`Logger.metadata(operator_id: …)`. Nunca grava `user_id` nem `tenant_id`.

## `require_operator/2`

Sem `:current_operator`, responde **`404`** com `TheBandWeb.ErrorHTML`, `"404.html"` e o layout
raiz, e para. **Não redireciona**: o visitante anônimo e o admin de uma organização recebem o mesmo
corpo de um caminho que não existe.

## A exibição única do segredo e dos códigos (seguranca-totp.md, T5)

O segredo TOTP, a URI `otpauth://` e os dez códigos de recuperação existem em claro **só no corpo
da resposta** do `POST` que os produziu (`POST /platform/setup` e `POST /platform/setup/second-factor`),
renderizada **diretamente** pelo controller (`render/3`, status `200`). Nunca passam por:

- `put_flash/3` + `redirect/2` (o hábito PRG do Phoenix): o flash mora no cookie de sessão, que é
  **só assinado** (research R3.2), e iria em base64 legível em toda requisição do domínio;
- `put_session/3`, `assign` de `Plug.Conn` que sobreviva à resposta, `Logger.metadata` ou cabeçalho;
- `redirect/2` com qualquer um deles na URL, nem `GET` que os mostre de novo.

As recusas re-renderizam o mesmo formulário **sem** eles: a do passo 2 devolve o `enrollment_token`
recebido no campo oculto, para a pessoa tentar de novo até o código vencer, e **não** mostra a chave
(protótipo 3.8, "The setup key is not shown again"); a do passo 3, com ou sem a caixa, devolve o
`acknowledgement_token` recebido e **não** mostra os códigos. Recarregar a página reenvia o `POST`
com um código já consumido, e recebe a recusa. Cenário C8 de `seguranca-totp.md`.

## As rotas

**Emendado em 2026-10-02 por T039**:

- os passos 2 e 3 levam o `email` num campo oculto, além do código do passo, porque
  `confirmar_segundo_fator/3` e `concluir_cadastro/2` recebem o e-mail. Ele não é segredo;
- `password_confirmation` diferente de `password` é conferido no controller **antes** de
  `definir_senha/3`, e o código de definição não é gasto. A frase dessa recusa, *"The two passwords
  do not match. Your setup code still works."*, não está no protótipo aprovado, e fica para a
  conferência da pessoa mantenedora;
- toda recusa de formulário responde `422`.

| método e caminho | quem | o que faz |
|---|---|---|
| `GET /platform/sign-in` | público | formulário de entrada |
| `POST /platform/session` | público | `Credentials.autenticar/3` com `email`, `password` e `second_factor_token`; recusa única; sucesso abre a sessão e vai a `/platform/organizations` |
| `GET /platform/setup` | público | formulário: e-mail, `setup_token`, `password`, confirmação |
| `POST /platform/setup` | público | `Credentials.definir_senha/3`; recusa única. Sucesso: a tela de cadastro do segundo fator, **renderizada na resposta deste `POST`** (T5), com o segredo em base32, a URI e o `enrollment_token` num campo oculto. `Cache-Control: no-store` |
| `POST /platform/setup/second-factor` | público | `Credentials.confirmar_segundo_fator/3` com `enrollment_token` e `second_factor_token`; recusa única. Sucesso: os dez códigos de recuperação, **uma vez**, **renderizados na resposta deste `POST`** (T5), o `acknowledgement_token` num campo oculto e a caixa `codes_stored` (`required`). **Não** habilita a entrada (Q3 (b); `segundo-fator-do-operador.md`, "O fluxo de cadastro"). `Cache-Control: no-store` |
| `POST /platform/setup/recovery-codes` | público | confere `codes_stored == "true"` **antes** de chamar o contexto; sem a caixa, re-renderiza a recusa da caixa **sem** consumir o passo e **sem** os códigos. Com a caixa, `Credentials.concluir_cadastro/2` com `email` e `acknowledgement_token`; recusa única. Sucesso: o segundo fator e os códigos passam a valer, e o caminho para `/platform/sign-in` |
| `DELETE /platform/session` | operador | encerra a sessão no servidor e solta o cookie |
| `GET /platform/organizations` | operador | a lista (`listar_organizacoes/1`) |
| `GET /platform/organizations/:slug` | operador | o histórico e o formulário do ato que cabe |
| `POST /platform/organizations/:slug/suspension` | operador | confere `confirm_slug` igual ao `:slug` da rota, comparação exata, **antes** de `suspender/3`; diferente ou ausente: a recusa da confirmação, e `suspender/3` não é chamada. Entrega o `:slug` a `suspender/3` **sem ler `tenants`** antes (`suspensao.md`, U1). Sucesso: **redireciona** (PRG, `302`) para `GET /platform/organizations/:slug`, e a mensagem de sucesso vai por flash, que aqui não carrega segredo; recusa do ato: re-renderiza a página, com o resumo lido **depois** do ato (achado U3) |
| `POST /platform/organizations/:slug/reactivation` | operador | a mesma conferência de `confirm_slug`, **antes** de `reativar/3`, e as mesmas respostas de sucesso e de recusa |
| `match :*, "/platform/*caminho"` | todos | **por último dentro do escopo**, na pipeline `:plataforma`, como `router.ex:118-119`: responde o mesmo `404` de `require_operator` (A12) |

Slug inexistente: o mesmo `404`, **também quando `confirm_slug` difere** (achado U4): a recusa da
confirmação re-renderiza a página, e a leitura do resumo para re-renderizá-la dá `:not_found`, que
vira o `404` antes de qualquer `422`. Organização que existe e o operador não alcança não há: o operador
alcança todas, só que só pelas colunas da FR-007.

**Limite por IP (A4) ainda não está neste contrato.** A aplicação não conhece o IP do cliente atrás
do proxy do Dokploy (`config/prod.exs:14-15`). A decisão de 2026-10-01 é medir primeiro se o Traefik
**sobrescreve** `x-forwarded-for`; só depois entram `Plug.RewriteOn` com `:x_forwarded_for` e o
limite em `POST /platform/session`, `POST /platform/setup`, `POST /platform/setup/second-factor` e
`POST /platform/setup/recovery-codes`,
com este contrato emendado **antes** do código. Sem a medição, fica só a espera por conta.

## Respostas

| caso | resposta |
|---|---|
| anônimo em rota de operador | `404` com o mesmo status, o mesmo conjunto de cabeçalhos de segurança e o mesmo corpo de `GET /platform/caminho-que-nao-existe`, **depois de retirar o `csrf-token`**, que muda a cada resposta (A12) |
| admin de organização em rota de operador | o mesmo `404` |
| `POST` sem token de CSRF, em qualquer caminho de `/platform` | o `403` de `ErrorHTML`, igual em todo caminho, com a CSP e o `no-store` da borda (T038). A frase dele (*"Your account is signed in…"*) não é verdadeira para quem não entrou, e fica para a pessoa mantenedora |
| cookie do operador em `/people`, `/api/v1/people`, `/mcp` | a recusa de quem não tem sessão: redirecionamento a `/sign-in` no navegador, `401` na API e na MCP |
| `{:error, {:throttled, _}}` em `POST /platform/session`, `/platform/setup`, `/platform/setup/second-factor` ou `/platform/setup/recovery-codes` | **a mesma** resposta de `:invalid_credentials`: frase, status e destino iguais, sem os segundos (A3; `credenciais-do-operador.md`, "Recusa única") |
| ato bem-sucedido | `302` para `GET /platform/organizations/:slug` (PRG); na requisição do `POST`, **um** `SELECT` em `tenants`, o do ato (U3) |
| ato recusado | a página re-renderizada mostra o motivo em inglês, e nada muda; **dois** `SELECT` em `tenants` na requisição: o do ato e o do resumo, lido depois dele para re-renderizar (U3) |
| `confirm_slug` diferente do slug, ou ausente | a página da organização re-renderizada, com o formulário como estava e `Not suspended. The confirmation did not match. Type <slug> exactly. Nothing changed.` (ou `Not reactivated. …`); status `422`; nenhuma função do contexto é chamada, nenhum evento de acesso (não houve tentativa do ato) |
| `codes_stored` ausente em `POST /platform/setup/recovery-codes` | a página re-renderizada com `Setup not finished. Tick the box to confirm you stored the recovery codes. The codes are not shown again: …`; o `acknowledgement_token` volta no campo oculto; o passo **não** é consumido nem conta falha; os códigos **não** reaparecem |
| `nao_autorizado` dentro de `suspender/3` ou `reativar/3` | encerra o cookie e responde `404` |
| `not_found` de `suspender/3` ou `reativar/3` | responde `404` e **não** encerra o cookie: é slug errado, e não perda do papel (`suspensao.md`, U2) |

## O que as rotas NÃO expõem, e por quê

| ausência | por quê |
|---|---|
| rota que conceda ou revogue o papel | FR-001 |
| rota sob `/organizations` | é a tela do EO (`router.ex:231`) |
| `live_session` | research R3.2; decidido em 2026-10-01 (pergunta 1 do plano, T005): o socket do LiveView só lê o cookie das organizações |
| JSON ou API do operador | não há consumidor; a FR-007 cabe numa tela |
| rota que leia dado de domínio "para suporte" | fora de escopo da spec |
| rota que mostre os códigos de recuperação de novo | só existem em claro na resposta de `POST /platform/setup/second-factor`; reenviá-los num campo oculto poria dez segredos num segundo `POST` (T012, Q3) |
| contagens de sessões e tokens no histórico | ficam no evento de acesso (T012, Q4 (b); FR-007) |
