# Contrato — as rotas da área do operador

FR-009, FR-011, O13, O14. Decisões em [research.md](../research.md) R3.2, R4 e R12.

> O contrato abaixo é a opção **(a)** de research R3.2: cookie próprio e controllers. Se a pessoa
> mantenedora escolher (b), este arquivo é reescrito antes do código, e os de domínio não mudam.

## A pipeline

```elixir
pipeline :plataforma do
  plug :accepts, ["html"]
  plug :fetch_session            # só pelo token de CSRF
  plug :put_root_layout, html: {TheBandWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers, @csp   # a mesma CSP de :browser, num atributo só
  plug TheBandWeb.Plataforma.OperatorScope
end
```

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
| `POST /platform/session` | público | `Credentials.autenticar/2`; recusa única; sucesso abre a sessão e vai a `/platform/organizations` |
| `GET /platform/setup` | público | formulário: e-mail, código, senha, confirmação |
| `POST /platform/setup` | público | `Credentials.definir_senha/3`; recusa única |
| `DELETE /platform/session` | operador | encerra a sessão no servidor e solta o cookie |
| `GET /platform/organizations` | operador | a lista (`listar_organizacoes/1`) |
| `GET /platform/organizations/:slug` | operador | o histórico e o formulário do ato que cabe |
| `POST /platform/organizations/:slug/suspension` | operador | `suspender/3` |
| `POST /platform/organizations/:slug/reactivation` | operador | `reativar/3` |

Slug inexistente: o mesmo `404`. Organização que existe e o operador não alcança não há: o operador
alcança todas, só que só pelas colunas da FR-007.

## Respostas

| caso | resposta |
|---|---|
| anônimo em rota de operador | `404`, corpo idêntico ao de `GET /platform/caminho-que-nao-existe` |
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
