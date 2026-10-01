# Contrato — as rotas da área do operador

FR-009, FR-011, O13, O14. Decisões em [research.md](../research.md) R3.2, R4 e R12.

> O contrato abaixo é a opção **(a)** de research R3.2: cookie próprio e controllers. Se a pessoa
> mantenedora escolher (b), este arquivo é reescrito antes do código, e os de domínio não mudam.
> A avaliação da segunda autenticação concordou com (a); a decisão ainda é da pessoa mantenedora
> (plan.md, pergunta 1), e o `tasks.md` a tem como pré-requisito das rotas.
>
> **Emendado em 2026-10-01**: A8 (a mesma origem, com CSP; decisão da pessoa mantenedora), A12 (o
> curinga do `404`) e o segundo fator (FR-016).

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

## As rotas

| método e caminho | quem | o que faz |
|---|---|---|
| `GET /platform/sign-in` | público | formulário de entrada |
| `POST /platform/session` | público | `Credentials.autenticar/3` com `email`, `password` e `second_factor_token`; recusa única; sucesso abre a sessão e vai a `/platform/organizations` |
| `GET /platform/setup` | público | formulário: e-mail, `setup_token`, `password`, confirmação |
| `POST /platform/setup` | público | `Credentials.definir_senha/3`; recusa única. Sucesso: a tela de cadastro do segundo fator, com o segredo em base32, a URI e o `enrollment_token` num campo oculto. `Cache-Control: no-store` |
| `POST /platform/setup/second-factor` | público | `Credentials.confirmar_segundo_fator/3` com `enrollment_token` e `second_factor_token`; recusa única. Sucesso: os dez códigos de recuperação, **uma vez**, e o caminho para `/platform/sign-in` |
| `DELETE /platform/session` | operador | encerra a sessão no servidor e solta o cookie |
| `GET /platform/organizations` | operador | a lista (`listar_organizacoes/1`) |
| `GET /platform/organizations/:slug` | operador | o histórico e o formulário do ato que cabe |
| `POST /platform/organizations/:slug/suspension` | operador | `suspender/3` |
| `POST /platform/organizations/:slug/reactivation` | operador | `reativar/3` |
| `match :*, "/platform/*caminho"` | todos | **por último dentro do escopo**, na pipeline `:plataforma`, como `router.ex:118-119`: responde o mesmo `404` de `require_operator` (A12) |

Slug inexistente: o mesmo `404`. Organização que existe e o operador não alcança não há: o operador
alcança todas, só que só pelas colunas da FR-007.

**Limite por IP (A4) ainda não está neste contrato.** A aplicação não conhece o IP do cliente atrás
do proxy do Dokploy (`config/prod.exs:14-15`). A decisão de 2026-10-01 é medir primeiro se o Traefik
**sobrescreve** `x-forwarded-for`; só depois entram `Plug.RewriteOn` com `:x_forwarded_for` e o
limite em `POST /platform/session`, `POST /platform/setup` e `POST /platform/setup/second-factor`,
com este contrato emendado **antes** do código. Sem a medição, fica só a espera por conta.

## Respostas

| caso | resposta |
|---|---|
| anônimo em rota de operador | `404` com o mesmo status, o mesmo conjunto de cabeçalhos de segurança e o mesmo corpo de `GET /platform/caminho-que-nao-existe`, **depois de retirar o `csrf-token`**, que muda a cada resposta (A12) |
| admin de organização em rota de operador | o mesmo `404` |
| cookie do operador em `/people`, `/api/v1/people`, `/mcp` | a recusa de quem não tem sessão: redirecionamento a `/sign-in` no navegador, `401` na API e na MCP |
| ato recusado | a tela mostra o motivo em inglês, e nada muda |
| `nao_autorizado` dentro de `suspender/3` | encerra o cookie e responde `404` |

## O que as rotas NÃO expõem, e por quê

| ausência | por quê |
|---|---|
| rota que conceda ou revogue o papel | FR-001 |
| rota sob `/organizations` | é a tela do EO (`router.ex:231`) |
| `live_session` | research R3.2; pergunta 1 do plano |
| JSON ou API do operador | não há consumidor; a FR-007 cabe numa tela |
| rota que leia dado de domínio "para suporte" | fora de escopo da spec |
